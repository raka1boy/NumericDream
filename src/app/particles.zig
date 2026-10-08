const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const scene_state = @import("scene_state.zig");
const ColorStopState = scene_state.ColorStopState;
const CombineMode = scene_state.CombineMode;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const GpuParticleSystem = fractal_gpu.ParticleSystem;
const GpuColorStop = fractal_gpu.ColorStop;
const particles_gpu = fractal_gpu.particles;
const SimParams = particles_gpu.SimParams;
const Job = particles_gpu.Job;
const max_color_stops = fractal_gpu.max_color_stops;

pub const max_systems = fractal_gpu.max_particle_systems;
pub const max_count = particles_gpu.max_particles;
pub const max_steps: u32 = 20000;

fn EnumLabels(comptime E: type, comptime labels: []const [:0]const u8) type {
    return struct {
        pub const all = std.enums.values(E);
        pub fn label(value: E) [:0]const u8 {
            return labels[@intFromEnum(value)];
        }
    };
}

pub const SpawnShape = enum {
    sphere,
    disc,
    rectangle,

    const L = EnumLabels(SpawnShape, &.{ "Sphere volume", "Disc", "Rectangle" });
    pub const all = L.all;
    pub const label = L.label;
};

pub const VelocityMode = enum {
    direction,
    radial,
    random,

    const L = EnumLabels(VelocityMode, &.{ "Direction + cone", "Radial from centre", "Random" });
    pub const all = L.all;
    pub const label = L.label;
};

pub const RenderMode = enum {
    spheres,
    dots,

    const L = EnumLabels(RenderMode, &.{ "Lit spheres", "Flat dots" });
    pub const all = L.all;
    pub const label = L.label;
};

pub const DotStyle = enum {
    soft_glow,
    hard_disc,

    const L = EnumLabels(DotStyle, &.{ "Soft glow", "Hard disc" });
    pub const all = L.all;
    pub const label = L.label;
};

pub const StripMode = enum {
    random,
    distance,

    const L = EnumLabels(StripMode, &.{ "Random per particle", "Distance from spawn centre" });
    pub const all = L.all;
    pub const label = L.label;
};

fn defaultColors() [max_color_stops]ColorStopState {
    var arr: [max_color_stops]ColorStopState = undefined;
    arr[0] = .{ .position = 0.0, .color = .{ 1.0, 0.55, 0.15 }, .glossiness = 0.6, .reflectiveness = 0.2 };
    arr[1] = .{ .position = 1.0, .color = .{ 0.25, 0.65, 1.0 }, .glossiness = 0.6, .reflectiveness = 0.2 };
    for (2..max_color_stops) |i| arr[i] = .{ .position = 0, .color = .{ 0.5, 0.5, 0.5 } };
    return arr;
}

