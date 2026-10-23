const std = @import("std");
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const CameraBasis = camera_mod.CameraBasis;
const SliderRange = @import("slider_range.zig").SliderRange;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const Uniforms = fractal_gpu.Uniforms;
const stampEyeBasis = @import("export_image.zig").stampEyeBasis;

pub const ahead: f32 = 0.6;
pub const min_range: f32 = 1e-4;
pub const max_range: f32 = 1e3;
pub const wheel_zoom: f32 = 0.15;

pub const NavigatorState = struct {
    open: bool = false,
    range: f32 = 4,
    range_range: SliderRange = .{ .min = 0.25, .max = 16 },
};

pub const Map = struct {
    center: Vec3,
    right: Vec3,
    up: Vec3,
    normal: Vec3,
    range: f32,

    pub fn of(cam: CameraBasis, range: f32) Map {
        const r = std.math.clamp(range, min_range, max_range);
        return .{
            .center = cam.pos.add(cam.forward.scale(r * ahead)),
            .right = cam.right,
            .up = cam.forward.scale(-1),
            .normal = cam.up,
            .range = r,
        };
    }

    pub fn toUnit(self: Map, p: Vec3) [2]f32 {
        const d = p.sub(self.center);
        return .{ d.dot(self.right) / self.range, d.dot(self.up) / self.range };
    }

    pub fn fromUnit(self: Map, x: f32, y: f32) Vec3 {
        return self.center.add(self.right.scale(x * self.range)).add(self.up.scale(y * self.range));
    }

    pub fn uniforms(self: Map, base: Uniforms, size: u32) Uniforms {
        var u = base;
        stampEyeBasis(&u, .{ .pos = self.center, .forward = self.normal, .right = self.right, .up = self.up });
        const side: f32 = @floatFromInt(size);
        u.resolution = .{ side, side };
        u.tile_scale = .{ 1, 1 };
        u.tile_bias = .{ 0, 0 };
        u.mode_2d = 1;
        u.slice_zoom = self.range;
        u.mc_sample = 0;
        u.time = 0;
        u.flat_samples = 1;
        u.flat_slab_slices = 1;
        return u;
    }
};
