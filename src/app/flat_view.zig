const std = @import("std");
const SliderRange = @import("slider_range.zig").SliderRange;
const Uniforms = @import("../gpu/fractal_renderer.zig").Uniforms;

pub const Coloring = enum {
    section,
    escape,
    distance,
    orbit,

    pub const all = std.enums.values(Coloring);

    pub fn label(self: Coloring) [:0]const u8 {
        return switch (self) {
            .section => "Cross-section",
            .escape => "Escape time",
            .distance => "Distance bands",
            .orbit => "Orbit trap field",
        };
    }
};

pub const Interior = enum {
    trap,
    orbit_radius,
    dark,

    pub const all = std.enums.values(Interior);

    pub fn label(self: Interior) [:0]const u8 {
        return switch (self) {
            .trap => "Orbit trap colour",
            .orbit_radius => "Closest orbit radius",
            .dark => "Black",
        };
    }
};

pub const FlatView = struct {
    window_open: bool = false,
    coloring: Coloring = .section,
    interior: Interior = .trap,

    bailout: f32 = 16,
    bailout_range: SliderRange = .{ .min = 1.5, .max = 256 },
    extra_iterations: f32 = 0,
    extra_iterations_range: SliderRange = .{ .min = 0, .max = 64 },
    band_density: f32 = 0.25,
    band_density_range: SliderRange = .{ .min = 0.01, .max = 2 },
    band_offset: f32 = 0,
    band_offset_range: SliderRange = .{ .min = 0, .max = 1 },
    halo: f32 = 0.35,
    halo_range: SliderRange = .{ .min = 0, .max = 1 },

    relief: f32 = 0,
    relief_range: SliderRange = .{ .min = 0, .max = 8 },
    light_angle: f32 = 135,
    light_angle_range: SliderRange = .{ .min = 0, .max = 360 },
    contours: f32 = 0,
    contours_range: SliderRange = .{ .min = 0, .max = 1 },
    contour_density: f32 = 2,
    contour_density_range: SliderRange = .{ .min = 0.25, .max = 8 },

    slab_slices: f32 = 1,
    slab_slices_range: SliderRange = .{ .min = 1, .max = 32 },
    slab_depth: f32 = 0.5,
    slab_depth_range: SliderRange = .{ .min = 0, .max = 4 },
    slab_opacity: f32 = 0.35,
    slab_opacity_range: SliderRange = .{ .min = 0.01, .max = 1 },

    samples: f32 = 8,
    samples_range: SliderRange = .{ .min = 1, .max = 64 },

    pub fn sampleCount(self: FlatView) u32 {
        return @intFromFloat(std.math.clamp(@round(self.samples), 1, 1024));
    }

    pub fn stamp(self: FlatView, u: *Uniforms) void {
        u.flat_coloring = @floatFromInt(@intFromEnum(self.coloring));
        u.flat_interior = @floatFromInt(@intFromEnum(self.interior));
        u.flat_bailout = self.bailout;
        u.flat_extra_iters = @round(@max(self.extra_iterations, 0));
        u.flat_band_density = self.band_density;
        u.flat_band_offset = self.band_offset;
        u.flat_relief = @max(self.relief, 0);
        u.flat_light_angle = self.light_angle;
        u.flat_contours = std.math.clamp(self.contours, 0, 1);
        u.flat_contour_density = @max(self.contour_density, 0.01);
        u.flat_slab_slices = @round(std.math.clamp(self.slab_slices, 1, 32));
        u.flat_slab_depth = @max(self.slab_depth, 0);
        u.flat_slab_opacity = std.math.clamp(self.slab_opacity, 0.01, 1);
        u.flat_samples = @floatFromInt(self.sampleCount());
        u.flat_halo = @max(self.halo, 0);
    }
};
