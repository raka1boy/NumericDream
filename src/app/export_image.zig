const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const file_dialog = @import("../bindings/file_dialog.zig");
const stbiw = @import("../bindings/stb_image_write.zig").c;
const jpeg_quality: c_int = 92;

pub const max_path_len: usize = 512;

pub const min_export_dim: i32 = 16;
pub const max_export_dim: i32 = 16384;

const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const Uniforms = fractal_gpu.Uniforms;
const RenderProgress = fractal_gpu.RenderProgress;
const GpuFractalInstance = fractal_gpu.FractalInstance;
const GpuLight = fractal_gpu.Light;
const GpuFogEmitter = fractal_gpu.FogEmitter;
const GpuWarp = fractal_gpu.Warp;
const max_instances = fractal_gpu.max_instances;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const progress_overlay_mod = @import("../gpu/progress_overlay.zig");
const ProgressOverlay = progress_overlay_mod.ProgressOverlay;

const camera_mod = @import("camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const CameraBasis = camera_mod.CameraBasis;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
const StereoState = @import("stereo.zig").StereoState;
const MarchPrecision = @import("render_precision.zig").MarchPrecision;
const McRenderState = @import("mc_render.zig").McRenderState;
const PhotonSettings = @import("photon_state.zig").PhotonSettings;

pub var quit_requested: bool = false;
pub var cancel_requested: bool = false;
const progress_redraw_interval_ms = 100;

pub const ProgressCtx = struct {
    overlay: *ProgressOverlay,
    gpu_ctx: *Context,
    last_draw_ms: u64 = 0,
};

pub fn onProgress(frac: f32, userdata: ?*anyopaque) void {
    const pc: *ProgressCtx = @ptrCast(@alignCast(userdata.?));
    const btn = progress_overlay_mod.cancelButtonRect(pc.gpu_ctx.width, pc.gpu_ctx.height);

    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {
        switch (event.type) {
            sdl.SDL_EVENT_QUIT => quit_requested = true,
            sdl.SDL_EVENT_KEY_DOWN => {
                if (event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) cancel_requested = true;
            },
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                if (event.button.button == sdl.SDL_BUTTON_LEFT and
                    event.button.x >= btn.x0 and event.button.x <= btn.x1 and
                    event.button.y >= btn.y0 and event.button.y <= btn.y1)
                {
                    cancel_requested = true;
                }
            },
            else => {},
        }
    }

    var mx: f32 = -1;
    var my: f32 = -1;
    _ = sdl.SDL_GetMouseState(&mx, &my);
    const hover = mx >= btn.x0 and mx <= btn.x1 and my >= btn.y0 and my <= btn.y1;

    const now: u64 = @intCast(sdl.SDL_GetTicks());
    if (frac < 0.999 and now -| pc.last_draw_ms < progress_redraw_interval_ms) return;
    pc.last_draw_ms = now;
    pc.overlay.draw(pc.gpu_ctx, frac, hover);
}

pub fn buildUniforms(
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    camera: FreeCamera,
    eye: CameraBasis,
    max_steps: f32,
    max_dist: f32,
    max_reflection_bounces: f32,
    photon: PhotonSettings,
    precision: MarchPrecision,
    mc: McRenderState,
    fog_samples: f32,
    width: u32,
    height: u32,
) Uniforms {
    var uniforms = Uniforms{
        .camera_pos = .{ eye.pos.x, eye.pos.y, eye.pos.z },
        .time = 0.0,
        .camera_right = .{ eye.right.x, eye.right.y, eye.right.z },
        .max_steps = max_steps,
        .camera_up = .{ eye.up.x, eye.up.y, eye.up.z },
        .max_dist = max_dist,
        .camera_forward = .{ eye.forward.x, eye.forward.y, eye.forward.z },
        .instance_count = @floatFromInt(instances.len),
        .resolution = .{ @floatFromInt(width), @floatFromInt(height) },
        .light_count = @floatFromInt(lights.len),
        .max_reflection_bounces = max_reflection_bounces,
        .light_bounces = photon.bounces,
        .high_quality = 1.0,
        .epsilon_coefficient = precision.epsilon_coefficient,
        .epsilon_floor = precision.epsilon_floor,
        .hq_footprint_budget_px = precision.hq_footprint_budget_px,
        .refine_fast = precision.refine_fast,
        .refine_hq = precision.refine_hq,
        .dof_enabled = if (camera.dof_enabled) 1.0 else 0.0,
        .focus_distance = camera.focus_distance,
        .aperture = camera.aperture,
        .focus_range = camera.focus_range,
        .fog_count = @floatFromInt(fog_emitters.len),
        .warp_count = @floatFromInt(warps.len),
        .fog_samples = @max(fog_samples, 1.0),
        .mode_2d = if (camera.mode_2d) 1.0 else 0.0,
        .slice_zoom = camera.zoom_2d,
        .mc_enabled = if (mc.enabled) 1.0 else 0.0,
        .instances = undefined,
        .lights = undefined,
        .fog_emitters = undefined,
        .warps = undefined,
    };
    for (0..max_instances) |i| {
        uniforms.instances[i] = if (i < instances.len) instances[i].toGpu() else std.mem.zeroes(GpuFractalInstance);
    }
    for (0..max_lights) |i| {
        uniforms.lights[i] = if (i < lights.len) lights[i].toGpu() else std.mem.zeroes(GpuLight);
    }
    for (0..max_fog_emitters) |i| {
        uniforms.fog_emitters[i] = if (i < fog_emitters.len) fog_emitters[i].toGpu() else std.mem.zeroes(GpuFogEmitter);
    }
    for (0..max_warps) |i| {
        uniforms.warps[i] = if (i < warps.len) warps[i].toGpu() else GpuWarp{};
    }

    return uniforms;
}

