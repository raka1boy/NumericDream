const std = @import("std");
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
const ParticleSystemState = @import("particles.zig").ParticleSystemState;
const gizmo_gpu = @import("../gpu/gizmo_renderer.zig");
const GizmoVertex = gizmo_gpu.GizmoVertex;

pub const max_vertices = gizmo_gpu.max_vertices;

const axis_length: f32 = 1.2;

const axis_x_color = [3]f32{ 0.95, 0.25, 0.25 };
const axis_y_color = [3]f32{ 0.3, 0.9, 0.3 };
const axis_z_color = [3]f32{ 0.3, 0.55, 0.95 };

fn pushSegment(out: []GizmoVertex, count: *usize, a: Vec3, color_a: [3]f32, b: Vec3, color_b: [3]f32) void {
    if (count.* + 2 > out.len) return;
    out[count.*] = .{ .position = .{ a.x, a.y, a.z }, .color = color_a };
    out[count.* + 1] = .{ .position = .{ b.x, b.y, b.z }, .color = color_b };
    count.* += 2;
}

fn pushInstanceGizmo(out: []GizmoVertex, count: *usize, offset: Vec3, rotation_deg: Vec3, scale: Vec3) void {
    const cols = camera_mod.eulerRotationColumns(
        std.math.degreesToRadians(rotation_deg.x),
        std.math.degreesToRadians(rotation_deg.y),
        std.math.degreesToRadians(rotation_deg.z),
    );
    pushSegment(out, count, offset, axis_x_color, offset.add(cols[0].scale(axis_length * scale.x)), axis_x_color);
    pushSegment(out, count, offset, axis_y_color, offset.add(cols[1].scale(axis_length * scale.y)), axis_y_color);
    pushSegment(out, count, offset, axis_z_color, offset.add(cols[2].scale(axis_length * scale.z)), axis_z_color);
}

fn pushWorldAxesGizmo(out: []GizmoVertex, count: *usize, center: Vec3) void {
    pushSegment(out, count, center, axis_x_color, center.add(.{ .x = axis_length, .y = 0, .z = 0 }), axis_x_color);
    pushSegment(out, count, center, axis_y_color, center.add(.{ .x = 0, .y = axis_length, .z = 0 }), axis_y_color);
    pushSegment(out, count, center, axis_z_color, center.add(.{ .x = 0, .y = 0, .z = axis_length }), axis_z_color);
}

const eye_left_color = [3]f32{ 0.95, 0.3, 0.3 };
const eye_right_color = [3]f32{ 0.3, 0.85, 0.95 };
const converge_color = [3]f32{ 1.0, 0.9, 0.3 };

const stereo_ray_drop: f32 = 0.3;

pub fn buildStereoRays(out: []GizmoVertex, start: usize, cam: camera_mod.CameraBasis, eye_separation: f32, convergence_distance: f32) usize {
    var count = start;
    const half_sep = eye_separation * 0.5;
    const drop = cam.up.scale(-stereo_ray_drop);
    const origin = cam.pos.add(drop);
    const target = origin.add(cam.forward.scale(convergence_distance));
    const offsets = [2]f32{ -half_sep, half_sep };
    const colors = [2][3]f32{ eye_left_color, eye_right_color };
    for (offsets, colors) |offset, color| {
        const eye = origin.add(cam.right.scale(offset));
        const dir = target.sub(eye).normalize();
        pushSegment(out, &count, eye, color, target, color);
        pushSegment(out, &count, target, color, target.add(dir.scale(convergence_distance)), .{ 0, 0, 0 });
    }

    const m = @max(convergence_distance * 0.02, 0.01);
    pushSegment(out, &count, target.sub(cam.right.scale(m)), converge_color, target.add(cam.right.scale(m)), converge_color);
    pushSegment(out, &count, target.sub(cam.up.scale(m)), converge_color, target.add(cam.up.scale(m)), converge_color);
    const on_axis = cam.pos.add(cam.forward.scale(convergence_distance));
    pushSegment(out, &count, target, converge_color, on_axis, .{ 0.35, 0.3, 0.1 });
    return count;
}

pub fn buildGizmoLines(
    out: []GizmoVertex,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    particle_systems: []const ParticleSystemState,
) usize {
    var count: usize = 0;
    for (instances) |*inst| {
        if (inst.window_open) pushInstanceGizmo(out, &count, inst.offset, inst.rotation, inst.scale.scale(inst.scale_uniform));
    }
    for (lights) |*light| {
        if (!light.window_open) continue;
        switch (light.kind) {
            .point => pushWorldAxesGizmo(out, &count, light.position),
            .global => {
                const dir = light.direction.normalize();
                pushSegment(out, &count, .{ .x = 0, .y = 0, .z = 0 }, light.color, dir.scale(axis_length * 2.0), light.color);
            },
            .ray => {
                pushWorldAxesGizmo(out, &count, light.position);
                const dir = light.direction.normalize();
                const tip = light.position.add(dir.scale(axis_length * 3.0));
                pushSegment(out, &count, light.position, light.color, tip, .{ 0, 0, 0 });
            },
        }
    }
    for (fog_emitters) |*fog| {
        if (fog.window_open) pushWorldAxesGizmo(out, &count, fog.position);
    }
    for (warps) |*w| {
        if (!w.window_open) continue;
        const extent: Vec3 = switch (w.region_kind) {
            .sphere, .global => .{ .x = w.radius, .y = w.radius, .z = w.radius },
            .box => w.extent,
        };
        pushInstanceGizmo(out, &count, w.center, w.rotation, extent);
    }
    for (particle_systems) |*ps| {
        if (!ps.window_open) continue;
        const extent: Vec3 = switch (ps.spawn_shape) {
            .sphere, .disc => .{ .x = ps.spawn_radius, .y = ps.spawn_radius, .z = ps.spawn_radius },
            .rectangle => .{ .x = ps.extent_x, .y = 0, .z = ps.extent_z },
        };
        pushInstanceGizmo(out, &count, ps.center, ps.rotation, extent.scale(1.0 / axis_length));
        if (ps.velocity_mode == .direction and ps.direction.length() > 1e-6) {
            const tip = ps.center.add(ps.direction.normalize().scale(axis_length * 1.5));
            pushSegment(out, &count, ps.center, .{ 1, 0.85, 0.3 }, tip, .{ 0, 0, 0 });
        }
    }
    return count;
}
