const std = @import("std");
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
const ParticleSystemState = @import("particles.zig").ParticleSystemState;

pub const Kind = enum { fractal, light, fog, warp, particles };

pub const Ref = struct {
    kind: Kind,
    index: usize,

    pub fn eql(a: Ref, b: Ref) bool {
        return a.kind == b.kind and a.index == b.index;
    }
};

fn idBase(kind: Kind) u8 {
    return switch (kind) {
        .fractal => 1,
        .light => 11,
        .fog => 21,
        .warp => 31,
        .particles => 41,
    };
}

fn maxCount(kind: Kind) usize {
    return switch (kind) {
        .fractal => fractal_gpu.max_instances,
        .light => fractal_gpu.max_lights,
        .fog => fractal_gpu.max_fog_emitters,
        .warp => fractal_gpu.max_warps,
        .particles => fractal_gpu.max_particle_systems,
    };
}

comptime {
    const order = [_]Kind{ .fractal, .light, .fog, .warp, .particles };
    for (order, 0..) |kind, i| {
        const end = @as(usize, idBase(kind)) + maxCount(kind);
        if (i + 1 < order.len) {
            std.debug.assert(end <= idBase(order[i + 1]));
        } else {
            std.debug.assert(end <= 256);
        }
    }
}

pub fn encodeId(ref: Ref) u8 {
    return idBase(ref.kind) + @as(u8, @intCast(ref.index));
}

pub fn decodeId(id: u8) ?Ref {
    inline for (.{ Kind.fractal, Kind.light, Kind.fog, Kind.warp, Kind.particles }) |kind| {
        const base = idBase(kind);
        if (id >= base and id < base + maxCount(kind)) {
            return .{ .kind = kind, .index = id - base };
        }
    }
    return null;
}

pub const Objects = struct {
    instances: []FractalInstanceState,
    lights: []LightState,
    fog_emitters: []FogEmitterState,
    warps: []WarpState,
    particle_systems: []ParticleSystemState,

    fn windowFlag(self: Objects, ref: Ref) ?*bool {
        return switch (ref.kind) {
            .fractal => if (ref.index < self.instances.len) &self.instances[ref.index].window_open else null,
            .light => if (ref.index < self.lights.len) &self.lights[ref.index].window_open else null,
            .fog => if (ref.index < self.fog_emitters.len) &self.fog_emitters[ref.index].window_open else null,
            .warp => if (ref.index < self.warps.len) &self.warps[ref.index].window_open else null,
            .particles => if (ref.index < self.particle_systems.len) &self.particle_systems[ref.index].window_open else null,
        };
    }

    pub fn toGpu(self: Objects, ref: Ref) ?Ref {
        const rank = switch (ref.kind) {
            .fractal => if (ref.index < self.instances.len and self.instances[ref.index].visible) ref.index else null,
            .light => visibleRank(self.lights, ref.index),
            .fog => visibleRank(self.fog_emitters, ref.index),
            .warp => visibleRank(self.warps, ref.index),
            .particles => if (ref.index < self.particle_systems.len and self.particle_systems[ref.index].visible) ref.index else null,
        };
        return .{ .kind = ref.kind, .index = rank orelse return null };
    }

    pub fn fromGpu(self: Objects, ref: Ref) ?Ref {
        const index = switch (ref.kind) {
            .fractal => if (ref.index < self.instances.len) ref.index else null,
            .light => nthVisible(self.lights, ref.index),
            .fog => nthVisible(self.fog_emitters, ref.index),
            .warp => nthVisible(self.warps, ref.index),
            .particles => if (ref.index < self.particle_systems.len) ref.index else null,
        };
        return .{ .kind = ref.kind, .index = index orelse return null };
    }
};

fn visibleRank(items: anytype, index: usize) ?usize {
    if (index >= items.len or !items[index].visible) return null;
    var rank: usize = 0;
    for (items[0..index]) |*item| {
        if (item.visible) rank += 1;
    }
    return rank;
}

fn nthVisible(items: anytype, rank: usize) ?usize {
    var seen: usize = 0;
    for (items, 0..) |*item, i| {
        if (!item.visible) continue;
        if (seen == rank) return i;
        seen += 1;
    }
    return null;
}

pub const State = struct {
    current: ?Ref = null,

    mask_valid: bool = false,

    pub fn select(self: *State, objects: Objects, ref: ?Ref) void {
        if (self.current) |old| {
            if (ref) |new| {
                if (old.eql(new)) return;
            }
            if (objects.windowFlag(old)) |flag| flag.* = false;
        }
        self.current = null;
        self.mask_valid = false;
        const new = ref orelse return;
        const flag = objects.windowFlag(new) orelse return;
        flag.* = true;
        self.current = new;
    }

    pub fn syncWithWindows(self: *State, objects: Objects) void {
        const ref = self.current orelse return;
        const open = objects.windowFlag(ref) orelse {
            self.current = null;
            self.mask_valid = false;
            return;
        };
        if (!open.*) {
            self.current = null;
            self.mask_valid = false;
        }
    }

    pub fn noteRemoved(self: *State, kind: Kind, index: usize) void {
        const ref = self.current orelse return;
        if (ref.kind != kind) return;
        if (ref.index == index) {
            self.current = null;
            self.mask_valid = false;
        } else if (ref.index > index) {
            self.current = .{ .kind = kind, .index = ref.index - 1 };
        }
    }

    pub fn noteSwapped(self: *State, kind: Kind, a: usize, b: usize) void {
        const ref = self.current orelse return;
        if (ref.kind != kind) return;
        if (ref.index == a) {
            self.current = .{ .kind = kind, .index = b };
        } else if (ref.index == b) {
            self.current = .{ .kind = kind, .index = a };
        } else return;
        self.mask_valid = false;
    }

    pub fn maskId(self: *const State, objects: Objects) u8 {
        const ref = self.current orelse return 0;
        return encodeId(objects.toGpu(ref) orelse return 0);
    }
};
