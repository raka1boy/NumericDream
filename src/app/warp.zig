const std = @import("std");
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const FreeCamera = camera_mod.FreeCamera;
const SliderRange = @import("slider_range.zig").SliderRange;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const GpuWarp = fractal_gpu.Warp;

const min_safe_denominator: f32 = 1e-4;

pub const RegionKind = enum { sphere, box, global };

pub const CoordKind = enum {
    twist,
    bend,
    rotate,
    scale,
    sphere_inversion,
    repeat,
    displace,

    pub const all = std.enums.values(CoordKind);

    pub fn label(self: CoordKind) [:0]const u8 {
        return switch (self) {
            .twist => "Twist",
            .bend => "Bend",
            .rotate => "Rotate",
            .scale => "Scale",
            .sphere_inversion => "Sphere inversion",
            .repeat => "Repeat",
            .displace => "Displace",
        };
    }
};

pub const WarpState = struct {
    coord_kind: CoordKind = .twist,
    region_kind: RegionKind = .sphere,

    center: Vec3,
    center_range_x: SliderRange,
    center_range_y: SliderRange,
    center_range_z: SliderRange,

    rotation: Vec3,
    rotation_range_x: SliderRange,
    rotation_range_y: SliderRange,
    rotation_range_z: SliderRange,

    radius: f32,
    radius_range: SliderRange,
    extent: Vec3,
    extent_range_x: SliderRange,
    extent_range_y: SliderRange,
    extent_range_z: SliderRange,

    falloff: f32,
    falloff_range: SliderRange,

    strength: f32,
    strength_range: SliderRange,

    step_safety: f32,
    step_safety_range: SliderRange,

    twist_rate: f32,
    twist_rate_range: SliderRange,
    bend_rate: f32,
    bend_rate_range: SliderRange,
    rotate_angle: f32,
    rotate_angle_range: SliderRange,
    scale: Vec3,
    scale_range_x: SliderRange,
    scale_range_y: SliderRange,
    scale_range_z: SliderRange,
    inversion_radius: f32,
    inversion_radius_range: SliderRange,
    inversion_min: f32,
    inversion_min_range: SliderRange,
    repeat_cell: Vec3,
    repeat_cell_range_x: SliderRange,
    repeat_cell_range_y: SliderRange,
    repeat_cell_range_z: SliderRange,
    displace_amp: f32,
    displace_amp_range: SliderRange,
    displace_freq: Vec3,
    displace_freq_range_x: SliderRange,
    displace_freq_range_y: SliderRange,
    displace_freq_range_z: SliderRange,

    window_open: bool = false,

    pub fn safetyRadius(self: WarpState) f32 {
        return switch (self.region_kind) {
            .sphere, .global => @max(self.radius, min_safe_denominator),
            .box => @max(self.extent.length(), min_safe_denominator),
        };
    }

    pub fn lipschitzParts(self: WarpState) struct { mult: f32, grad: f32 } {
        const r = self.safetyRadius();
        var l_f: f32 = 1.0;
        var d: f32 = 0.0;
        switch (self.coord_kind) {
            .twist => {
                const k = @abs(self.twist_rate);
                l_f = 1.0 + k * r;
                d = @min(k * r * r, 2.0 * r);
            },
            .bend => {
                const k = @abs(self.bend_rate);
                l_f = 1.0 + k * r;
                d = @min(k * r * r, 2.0 * r);
            },
            .rotate => {
                const a = std.math.degreesToRadians(self.rotate_angle);
                l_f = 1.0;
                d = 2.0 * r * @abs(@sin(a * 0.5));
            },
            .scale => {
                const sx = @max(@abs(self.scale.x), 1e-3);
                const sy = @max(@abs(self.scale.y), 1e-3);
                const sz = @max(@abs(self.scale.z), 1e-3);
                l_f = @max(1.0 / sx, @max(1.0 / sy, 1.0 / sz));
                d = r * @max(@abs(1.0 / sx - 1.0), @max(@abs(1.0 / sy - 1.0), @abs(1.0 / sz - 1.0)));
            },
            .sphere_inversion => {
                const big_r = @max(@abs(self.inversion_radius), min_safe_denominator);
                const r_min = @max(self.inversion_min, 1e-3);
                l_f = (big_r * big_r) / (r_min * r_min);
                const at_min = @abs(big_r * big_r / r_min - r_min);
                const at_max = @abs(big_r * big_r / r - r);
                d = @max(at_min, at_max);
            },
            .repeat => {
                l_f = 1.0;
                d = 0.5 * self.repeat_cell.length();
            },
            .displace => {
                const amp = @abs(self.displace_amp);
                const f = @max(@abs(self.displace_freq.x), @max(@abs(self.displace_freq.y), @abs(self.displace_freq.z)));
                l_f = 1.0 + amp * f;
                d = amp * @sqrt(3.0);
            },
        }

        const banded = self.region_kind != .global and self.falloff > 1e-4;
        return .{
            .mult = @max(l_f - 1.0, 0.0),
            .grad = if (banded) 1.5 * d / self.falloff else 0.0,
        };
    }

    pub fn toGpu(self: WarpState) GpuWarp {
        var p0: [4]f32 = .{ 0, 0, 0, 0 };
        var p1: [4]f32 = .{ 0, 0, 0, 0 };
        switch (self.coord_kind) {
            .twist => p0[0] = self.twist_rate,
            .bend => p0[0] = self.bend_rate,
            .rotate => p0[0] = std.math.degreesToRadians(self.rotate_angle),
            .scale => p0 = .{ self.scale.x, self.scale.y, self.scale.z, 0 },
            .sphere_inversion => {
                p0[0] = self.inversion_radius;
                p0[1] = @max(self.inversion_min, 1e-3);
            },
            .repeat => p0 = .{ self.repeat_cell.x, self.repeat_cell.y, self.repeat_cell.z, 0 },
            .displace => {
                p0[0] = self.displace_amp;
                p1 = .{ self.displace_freq.x, self.displace_freq.y, self.displace_freq.z, 0 };
            },
        }

        const extent: [3]f32 = switch (self.region_kind) {
            .sphere, .global => .{ self.radius, self.radius, self.radius },
            .box => .{ self.extent.x, self.extent.y, self.extent.z },
        };

        const lip = self.lipschitzParts();
        return .{
            .center = .{ self.center.x, self.center.y, self.center.z },
            .region_kind = @floatFromInt(@backingInt(self.region_kind)),
            .extent = extent,
            .falloff = self.falloff,
            .rotation = .{
                std.math.degreesToRadians(self.rotation.x),
                std.math.degreesToRadians(self.rotation.y),
                std.math.degreesToRadians(self.rotation.z),
            },
            .sub_kind = @floatFromInt(@backingInt(self.coord_kind)),
            .params0 = p0,
            .params1 = p1,
            .strength = self.strength,
            .lip_mult = lip.mult,
            .lip_grad = lip.grad,
            .safety = std.math.clamp(self.step_safety, 0.05, 2.0),
        };
    }
};