fn renderErrorStatus(buf: []u8, err: anyerror) [:0]const u8 {
    if (err == error.RenderCancelled) return std.fmt.bufPrintSentinel(buf, "Render canceled.", .{}, 0) catch "Canceled.";
    return std.fmt.bufPrintSentinel(buf, "Render failed: {s}", .{@errorName(err)}, 0) catch "Render failed.";
}

pub fn combineStereoRows(allocator: std.mem.Allocator, left: []const u8, right: []const u8, eye_width: u32, height: u32) ![]u8 {
    const final_width = eye_width * 2;
    const combined = try allocator.alloc(u8, @as(usize, final_width) * height * 4);
    const eye_stride = @as(usize, eye_width) * 4;
    const combined_stride = @as(usize, final_width) * 4;
    for (0..height) |row| {
        const dst = combined[row * combined_stride ..];
        @memcpy(dst[0..eye_stride], right[row * eye_stride ..][0..eye_stride]);
        @memcpy(dst[eye_stride..][0..eye_stride], left[row * eye_stride ..][0..eye_stride]);
    }
    return combined;
}

pub fn mcSampleCount(mc: McRenderState, mode_2d: bool) u32 {
    if (mode_2d) return 1;
    return if (mc.enabled) @intFromFloat(@max(mc.export_samples, 1)) else 1;
}

pub fn renderEye(
    allocator: std.mem.Allocator,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    camera: FreeCamera,
    eye: CameraBasis,
    max_steps: f32,
    max_dist: f32,
    max_reflection_bounces: f32,
    photon: PhotonSettings,
    precision: MarchPrecision,
    mc: McRenderState,
    fog_samples: f32,
    width: u32,
    height: u32,
    progress: RenderProgress,
) ![]u8 {
    const uniforms = buildUniforms(
        instances,
        lights,
        fog_emitters,
        warps,
        camera,
        eye,
        max_steps,
        max_dist,
        max_reflection_bounces,
        photon,
        precision,
        mc,
        fog_samples,
        width,
        height,
    );
    fractal.photon_settings = photon;
    const samples = fractal_gpu.SampleSet{ .repeat = .{ .uniforms = uniforms, .count = mcSampleCount(mc, camera.mode_2d) } };
    return fractal.renderToImage(gpu_ctx, &samples, width, height, allocator, progress);
}

