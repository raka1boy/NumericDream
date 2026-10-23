const SliderRange = @import("slider_range.zig").SliderRange;

pub const McRenderState = struct {
    enabled: bool = false,

    max_samples: f32 = 256,
    max_samples_range: SliderRange = .{ .min = 4, .max = 32 },
    export_samples: f32 = 512,
    export_samples_range: SliderRange = .{ .min = 16, .max = 128 },

    adaptive: bool = false,
    adaptive_threshold: f32 = 0.02,
    adaptive_threshold_range: SliderRange = .{ .min = 0.002, .max = 0.1 },
    adaptive_min_samples: f32 = 16,
    adaptive_min_samples_range: SliderRange = .{ .min = 4, .max = 64 },

    inner_samples: f32 = 1,
    inner_samples_range: SliderRange = .{ .min = 1, .max = 32 },
    light_pick: bool = true,
    fog_tracking: bool = true,
    primary_cache: bool = true,
    wavefront: bool = true,

    denoise: bool = false,
    denoise_preview: bool = false,
    denoise_strength: f32 = 1.0,
    denoise_strength_range: SliderRange = .{ .min = 0, .max = 1 },
};
