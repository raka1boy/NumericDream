const std = @import("std");

const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const FreeCamera = camera_mod.FreeCamera;

const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
const FormulaState = @import("formula.zig").FormulaState;

const SliderRange = @import("slider_range.zig").SliderRange;

const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const max_instances = fractal_gpu.max_instances;
const max_mixins = fractal_gpu.max_mixins;
const max_color_stops = fractal_gpu.max_color_stops;
const max_params = fractal_gpu.max_params;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;

pub const max_keyframes = 64;

pub const FormulaParamsSnapshot = struct { values: [max_params]f32 = std.mem.zeroes([max_params]f32) };

pub const MixinSnapshot = struct { params: FormulaParamsSnapshot = .{} };

pub const ColorStopSnapshot = struct {
    position: f32 = 0,
    color: [3]f32 = .{ 0, 0, 0 },
    glossiness: f32 = 0,
    transparency: f32 = 0,
    reflectiveness: f32 = 0,
    ior: f32 = 1.5,
    subsurface: f32 = 0,
    abbe: f32 = 0,
    inner_max_steps: f32 = 64,
    roughness: f32 = 0,
    film_thickness: f32 = 400,
    film_ior: f32 = 1.8,
    film_strength: f32 = 0,
    film_angle_scale: f32 = 1,
    film_perturb: f32 = 0,
    film_perturb_scale: f32 = 0.2,
};

pub const InstanceSnapshot = struct {
    offset: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    scale: Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    rotation: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    blend_k: f32 = 0,
    params: FormulaParamsSnapshot = .{},
    mixins: [max_mixins]MixinSnapshot = std.mem.zeroes([max_mixins]MixinSnapshot),
    colors: [max_color_stops]ColorStopSnapshot = @splat(.{}),
};

pub const LightSnapshot = struct {
    color: [3]f32 = .{ 1, 1, 1 },
    brightness: f32 = 1,
    position: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    direction: Vec3 = .{ .x = 0, .y = 1, .z = 0 },
    shadow_softness: f32 = 8,
    spread: f32 = 25,
};

pub const FogSnapshot = struct {
    position: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    radius: f32 = 1,
    density: f32 = 1,
    softness: f32 = 0.5,
    color: [3]f32 = .{ 1, 1, 1 },
    anisotropy: f32 = 0,
};

pub const WarpSnapshot = struct {
    center: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    rotation: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    radius: f32 = 1,
    extent: Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    falloff: f32 = 0,
    strength: f32 = 1,
    twist_rate: f32 = 0,
    bend_rate: f32 = 0,
    rotate_angle: f32 = 0,
    scale: Vec3 = .{ .x = 1, .y = 1, .z = 1 },
    inversion_radius: f32 = 1,
    inversion_min: f32 = 0.25,
    repeat_cell: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    displace_amp: f32 = 0,
    displace_freq: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
};

pub const CameraSnapshot = struct {
    position: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    forward: Vec3 = .{ .x = 0, .y = 0, .z = -1 },
    up: Vec3 = .{ .x = 0, .y = 1, .z = 0 },
    focus_distance: f32 = 3.2,
    aperture: f32 = 0.05,
    focus_range: f32 = 0.5,
    zoom_2d: f32 = camera_mod.default_zoom_2d,
};

pub const AnimSnapshot = struct {
    camera: CameraSnapshot = .{},
    instances: [max_instances]InstanceSnapshot = @splat(.{}),
    lights: [max_lights]LightSnapshot = std.mem.zeroes([max_lights]LightSnapshot),
    fog_emitters: [max_fog_emitters]FogSnapshot = std.mem.zeroes([max_fog_emitters]FogSnapshot),
    warps: [max_warps]WarpSnapshot = @splat(.{}),
};

pub const Keyframe = struct { time: f32, snapshot: AnimSnapshot };

pub const TimelineState = struct {
    keyframes: [max_keyframes]Keyframe = undefined,
    keyframe_count: usize = 0,
    duration: f32 = 10.0,
    duration_range: SliderRange = .{ .min = 0.5, .max = 600.0 },
    playhead: f32 = 0.0,
    playing: bool = false,
    dirty: bool = false,
};

pub const AnimRenderState = struct {
    window_open: bool = false,
    fps: f32 = 30.0,
    fps_range: SliderRange = .{ .min = 1.0, .max = 120.0 },
    width: i32 = 1280,
    height: i32 = 720,
    fog_samples: f32 = 1,
    fog_samples_range: SliderRange = .{ .min = 1, .max = 16 },
    motion_blur: f32 = 0.0,
    motion_blur_range: SliderRange = .{ .min = 0.0, .max = 1.0 },
    motion_blur_samples: f32 = 8,
    motion_blur_samples_range: SliderRange = .{ .min = 2, .max = 32 },
    save_frames: bool = false,
    status_buf: [200]u8 = undefined,
    status: [:0]const u8 = "",
};

