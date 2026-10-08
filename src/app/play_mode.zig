const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const mesher = fractal_gpu.mesher;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const FreeCamera = camera_mod.FreeCamera;

pub const look_sensitivity: f32 = 0.0025;

const eye_height_per_speed: f32 = 0.25;
const radius: f32 = 0.3;
const skin: f32 = 0.08 * radius;
const walk_speed: f32 = 4;
const fly_speed: f32 = 10;
const gravity: f32 = 14;
const jump_speed: f32 = 4.2;
const terminal_speed: f32 = 30;
const air_control: f32 = 3;
const fly_response: f32 = 8;
const field_step: f32 = 1;
const walkable_cos: f32 = 0.5;
const max_pitch: f32 = 1.55;
const turn_speed: f32 = 1.6;
const max_substeps: u32 = 8;
const double_tap_ms: u64 = 300;
const body = [_]f32{ 1 - radius, 0.5 * (1 - radius), 0 };
const carve_radius: f32 = 1 + radius;
const carve_life_ms: u64 = 10_000;
const carve_anim_ms: f32 = 250;
const carve_range: f32 = 48;
const carve_samples = 512;

const zero = Vec3{ .x = 0, .y = 0, .z = 0 };

const Carve = struct {
    centre: Vec3,
    radius: f32,
    born_ms: u64,
    closing_ms: u64 = 0,

    fn currentRadius(self: Carve, now_ms: u64) f32 {
        const grow = easeOut(@as(f32, @floatFromInt(now_ms -| self.born_ms)) / carve_anim_ms);
        const shrink = if (self.closing_ms == 0) 1 else easeOut(1 - @as(f32, @floatFromInt(now_ms -| self.closing_ms)) / carve_anim_ms);
        return self.radius * grow * shrink;
    }
};

fn easeOut(t: f32) f32 {
    const c = std.math.clamp(t, 0, 1);
    return 1 - (1 - c) * (1 - c) * (1 - c);
}

