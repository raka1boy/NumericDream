const std = @import("std");
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;

pub const Kind = enum { fractal, light, fog, warp };

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
    };
}

fn maxCount(kind: Kind) usize {
    return switch (kind) {
        .fractal => fractal_gpu.max_instances,
        .light => fractal_gpu.max_lights,
        .fog => fractal_gpu.max_fog_emitters,
        .warp => fractal_gpu.max_warps,
    };
}

comptime {
    const order = [_]Kind{ .fractal, .light, .fog, .warp };
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
    inline for (.{ Kind.fractal, Kind.light, Kind.fog, Kind.warp }) |kind| {
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

    fn windowFlag(self: Objects, ref: Ref) ?*bool {
        return switch (ref.kind) {
            .fractal => if (ref.index < self.instances.len) &self.instances[ref.index].window_open else null,
            .light => if (ref.index < self.lights.len) &self.lights[ref.index].window_open else null,
            .fog => if (ref.index < self.fog_emitters.len) &self.fog_emitters[ref.index].window_open else null,
            .warp => if (ref.index < self.warps.len) &self.warps[ref.index].window_open else null,
        };
    }
};

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

    pub fn maskId(self: *const State) u8 {
        const ref = self.current orelse return 0;
        return encodeId(ref);
    }
};
