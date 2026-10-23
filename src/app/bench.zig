const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const stbiw = @import("../bindings/stb_image_write.zig").c;

const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const max_instances = fractal_gpu.max_instances;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const max_particle_systems = fractal_gpu.max_particle_systems;

const perf_probe = @import("perf_probe.zig");
const BenchConfig = perf_probe.BenchConfig;
const scene_file = @import("scene_file.zig");
const scene_state = @import("scene_state.zig");
const export_image = @import("export_image.zig");
const camera_mod = @import("camera.zig");
const SliderRange = @import("slider_range.zig").SliderRange;
const particles_mod = @import("particles.zig");
const screen_shader_mod = @import("screen_shader.zig");
const animation = @import("animation.zig");
const render_precision = @import("render_precision.zig");
const AccelState = @import("accel_state.zig").AccelState;
const FogVisState = @import("fog_vis_state.zig").FogVisState;

const Scene = struct {
    camera: camera_mod.FreeCamera = camera_mod.FreeCamera.initial(),
    max_steps: f32 = 128,
    max_steps_range: SliderRange = .{ .min = 32, .max = 512 },
    max_dist: f32 = 24,
    max_dist_range: SliderRange = .{ .min = 4, .max = 64 },
    preview_quality: f32 = 1,
    preview_quality_range: SliderRange = .{ .min = 0.1, .max = 1 },
    max_reflection_bounces: f32 = 1,
    max_reflection_bounces_range: SliderRange = .{ .min = 0, .max = 8 },
    photon: @import("photon_state.zig").PhotonSettings = .{},
    precision: render_precision.MarchPrecision = .{},
    render_settings: render_precision.RenderSettingsState = .{},
    export_width: i32 = 0,
    export_height: i32 = 0,
    instances: [max_instances]scene_state.FractalInstanceState = undefined,
    instance_count: usize = 0,
    lights: [max_lights]scene_state.LightState = undefined,
    light_count: usize = 0,
    fog_emitters: [max_fog_emitters]scene_state.FogEmitterState = undefined,
    fog_count: usize = 0,
    warps: [max_warps]@import("warp.zig").WarpState = undefined,
    warp_count: usize = 0,
    particle_systems: [max_particle_systems]particles_mod.ParticleSystemState = undefined,
    particle_count: usize = 0,
    screen_shaders: [screen_shader_mod.max_screen_shaders]screen_shader_mod.ScreenShaderState = undefined,
    screen_shader_count: usize = 0,
    sky: @import("sky.zig").SkyState = .{},
    stereo: @import("stereo.zig").StereoState = .{},
    mc: @import("mc_render.zig").McRenderState = .{},
    approx: @import("approximations.zig").Approximations = .{},
    timeline: animation.TimelineState = .{},
};

const Result = struct {
    pixels: []u8,
    total_ms: f64,
    march_ms: f64,
};

fn ignoreProgress(_: f32, _: ?*anyopaque) void {
    var event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&event)) {}
}

fn nowMs() f64 {
    return @as(f64, @floatFromInt(sdl.SDL_GetTicksNS())) / std.time.ns_per_ms;
}

fn loadInto(allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, path: []const u8, s: *Scene) !void {
    const io = std.Io.Threaded.global_single_threaded.io();
    const content = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1 << 24));
    defer allocator.free(content);
    var parsed = try scene_file.parseScene(allocator, content);
    defer parsed.deinit();
    scene_file.applyScene(
        allocator,
        gpu_ctx,
        fractal,
        &s.camera,
        &s.max_steps,
        &s.max_steps_range,
        &s.max_dist,
        &s.max_dist_range,
        &s.preview_quality,
        &s.preview_quality_range,
        &s.max_reflection_bounces,
        &s.max_reflection_bounces_range,
        &s.photon,
        &s.precision,
        &s.render_settings,
        &s.export_width,
        &s.export_height,
        &s.instances,
        &s.instance_count,
        &s.lights,
        &s.light_count,
        &s.fog_emitters,
        &s.fog_count,
        &s.warps,
        &s.warp_count,
        &s.particle_systems,
        &s.particle_count,
        &s.screen_shaders,
        &s.screen_shader_count,
        &s.sky,
        &s.stereo,
        &s.mc,
        &s.approx,
        &s.timeline,
        parsed.value,
        .load,
    );
}

fn render(allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, s: *const Scene, width: u32, height: u32, samples: u32) !Result {
    var mc = s.mc;
    mc.enabled = true;
    mc.export_samples = @floatFromInt(samples);
    mc.denoise = false;
    const rs = s.render_settings;
    const started = nowMs();
    const pixels = try export_image.renderEye(
        allocator,
        gpu_ctx,
        fractal,
        s.instances[0..s.instance_count],
        s.lights[0..s.light_count],
        s.fog_emitters[0..s.fog_count],
        s.warps[0..s.warp_count],
        s.particle_systems[0..s.particle_count],
        s.camera,
        s.camera.basis(),
        rs.max_steps,
        rs.max_dist,
        rs.max_reflection_bounces,
        s.photon,
        rs.precision,
        mc,
        rs.fog_samples,
        width,
        height,
        .{ .callback = ignoreProgress },
    );
    return .{ .pixels = pixels, .total_ms = nowMs() - started, .march_ms = fractal.last_march_ms };
}

