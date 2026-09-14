const std = @import("std");

const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const GpuSky = fractal_gpu.Sky;
const SliderRange = @import("slider_range.zig").SliderRange;
const Vec3 = @import("camera.zig").Vec3;
const export_image = @import("export_image.zig");

pub const max_path_len = export_image.max_path_len;

pub const SkyMode = enum {
    procedural,
    image,

    pub fn label(self: SkyMode) [:0]const u8 {
        return switch (self) {
            .procedural => "Procedural",
            .image => "Image",
        };
    }
};

pub const SkyState = struct {
    mode: SkyMode = .procedural,

    zenith: [3]f32 = .{ 0.02, 0.02, 0.05 },
    horizon: [3]f32 = .{ 0.04, 0.035, 0.07 },
    ground: [3]f32 = .{ 0.06, 0.05, 0.09 },
    falloff: f32 = 1.0,
    falloff_range: SliderRange = .{ .min = 0.2, .max = 8.0 },

    sun_enabled: bool = false,
    sun_direction: Vec3 = .{ .x = 0.4, .y = 0.55, .z = 0.3 },
    sun_direction_range_x: SliderRange = .{ .min = -1, .max = 1 },
    sun_direction_range_y: SliderRange = .{ .min = -1, .max = 1 },
    sun_direction_range_z: SliderRange = .{ .min = -1, .max = 1 },
    sun_size: f32 = 3.0,
    sun_size_range: SliderRange = .{ .min = 0.1, .max = 30.0 },
    sun_color: [3]f32 = .{ 1.0, 0.95, 0.85 },
    sun_intensity: f32 = 20.0,
    sun_intensity_range: SliderRange = .{ .min = 0.0, .max = 200.0 },

    image_path: [max_path_len]u8 = @splat(0),
    image_status: [status_len]u8 = @splat(0),

    intensity: f32 = 1.0,
    intensity_range: SliderRange = .{ .min = 0.0, .max = 8.0 },
    yaw: f32 = 0.0,
    yaw_range: SliderRange = .{ .min = 0.0, .max = 360.0 },

    photons: bool = false,

    window_open: bool = false,

    pub fn pathSlice(self: *const SkyState) []const u8 {
        const n = std.mem.indexOfScalar(u8, &self.image_path, 0) orelse self.image_path.len;
        return self.image_path[0..n];
    }

    pub fn setPath(self: *SkyState, path: []const u8) void {
        const n = @min(path.len, self.image_path.len - 1);
        @memcpy(self.image_path[0..n], path[0..n]);
        @memset(self.image_path[n..], 0);
    }

    pub fn statusSlice(self: *const SkyState) [:0]const u8 {
        const n = std.mem.indexOfScalar(u8, &self.image_status, 0) orelse 0;
        return self.image_status[0..n :0];
    }

    pub fn setStatus(self: *SkyState, comptime fmt: []const u8, args: anytype) void {
        @memset(&self.image_status, 0);
        _ = std.fmt.bufPrint(self.image_status[0 .. self.image_status.len - 1], fmt, args) catch {};
    }

    pub fn toGpu(self: SkyState, has_image: bool) GpuSky {
        const use_image = self.mode == .image and has_image;
        const dir_len = @sqrt(self.sun_direction.x * self.sun_direction.x +
            self.sun_direction.y * self.sun_direction.y +
            self.sun_direction.z * self.sun_direction.z);
        const inv = if (dir_len > 1e-6) 1.0 / dir_len else 0.0;
        const sun_on = self.sun_enabled and !use_image and dir_len > 1e-6;
        return .{
            .mode = if (use_image) 1.0 else 0.0,
            .intensity = @max(self.intensity, 0.0),
            .falloff = @max(self.falloff, 0.01),
            .photons = if (self.photons) 1.0 else 0.0,
            .zenith = self.zenith,
            .sun_cos = if (sun_on)
                @cos(std.math.degreesToRadians(std.math.clamp(self.sun_size, 0.01, 89.0)))
            else
                -2.0,
            .horizon = self.horizon,
            .sun_intensity = @max(self.sun_intensity, 0.0),
            .ground = self.ground,
            .yaw = std.math.degreesToRadians(self.yaw),
            .sun_color = self.sun_color,
            .sun_dir = .{
                self.sun_direction.x * inv,
                self.sun_direction.y * inv,
                self.sun_direction.z * inv,
            },
        };
    }
};

