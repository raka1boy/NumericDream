const SliderRange = @import("slider_range.zig").SliderRange;

pub const StereoState = struct {
    enabled: bool = false,
    settings_open: bool = false,
    //viewport draws both eyes blended 50/50 so the convergence plane can be judged before an export
    preview: bool = false,
    eye_separation: f32 = 0.12,
    eye_separation_range: SliderRange = .{ .min = 0.0, .max = 1.0 },
    convergence_distance: f32 = 3.0,
    convergence_distance_range: SliderRange = .{ .min = 0.1, .max = 20.0 },
};
