//requires ffmpeg in order to compile frames into actual video.
const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const file_dialog = @import("../bindings/file_dialog.zig");
const stbiw = @import("../bindings/stb_image_write.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;

const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const Uniforms = fractal_gpu.Uniforms;
const SampleSet = fractal_gpu.SampleSet;
const RenderProgress = fractal_gpu.RenderProgress;

const camera_mod = @import("camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const CameraBasis = camera_mod.CameraBasis;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const StereoState = @import("stereo.zig").StereoState;
const RenderSettingsState = @import("render_precision.zig").RenderSettingsState;
const McRenderState = @import("mc_render.zig").McRenderState;
const PhotonSettings = @import("photon_state.zig").PhotonSettings;
const ProgressOverlay = @import("../gpu/progress_overlay.zig").ProgressOverlay;

const animation = @import("animation.zig");
const TimelineState = animation.TimelineState;

const export_image = @import("export_image.zig");

const max_instances = fractal_gpu.max_instances;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const WarpState = @import("warp.zig").WarpState;

pub fn renderAnimation(
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    timeline: *const TimelineState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    lights: []const LightState,
    light_count: usize,
    fog_emitters: []const FogEmitterState,
    fog_count: usize,
    warps: []const WarpState,
    warp_count: usize,
    camera: FreeCamera,
    render_settings: RenderSettingsState,
    photon: PhotonSettings,
    stereo: StereoState,
    mc: McRenderState,
    fps: f32,
    out_width: i32,
    out_height: i32,
    fog_samples: f32,
    motion_blur: f32,
    motion_blur_samples: f32,
    save_frames: bool,
    progress_overlay: *ProgressOverlay,
    status_buf: []u8,
) [:0]const u8 {
    if (timeline.keyframe_count == 0) {
        return std.fmt.bufPrintSentinel(status_buf, "No keyframes to render.", .{}, 0) catch "";
    }

    var folder_buf: [export_image.max_path_len]u8 = undefined;
    const folder_len = file_dialog.pickFolder(window, &folder_buf) orelse
        return std.fmt.bufPrintSentinel(status_buf, "Render canceled.", .{}, 0) catch "";
    if (folder_len >= folder_buf.len) {
        return std.fmt.bufPrintSentinel(status_buf, "Output folder path too long.", .{}, 0) catch "";
    }
    const folder = folder_buf[0..folder_len];

    export_image.cancel_requested = false;
    scene_state.drainPendingCompile(fractal, allocator);

    const safe_fps = @max(fps, 1.0);
    const frame_count: u32 = @intFromFloat(@floor(timeline.duration * safe_fps) + 1);
    const w: u32 = @intCast(@max(out_width, 1));
    const h: u32 = @intCast(@max(out_height, 1));

    var progress_ctx = export_image.ProgressCtx{ .overlay = progress_overlay, .gpu_ctx = gpu_ctx };
    const mc_samples = export_image.mcSampleCount(mc, camera.mode_2d);
    const blur_enabled = motion_blur > 0.0005 and timeline.keyframe_count > 1;
    const sample_count: u32 = if (blur_enabled)
        @max(mc_samples, @as(u32, @intFromFloat(@max(motion_blur_samples, 1))))
    else
        mc_samples;

    const sample_buf: []Uniforms = if (blur_enabled)
        allocator.alloc(Uniforms, sample_count) catch
            return std.fmt.bufPrintSentinel(status_buf, "Out of memory.", .{}, 0) catch ""
    else
        &.{};
    defer if (sample_buf.len > 0) allocator.free(sample_buf);

    const frame_render = FrameRender{
        .allocator = allocator,
        .gpu_ctx = gpu_ctx,
        .fractal = fractal,
        .timeline = timeline,
        .instances = instances[0..instance_count],
        .lights = lights[0..light_count],
        .fog_emitters = fog_emitters[0..fog_count],
        .warps = warps[0..warp_count],
        .camera = camera,
        .render_settings = render_settings,
        .photon = photon,
        .stereo = stereo,
        .mc = mc,
        .fog_samples = fog_samples,
        .width = w,
        .height = h,
        .shutter = if (blur_enabled) motion_blur / safe_fps else 0,
        .sample_count = sample_count,
        .sample_buf = sample_buf,
    };

    const pix_fmt: []const u8 = switch (gpu_ctx.surface_format) {
        wgpu.WGPUTextureFormat_BGRA8Unorm, wgpu.WGPUTextureFormat_BGRA8UnormSrgb => "bgra",
        else => "rgba",
    };
    const final_width_hint: u32 = if (stereo.enabled) w * 2 else w;

    var pipe = startFfmpegPipe(folder, safe_fps, final_width_hint, h, pix_fmt);
    const write_pngs = save_frames or pipe == null;

    var frames_written: u32 = 0;
    var aborted = false;
    var pipe_failed = false;

    for (0..frame_count) |f| {
        if (export_image.quit_requested or export_image.cancel_requested) {
            aborted = true;
            break;
        }

        const t = @min(@as(f32, @floatFromInt(f)) / safe_fps, timeline.duration);
        const range_start: f32 = @as(f32, @floatFromInt(f)) / @as(f32, @floatFromInt(frame_count));
        const range_end: f32 = @as(f32, @floatFromInt(f + 1)) / @as(f32, @floatFromInt(frame_count));

        var final_width: u32 = w;
        const pixels: []u8 = blk: {
            if (!stereo.enabled) {
                break :blk frame_render.eye(
                    t,
                    null,
                    .{ .callback = export_image.onProgress, .userdata = &progress_ctx, .range_start = range_start, .range_end = range_end, .cancel_flag = &export_image.cancel_requested },
                ) catch {
                    aborted = true;
                    break :blk &.{};
                };
            }

            final_width = w * 2;
            const half_sep = stereo.eye_separation * 0.5;
            const mid = (range_start + range_end) * 0.5;

            const left_pixels = frame_render.eye(
                t,
                -half_sep,
                .{ .callback = export_image.onProgress, .userdata = &progress_ctx, .range_start = range_start, .range_end = mid, .cancel_flag = &export_image.cancel_requested },
            ) catch {
                aborted = true;
                break :blk &.{};
            };
            defer allocator.free(left_pixels);

            const right_pixels = frame_render.eye(
                t,
                half_sep,
                .{ .callback = export_image.onProgress, .userdata = &progress_ctx, .range_start = mid, .range_end = range_end, .cancel_flag = &export_image.cancel_requested },
            ) catch {
                aborted = true;
                break :blk &.{};
            };
            defer allocator.free(right_pixels);

            const combined = export_image.combineStereoRows(allocator, left_pixels, right_pixels, w, h) catch {
                aborted = true;
                break :blk &.{};
            };
            break :blk combined;
        };
        if (aborted) break;
        defer allocator.free(pixels);

        if (pipe) |*p| {
            if (!p.writeFrame(pixels)) {
                pipe_failed = true;
                aborted = true;
                break;
            }
        }

        if (write_pngs) {
            const sdl_format = switch (gpu_ctx.surface_format) {
                wgpu.WGPUTextureFormat_BGRA8Unorm, wgpu.WGPUTextureFormat_BGRA8UnormSrgb => sdl.SDL_PIXELFORMAT_BGRA32,
                else => sdl.SDL_PIXELFORMAT_RGBA32,
            };
            if (sdl_format == sdl.SDL_PIXELFORMAT_BGRA32) export_image.swapRedBlue(pixels);

            var path_buf: [560]u8 = undefined;

            const path_z = std.fmt.bufPrintSentinel(&path_buf, "{s}{c}frame_{d:0>5}.png", .{ folder, std.fs.path.sep, f + 1 }, 0) catch {
                aborted = true;
                break;
            };
            const wpx: c_int = @intCast(final_width);
            const hpx: c_int = @intCast(h);
            _ = stbiw.stbi_write_png(path_z.ptr, wpx, hpx, 4, pixels.ptr, wpx * 4);
        }
        frames_written += 1;
    }

    const mux_result: MuxResult = if (pipe) |*p| blk: {
        const term = p.finish();
        break :blk if (pipe_failed) .failed else term;
    } else if (write_pngs)
        muxToMp4(allocator, folder, safe_fps)
    else
        .not_found;

    if (pipe_failed) {
        return std.fmt.bufPrintSentinel(status_buf, "ffmpeg stopped accepting frames after {d}/{d}. Render halted.", .{ frames_written, frame_count }, 0) catch "ffmpeg pipe failed.";
    }
    if (aborted) {
        return std.fmt.bufPrintSentinel(status_buf, "Rendered {d}/{d} frames to {s} (canceled).", .{ frames_written, frame_count, folder }, 0) catch "Canceled.";
    }

    const dest: []const u8 = if (write_pngs) "frames + anim.mp4" else "anim.mp4";
    return switch (mux_result) {
        .muxed => std.fmt.bufPrintSentinel(status_buf, "Rendered {d} frames to {s} ({s}).", .{ frames_written, folder, dest }, 0) catch "Saved.",
        .not_found => std.fmt.bufPrintSentinel(status_buf, "Saved {d} frames to {s}. ffmpeg not found on PATH -- mp4 muxing skipped.", .{ frames_written, folder }, 0) catch "Saved.",
        .failed => std.fmt.bufPrintSentinel(status_buf, "Saved {d} frames to {s}. ffmpeg mux failed.", .{ frames_written, folder }, 0) catch "Saved.",
    };
}

const FrameScene = struct {
    instances: [max_instances]FractalInstanceState,
    lights: [max_lights]LightState,
    fog_emitters: [max_fog_emitters]FogEmitterState,
    warps: [max_warps]WarpState,
    camera: FreeCamera,
    instance_count: usize,
    light_count: usize,
    fog_count: usize,
    warp_count: usize,
};

const FrameRender = struct {
    allocator: std.mem.Allocator,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    timeline: *const TimelineState,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    camera: FreeCamera,
    render_settings: RenderSettingsState,
    photon: PhotonSettings,
    stereo: StereoState,
    mc: McRenderState,
    fog_samples: f32,
    width: u32,
    height: u32,
    shutter: f32,
    sample_count: u32,
    sample_buf: []Uniforms,
    fn sceneAt(self: *const FrameRender, t: f32, out: *FrameScene) void {
        out.instance_count = self.instances.len;
        out.light_count = self.lights.len;
        out.fog_count = self.fog_emitters.len;
        out.warp_count = self.warps.len;
        for (self.instances, 0..) |inst, i| out.instances[i] = inst;
        for (self.lights, 0..) |light, i| out.lights[i] = light;
        for (self.fog_emitters, 0..) |fog, i| out.fog_emitters[i] = fog;
        for (self.warps, 0..) |w, i| out.warps[i] = w;
        out.camera = self.camera;

        const snap = animation.evaluate(self.timeline, t);
        animation.applySnapshot(
            &snap,
            out.instances[0..out.instance_count],
            out.instance_count,
            out.lights[0..out.light_count],
            out.light_count,
            out.fog_emitters[0..out.fog_count],
            out.fog_count,
            out.warps[0..out.warp_count],
            out.warp_count,
            &out.camera,
        );
    }
    fn basisFor(self: *const FrameRender, scene: *const FrameScene, half_sep: ?f32) CameraBasis {
        const cam = scene.camera.basis();
        const sep = half_sep orelse return cam;
        return camera_mod.stereoEyeBasis(cam, scene.camera.mode_2d, self.stereo.convergence_distance, sep);
    }

    fn uniformsFor(self: *const FrameRender, scene: *const FrameScene, half_sep: ?f32) Uniforms {
        return export_image.buildUniforms(
            scene.instances[0..scene.instance_count],
            scene.lights[0..scene.light_count],
            scene.fog_emitters[0..scene.fog_count],
            scene.warps[0..scene.warp_count],
            scene.camera,
            self.basisFor(scene, half_sep),
            self.render_settings.max_steps,
            self.render_settings.max_dist,
            self.render_settings.max_reflection_bounces,
            self.photon,
            self.render_settings.precision,
            self.mc,
            self.fog_samples,
            self.width,
            self.height,
        );
    }

    fn eye(self: *const FrameRender, t: f32, half_sep: ?f32, progress: RenderProgress) ![]u8 {
        var scene: FrameScene = undefined;

        self.fractal.photon_settings = self.photon;

        if (self.shutter <= 0) {
            self.sceneAt(t, &scene);
            const samples = SampleSet{ .repeat = .{ .uniforms = self.uniformsFor(&scene, half_sep), .count = self.sample_count } };
            return self.fractal.renderToImage(self.gpu_ctx, &samples, self.width, self.height, self.allocator, progress);
        }

        const n: f32 = @floatFromInt(self.sample_count);
        for (0..self.sample_count) |s| {
            const offset = ((@as(f32, @floatFromInt(s)) + 0.5) / n - 0.5) * self.shutter;
            self.sceneAt(t + offset, &scene);
            self.sample_buf[s] = self.uniformsFor(&scene, half_sep);
        }
        const samples = SampleSet{ .per_sample = self.sample_buf[0..self.sample_count] };
        return self.fractal.renderToImage(self.gpu_ctx, &samples, self.width, self.height, self.allocator, progress);
    }
};

const MuxResult = enum { muxed, not_found, failed };

const FfmpegPipe = struct {
    child: std.process.Child,
    io: std.Io,

    fn writeFrame(self: *FfmpegPipe, bytes: []const u8) bool {
        const stdin = self.child.stdin orelse return false;
        stdin.writeStreamingAll(self.io, bytes) catch return false;
        return true;
    }

    fn finish(self: *FfmpegPipe) MuxResult {
        if (self.child.stdin) |stdin| {
            stdin.close(self.io);
            self.child.stdin = null;
        }
        const term = self.child.wait(self.io) catch return .failed;
        return switch (term) {
            .exited => |code| if (code == 0) .muxed else .failed,
            else => .failed,
        };
    }
};

fn startFfmpegPipe(folder: []const u8, fps: f32, width: u32, height: u32, pix_fmt: []const u8) ?FfmpegPipe {
    const io = std.Io.Threaded.global_single_threaded.io();

    var fps_buf: [32]u8 = undefined;
    const fps_str = std.fmt.bufPrint(&fps_buf, "{d}", .{fps}) catch return null;
    var size_buf: [32]u8 = undefined;
    const size_str = std.fmt.bufPrint(&size_buf, "{d}x{d}", .{ width, height }) catch return null;

    const child = std.process.spawn(io, .{
        .argv = &.{
            "ffmpeg",        "-y",
            "-f",            "rawvideo",
            "-pixel_format", pix_fmt,
            "-video_size",   size_str,
            "-framerate",    fps_str,
            "-i",            "-",
            "-vf",           "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:v",          "libx264",
            "-pix_fmt",      "yuv420p",
            "anim.mp4",
        },
        .cwd = .{ .path = folder },
        .stdin = .pipe,
        .stdout = .ignore,
        .stderr = .ignore,
        .create_no_window = true,
    }) catch return null;

    return .{ .child = child, .io = io };
}

fn muxToMp4(allocator: std.mem.Allocator, folder: []const u8, fps: f32) MuxResult {
    const io = std.Io.Threaded.global_single_threaded.io();

    var fps_buf: [32]u8 = undefined;
    const fps_str = std.fmt.bufPrint(&fps_buf, "{d}", .{fps}) catch return .failed;

    const result = std.process.run(allocator, io, .{
        .argv = &.{ "ffmpeg", "-y", "-framerate", fps_str, "-start_number", "1", "-i", "frame_%05d.png", "-c:v", "libx264", "-pix_fmt", "yuv420p", "anim.mp4" },
        .cwd = .{ .path = folder },
    }) catch |err| {
        if (err == error.FileNotFound) return .not_found;
        return .failed;
    };
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    return switch (result.term) {
        .exited => |code| if (code == 0) .muxed else .failed,
        else => .failed,
    };
}