pub const PlayState = struct {
    enabled: bool = false,
    captured: bool = false,
    flying: bool = false,
    grounded: bool = false,
    status_buf: [128]u8 = undefined,
    status: [:0]const u8 = "",

    was_enabled: bool = false,
    synced: bool = false,
    eye: Vec3 = zero,
    up: Vec3 = .{ .x = 0, .y = 1, .z = 0 },
    heading: Vec3 = .{ .x = 0, .y = 0, .z = -1 },
    pitch: f32 = 0,
    velocity: Vec3 = zero,
    eye_height: f32 = 0,
    jump_queued: bool = false,
    last_space_ms: u64 = 0,
    written: [3]Vec3 = .{ zero, zero, zero },

    carves: [fractal_gpu.max_carves]Carve = undefined,
    carve_count: usize = 0,
    fire_queued: bool = false,

    pub fn setCaptured(self: *PlayState, window: *sdl.SDL_Window, on: bool) void {
        _ = sdl.SDL_SetWindowRelativeMouseMode(window, on);
        self.captured = on;
    }

    pub fn syncCapture(self: *PlayState, window: *sdl.SDL_Window) void {
        if (self.enabled and !self.was_enabled) {
            self.flying = false;
            self.synced = false;
            self.status = "";
            self.setCaptured(window, true);
        }
        if (!self.enabled and self.captured) self.setCaptured(window, false);
        if (!self.enabled) {
            self.carve_count = 0;
            self.fire_queued = false;
        }
        self.was_enabled = self.enabled;
    }

    pub fn pressFire(self: *PlayState) void {
        self.fire_queued = true;
    }

    pub fn stampCarves(self: *const PlayState, uniforms: *fractal_gpu.Uniforms, now_ms: u64) void {
        for (self.carves[0..self.carve_count], 0..) |c, i| {
            uniforms.carves[i] = .{ c.centre.x, c.centre.y, c.centre.z, c.currentRadius(now_ms) };
        }
        uniforms.carve_count = @floatFromInt(self.carve_count);
    }

    pub fn look(self: *PlayState, yaw: f32, pitch: f32) void {
        self.heading = self.heading.rotate(self.up, -yaw);
        self.orthonormalize();
        self.pitch = std.math.clamp(self.pitch + pitch, -max_pitch, max_pitch);
    }

    pub fn pressSpace(self: *PlayState, now_ms: u64) void {
        if (self.last_space_ms != 0 and now_ms -| self.last_space_ms <= double_tap_ms) {
            self.flying = !self.flying;
            self.last_space_ms = 0;
            if (self.flying) {
                self.velocity = zero;
                self.grounded = false;
            }
            return;
        }
        self.last_space_ms = now_ms;
        self.jump_queued = true;
    }

    pub fn stateLabel(self: *const PlayState) [:0]const u8 {
        if (self.flying) return "Flying";
        return if (self.grounded) "Walking" else "Falling";
    }

    pub fn step(
        self: *PlayState,
        ctx: *Context,
        fractal: *FractalRenderer,
        allocator: std.mem.Allocator,
        instances: []const FractalInstanceState,
        cam: *FreeCamera,
        keys: ?[*c]const bool,
        dt: f32,
        now_ms: u64,
    ) void {
        const n = instances.len;
        const gpu = fractal.meshGpu(ctx, allocator, scene_state.buildFormulaSources(instances, n), scene_state.buildMixinSources(instances, n)) catch |err| return self.fail(err);
        const probe = Probe{ .ctx = ctx, .gpu = gpu, .uniforms_group = fractal.bind_group };
        self.tick(cam, probe, keys, dt) catch |err| return self.fail(err);
        self.updateCarves(probe, now_ms) catch |err| return self.fail(err);
    }

    fn updateCarves(self: *PlayState, probe: Probe, now_ms: u64) !void {
        const h = self.eye_height;
        var i: usize = 0;
        while (i < self.carve_count) {
            const c = &self.carves[i];
            if (c.closing_ms == 0 and now_ms -| c.born_ms >= carve_life_ms and !self.bodyOverlaps(c.*, h)) {
                c.closing_ms = now_ms;
            }
            if (c.closing_ms != 0 and @as(f32, @floatFromInt(now_ms -| c.closing_ms)) >= carve_anim_ms) {
                self.carve_count -= 1;
                self.carves[i] = self.carves[self.carve_count];
                continue;
            }
            i += 1;
        }

        if (!self.fire_queued) return;
        self.fire_queued = false;
        const dir = self.heading.scale(@cos(self.pitch)).add(self.up.scale(@sin(self.pitch))).normalize();
        const spacing = carve_range * h / carve_samples;
        var pts: [carve_samples][4]f32 = undefined;
        for (&pts, 0..) |*p, s| p.* = point(self.eye.add(dir.scale(spacing * @as(f32, @floatFromInt(s)))), spacing);
        var out: [carve_samples][4]f32 = undefined;
        try probe.eval(&pts, &out);
        for (out, 0..) |o, s| {
            if (o[0] <= 0.5 * spacing) {
                self.addCarve(.{
                    .centre = self.eye.add(dir.scale(spacing * @as(f32, @floatFromInt(s)))),
                    .radius = carve_radius * h,
                    .born_ms = now_ms,
                });
                return;
            }
        }
    }

    fn addCarve(self: *PlayState, c: Carve) void {
        if (self.carve_count < self.carves.len) {
            self.carves[self.carve_count] = c;
            self.carve_count += 1;
            return;
        }
        var oldest: usize = 0;
        for (self.carves, 0..) |o, i| {
            if (o.born_ms < self.carves[oldest].born_ms) oldest = i;
        }
        self.carves[oldest] = c;
    }

    fn bodyOverlaps(self: *const PlayState, c: Carve, h: f32) bool {
        const feet = self.eye.sub(self.up.scale(body[0] * h));
        const seg = self.eye.sub(feet);
        const t = std.math.clamp(c.centre.sub(feet).dot(seg) / @max(seg.dot(seg), 1e-12), 0, 1);
        const closest = feet.add(seg.scale(t));
        return closest.sub(c.centre).length() < c.radius + radius * h;
    }

    fn fail(self: *PlayState, err: anyerror) void {
        if (err == error.ShaderCompileFailed or err == error.PipelineCreationFailed) {
            std.log.err("play mode probe shader: {s}", .{webgpu_context.g_error_sink.message()});
        }
        self.status = std.fmt.bufPrintSentinel(&self.status_buf, "Play mode stopped: {s}", .{@errorName(err)}, 0) catch "Play mode stopped.";
        self.enabled = false;
    }

    fn adoptCamera(self: *PlayState, cam: FreeCamera) void {
        self.eye = cam.position;
        self.up = cam.up.scale(-1).normalize();
        self.heading = cam.forward;
        self.pitch = 0;
        self.orthonormalize();
        self.velocity = zero;
        self.grounded = false;
        self.eye_height = 0;
        self.synced = true;
    }

    fn writeCamera(self: *PlayState, cam: *FreeCamera) void {
        const c = @cos(self.pitch);
        const s = @sin(self.pitch);
        cam.position = self.eye;
        cam.forward = self.heading.scale(c).add(self.up.scale(s));
        cam.up = self.heading.scale(s).sub(self.up.scale(c));
        self.written = .{ cam.position, cam.forward, cam.up };
    }

    fn cameraMoved(self: *const PlayState, cam: FreeCamera) bool {
        const now = [3]Vec3{ cam.position, cam.forward, cam.up };
        return !std.mem.eql(u8, std.mem.asBytes(&now), std.mem.asBytes(&self.written));
    }

    fn orthonormalize(self: *PlayState) void {
        var h = self.heading.sub(self.up.scale(self.heading.dot(self.up)));
        if (h.length() < 1e-4) {
            const a: Vec3 = if (@abs(self.up.x) < 0.9) .{ .x = 1, .y = 0, .z = 0 } else .{ .x = 0, .y = 0, .z = 1 };
            h = a.cross(self.up);
        }
        self.heading = h.normalize();
    }

    fn tick(self: *PlayState, cam: *FreeCamera, probe: Probe, keys: ?[*c]const bool, dt: f32) !void {
        if (!self.synced or self.cameraMoved(cam.*)) self.adoptCamera(cam.*);

        const h = eye_height_per_speed * cam.speed_multiplier;
        if (self.eye_height > 0 and h != self.eye_height) {
            self.eye = self.eye.add(self.up.scale(h - self.eye_height));
        }
        self.eye_height = h;
        const r = radius * h;
        const sk = skin * h;

        var fwd: f32 = 0;
        var side: f32 = 0;
        var lift: f32 = 0;
        var space_held = false;
        if (keys) |k| {
            if (k[sdl.SDL_SCANCODE_W]) fwd += 1;
            if (k[sdl.SDL_SCANCODE_S]) fwd -= 1;
            if (k[sdl.SDL_SCANCODE_D]) side -= 1;
            if (k[sdl.SDL_SCANCODE_A]) side += 1;
            if (k[sdl.SDL_SCANCODE_SPACE]) {
                lift += 1;
                space_held = true;
            }
            if (k[sdl.SDL_SCANCODE_LSHIFT] or k[sdl.SDL_SCANCODE_RSHIFT]) lift -= 1;
            if (k[sdl.SDL_SCANCODE_LEFT]) self.look(-turn_speed * dt, 0);
            if (k[sdl.SDL_SCANCODE_RIGHT]) self.look(turn_speed * dt, 0);
            if (k[sdl.SDL_SCANCODE_UP]) self.look(0, turn_speed * dt);
            if (k[sdl.SDL_SCANCODE_DOWN]) self.look(0, -turn_speed * dt);
        }
        const right = self.heading.cross(self.up).normalize();
        const wish = self.heading.scale(fwd).add(right.scale(side)).normalize();

        var snap: f32 = 0;
        if (self.flying) {
            const desired = wish.add(self.up.scale(lift)).normalize().scale(fly_speed * h);
            self.velocity = lerp(self.velocity, desired, 1 - @exp(-fly_response * dt));
        } else {
            var vn = self.velocity.dot(self.up);
            var vt = self.velocity.sub(self.up.scale(vn));
            const desired = wish.scale(walk_speed * h);
            if (self.grounded) {
                vt = desired;
                vn = 0;
                if (self.jump_queued or space_held) {
                    vn = jump_speed * h;
                    self.grounded = false;
                } else {
                    snap = vt.length() * dt;
                }
            } else {
                vt = lerp(vt, desired, 1 - @exp(-air_control * dt));
                vn = @max(vn - gravity * h * dt, -terminal_speed * h);
            }
            self.velocity = vt.add(self.up.scale(vn));
        }
        self.jump_queued = false;

        const delta = self.velocity.scale(dt).sub(self.up.scale(snap));
        const n_sub: u32 = @intFromFloat(std.math.clamp(@ceil(delta.length() / (0.5 * r)), 1, @as(f32, max_substeps)));
        const sub = delta.scale(1.0 / @as(f32, @floatFromInt(n_sub)));

        var grounded = false;
        var field: [4]f32 = .{ 0, 0, 0, 0 };
        for (0..n_sub) |i| {
            self.eye = self.eye.add(sub);
            var pts: [body.len + 1][4]f32 = undefined;
            for (body, 0..) |o, s| pts[s] = point(self.eye.sub(self.up.scale(o * h)), 0.25 * r);
            const last = i + 1 == n_sub;
            const count: usize = if (last) body.len + 1 else body.len;
            if (last) pts[body.len] = point(self.eye.sub(self.up.scale(0.5 * h)), -field_step * h);
            var out: [body.len + 1][4]f32 = undefined;
            try probe.eval(pts[0..count], out[0..count]);
            grounded = self.resolve(out[0..body.len], r, sk);
            if (last) field = out[body.len];
        }
        self.grounded = grounded and !self.flying;
        self.followSurface(field, dt, h, r);
        self.writeCamera(cam);
    }

    fn resolve(self: *PlayState, out: []const [4]f32, r: f32, sk: f32) bool {
        var push = zero;
        var grounded = false;
        for (out, 0..) |o, s| {
            const d = o[0];
            if (!std.math.isFinite(d)) continue;
            const g = Vec3{ .x = o[1], .y = o[2], .z = o[3] };
            const gl = g.length();
            const has_normal = gl > 1e-6 and std.math.isFinite(gl);
            const n = if (has_normal) g.scale(1.0 / gl) else zero;
            const along_up = n.dot(self.up);
            const feet_on_ground = s == 0 and has_normal and along_up > walkable_cos;
            if (d >= r) {
                if (feet_on_ground and d < r + sk and self.velocity.dot(self.up) <= 0) grounded = true;
                continue;
            }
            if (!has_normal) {
                if (d <= 0) push = combinePush(push, self.up.scale(r));
                continue;
            }
            if (feet_on_ground) grounded = true;
            const depth = r + 0.5 * sk - d;
            const q = if (feet_on_ground and !self.flying) self.up.scale(depth / along_up) else n.scale(depth);
            push = combinePush(push, q);
            const vn = self.velocity.dot(n);
            if (vn < 0) self.velocity = self.velocity.sub(n.scale(vn));
        }
        self.eye = self.eye.add(push);
        return grounded;
    }

    fn followSurface(self: *PlayState, field: [4]f32, dt: f32, h: f32, r: f32) void {
        const g = Vec3{ .x = field[1], .y = field[2], .z = field[3] };
        const gl = g.length();
        if (!(gl > 1e-6) or !std.math.isFinite(gl)) return;
        const target = g.scale(1.0 / gl);
        const angle = std.math.acos(std.math.clamp(self.up.dot(target), -1, 1));
        if (angle < 2e-4) return;
        var axis = self.up.cross(target);
        if (axis.length() < 1e-6) axis = self.heading.cross(self.up);
        axis = axis.normalize();
        const rate: f32 = if (self.flying) 1.5 else if (self.grounded) 5 else 2.5;
        const turn = angle * (1 - @exp(-rate * dt));
        const pivot = self.eye.sub(self.up.scale(h - r));
        self.up = self.up.rotate(axis, turn).normalize();
        self.heading = self.heading.rotate(axis, turn);
        self.velocity = self.velocity.rotate(axis, turn);
        self.orthonormalize();
        self.eye = pivot.add(self.up.scale(h - r));
    }
};

const Probe = struct {
    ctx: *const Context,
    gpu: *mesher.MeshGpu,
    uniforms_group: wgpu.WGPUBindGroup,

    fn eval(self: Probe, points: []const [4]f32, out: [][4]f32) !void {
        const n: u32 = @intCast(points.len);
        try self.gpu.run(self.ctx, self.uniforms_group, .probe, .{
            .origin = .{ 0, 0, 0 },
            .cell = 0,
            .iso = 0,
            .count = n,
        }, std.mem.sliceAsBytes(points), std.mem.sliceAsBytes(out), n);
    }
};

fn point(p: Vec3, step: f32) [4]f32 {
    return .{ p.x, p.y, p.z, step };
}

fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
    return a.add(b.sub(a).scale(t));
}

fn combinePush(acc: Vec3, q: Vec3) Vec3 {
    const ql = q.length();
    if (ql < 1e-12) return acc;
    const qh = q.scale(1.0 / ql);
    const extra = ql - acc.dot(qh);
    return if (extra > 0) acc.add(qh.scale(extra)) else acc;
}