pub fn exportImage(
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    camera: FreeCamera,
    max_steps: f32,
    max_dist: f32,
    max_reflection_bounces: f32,
    photon: PhotonSettings,
    precision: MarchPrecision,
    fog_samples: f32,
    export_width: i32,
    export_height: i32,
    stereo: StereoState,
    mc: McRenderState,
    progress_overlay: *ProgressOverlay,
    status_buf: []u8,
) [:0]const u8 {
    var path_buf: [max_path_len]u8 = undefined;
    const saved = file_dialog.pickSaveImageFile(window, &path_buf) orelse
        return std.fmt.bufPrintSentinel(status_buf, "Export canceled.", .{}, 0) catch "";
    if (saved.len >= path_buf.len) {
        return std.fmt.bufPrintSentinel(status_buf, "Export path too long.", .{}, 0) catch "";
    }
    path_buf[saved.len] = 0;
    const path_z: [*:0]const u8 = @ptrCast(&path_buf);
    const format = saved.format;

    cancel_requested = false;

    scene_state.drainPendingCompile(fractal, allocator);

    const eye_width: u32 = @intCast(@max(export_width, 1));
    const height: u32 = @intCast(@max(export_height, 1));
    var progress_ctx = ProgressCtx{ .overlay = progress_overlay, .gpu_ctx = gpu_ctx };
    const cam = camera.basis();

    var final_width: u32 = eye_width;
    const pixels: []u8 = blk: {
        if (!stereo.enabled) {
            break :blk renderEye(
                allocator,
                gpu_ctx,
                fractal,
                instances,
                lights,
                fog_emitters,
                warps,
                camera,
                cam,
                max_steps,
                max_dist,
                max_reflection_bounces,
                photon,
                precision,
                mc,
                fog_samples,
                eye_width,
                height,
                .{ .callback = onProgress, .userdata = &progress_ctx, .cancel_flag = &cancel_requested },
            ) catch |err| return renderErrorStatus(status_buf, err);
        }

        final_width = eye_width * 2;
        const half_sep = stereo.eye_separation * 0.5;
        const left_eye = camera_mod.stereoEyeBasis(cam, camera.mode_2d, stereo.convergence_distance, -half_sep);
        const right_eye = camera_mod.stereoEyeBasis(cam, camera.mode_2d, stereo.convergence_distance, half_sep);

        const left_pixels = renderEye(
            allocator,
            gpu_ctx,
            fractal,
            instances,
            lights,
            fog_emitters,
            warps,
            camera,
            left_eye,
            max_steps,
            max_dist,
            max_reflection_bounces,
            photon,
            precision,
            mc,
            fog_samples,
            eye_width,
            height,
            .{ .callback = onProgress, .userdata = &progress_ctx, .range_start = 0.0, .range_end = 0.5, .cancel_flag = &cancel_requested },
        ) catch |err| return renderErrorStatus(status_buf, err);
        defer allocator.free(left_pixels);

        const right_pixels = renderEye(
            allocator,
            gpu_ctx,
            fractal,
            instances,
            lights,
            fog_emitters,
            warps,
            camera,
            right_eye,
            max_steps,
            max_dist,
            max_reflection_bounces,
            photon,
            precision,
            mc,
            fog_samples,
            eye_width,
            height,
            .{ .callback = onProgress, .userdata = &progress_ctx, .range_start = 0.5, .range_end = 1.0, .cancel_flag = &cancel_requested },
        ) catch |err| return renderErrorStatus(status_buf, err);
        defer allocator.free(right_pixels);

        const combined = combineStereoRows(allocator, left_pixels, right_pixels, eye_width, height) catch {
            return std.fmt.bufPrintSentinel(status_buf, "Out of memory.", .{}, 0) catch "";
        };
        break :blk combined;
    };
    defer allocator.free(pixels);

    const sdl_format = switch (gpu_ctx.surface_format) {
        wgpu.WGPUTextureFormat_BGRA8Unorm, wgpu.WGPUTextureFormat_BGRA8UnormSrgb => sdl.SDL_PIXELFORMAT_BGRA32,
        wgpu.WGPUTextureFormat_RGBA8Unorm, wgpu.WGPUTextureFormat_RGBA8UnormSrgb => sdl.SDL_PIXELFORMAT_RGBA32,
        else => sdl.SDL_PIXELFORMAT_UNKNOWN,
    };
    if (sdl_format == sdl.SDL_PIXELFORMAT_UNKNOWN) {
        return std.fmt.bufPrintSentinel(status_buf, "Unsupported surface format for export.", .{}, 0) catch "";
    }

    const saved_ok = switch (format) {
        .bmp => blk: {
            const pitch: c_int = @intCast(final_width * 4);
            const surface = sdl.SDL_CreateSurfaceFrom(@intCast(final_width), @intCast(height), @intCast(sdl_format), pixels.ptr, pitch) orelse
                break :blk false;
            defer sdl.SDL_DestroySurface(surface);
            break :blk sdl.SDL_SaveBMP(surface, path_z);
        },
        .png, .jpeg => blk: {
            if (sdl_format == sdl.SDL_PIXELFORMAT_BGRA32) swapRedBlue(pixels);
            const w: c_int = @intCast(final_width);
            const h: c_int = @intCast(height);
            break :blk switch (format) {
                .png => stbiw.stbi_write_png(path_z, w, h, 4, pixels.ptr, w * 4) != 0,
                .jpeg => stbiw.stbi_write_jpg(path_z, w, h, 4, pixels.ptr, jpeg_quality) != 0,
                .bmp => unreachable,
            };
        },
    };
    if (!saved_ok) {
        return std.fmt.bufPrintSentinel(status_buf, "Failed to save image.", .{}, 0) catch "";
    }

    return std.fmt.bufPrintSentinel(status_buf, "Saved {d}x{d} image.", .{ final_width, height }, 0) catch "Saved.";
}

pub fn swapRedBlue(pixels: []u8) void {
    var i: usize = 0;
    while (i < pixels.len) : (i += 4) {
        const r = pixels[i];
        pixels[i] = pixels[i + 2];
        pixels[i + 2] = r;
    }
}

pub fn scaleExportResolution(export_width: *i32, export_height: *i32, factor: f32) void {
    const w: f32 = @floatFromInt(export_width.*);
    const h: f32 = @floatFromInt(export_height.*);
    export_width.* = std.math.clamp(@as(i32, @intFromFloat(@round(w * factor))), min_export_dim, max_export_dim);
    export_height.* = std.math.clamp(@as(i32, @intFromFloat(@round(h * factor))), min_export_dim, max_export_dim);
}
