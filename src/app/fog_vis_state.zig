const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const fog_vis = @import("../gpu/fog_vis.zig");
const accel_state = @import("accel_state.zig");
const debounce = @import("debounce.zig");
const DebouncedDirty = debounce.DebouncedDirty;

pub const FogVisState = struct {
    enabled: bool = true,

    resolution: f32 = @floatFromInt(fog_vis.default_resolution),
    resolution_range: SliderRange = .{
        .min = @floatFromInt(fog_vis.min_resolution),
        .max = @floatFromInt(fog_vis.max_resolution),
    },

    debounce_ms: f32 = 180,
    debounce_ms_range: SliderRange = .{ .min = 0, .max = 1000 },

    debounce_state: DebouncedDirty = .{},

    pub fn resolutionU32(self: *const FogVisState) u32 {
        return fog_vis.clampResolution(@intFromFloat(@max(self.resolution, 1)));
    }
};

pub fn sceneHash(uniforms: anytype, photons: bool, resolution: u32) u64 {
    var h = std.hash.Wyhash.init(accel_state.sceneHash(uniforms));
    h.update(std.mem.asBytes(&resolution));
    h.update(std.mem.asBytes(&photons));
    h.update(std.mem.asBytes(&uniforms.has_transparency));
    const light_count: usize = @intFromFloat(std.math.clamp(uniforms.light_count, 0, @as(f32, @floatFromInt(uniforms.lights.len))));
    for (uniforms.lights[0..light_count], 0..) |*light, i| {
        if (light.cast_shadows < 0.5) continue;
        h.update(std.mem.asBytes(&i));
        h.update(std.mem.asBytes(&light.position_or_direction));
        h.update(std.mem.asBytes(&light.light_type));
    }
    const fog_count: usize = @intFromFloat(std.math.clamp(uniforms.fog_count, 0, @as(f32, @floatFromInt(uniforms.fog_emitters.len))));
    for (uniforms.fog_emitters[0..fog_count]) |*fog| {
        h.update(std.mem.asBytes(&fog.position));
        h.update(std.mem.asBytes(&fog.radius));
    }
    return h.final();
}

pub const Decision = debounce.Decision;

pub fn update(state: *FogVisState, grid: *fog_vis.FogVisGrid, enabled: bool, now_ms: u64, hash: u64) Decision {
    if (!enabled) {
        grid.invalidate();
        return .idle;
    }
    if (grid.key != hash) grid.invalidate();
    const result = state.debounce_state.update(!grid.valid, now_ms, hash, .{ 0, 0, 0 }, state.debounce_ms);
    if (result.scene_changed) grid.invalidate();
    return result.decision;
}

pub fn noteBuilt(state: *FogVisState) void {
    state.debounce_state.noteBuilt();
}

pub fn noteFailed(state: *FogVisState, now_ms: u64) void {
    state.debounce_state.noteFailed(now_ms);
}
