const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const accel = @import("../gpu/accel.zig");
const debounce = @import("debounce.zig");
const DebouncedDirty = debounce.DebouncedDirty;

pub const AccelState = struct {
    enabled: bool = true,

    resolution: f32 = @floatFromInt(accel.default_resolution),
    resolution_range: SliderRange = .{
        .min = @floatFromInt(accel.min_resolution),
        .max = @floatFromInt(accel.max_resolution),
    },

    levels: f32 = @floatFromInt(accel.default_levels),
    levels_range: SliderRange = .{ .min = 1, .max = @floatFromInt(accel.max_cascades) },

    safety: f32 = 0.92,
    safety_range: SliderRange = .{ .min = 0.5, .max = 1.0 },

    debounce_ms: f32 = 180,
    debounce_ms_range: SliderRange = .{ .min = 0, .max = 1000 },

    debounce_state: DebouncedDirty = .{},

    last_build_ms: u64 = 0,
    last_build_voxels: u64 = 0,
};

pub fn sceneHash(uniforms: anytype) u64 {
    var h = std.hash.Wyhash.init(0);
    const count: usize = @intFromFloat(@max(uniforms.instance_count, 0));
    h.update(std.mem.asBytes(&count));
    for (uniforms.instances[0..@min(count, uniforms.instances.len)]) |*inst| {
        h.update(std.mem.asBytes(inst));
    }
    const warp_count: usize = @intFromFloat(@max(uniforms.warp_count, 0));
    h.update(std.mem.asBytes(&warp_count));
    for (uniforms.warps[0..@min(warp_count, uniforms.warps.len)]) |*warp| {
        h.update(std.mem.asBytes(warp));
    }
    return h.final();
}

pub const Decision = enum {
    idle,
    rebuild,
};

pub fn update(
    state: *AccelState,
    grid: *accel.AccelGrid,
    enabled: bool,
    now_ms: u64,
    hash: u64,
    camera_pos: [3]f32,
    recenter_distance: f32,
) Decision {
    if (!enabled) {
        grid.invalidate();
        state.debounce_state.reset();
        return .idle;
    }

    const extra_wants_rebuild = !grid.valid or grid.drift(camera_pos) > recenter_distance;
    const result = state.debounce_state.update(extra_wants_rebuild, now_ms, hash, camera_pos, state.debounce_ms);

    if (result.scene_changed) {
        grid.invalidate();
    }

    return switch (result.decision) {
        .idle => .idle,
        .rebuild => .rebuild,
    };
}

pub fn noteBuilt(state: *AccelState, grid: *const accel.AccelGrid) void {
    state.debounce_state.noteBuilt();
    state.last_build_ms = grid.last_build_ms;
    const r: u64 = grid.resolution;
    state.last_build_voxels = r * r * r * grid.levels;
}

pub fn noteFailed(state: *AccelState, now_ms: u64) void {
    state.debounce_state.noteFailed(now_ms);
}