pub fn newWarp() WarpState {
    return .{
        .center = .{ .x = 0, .y = 0, .z = 0 },
        .center_range_x = .{ .min = -10, .max = 10 },
        .center_range_y = .{ .min = -10, .max = 10 },
        .center_range_z = .{ .min = -10, .max = 10 },
        .rotation = .{ .x = 0, .y = 0, .z = 0 },
        .rotation_range_x = .{ .min = -180, .max = 180 },
        .rotation_range_y = .{ .min = -180, .max = 180 },
        .rotation_range_z = .{ .min = -180, .max = 180 },
        .radius = 2.0,
        .radius_range = .{ .min = 0.05, .max = 20.0 },
        .extent = .{ .x = 1, .y = 1, .z = 1 },
        .extent_range_x = .{ .min = 0.05, .max = 20.0 },
        .extent_range_y = .{ .min = 0.05, .max = 20.0 },
        .extent_range_z = .{ .min = 0.05, .max = 20.0 },
        .falloff = 0.5,
        .falloff_range = .{ .min = 0.0, .max = 8.0 },
        .strength = 1.0,
        .strength_range = .{ .min = 0.0, .max = 1.0 },
        .step_safety = 1.0,
        .step_safety_range = .{ .min = 0.05, .max = 2.0 },
        .twist_rate = 1.0,
        .twist_rate_range = .{ .min = -6.0, .max = 6.0 },
        .bend_rate = 0.5,
        .bend_rate_range = .{ .min = -6.0, .max = 6.0 },
        .rotate_angle = 45.0,
        .rotate_angle_range = .{ .min = -180.0, .max = 180.0 },
        .scale = .{ .x = 1, .y = 1, .z = 1 },
        .scale_range_x = .{ .min = 0.1, .max = 4.0 },
        .scale_range_y = .{ .min = 0.1, .max = 4.0 },
        .scale_range_z = .{ .min = 0.1, .max = 4.0 },
        .inversion_radius = 1.0,
        .inversion_radius_range = .{ .min = 0.05, .max = 8.0 },
        .inversion_min = 0.25,
        .inversion_min_range = .{ .min = 0.02, .max = 4.0 },
        .repeat_cell = .{ .x = 2, .y = 0, .z = 2 },
        .repeat_cell_range_x = .{ .min = 0.0, .max = 16.0 },
        .repeat_cell_range_y = .{ .min = 0.0, .max = 16.0 },
        .repeat_cell_range_z = .{ .min = 0.0, .max = 16.0 },
        .displace_amp = 0.2,
        .displace_amp_range = .{ .min = 0.0, .max = 4.0 },
        .displace_freq = .{ .x = 2, .y = 2, .z = 2 },
        .displace_freq_range_x = .{ .min = 0.0, .max = 16.0 },
        .displace_freq_range_y = .{ .min = 0.0, .max = 16.0 },
        .displace_freq_range_z = .{ .min = 0.0, .max = 16.0 },
    };
}