fn savePng(allocator: std.mem.Allocator, gpu_ctx: *const Context, dir: []const u8, name: []const u8, pixels: []const u8, width: u32, height: u32) void {
    const copy = allocator.dupe(u8, pixels) catch return;
    defer allocator.free(copy);
    const bgra = gpu_ctx.surface_format == wgpu.WGPUTextureFormat_BGRA8Unorm or gpu_ctx.surface_format == wgpu.WGPUTextureFormat_BGRA8UnormSrgb;
    if (bgra) export_image.swapRedBlue(copy);
    var i: usize = 3;
    while (i < copy.len) : (i += 4) copy[i] = 255;
    var path_buf: [600]u8 = undefined;
    const path = std.fmt.bufPrintSentinel(&path_buf, "{s}/{s}.png", .{ dir, name }, 0) catch return;
    const w: c_int = @intCast(width);
    if (stbiw.stbi_write_png(path.ptr, w, @intCast(height), 4, copy.ptr, w * 4) == 0) {
        std.debug.print("[bench] could not write {s}\n", .{path});
    } else {
        std.debug.print("[bench] wrote {s}\n", .{path});
    }
}

const Diff = struct { mean_abs: f64, rmse: f64, psnr: f64, over8: f64, max: u8, bias: [3]f64 };

fn diffImages(allocator: std.mem.Allocator, a: []const u8, b: []const u8, out: ?*[]u8) Diff {
    var sum_abs: f64 = 0;
    var sum_sq: f64 = 0;
    var over: usize = 0;
    var max_d: u8 = 0;
    var signed: [3]f64 = @splat(0);
    const pixels = a.len / 4;
    var img: []u8 = &.{};
    if (out != null) img = allocator.alloc(u8, a.len) catch &.{};
    for (0..pixels) |p| {
        var worst: u8 = 0;
        for (0..3) |c| {
            const x = a[p * 4 + c];
            const y = b[p * 4 + c];
            const d: u8 = if (x > y) x - y else y - x;
            signed[c] += @as(f64, @floatFromInt(y)) - @as(f64, @floatFromInt(x));
            sum_abs += @floatFromInt(d);
            sum_sq += @as(f64, @floatFromInt(d)) * @as(f64, @floatFromInt(d));
            worst = @max(worst, d);
            if (img.len > 0) img[p * 4 + c] = @intCast(@min(@as(u32, d) * 8, 255));
        }
        if (img.len > 0) img[p * 4 + 3] = 255;
        if (worst > 8) over += 1;
        max_d = @max(max_d, worst);
    }
    if (out) |o| o.* = img;
    const n: f64 = @floatFromInt(pixels * 3);
    const per_channel: f64 = @floatFromInt(@max(pixels, 1));
    const mse = sum_sq / @max(n, 1);
    return .{
        .mean_abs = sum_abs / @max(n, 1),
        .rmse = @sqrt(mse),
        .psnr = if (mse > 0) 10 * std.math.log10(255.0 * 255.0 / mse) else std.math.inf(f64),
        .over8 = 100 * @as(f64, @floatFromInt(over)) / @as(f64, @floatFromInt(@max(pixels, 1))),
        .max = max_d,
        .bias = .{ signed[0] / per_channel, signed[1] / per_channel, signed[2] / per_channel },
    };
}

fn printDiff(label: []const u8, d: Diff) void {
    std.debug.print("[bench] {s}: mean|d|={d:.3} rmse={d:.3} psnr={d:.1}dB pixels>8={d:.3}% max={d} bias(b-a)=({d:.3},{d:.3},{d:.3})\n", .{ label, d.mean_abs, d.rmse, d.psnr, d.over8, d.max, d.bias[0], d.bias[1], d.bias[2] });
}

fn timedMode(allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, s: *const Scene, cfg: BenchConfig, wave: bool) !Result {
    fractal.wavefront = wave;
    const label = if (wave) "wavefront" else "megakernel";
    const warm = try render(allocator, gpu_ctx, fractal, s, 64, 64, 2);
    allocator.free(warm.pixels);
    if (fractal.last_used_wavefront != wave) {
        std.debug.print("[bench] {s} unavailable on this device/scene\n", .{label});
        return error.ModeUnavailable;
    }

    var best: ?Result = null;
    for (0..cfg.repeats) |r| {
        const one = try render(allocator, gpu_ctx, fractal, s, cfg.width, cfg.height, cfg.samples);
        std.debug.print("[bench] {s} run {d}: total {d:.0}ms, sample passes {d:.0}ms ({d:.2}ms/sample)\n", .{
            label, r + 1, one.total_ms, one.march_ms, one.march_ms / @as(f64, @floatFromInt(cfg.samples)),
        });
        if (best == null or one.march_ms < best.?.march_ms) {
            if (best) |b| allocator.free(b.pixels);
            best = one;
        } else {
            allocator.free(one.pixels);
        }
    }
    if (cfg.profile) {
        if (fractal_gpu.wavefront.Profile.init(gpu_ctx)) |p| {
            fractal.profile = p;
            defer {
                fractal.profile.?.deinit();
                fractal.profile = null;
            }
            const profiled = try render(allocator, gpu_ctx, fractal, s, cfg.width, cfg.height, cfg.samples);
            allocator.free(profiled.pixels);
            std.debug.print("[bench] profiled {s} run: {d:.0}ms wall\n", .{ label, profiled.march_ms });
            fractal.profile.?.report();
        } else {
            std.debug.print("[bench] timestamp queries unavailable; no wavefront profile\n", .{});
        }
    }
    return best.?;
}

