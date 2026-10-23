const std = @import("std");
const scene_file = @import("scene_file.zig");
const main_panels = @import("../ui/main_panels.zig");
const perf_probe = @import("perf_probe.zig");

const App = main_panels.App;

pub const LiveBench = struct {
    cfg: perf_probe.LiveBenchConfig,
    started: bool = false,
    start_ms: u64 = 0,
    start_samples: u32 = 0,
    start_frames: u32 = 0,
    frames: u32 = 0,

    pub fn load(cfg: perf_probe.LiveBenchConfig, app: *const App) !LiveBench {
        const io = std.Io.Threaded.global_single_threaded.io();
        const content = try std.Io.Dir.cwd().readFileAlloc(io, cfg.scene, app.allocator, .limited(1 << 24));
        defer app.allocator.free(content);
        var parsed = try scene_file.parseScene(app.allocator, content);
        defer parsed.deinit();
        scene_file.applyScene(
            app.allocator,
            app.gpu_ctx,
            app.fractal,
            app.camera,
            app.max_steps,
            app.max_steps_range,
            app.max_dist,
            app.max_dist_range,
            app.preview_quality,
            app.preview_quality_range,
            app.max_reflection_bounces,
            app.max_reflection_bounces_range,
            app.photon,
            app.precision,
            app.render_settings,
            app.export_width,
            app.export_height,
            app.instances,
            app.instance_count,
            app.lights,
            app.light_count,
            app.fog_emitters,
            app.fog_count,
            app.warps,
            app.warp_count,
            app.particle_systems,
            app.particle_count,
            app.screen_shaders,
            app.screen_shader_count,
            app.sky,
            app.stereo,
            app.mc,
            &app.render_parts.approx,
            app.timeline,
            parsed.value,
            .load,
        );
        app.mc.enabled = true;
        app.mc.max_samples = 1 << 20;
        std.debug.print("[bench-live] scene={s} seconds={d:.0} warmup={d} samples\n", .{ cfg.scene, cfg.seconds, cfg.warmup_samples });
        return .{ .cfg = cfg };
    }

    pub fn tick(self: *LiveBench, samples: u32, ready: bool, now_ms: u64) bool {
        self.frames += 1;
        if (!self.started) {
            if (ready and samples >= self.cfg.warmup_samples) {
                self.started = true;
                self.start_ms = now_ms;
                self.start_samples = samples;
                self.start_frames = self.frames;
            }
            return false;
        }
        const elapsed_ms = now_ms -| self.start_ms;
        if (@as(f32, @floatFromInt(elapsed_ms)) < self.cfg.seconds * 1000) return false;
        const secs = @as(f64, @floatFromInt(elapsed_ms)) / 1000;
        const done = samples -| self.start_samples;
        const frames = self.frames - self.start_frames;
        std.debug.print("[bench-live] RESULT {d} samples in {d:.2}s = {d:.1} samples/s, {d} frames = {d:.1} fps, {d:.2} samples/frame\n", .{
            done,
            secs,
            @as(f64, @floatFromInt(done)) / secs,
            frames,
            @as(f64, @floatFromInt(frames)) / secs,
            @as(f64, @floatFromInt(done)) / @as(f64, @floatFromInt(@max(frames, 1))),
        });
        return true;
    }
};