fn rotateFrame(w: *const WarpState, v: Vec3, inverse: bool) Vec3 {
    const rx = std.math.degreesToRadians(w.rotation.x);
    const ry = std.math.degreesToRadians(w.rotation.y);
    const rz = std.math.degreesToRadians(w.rotation.z);
    const cols = camera_mod.eulerRotationColumns(rx, ry, rz);
    if (inverse) {
        return .{ .x = cols[0].dot(v), .y = cols[1].dot(v), .z = cols[2].dot(v) };
    }
    return cols[0].scale(v.x).add(cols[1].scale(v.y)).add(cols[2].scale(v.z));
}
//negative inside
fn regionDe(w: *const WarpState, p: Vec3) f32 {
    if (w.region_kind == .global) return -1e20;
    const q = rotateFrame(w, p.sub(w.center), true);
    if (w.region_kind == .sphere) return q.length() - @max(w.radius, min_safe_denominator);
    const ex = @max(w.extent.x, min_safe_denominator);
    const ey = @max(w.extent.y, min_safe_denominator);
    const ez = @max(w.extent.z, min_safe_denominator);
    const dx = @abs(q.x) - ex;
    const dy = @abs(q.y) - ey;
    const dz = @abs(q.z) - ez;
    const outside = Vec3{ .x = @max(dx, 0), .y = @max(dy, 0), .z = @max(dz, 0) };
    return outside.length() + @min(@max(dx, @max(dy, dz)), 0.0);
}

fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    if (edge1 - edge0 == 0) return if (x < edge0) 0 else 1;
    const t = std.math.clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

fn influence(w: *const WarpState, p: Vec3) f32 {
    if (w.region_kind == .global) return w.strength;
    const de = regionDe(w, p);
    if (w.falloff <= 1e-4) return if (de <= 0) w.strength else 0;
    return w.strength * (1.0 - smoothstep(-w.falloff, 0.0, de));
}

fn coordWarpRaw(w: *const WarpState, p: Vec3) Vec3 {
    var q = rotateFrame(w, p.sub(w.center), true);
    switch (w.coord_kind) {
        .twist => {
            const a = w.twist_rate * q.y;
            const c = @cos(a);
            const s = @sin(a);
            q = .{ .x = c * q.x - s * q.z, .y = q.y, .z = s * q.x + c * q.z };
        },
        .bend => {
            const a = w.bend_rate * q.x;
            const c = @cos(a);
            const s = @sin(a);
            q = .{ .x = c * q.x - s * q.y, .y = s * q.x + c * q.y, .z = q.z };
        },
        .rotate => {
            const a = std.math.degreesToRadians(w.rotate_angle);
            const c = @cos(a);
            const s = @sin(a);
            q = .{ .x = c * q.x - s * q.z, .y = q.y, .z = s * q.x + c * q.z };
        },
        .scale => {
            q = .{
                .x = q.x / @max(@abs(w.scale.x), 1e-3),
                .y = q.y / @max(@abs(w.scale.y), 1e-3),
                .z = q.z / @max(@abs(w.scale.z), 1e-3),
            };
        },
        .sphere_inversion => {
            const r_min = @max(w.inversion_min, 1e-3);
            const r2 = @max(q.dot(q), r_min * r_min);
            const big_r = w.inversion_radius;
            q = q.scale(big_r * big_r / r2);
        },
        .repeat => {
            q = .{
                .x = foldAxis(q.x, w.repeat_cell.x),
                .y = foldAxis(q.y, w.repeat_cell.y),
                .z = foldAxis(q.z, w.repeat_cell.z),
            };
        },
        .displace => {
            const a = w.displace_amp;
            q = .{
                .x = q.x + a * @sin(w.displace_freq.x * q.y),
                .y = q.y + a * @sin(w.displace_freq.y * q.z),
                .z = q.z + a * @sin(w.displace_freq.z * q.x),
            };
        },
    }
    return rotateFrame(w, q, false).add(w.center);
}

