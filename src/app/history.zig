const std = @import("std");
const scene_file = @import("scene_file.zig");
const main_panels = @import("../ui/main_panels.zig");
const camera_mod = @import("camera.zig");

const App = main_panels.App;

const capacity = 100;
const settle_ms: u64 = 350;

pub const History = struct {
    undo_stack: [capacity][]u8 = undefined,
    undo_len: usize = 0,
    redo_stack: [capacity][]u8 = undefined,
    redo_len: usize = 0,
    current: ?[]u8 = null,
    pending_base: ?[]u8 = null,
    last_change_ms: u64 = 0,

    pub fn deinit(self: *History, allocator: std.mem.Allocator) void {
        for (self.undo_stack[0..self.undo_len]) |b| allocator.free(b);
        for (self.redo_stack[0..self.redo_len]) |b| allocator.free(b);
        if (self.current) |b| allocator.free(b);
        if (self.pending_base) |b| allocator.free(b);
        self.* = .{};
    }

    pub fn settling(self: *const History) bool {
        return self.pending_base != null;
    }

    pub fn track(self: *History, app: *const App, now_ms: u64, suspended: bool, dragging: bool) void {
        const bytes = encode(app) orelse return;
        const cur = self.current orelse {
            self.current = bytes;
            return;
        };
        if (std.mem.eql(u8, bytes, cur)) {
            app.allocator.free(bytes);
            if (self.pending_base != null and !dragging and now_ms -| self.last_change_ms >= settle_ms) self.commitPending(app.allocator);
            return;
        }
        self.current = bytes;
        if (suspended) {
            app.allocator.free(cur);
            return;
        }
        if (self.pending_base == null) {
            self.pending_base = cur;
            self.clearRedo(app.allocator);
        } else {
            app.allocator.free(cur);
        }
        self.last_change_ms = now_ms;
    }

    pub fn undo(self: *History, app: *const App) bool {
        const target = blk: {
            if (self.pending_base) |base| {
                self.pending_base = null;
                break :blk base;
            }
            if (self.undo_len == 0) return false;
            self.undo_len -= 1;
            break :blk self.undo_stack[self.undo_len];
        };
        if (self.current) |cur| self.pushRedo(app.allocator, cur);
        self.current = null;
        return self.restore(app, target);
    }

    pub fn redo(self: *History, app: *const App) bool {
        if (self.redo_len == 0) return false;
        self.commitPending(app.allocator);
        if (self.redo_len == 0) return false;
        self.redo_len -= 1;
        const target = self.redo_stack[self.redo_len];
        if (self.current) |cur| self.pushUndo(app.allocator, cur);
        self.current = null;
        return self.restore(app, target);
    }

    fn restore(self: *History, app: *const App, target: []u8) bool {
        defer app.allocator.free(target);
        var parsed = scene_file.parseScene(app.allocator, target) catch {
            self.current = encode(app);
            return false;
        };
        defer parsed.deinit();
        apply(app, parsed.value);
        self.current = encode(app);
        return true;
    }

    fn commitPending(self: *History, allocator: std.mem.Allocator) void {
        const base = self.pending_base orelse return;
        self.pending_base = null;
        self.pushUndo(allocator, base);
    }

    fn pushUndo(self: *History, allocator: std.mem.Allocator, bytes: []u8) void {
        if (self.undo_len == capacity) {
            allocator.free(self.undo_stack[0]);
            std.mem.copyForwards([]u8, self.undo_stack[0 .. capacity - 1], self.undo_stack[1..capacity]);
            self.undo_len -= 1;
        }
        self.undo_stack[self.undo_len] = bytes;
        self.undo_len += 1;
    }

    fn pushRedo(self: *History, allocator: std.mem.Allocator, bytes: []u8) void {
        if (self.redo_len == capacity) {
            allocator.free(self.redo_stack[0]);
            std.mem.copyForwards([]u8, self.redo_stack[0 .. capacity - 1], self.redo_stack[1..capacity]);
            self.redo_len -= 1;
        }
        self.redo_stack[self.redo_len] = bytes;
        self.redo_len += 1;
    }

    fn clearRedo(self: *History, allocator: std.mem.Allocator) void {
        for (self.redo_stack[0..self.redo_len]) |b| allocator.free(b);
        self.redo_len = 0;
    }
};

fn encode(app: *const App) ?[]u8 {
    var cam = app.camera.*;
    const home = camera_mod.FreeCamera.initial();
    cam.position = home.position;
    cam.forward = home.forward;
    cam.up = home.up;
    cam.zoom_2d = home.zoom_2d;
    cam.speed_multiplier = home.speed_multiplier;
    return scene_file.encodeScene(
        app.allocator,
        false,
        cam,
        app.max_steps.*,
        app.max_steps_range.*,
        app.max_dist.*,
        app.max_dist_range.*,
        app.preview_quality.*,
        app.preview_quality_range.*,
        app.max_reflection_bounces.*,
        app.max_reflection_bounces_range.*,
        app.photon.*,
        app.precision.*,
        app.render_settings.*,
        app.export_width.*,
        app.export_height.*,
        app.instances[0..app.instance_count.*],
        app.lights[0..app.light_count.*],
        app.fog_emitters[0..app.fog_count.*],
        app.warps[0..app.warp_count.*],
        app.particle_systems[0..app.particle_count.*],
        app.screen_shaders[0..app.screen_shader_count.*],
        app.sky,
        app.stereo.*,
        app.mc.*,
        app.render_parts.approx,
        app.timeline.*,
    ) catch null;
}

fn apply(app: *const App, scene: scene_file.SceneFile) void {
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
        scene,
        .undo,
    );
}