fn lerpF32(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

fn lerpVec3(a: Vec3, b: Vec3, t: f32) Vec3 {
    return .{ .x = lerpF32(a.x, b.x, t), .y = lerpF32(a.y, b.y, t), .z = lerpF32(a.z, b.z, t) };
}

fn lerpAny(comptime T: type, a: T, b: T, t: f32) T {
    var out: T = .{};
    const info = @typeInfo(T).@"struct";
    inline for (info.field_names, info.field_types) |name, FieldType| {
        const av = @field(a, name);
        const bv = @field(b, name);
        switch (@typeInfo(FieldType)) {
            .float => @field(out, name) = lerpF32(av, bv, t),
            .@"struct" => @field(out, name) = if (FieldType == Vec3) lerpVec3(av, bv, t) else lerpAny(FieldType, av, bv, t),
            .array => |arr_info| {
                var arr: FieldType = undefined;
                if (arr_info.child == f32) {
                    inline for (0..arr_info.len) |i| arr[i] = lerpF32(av[i], bv[i], t);
                } else {
                    inline for (0..arr_info.len) |i| arr[i] = lerpAny(arr_info.child, av[i], bv[i], t);
                }
                @field(out, name) = arr;
            },
            .@"enum" => @field(out, name) = if (t < 0.5) av else bv,
            else => @compileError("lerpAny: unhandled field type for " ++ @typeName(T) ++ "." ++ name),
        }
    }
    return out;
}

fn orthonormalize(forward: Vec3, up: Vec3) struct { forward: Vec3, up: Vec3 } {
    const f = forward.normalize();
    const right = f.cross(up).normalize();
    const u = right.cross(f).normalize();
    return .{ .forward = f, .up = u };
}

fn lerpZoom2d(a: f32, b: f32, t: f32) f32 {
    if (a <= 0 or b <= 0) return lerpF32(a, b, t);
    return @exp(lerpF32(@log(a), @log(b), t));
}

fn lerpCamera(a: CameraSnapshot, b: CameraSnapshot, t: f32) CameraSnapshot {
    var out = lerpAny(CameraSnapshot, a, b, t);
    out.zoom_2d = lerpZoom2d(a.zoom_2d, b.zoom_2d, t);
    const basis = orthonormalize(out.forward, out.up);
    out.forward = basis.forward;
    out.up = basis.up;
    return out;
}

fn lerpSnapshot(a: AnimSnapshot, b: AnimSnapshot, t: f32) AnimSnapshot {
    var out = lerpAny(AnimSnapshot, a, b, t);
    out.camera = lerpCamera(a.camera, b.camera, t);
    return out;
}

/// Copies every field of `Snap` out of `src` (which must have fields of the same names).
fn capture(comptime Snap: type, src: anytype) Snap {
    var out: Snap = undefined;
    inline for (@typeInfo(Snap).@"struct".field_names) |name| @field(out, name) = @field(src, name);
    return out;
}

fn apply(snap: anytype, dst: anytype) void {
    inline for (@typeInfo(@TypeOf(snap)).@"struct".field_names) |name| @field(dst, name) = @field(snap, name);
}

fn captureParams(formula: *const FormulaState) FormulaParamsSnapshot {
    var out = FormulaParamsSnapshot{};
    for (0..@min(formula.custom_param_count, max_params)) |p| out.values[p] = formula.custom_params[p].value;
    return out;
}

fn applyParams(snap: *const FormulaParamsSnapshot, formula: *FormulaState) void {
    for (0..@min(formula.custom_param_count, max_params)) |p| formula.custom_params[p].value = snap.values[p];
}

pub fn captureSnapshot(
    instances: []const FractalInstanceState,
    instance_count: usize,
    lights: []const LightState,
    light_count: usize,
    fog_emitters: []const FogEmitterState,
    fog_count: usize,
    warps: []const WarpState,
    warp_count: usize,
    camera: FreeCamera,
) AnimSnapshot {
    var snap = AnimSnapshot{ .camera = capture(CameraSnapshot, camera) };

    for (0..@min(instance_count, max_instances)) |i| {
        const inst = &instances[i];
        var s = InstanceSnapshot{ .offset = inst.offset, .scale = inst.scale, .rotation = inst.rotation, .blend_k = inst.blend_k };
        s.params = captureParams(&inst.formula);
        for (0..@min(inst.mixin_count, max_mixins)) |m| s.mixins[m].params = captureParams(&inst.mixins[m].formula);
        for (0..@min(inst.color_count, max_color_stops)) |c| s.colors[c] = capture(ColorStopSnapshot, inst.colors[c]);
        snap.instances[i] = s;
    }
    for (0..@min(light_count, max_lights)) |i| snap.lights[i] = capture(LightSnapshot, lights[i]);
    for (0..@min(fog_count, max_fog_emitters)) |i| snap.fog_emitters[i] = capture(FogSnapshot, fog_emitters[i]);
    for (0..@min(warp_count, max_warps)) |i| snap.warps[i] = capture(WarpSnapshot, warps[i]);
    return snap;
}

pub fn applySnapshot(
    snapshot: *const AnimSnapshot,
    instances: []FractalInstanceState,
    instance_count: usize,
    lights: []LightState,
    light_count: usize,
    fog_emitters: []FogEmitterState,
    fog_count: usize,
    warps: []WarpState,
    warp_count: usize,
    camera: *FreeCamera,
) void {
    apply(snapshot.camera, camera);
    camera.zoom_2d = std.math.clamp(camera.zoom_2d, camera_mod.min_zoom_2d, camera_mod.max_zoom_2d);
    const basis = orthonormalize(camera.forward, camera.up);
    camera.forward = basis.forward;
    camera.up = basis.up;

    for (0..@min(instance_count, max_instances)) |i| {
        const inst = &instances[i];
        const s = &snapshot.instances[i];
        inst.offset = s.offset;
        inst.scale = s.scale;
        inst.rotation = s.rotation;
        inst.blend_k = s.blend_k;
        applyParams(&s.params, &inst.formula);
        for (0..@min(inst.mixin_count, max_mixins)) |m| applyParams(&s.mixins[m].params, &inst.mixins[m].formula);
        for (0..@min(inst.color_count, max_color_stops)) |c| apply(s.colors[c], &inst.colors[c]);
    }
    for (0..@min(light_count, max_lights)) |i| apply(snapshot.lights[i], &lights[i]);
    for (0..@min(fog_count, max_fog_emitters)) |i| apply(snapshot.fog_emitters[i], &fog_emitters[i]);
    for (0..@min(warp_count, max_warps)) |i| apply(snapshot.warps[i], &warps[i]);
}

// Caller must ensure timeline.keyframe_count > 0.
pub fn evaluate(timeline: *const TimelineState, t_in: f32) AnimSnapshot {
    const n = timeline.keyframe_count;
    std.debug.assert(n > 0);
    if (n == 1) return timeline.keyframes[0].snapshot;

    const t = std.math.clamp(t_in, timeline.keyframes[0].time, timeline.keyframes[n - 1].time);

    var i: usize = 0;
    while (i + 1 < n and timeline.keyframes[i + 1].time < t) : (i += 1) {}
    const a = timeline.keyframes[i];
    const b = timeline.keyframes[@min(i + 1, n - 1)];

    const span = b.time - a.time;
    const alpha = if (span > 1e-6) (t - a.time) / span else 0.0;
    return lerpSnapshot(a.snapshot, b.snapshot, alpha);
}

pub fn addKeyframe(timeline: *TimelineState, time_in: f32, snapshot: AnimSnapshot) ?usize {
    if (timeline.keyframe_count >= max_keyframes) return null;
    const time = std.math.clamp(time_in, 0, timeline.duration);

    var insert_at: usize = timeline.keyframe_count;
    for (0..timeline.keyframe_count) |i| {
        if (time < timeline.keyframes[i].time) {
            insert_at = i;
            break;
        }
    }

    var j = timeline.keyframe_count;
    while (j > insert_at) : (j -= 1) timeline.keyframes[j] = timeline.keyframes[j - 1];
    timeline.keyframes[insert_at] = .{ .time = time, .snapshot = snapshot };
    timeline.keyframe_count += 1;
    timeline.dirty = true;
    return insert_at;
}

pub fn updateKeyframeAt(timeline: *TimelineState, index: usize, snapshot: AnimSnapshot) void {
    timeline.keyframes[index].snapshot = snapshot;
    timeline.dirty = true;
}

pub fn removeKeyframeAt(timeline: *TimelineState, index: usize) void {
    var i = index;
    while (i + 1 < timeline.keyframe_count) : (i += 1) timeline.keyframes[i] = timeline.keyframes[i + 1];
    timeline.keyframe_count -= 1;
    timeline.dirty = true;
}

pub fn tickPlayback(timeline: *TimelineState, dt: f32) void {
    if (!timeline.playing) return;
    timeline.playhead += dt;
    if (timeline.playhead >= timeline.duration) {
        timeline.playhead = timeline.duration;
        timeline.playing = false;
    }
    timeline.dirty = true;
}