pub const ParticleSystemState = struct {
    spawn_shape: SpawnShape = .disc,
    center: Vec3 = .{ .x = 0, .y = 2, .z = 0 },
    center_range_x: SliderRange = .{ .min = -10, .max = 10 },
    center_range_y: SliderRange = .{ .min = -10, .max = 10 },
    center_range_z: SliderRange = .{ .min = -10, .max = 10 },
    rotation: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    rotation_range_x: SliderRange = .{ .min = -180, .max = 180 },
    rotation_range_y: SliderRange = .{ .min = -180, .max = 180 },
    rotation_range_z: SliderRange = .{ .min = -180, .max = 180 },
    spawn_radius: f32 = 1.5,
    spawn_radius_range: SliderRange = .{ .min = 0, .max = 8 },
    extent_x: f32 = 1.5,
    extent_x_range: SliderRange = .{ .min = 0.01, .max = 10 },
    extent_z: f32 = 1.5,
    extent_z_range: SliderRange = .{ .min = 0.01, .max = 10 },

    velocity_mode: VelocityMode = .direction,
    direction: Vec3 = .{ .x = 0, .y = -1, .z = 0 },
    direction_range_x: SliderRange = .{ .min = -1, .max = 1 },
    direction_range_y: SliderRange = .{ .min = -1, .max = 1 },
    direction_range_z: SliderRange = .{ .min = -1, .max = 1 },
    spread: f32 = 5,
    spread_range: SliderRange = .{ .min = 0, .max = 180 },
    speed_min: f32 = 0.6,
    speed_min_range: SliderRange = .{ .min = 0, .max = 10 },
    speed_max: f32 = 1.0,
    speed_max_range: SliderRange = .{ .min = 0, .max = 10 },

    count: f32 = 4000,
    count_range: SliderRange = .{ .min = 1, .max = @floatFromInt(max_count) },
    seed: f32 = 1,
    seed_range: SliderRange = .{ .min = 0, .max = 1000 },
    size: f32 = 0.015,
    size_range: SliderRange = .{ .min = 0.001, .max = 0.5 },
    size_variation: f32 = 0.3,
    size_variation_range: SliderRange = .{ .min = 0, .max = 1 },

    emit_duration: f32 = 6,
    emit_duration_range: SliderRange = .{ .min = 0, .max = 30 },
    lifetime: f32 = 0,
    lifetime_range: SliderRange = .{ .min = 0, .max = 30 },

    t: f32 = 0,
    t_range: SliderRange = .{ .min = 0, .max = 10 },
    sim_rate: f32 = 60,
    sim_rate_range: SliderRange = .{ .min = 5, .max = 240 },
    kill_radius: f32 = 20,
    kill_radius_range: SliderRange = .{ .min = 0.5, .max = 100 },
    stop_on_scene: bool = true,
    stick: bool = true,

    render_mode: RenderMode = .spheres,
    dot_style: DotStyle = .soft_glow,
    glow: f32 = 1,
    glow_range: SliderRange = .{ .min = 0, .max = 8 },
    glow_extent: f32 = 3,
    glow_extent_range: SliderRange = .{ .min = 1, .max = 8 },
    combine_mode: CombineMode = .hard_union,
    blend_k: f32 = 0.02,
    blend_k_range: SliderRange = .{ .min = 0, .max = 0.5 },

    strip_mode: StripMode = .random,
    strip_span: f32 = 2,
    strip_span_range: SliderRange = .{ .min = 0.05, .max = 20 },
    strip_offset: f32 = 0,
    strip_offset_range: SliderRange = .{ .min = -1, .max = 1 },
    colors: [max_color_stops]ColorStopState = defaultColors(),
    color_count: usize = 2,
    selected_color: ?usize = null,

    window_open: bool = false,
    visible: bool = true,

    pub fn countInt(self: *const ParticleSystemState) u32 {
        return @intFromFloat(std.math.clamp(@round(self.count), 0, @as(f32, @floatFromInt(max_count))));
    }

    pub fn dt(self: *const ParticleSystemState) f32 {
        return 1.0 / std.math.clamp(self.sim_rate, 1, 10000);
    }

    pub fn targetSteps(self: *const ParticleSystemState) u32 {
        const steps = @floor(@max(self.t, 0) / self.dt() + 1e-4);
        return @intFromFloat(@min(steps, @as(f32, @floatFromInt(max_steps))));
    }

    pub fn effectiveT(self: *const ParticleSystemState) f32 {
        return @min(@max(self.t, 0), @as(f32, @floatFromInt(max_steps)) * self.dt());
    }

    fn maxRadius(self: *const ParticleSystemState) f32 {
        return @max(self.size, 1e-5) * (1 + std.math.clamp(self.size_variation, 0, 1));
    }

    fn smoothBlend(self: *const ParticleSystemState) bool {
        return switch (self.combine_mode) {
            .de_combinate, .smooth_min_lin, .smooth_min_nlin, .smooth_mix => self.blend_k > 0,
            else => false,
        };
    }

    fn insertion(self: *const ParticleSystemState) struct { mult: f32, add: f32 } {
        return switch (self.render_mode) {
            .spheres => .{ .mult = 1, .add = if (self.smoothBlend()) self.blend_k else 0 },
            .dots => .{ .mult = if (self.dot_style == .soft_glow) @max(self.glow_extent, 1) else 1, .add = 0 },
        };
    }

    fn frame(self: *const ParticleSystemState) [3]Vec3 {
        return camera_mod.eulerRotationColumns(
            std.math.degreesToRadians(self.rotation.x),
            std.math.degreesToRadians(self.rotation.y),
            std.math.degreesToRadians(self.rotation.z),
        );
    }

    pub fn simParams(self: *const ParticleSystemState) SimParams {
        const cols = self.frame();
        const dir_len = self.direction.length();
        const dir = if (dir_len > 1e-6) self.direction.scale(1 / dir_len) else Vec3{ .x = 0, .y = -1, .z = 0 };
        const ins = self.insertion();
        const r_max = self.maxRadius();
        const lo = @max(@min(self.speed_min, self.speed_max), 0);
        const hi = @max(@max(self.speed_min, self.speed_max), 0);
        return .{
            .center = .{ self.center.x, self.center.y, self.center.z },
            .count = @floatFromInt(self.countInt()),
            .axis_u = .{ cols[0].x, cols[0].y, cols[0].z },
            .spawn_radius = @max(self.spawn_radius, 0),
            .axis_v = .{ cols[2].x, cols[2].y, cols[2].z },
            .spawn_shape = @floatFromInt(@intFromEnum(self.spawn_shape)),
            .direction = .{ dir.x, dir.y, dir.z },
            .velocity_mode = @floatFromInt(@intFromEnum(self.velocity_mode)),
            .extent = .{ @max(self.extent_x, 0), @max(self.extent_z, 0) },
            .speed_min = lo,
            .speed_max = hi,
            .spread = std.math.degreesToRadians(std.math.clamp(self.spread, 0, 180)),
            .size = @max(self.size, 1e-5),
            .size_var = std.math.clamp(self.size_variation, 0, 1),
            .seed = @round(self.seed),
            .emit_duration = @max(self.emit_duration, 0),
            .lifetime = @max(self.lifetime, 0),
            .dt = self.dt(),
            .t = self.effectiveT(),
            .kill_radius = @max(self.kill_radius, 1e-3),
            .stop_scene = if (self.stop_on_scene) 1 else 0,
            .stick = if (self.stick) 1 else 0,
            .strip_mode = @floatFromInt(@intFromEnum(self.strip_mode)),
            .strip_span = @max(self.strip_span, 1e-4),
            .strip_offset = self.strip_offset,
            .sim_cell = 2 * r_max,
            .r_insert = r_max * ins.mult + ins.add,
            .insert_mult = ins.mult,
            .insert_add = ins.add,
        };
    }

    pub fn toGpu(self: *const ParticleSystemState) GpuParticleSystem {
        const order = scene_state.sortedColorOrder(&self.colors, self.color_count);
        var colors: [max_color_stops]GpuColorStop = std.mem.zeroes([max_color_stops]GpuColorStop);
        for (0..self.color_count) |i| colors[i] = self.colors[order[i]].toGpu();
        return .{
            .center = .{ self.center.x, self.center.y, self.center.z },
            .mode = if (!self.visible) 0 else switch (self.render_mode) {
                .spheres => 1,
                .dots => 2,
            },
            .dot_style = @floatFromInt(@intFromEnum(self.dot_style)),
            .glow = @max(self.glow, 0),
            .combine_mode = @floatFromInt(@intFromEnum(self.combine_mode)),
            .blend_k = @max(self.blend_k, 0),
            .color_count = @floatFromInt(self.color_count),
            .glow_extent = @max(self.glow_extent, 1),
            .colors = colors,
        };
    }
};

