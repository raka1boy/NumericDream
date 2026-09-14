const std = @import("std");
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
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

pub fn buildGizmoLines(
    out: []GizmoVertex,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
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
    return count;
}