fn foldAxis(v: f32, cell: f32) f32 {
    if (cell <= 1e-4) return v;
    return v - cell * @round(v / cell);
}

pub fn applyAll(warps: []const WarpState, p: Vec3) Vec3 {
    var q = p;
    for (warps) |*w| {
        const inf = influence(w, p);
        if (inf <= 1e-4) continue;
        const raw = coordWarpRaw(w, q);
        q = q.add(raw.sub(q).scale(inf));
    }
    return q;
}

fn jacobian(warps: []const WarpState, p: Vec3) [3]Vec3 {
    const h = 1e-3 * @max(1.0, p.length());
    const axes = [3]Vec3{
        .{ .x = h, .y = 0, .z = 0 },
        .{ .x = 0, .y = h, .z = 0 },
        .{ .x = 0, .y = 0, .z = h },
    };
    var cols: [3]Vec3 = undefined;
    for (axes, 0..) |a, i| {
        const plus = applyAll(warps, p.add(a));
        const minus = applyAll(warps, p.sub(a));
        cols[i] = plus.sub(minus).scale(1.0 / (2.0 * h));
    }
    return cols;
}

fn mulCols(cols: [3]Vec3, v: Vec3) Vec3 {
    return cols[0].scale(v.x).add(cols[1].scale(v.y)).add(cols[2].scale(v.z));
}

fn solve(cols: [3]Vec3, v: Vec3) ?Vec3 {
    const det = cols[0].dot(cols[1].cross(cols[2]));
    if (@abs(det) < 1e-6) return null;
    const inv_det = 1.0 / det;
    return .{
        .x = v.dot(cols[1].cross(cols[2])) * inv_det,
        .y = cols[0].dot(v.cross(cols[2])) * inv_det,
        .z = cols[0].dot(cols[1].cross(v)) * inv_det,
    };
}

fn finite(v: Vec3) bool {
    return std.math.isFinite(v.x) and std.math.isFinite(v.y) and std.math.isFinite(v.z);
}

const min_stretch: f32 = 0.1;
const max_stretch: f32 = 10.0;

pub fn transportCamera(cam: *FreeCamera, prev_pos: Vec3, warps: []const WarpState) void {
    if (!cam.follow_warp or warps.len == 0 or cam.mode_2d) return;

    const delta = cam.position.sub(prev_pos);
    const dist = delta.length();
    if (dist < 1e-9) return;
    const dir = delta.scale(1.0 / dist);

    const j0 = jacobian(warps, prev_pos);
    const stretch = mulCols(j0, dir).length();
    if (std.math.isFinite(stretch) and stretch > 1e-6) {
        const clamped = std.math.clamp(stretch, min_stretch, max_stretch);
        cam.position = prev_pos.add(dir.scale(dist / clamped));
    }

    const base = applyAll(warps, prev_pos);
    const eps = 1e-3 * @max(1.0, prev_pos.length());
    const m_forward = applyAll(warps, prev_pos.add(cam.forward.scale(eps))).sub(base);
    const m_up = applyAll(warps, prev_pos.add(cam.up.scale(eps))).sub(base);

    const j1 = jacobian(warps, cam.position);
    const new_forward = solve(j1, m_forward) orelse return;
    const new_up = solve(j1, m_up) orelse return;
    if (!finite(new_forward) or !finite(new_up)) return;
    if (new_forward.length() < 1e-9 or new_up.length() < 1e-9) return;

    cam.forward = new_forward.normalize();
    cam.up = new_up.normalize();
    cam.normalizeBasis();
}