fn simKey(p: SimParams, geometry_hash: u64) u64 {
    var trajectory = p;
    trajectory.t = 0;
    trajectory.steps_done = 0;
    trajectory.strip_mode = 0;
    trajectory.strip_span = 0;
    trajectory.strip_offset = 0;
    trajectory.r_insert = 0;
    trajectory.insert_mult = 0;
    trajectory.insert_add = 0;
    trajectory.system = 0;
    var h = std.hash.Wyhash.init(geometry_hash);
    h.update(std.mem.asBytes(&trajectory));
    return h.final();
}

fn buildKey(p: SimParams) u64 {
    var h = std.hash.Wyhash.init(7);
    for ([_]f32{ p.t, p.strip_mode, p.strip_span, p.strip_offset, p.r_insert, p.insert_mult, p.insert_add }) |v| {
        h.update(std.mem.asBytes(&v));
    }
    return h.final();
}

pub fn buildJobs(systems: []const ParticleSystemState, geometry_hash: u64) [max_systems]?Job {
    var jobs: [max_systems]?Job = @splat(null);
    for (systems, 0..) |*sys, i| {
        if (i >= max_systems or !sys.visible) continue;
        const params = sys.simParams();
        jobs[i] = .{
            .params = params,
            .sim_key = simKey(params, if (sys.stop_on_scene) geometry_hash else 0),
            .build_key = buildKey(params),
            .target_steps = sys.targetSteps(),
        };
    }
    return jobs;
}

pub fn shaderNeeds(systems: []const ParticleSystemState) struct { lit: bool, dots: bool } {
    var lit = false;
    var dots = false;
    for (systems) |*sys| {
        if (!sys.visible) continue;
        switch (sys.render_mode) {
            .spheres => lit = true,
            .dots => dots = true,
        }
    }
    return .{ .lit = lit, .dots = dots };
}

pub fn stampUniforms(uniforms: anytype, systems: []const ParticleSystemState) void {
    for (0..max_systems) |i| {
        uniforms.particle_systems[i] = if (i < systems.len) systems[i].toGpu() else .{};
    }
}
