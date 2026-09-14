const std = @import("std");

pub const Part = enum(u5) {
    color_strips,
    direct_lights,
    specular,
    shadows,
    ambient_occlusion,
    fog,
    reflections,
    refraction,
    photon_map,
    subsurface,
    iridescence,
    dispersion,
    sky,
    depth_of_field,
    mc_indirect,

    pub const count = @typeInfo(Part).@"enum".field_names.len;

    pub fn bit(self: Part) u32 {
        return @as(u32, 1) << @backingInt(self);
    }
};

pub const Group = enum {
    surface,
    light,
    transport,
    post,

    pub fn label(self: Group) [:0]const u8 {
        return switch (self) {
            .surface => "Surface",
            .light => "Light",
            .transport => "Transport",
            .post => "Camera",
        };
    }
};

pub const PartInfo = struct {
    label: [:0]const u8,
    group: Group,
    off_hint: [:0]const u8,
};

pub fn info(part: Part) PartInfo {
    return switch (part) {
        .color_strips => .{ .label = "Colour strips", .group = .surface, .off_hint = "Every surface takes the flat grey of Geometry only; glossiness, transparency and the rest are kept." },
        .specular => .{ .label = "Specular highlights", .group = .surface, .off_hint = "Lights keep their diffuse term but throw no highlight." },
        .subsurface => .{ .label = "Subsurface scattering", .group = .surface, .off_hint = "Translucent materials shade as solid." },
        .iridescence => .{ .label = "Iridescence", .group = .surface, .off_hint = "Thin films tint nothing." },
        .direct_lights => .{ .label = "Direct lights", .group = .light, .off_hint = "No light from the light list, on surfaces or in fog. What remains is ambient, sky and the photon map." },
        .shadows => .{ .label = "Shadows", .group = .light, .off_hint = "Every surface and every fog step sees every light unoccluded." },
        .ambient_occlusion => .{ .label = "Ambient occlusion", .group = .light, .off_hint = "The ambient term is flat everywhere." },
        .photon_map => .{ .label = "Photon map", .group = .light, .off_hint = "Gathers nothing: no caustics or bounced light. Shadow rays go back to passing through glass themselves. The map is still traced, so switching it back on is instant." },
        .sky => .{ .label = "Sky", .group = .light, .off_hint = "Black behind the scene and no sky light on surfaces." },
        .fog => .{ .label = "Fog", .group = .transport, .off_hint = "Fog emitters neither glow nor block anything." },
        .reflections => .{ .label = "Reflections", .group = .transport, .off_hint = "Reflective surfaces show only their own shading; the reflected share of the light is dropped, so grazing angles darken a little." },
        .refraction => .{ .label = "Refraction", .group = .transport, .off_hint = "Transparent materials shade as opaque, for the camera and for shadow rays alike." },
        .dispersion => .{ .label = "Dispersion", .group = .transport, .off_hint = "Every material refracts every wavelength the same way." },
        .mc_indirect => .{ .label = "MC indirect light", .group = .transport, .off_hint = "MC Render's bounce ray is skipped; the ambient term stands in for it. No effect unless MC Render is on." },
        .depth_of_field => .{ .label = "Depth of field", .group = .post, .off_hint = "Pinhole camera, whatever the aperture says." },
    };
}

pub const RenderParts = struct {
    enabled: bool = false,
    window_open: bool = false,
    geometry_only: bool = true,
    on: [Part.count]bool = @splat(true),

    pub fn geometryOnly(self: RenderParts) bool {
        return self.enabled and self.geometry_only;
    }

    pub fn isOn(self: RenderParts, part: Part) bool {
        return self.on[@backingInt(part)];
    }

    pub fn set(self: *RenderParts, part: Part, value: bool) void {
        self.on[@backingInt(part)] = value;
    }

    pub fn setAll(self: *RenderParts, value: bool) void {
        self.on = @splat(value);
    }

    pub fn mask(self: RenderParts) u32 {
        if (!self.enabled or self.geometry_only) return 0;
        var bits: u32 = 0;
        for (std.enums.values(Part)) |part| {
            if (!self.isOn(part)) bits |= part.bit();
        }
        return bits;
    }

    pub fn maskUniform(self: RenderParts) f32 {
        return @floatFromInt(self.mask());
    }
};

test "mask bits follow the enum order and clear when the feature is off" {
    var parts = RenderParts{ .enabled = true, .geometry_only = false };
    try std.testing.expectEqual(@as(u32, 0), parts.mask());
    parts.set(.shadows, false);
    parts.set(.fog, false);
    try std.testing.expectEqual((@as(u32, 1) << 3) | (@as(u32, 1) << 5), parts.mask());
    parts.geometry_only = true;
    try std.testing.expectEqual(@as(u32, 0), parts.mask());
    parts.geometry_only = false;
    parts.enabled = false;
    try std.testing.expectEqual(@as(u32, 0), parts.mask());
}
