const SliderRange = @import("slider_range.zig").SliderRange;

pub const MarchPrecision = struct {
    epsilon_coefficient: f32 = 0.0005,
    epsilon_coefficient_range: SliderRange = .{ .min = 0.0001, .max = 0.005 },

    epsilon_floor: f32 = 0.00005,
    epsilon_floor_range: SliderRange = .{ .min = 0.000005, .max = 0.001 },

    hq_footprint_budget_px: f32 = 2.0,
    hq_footprint_budget_px_range: SliderRange = .{ .min = 0.25, .max = 8.0 },

    refine_fast: f32 = 4,
    refine_fast_range: SliderRange = .{ .min = 1, .max = 12 },
    refine_hq: f32 = 20,
    refine_hq_range: SliderRange = .{ .min = 4, .max = 40 },
};

pub const RenderSettingsState = struct {
    window_open: bool = false,

    max_steps: f32 = 256,
    max_steps_range: SliderRange = .{ .min = 32, .max = 1024 },

    max_dist: f32 = 24.0,
    max_dist_range: SliderRange = .{ .min = 4, .max = 64 },

    max_reflection_bounces: f32 = 1,
    max_reflection_bounces_range: SliderRange = .{ .min = 0, .max = 8 },

    fog_samples: f32 = 8,
    fog_samples_range: SliderRange = .{ .min = 1, .max = 16 },

    precision: MarchPrecision = .{},
};
