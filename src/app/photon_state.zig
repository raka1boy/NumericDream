const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const photons = @import("../gpu/photons.zig");
const debounce = @import("debounce.zig");
const DebouncedDirty = debounce.DebouncedDirty;

pub const PhotonSettings = struct {
    enabled: bool = true,

    bounces: f32 = 2,
    bounces_range: SliderRange = .{ .min = 0, .max = 8 },

    paths: f32 = 262144,
    paths_range: SliderRange = .{ .min = 4096, .max = 2097152 },

    radius: f32 = 0.05,
    radius_range: SliderRange = .{ .min = 0.002, .max = 1.0 },

    volume_scale: f32 = 1,
    volume_scale_range: SliderRange = .{ .min = 1, .max = 6 },

    dispersion_softness: f32 = 1.0,
    dispersion_softness_range: SliderRange = .{ .min = 0, .max = 10 },

    intensity: f32 = 1.0,
    intensity_range: SliderRange = .{ .min = 0, .max = 8 },

    grid_log2: f32 = @floatFromInt(photons.default_grid_log2),
    grid_log2_range: SliderRange = .{
        .min = @floatFromInt(photons.min_grid_log2),
        .max = @floatFromInt(photons.max_grid_log2),
    },

    refine_per_sample: bool = true,

    debounce_ms: f32 = 180,
    debounce_ms_range: SliderRange = .{ .min = 0, .max = 1000 },

    pub fn cellSize(self: PhotonSettings) f32 {
        return @max(self.radius, 1e-4) * 2.0;
    }

    pub fn gridLog2(self: PhotonSettings) u32 {
        return photons.clampGridLog2(@intFromFloat(std.math.clamp(
            self.grid_log2,
            @as(f32, @floatFromInt(photons.min_grid_log2)),
            @as(f32, @floatFromInt(photons.max_grid_log2)),
        )));
    }

    pub fn pathCount(self: PhotonSettings) u32 {
        return @intFromFloat(std.math.clamp(self.paths, 0, 16_777_216));
    }

    pub fn dispersionSoftRadians(self: PhotonSettings) f32 {
        return std.math.clamp(self.dispersion_softness, 0, 90) * (std.math.pi / 180.0);
    }
};

pub const PhotonPolicy = struct {
    debounce_state: DebouncedDirty = .{},
    traced_sample: f32 = -1,
    seed: f32 = 1,
    last_trace_ms: u64 = 0,
    last_paths: u32 = 0,
};

fn hashCounted(h: *std.hash.Wyhash, count_f: f32, items: anytype) void {
    const count: usize = @intFromFloat(@max(count_f, 0));
    h.update(std.mem.asBytes(&count));
    for (items[0..@min(count, items.len)]) |*item| h.update(std.mem.asBytes(item));
}

pub fn sceneHash(uniforms: anytype, settings: PhotonSettings) u64 {
    var h = std.hash.Wyhash.init(0);
    hashCounted(&h, uniforms.instance_count, &uniforms.instances);
    hashCounted(&h, uniforms.light_count, &uniforms.lights);
    hashCounted(&h, uniforms.fog_count, &uniforms.fog_emitters);
    hashCounted(&h, uniforms.warp_count, &uniforms.warps);
    h.update(std.mem.asBytes(&uniforms.max_dist));
    h.update(std.mem.asBytes(&uniforms.sky));
    h.update(std.mem.asBytes(&settings.enabled));
    h.update(std.mem.asBytes(&settings.bounces));
    h.update(std.mem.asBytes(&settings.paths));
    h.update(std.mem.asBytes(&settings.radius));
    h.update(std.mem.asBytes(&settings.grid_log2));
    h.update(std.mem.asBytes(&settings.volume_scale));
    h.update(std.mem.asBytes(&settings.dispersion_softness));
    return h.final();
}

pub const Decision = enum { idle, retrace };

pub fn update(
    policy: *PhotonPolicy,
    map: anytype,
    settings: PhotonSettings,
    enabled: bool,
    now_ms: u64,
    hash: u64,
    camera_pos: [3]f32,
    recenter_distance: f32,
    mc_sample: f32,
) Decision {
    if (!enabled) {
        map.invalidate();
        policy.debounce_state.reset();
        policy.traced_sample = -1;
        return .idle;
    }

    if (settings.refine_per_sample and map.valid and mc_sample != policy.traced_sample) {
        return .retrace;
    }

    const extra_wants_trace = !map.valid or
        map.wantsRecap() or
        map.drift(camera_pos) > recenter_distance;
    const result = policy.debounce_state.update(extra_wants_trace, now_ms, hash, camera_pos, settings.debounce_ms);

    return switch (result.decision) {
        .idle => .idle,
        .rebuild => .retrace,
    };
}

pub fn noteTraced(policy: *PhotonPolicy, map: anytype, mc_sample: f32) void {
    policy.debounce_state.noteBuilt();
    policy.traced_sample = mc_sample;
    policy.last_trace_ms = map.last_trace_ms;
    policy.last_paths = map.last_paths;
    policy.seed = @mod(policy.seed + 1, 1_000_003);
}

pub fn noteFailed(policy: *PhotonPolicy, now_ms: u64) void {
    policy.debounce_state.noteFailed(now_ms);
}
