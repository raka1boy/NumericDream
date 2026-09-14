const SliderRange = @import("slider_range.zig").SliderRange;

pub const McRenderState = struct {
    enabled: bool = false,

    max_samples: f32 = 256,
    max_samples_range: SliderRange = .{ .min = 4, .max = 32 },
    export_samples: f32 = 512,
    export_samples_range: SliderRange = .{ .min = 16, .max = 128 },
};
