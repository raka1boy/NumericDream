const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const scene_state = @import("scene_state.zig");
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const SkyState = @import("sky.zig").SkyState;

pub const Approx = enum(u5) {
    simple_fog,
    fake_caustics,
    fake_bounce,
    sky_ambient,
    thin_glass,
    tint,
    cheap_dispersion,
    coarse_secondary,
    distance_lod,

    pub fn bit(self: Approx) u32 {
        return @as(u32, 1) << @backingInt(self);
    }
};

pub const Info = struct {
    label: [:0]const u8,
    hint: [:0]const u8,
};

pub fn info(a: Approx) Info {
    return switch (a) {
        .simple_fog => .{ .label = "Simple fog", .hint = "Fog spheres become flat, unshadowed haze with a closed-form density, and light shafts are drawn as a screen-space streak from the brightest light. The fog march and its photon lookups are skipped." },
        .fake_caustics => .{ .label = "Fake caustics", .hint = "Shadow rays pass through glass and pick up a procedural ripple pattern instead of photon-map caustics." },
        .fake_bounce => .{ .label = "Fake bounce light", .hint = "Surfaces facing away from a light get a dim, self-coloured fill instead of photon-map bounce light." },
        .sky_ambient => .{ .label = "Indirect light", .hint = "Ambient light is the sky (and sun) seen along the normal, darkened by how many march steps the hit took. Replaces MC Render's bounce ray and the 5-tap AO." },
        .thin_glass => .{ .label = "Thin glass", .hint = "Light refracts once into glass and then shows the sky in that bent direction. Nothing behind glass is visible through it." },
        .tint => .{ .label = "Tint approximation", .hint = "Glass thickness comes from one short 12-step march inside and tints by Beer-Lambert absorption. Rays leave glass going the way they came in, as through a flat slab." },
        .cheap_dispersion => .{ .label = "Cheap dispersion", .hint = "Only the last refraction before the sky splits into red, green and blue. Rainbow fringes come out clean, but colour does not separate through several walls." },
        .coarse_secondary => .{ .label = "Low-precision secondary marches", .hint = "Reflected, refracted and bounce rays march with half the steps, a 4x looser hit distance and no refinement." },
        .distance_lod => .{ .label = "Distance LOD", .hint = "Fractals lose iterations with distance from the camera, blended between levels. Far detail softens and can bulge slightly." },
    };
}

pub const Approximations = struct {
    simple_fog: bool = false,
    fake_caustics: bool = false,
    fake_bounce: bool = false,
    sky_ambient: bool = false,
    thin_glass: bool = false,
    tint: bool = false,
    cheap_dispersion: bool = false,
    coarse_secondary: bool = false,
    distance_lod: bool = false,

    shaft_strength: f32 = 1.0,
    shaft_strength_range: SliderRange = .{ .min = 0.0, .max = 4.0 },
    caustic_strength: f32 = 1.0,
    caustic_strength_range: SliderRange = .{ .min = 0.0, .max = 3.0 },
    caustic_scale: f32 = 0.3,
    caustic_scale_range: SliderRange = .{ .min = 0.02, .max = 2.0 },
    bounce_strength: f32 = 0.35,
    bounce_strength_range: SliderRange = .{ .min = 0.0, .max = 2.0 },
    tint_density: f32 = 1.0,
    tint_density_range: SliderRange = .{ .min = 0.0, .max = 8.0 },
    lod_start: f32 = 2.0,
    lod_start_range: SliderRange = .{ .min = 0.1, .max = 20.0 },
    lod_strength: f32 = 1.5,
    lod_strength_range: SliderRange = .{ .min = 0.0, .max = 6.0 },

    pub fn isOn(self: Approximations, a: Approx) bool {
        return switch (a) {
            inline else => |tag| @field(self, @tagName(tag)),
        };
    }

    pub fn set(self: *Approximations, a: Approx, value: bool) void {
        switch (a) {
            inline else => |tag| @field(self, @tagName(tag)) = value,
        }
    }

    pub fn mask(self: Approximations) u32 {
        var bits: u32 = 0;
        for (std.enums.values(Approx)) |a| {
            if (self.isOn(a)) bits |= a.bit();
        }
        return bits;
    }

    pub fn activeCount(self: Approximations) u32 {
        return @popCount(self.mask());
    }

    pub fn replacesPhotons(self: Approximations) bool {
        return self.simple_fog and self.fake_caustics and self.fake_bounce;
    }
};

pub const ShaftSource = struct {
    position: [3]f32,
    color: [3]f32,
    directional: bool,
};

fn fogAmount(fog_emitters: []const FogEmitterState) f32 {
    var clear: f32 = 1.0;
    for (fog_emitters) |f| {
        if (!f.visible) continue;
        clear *= @exp(-@max(f.density, 0.0) * @max(f.radius, 0.0));
    }
    return 1.0 - clear;
}

fn dist2(a: [3]f32, b: [3]f32) f32 {
    const d = [3]f32{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
    return d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
}

const sky_sun_shaft_scale: f32 = 0.02;

pub fn shaftSource(lights: []const LightState, sky: SkyState, camera_pos: [3]f32) ?ShaftSource {
    var best: ?ShaftSource = null;
    var best_power: f32 = 0;
    for (lights) |l| {
        if (!l.visible or l.brightness <= 0) continue;
        const directional = l.kind == .global;
        const pos: [3]f32 = if (directional)
            .{ l.direction.x, l.direction.y, l.direction.z }
        else
            .{ l.position.x, l.position.y, l.position.z };
        const power = if (directional) l.brightness else l.brightness / @max(dist2(pos, camera_pos), 1.0);
        if (power <= best_power) continue;
        best_power = power;
        best = .{
            .position = pos,
            .color = .{ l.color[0] * power, l.color[1] * power, l.color[2] * power },
            .directional = directional,
        };
    }
    if (best != null) return best;

    const g = sky.toGpu(false);
    if (g.sun_cos <= -1.0) return null;
    const yaw = g.yaw;
    const c = @cos(yaw);
    const s = @sin(yaw);
    const d = g.sun_dir;
    const power = g.sun_intensity * sky_sun_shaft_scale;
    return .{
        .position = .{ c * d[0] + s * d[2], d[1], -s * d[0] + c * d[2] },
        .color = .{ g.sun_color[0] * power, g.sun_color[1] * power, g.sun_color[2] * power },
        .directional = true,
    };
}

pub fn shaftParams(approx: Approximations, lights: []const LightState, fog_emitters: []const FogEmitterState, sky: SkyState, camera_pos: [3]f32) ?[8]f32 {
    if (!approx.simple_fog or approx.shaft_strength <= 0) return null;
    const amount = fogAmount(fog_emitters) * approx.shaft_strength;
    if (amount <= 0) return null;
    const src = shaftSource(lights, sky, camera_pos) orelse return null;
    return .{
        src.position[0],
        src.position[1],
        src.position[2],
        amount,
        src.color[0],
        src.color[1],
        src.color[2],
        if (src.directional) 1.0 else 0.0,
    };
}

test "mask follows the enum order" {
    var a = Approximations{};
    try std.testing.expectEqual(@as(u32, 0), a.mask());
    a.set(.fake_bounce, true);
    a.set(.distance_lod, true);
    try std.testing.expectEqual((@as(u32, 1) << 2) | (@as(u32, 1) << 8), a.mask());
    try std.testing.expectEqual(@as(u32, 2), a.activeCount());
    try std.testing.expect(!a.replacesPhotons());
    a.simple_fog = true;
    a.fake_caustics = true;
    try std.testing.expect(a.replacesPhotons());
}
