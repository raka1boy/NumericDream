const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const SliderRange = @import("slider_range.zig").SliderRange;

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn scale(a: Vec3, s: f32) Vec3 {
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s };
    }
    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }
    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }
    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.y * b.z - a.z * b.y, .y = a.z * b.x - a.x * b.z, .z = a.x * b.y - a.y * b.x };
    }
    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }
    pub fn length(a: Vec3) f32 {
        return @sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
    }
    pub fn normalize(a: Vec3) Vec3 {
        const len = a.length();
        if (len < 1e-6) return .{ .x = 0, .y = 0, .z = 0 };
        return a.scale(1.0 / len);
    }
    pub fn rotate(a: Vec3, axis: Vec3, angle: f32) Vec3 {
        const c = @cos(angle);
        const s = @sin(angle);
        return a.scale(c).add(axis.cross(a).scale(s)).add(axis.scale(axis.dot(a) * (1 - c)));
    }
};

pub fn eulerRotationColumns(rx: f32, ry: f32, rz: f32) [3]Vec3 {
    const cx = @cos(rx);
    const sx = @sin(rx);
    const cy = @cos(ry);
    const sy = @sin(ry);
    const cz = @cos(rz);
    const sz = @sin(rz);
    return .{
        .{ .x = cy * cz, .y = cy * sz, .z = -sy },
        .{ .x = sx * sy * cz - cx * sz, .y = sx * sy * sz + cx * cz, .z = sx * cy },
        .{ .x = cx * sy * cz + sx * sz, .y = cx * sy * sz - sx * cz, .z = cx * cy },
    };
}

pub const CameraBasis = struct { pos: Vec3, forward: Vec3, right: Vec3, up: Vec3 };
pub const default_zoom_2d: f32 = 2.0;
pub const min_zoom_2d: f32 = 1e-6;
pub const max_zoom_2d: f32 = 1e4;
pub const FreeCamera = struct {
    position: Vec3,
    forward: Vec3,
    up: Vec3,
    speed_multiplier: f32 = 1.0,
    dof_enabled: bool = false,
    focus_distance: f32 = 3.2,
    focus_distance_range: SliderRange = .{ .min = 0.1, .max = 20.0 },
    aperture: f32 = 0.05,
    aperture_range: SliderRange = .{ .min = 0.0, .max = 0.5 },
    focus_range: f32 = 0.5,
    focus_range_range: SliderRange = .{ .min = 0.0, .max = 5.0 },
    mode_2d: bool = false,
    zoom_2d: f32 = default_zoom_2d,
    follow_warp: bool = false,
    const zoom_speed_2d: f32 = 1.2;

    pub fn slowDown(self: *FreeCamera) void {
        self.speed_multiplier *= 0.5;
    }
    pub fn speedUp(self: *FreeCamera) void {
        self.speed_multiplier *= 1.5;
    }
    pub fn initial() FreeCamera {
        const yaw0: f32 = 0.7;
        const pitch0: f32 = 0.35;
        const distance: f32 = 3.2;
        const cp = @cos(pitch0);
        const pos = Vec3{ .x = distance * cp * @cos(yaw0), .y = distance * @sin(pitch0), .z = distance * cp * @sin(yaw0) };
        const forward = pos.scale(-1).normalize();
        const world_up = Vec3{ .x = 0, .y = 1, .z = 0 };
        const right = forward.cross(world_up).normalize();
        const up = right.cross(forward).normalize();
        return .{ .position = pos, .forward = forward, .up = up };
    }

    pub fn basis(self: FreeCamera) CameraBasis {
        const right = self.forward.cross(self.up).normalize();
        return .{ .pos = self.position, .forward = self.forward, .right = right, .up = self.up };
    }
    pub fn normalizeBasis(self: *FreeCamera) void {
        self.forward = self.forward.normalize();
        const right = self.forward.cross(self.up).normalize();
        self.up = right.cross(self.forward).normalize();
    }
    pub fn turnYaw(self: *FreeCamera, angle: f32) void {
        self.forward = self.forward.rotate(self.up, -angle);
        self.normalizeBasis();
    }
    pub fn turnPitch(self: *FreeCamera, angle: f32) void {
        const right = self.forward.cross(self.up).normalize();
        self.forward = self.forward.rotate(right, angle);
        self.up = self.up.rotate(right, angle);
        self.normalizeBasis();
    }
    pub fn turnRoll(self: *FreeCamera, angle: f32) void {
        self.up = self.up.rotate(self.forward, angle);
        self.normalizeBasis();
    }
    pub fn tick(self: *FreeCamera, keys: [*c]const bool, dt: f32) void {
        const zoom_scale: f32 = if (self.mode_2d) self.zoom_2d / default_zoom_2d else 1.0;
        const move_speed: f32 = 2.5 * self.speed_multiplier * zoom_scale;
        const turn_speed: f32 = 1.6;

        if (self.mode_2d) {
            if (keys[sdl.SDL_SCANCODE_F]) self.zoom_2d *= @exp(-zoom_speed_2d * dt);
            if (keys[sdl.SDL_SCANCODE_R]) self.zoom_2d *= @exp(zoom_speed_2d * dt);
            self.zoom_2d = std.math.clamp(self.zoom_2d, min_zoom_2d, max_zoom_2d);
        }

        const b = self.basis();
        var move = Vec3{ .x = 0, .y = 0, .z = 0 };
        if (keys[sdl.SDL_SCANCODE_W]) move = move.add(b.forward);
        if (keys[sdl.SDL_SCANCODE_S]) move = move.sub(b.forward);
        if (keys[sdl.SDL_SCANCODE_D]) move = move.add(b.right);
        if (keys[sdl.SDL_SCANCODE_A]) move = move.sub(b.right);
        self.position = self.position.add(move.normalize().scale(move_speed * dt));

        if (keys[sdl.SDL_SCANCODE_LEFT]) self.turnYaw(-turn_speed * dt);
        if (keys[sdl.SDL_SCANCODE_RIGHT]) self.turnYaw(turn_speed * dt);
        if (keys[sdl.SDL_SCANCODE_DOWN]) self.turnPitch(turn_speed * dt);
        if (keys[sdl.SDL_SCANCODE_UP]) self.turnPitch(-turn_speed * dt);
        if (keys[sdl.SDL_SCANCODE_Q]) self.turnRoll(turn_speed * dt);
        if (keys[sdl.SDL_SCANCODE_E]) self.turnRoll(-turn_speed * dt);
    }
};
pub fn eyeBasis(pos: Vec3, forward: Vec3, right: Vec3, convergence_distance: f32, half_sep: f32) CameraBasis {
    const eye_pos = pos.add(right.scale(half_sep));
    const target = pos.add(forward.scale(convergence_distance));
    const eye_forward = target.sub(eye_pos).normalize();
    const world_up = Vec3{ .x = 0, .y = 1, .z = 0 };
    const eye_right = eye_forward.cross(world_up).normalize();
    const eye_up = eye_right.cross(eye_forward).normalize();
    return .{ .pos = eye_pos, .forward = eye_forward, .right = eye_right, .up = eye_up };
}
pub fn stereoEyeBasis(cam: CameraBasis, mode_2d: bool, convergence_distance: f32, half_sep: f32) CameraBasis {
    if (!mode_2d) return eyeBasis(cam.pos, cam.forward, cam.right, convergence_distance, half_sep);
    return .{
        .pos = cam.pos.add(cam.right.scale(half_sep)),
        .forward = cam.forward,
        .right = cam.right,
        .up = cam.up,
    };
}