pub fn run(allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, cfg: BenchConfig) !void {
    std.debug.print("[bench] scene={s} size={d}x{d} samples={d} repeats={d} mode={s}\n", .{ cfg.scene, cfg.width, cfg.height, cfg.samples, cfg.repeats, @tagName(cfg.mode) });
    std.debug.print("[bench] limits: maxBindGroups={d} maxStorageBuffersPerShaderStage={d} maxStorageBufferBindingSize={d} maxComputeInvocationsPerWorkgroup={d}\n", .{
        gpu_ctx.limits.maxBindGroups,
        gpu_ctx.limits.maxStorageBuffersPerShaderStage,
        gpu_ctx.limits.maxStorageBufferBindingSize,
        gpu_ctx.limits.maxComputeInvocationsPerWorkgroup,
    });

    const scene = try allocator.create(Scene);
    defer allocator.destroy(scene);
    scene.* = .{};
    try loadInto(allocator, gpu_ctx, fractal, cfg.scene, scene);

    const needs = particles_mod.shaderNeeds(scene.particle_systems[0..scene.particle_count]);
    fractal.setViewNeeds(true, false);
    const compile_start = nowMs();
    try fractal.rebuild(gpu_ctx, allocator, scene_state.sceneFormulas(scene.instances[0..scene.instance_count]), .{
        .warps = scene.warp_count > 0,
        .particles_lit = needs.lit,
        .particles_dots = needs.dots,
    });
    scene_state.finishCompileFor(fractal, allocator, scene.instances[0..scene.instance_count]);
    scene_state.syncImages(gpu_ctx, fractal, scene.instances[0..scene.instance_count]);
    std.debug.print("[bench] shader ready in {d:.0}ms\n", .{nowMs() - compile_start});

    const accel = AccelState{};
    const fog_vis = FogVisState{};
    fractal.accel_enabled = accel.enabled;
    fractal.accel_safety = accel.safety;
    fractal.fog_vis_enabled = fog_vis.enabled;
    fractal.fog_vis_resolution = fog_vis.resolutionU32();
    fractal.sky_settings = scene.sky;
    fractal.approx_settings = scene.approx;
    fractal.setPostEffects(&.{});

    const io = std.Io.Threaded.global_single_threaded.io();
    std.Io.Dir.cwd().createDirPath(io, cfg.out_dir) catch |err| {
        std.debug.print("[bench] could not create {s} ({s}); images will not be saved\n", .{ cfg.out_dir, @errorName(err) });
    };

    var mega: ?Result = null;
    defer if (mega) |m| allocator.free(m.pixels);
    var wave: ?Result = null;
    defer if (wave) |w| allocator.free(w.pixels);

    if (cfg.mode != .wave) {
        mega = try timedMode(allocator, gpu_ctx, fractal, scene, cfg, false);
        savePng(allocator, gpu_ctx, cfg.out_dir, "megakernel", mega.?.pixels, cfg.width, cfg.height);
    }
    if (cfg.mode != .mega) {
        wave = timedMode(allocator, gpu_ctx, fractal, scene, cfg, true) catch |err| blk: {
            if (err != error.ModeUnavailable) return err;
            break :blk null;
        };
        if (wave) |w| savePng(allocator, gpu_ctx, cfg.out_dir, "wavefront", w.pixels, cfg.width, cfg.height);
    }

    if (mega != null and wave != null) {
        const m = mega.?;
        const w = wave.?;
        std.debug.print("[bench] RESULT megakernel {d:.0}ms vs wavefront {d:.0}ms sample passes -> speedup x{d:.2} (totals {d:.0} vs {d:.0}ms)\n", .{
            m.march_ms, w.march_ms, m.march_ms / @max(w.march_ms, 0.001), m.total_ms, w.total_ms,
        });
        var diff_img: []u8 = &.{};
        const d = diffImages(allocator, m.pixels, w.pixels, &diff_img);
        defer if (diff_img.len > 0) allocator.free(diff_img);
        printDiff("megakernel vs wavefront", d);
        if (diff_img.len > 0) savePng(allocator, gpu_ctx, cfg.out_dir, "diff_x8", diff_img, cfg.width, cfg.height);
    }
    fractal.wavefront = false;
}