const status_len: usize = 96;

pub const Preset = struct {
    name: [:0]const u8,
    zenith: [3]f32,
    horizon: [3]f32,
    ground: [3]f32,
    falloff: f32,
    sun_enabled: bool,
    sun_color: [3]f32,
    sun_intensity: f32,
    sun_size: f32,
    sun_direction: Vec3,
};

pub const presets = [_]Preset{
    .{
        .name = "Classic (dim)",
        .zenith = .{ 0.02, 0.02, 0.05 },
        .horizon = .{ 0.04, 0.035, 0.07 },
        .ground = .{ 0.06, 0.05, 0.09 },
        .falloff = 1.0,
        .sun_enabled = false,
        .sun_color = .{ 1.0, 0.95, 0.85 },
        .sun_intensity = 20.0,
        .sun_size = 3.0,
        .sun_direction = .{ .x = 0.4, .y = 0.55, .z = 0.3 },
    },
    .{
        .name = "Daylight",
        .zenith = .{ 0.10, 0.24, 0.58 },
        .horizon = .{ 0.62, 0.74, 0.92 },
        .ground = .{ 0.18, 0.16, 0.14 },
        .falloff = 2.6,
        .sun_enabled = true,
        .sun_color = .{ 1.0, 0.96, 0.88 },
        .sun_intensity = 40.0,
        .sun_size = 2.0,
        .sun_direction = .{ .x = 0.35, .y = 0.62, .z = 0.35 },
    },
    .{
        .name = "Sunset",
        .zenith = .{ 0.06, 0.09, 0.22 },
        .horizon = .{ 0.95, 0.42, 0.16 },
        .ground = .{ 0.10, 0.06, 0.06 },
        .falloff = 4.5,
        .sun_enabled = true,
        .sun_color = .{ 1.0, 0.52, 0.22 },
        .sun_intensity = 30.0,
        .sun_size = 4.0,
        .sun_direction = .{ .x = 0.85, .y = 0.09, .z = 0.2 },
    },
    .{
        .name = "Overcast",
        .zenith = .{ 0.55, 0.57, 0.60 },
        .horizon = .{ 0.72, 0.73, 0.75 },
        .ground = .{ 0.28, 0.28, 0.29 },
        .falloff = 1.6,
        .sun_enabled = false,
        .sun_color = .{ 1.0, 1.0, 1.0 },
        .sun_intensity = 0.0,
        .sun_size = 12.0,
        .sun_direction = .{ .x = 0.2, .y = 0.9, .z = 0.2 },
    },
    .{
        .name = "Studio",
        .zenith = .{ 0.85, 0.85, 0.88 },
        .horizon = .{ 0.40, 0.40, 0.42 },
        .ground = .{ 0.04, 0.04, 0.04 },
        .falloff = 1.2,
        .sun_enabled = false,
        .sun_color = .{ 1.0, 1.0, 1.0 },
        .sun_intensity = 0.0,
        .sun_size = 20.0,
        .sun_direction = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
    },
};

pub fn applyPreset(sky: *SkyState, p: Preset) void {
    sky.zenith = p.zenith;
    sky.horizon = p.horizon;
    sky.ground = p.ground;
    sky.falloff = p.falloff;
    sky.sun_enabled = p.sun_enabled;
    sky.sun_color = p.sun_color;
    sky.sun_intensity = p.sun_intensity;
    sky.sun_size = p.sun_size;
    sky.sun_direction = p.sun_direction;
    sky.mode = .procedural;
}
