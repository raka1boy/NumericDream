const std = @import("std");
const nk = @import("../bindings/nuklear.zig").c;
const widgets = @import("widgets.zig");
const layout = @import("layout.zig");
const editor_windows = @import("editor_windows.zig");
const ui_backend = @import("nuklear_backend.zig");
const camera_mod = @import("../app/camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const flat_view = @import("../app/flat_view.zig");
const FlatView = flat_view.FlatView;
const navigator_mod = @import("../app/navigator.zig");
const NavigatorState = navigator_mod.NavigatorState;
const NavigatorRenderer = @import("../gpu/navigator.zig").NavigatorRenderer;

const nav_line = nk.struct_nk_color{ .r = 255, .g = 220, .b = 80, .a = 220 };
const nav_dot_px: f32 = 4;
const nav_ray_units: f32 = 8;

pub fn buildFlatViewWindow(ctx: *nk.nk_context, ws: layout.Workspace, camera: *FreeCamera, compiling_3d: bool) void {
    const flat = &camera.flat;
    if (!flat.window_open) return;
    const title = "2D view";
    if (layout.begin(ctx, ws, title, .{ .floating = .{ 320, 640 } })) {
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        camera.mode_2d = nk.nk_check_label(ctx, "Show the 2D view", if (camera.mode_2d) 1 else 0) != 0;
        if (compiling_3d and !camera.mode_2d) widgets.hint(ctx, "Compiling the 3D shader -- the last image stays up until it is ready.", widgets.warn);

        if (widgets.beginSection(ctx, "Colouring", .open)) {
            defer widgets.endSection(ctx);
            buildColoring(ctx, flat);
        }
        if (widgets.beginSection(ctx, "Shading", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderFloat(ctx, "Relief", &flat.relief, &flat.relief_range);
            if (flat.relief > 0) widgets.sliderFloat(ctx, "Light angle", &flat.light_angle, &flat.light_angle_range);
            widgets.sliderFloat(ctx, "Contour lines", &flat.contours, &flat.contours_range);
            if (flat.contours > 0) widgets.sliderFloat(ctx, "Lines per distance octave", &flat.contour_density, &flat.contour_density_range);
        }
        if (widgets.beginSection(ctx, "Slab (X-ray)", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderInt(ctx, "Slices", &flat.slab_slices, &flat.slab_slices_range);
            if (flat.slab_slices > 1.5) {
                widgets.sliderFloat(ctx, "Depth (x view height)", &flat.slab_depth, &flat.slab_depth_range);
                widgets.sliderFloat(ctx, "Opacity per slice", &flat.slab_opacity, &flat.slab_opacity_range);
                widgets.hint(ctx, "Stacks slices behind the plane. Low opacity sees through like an X-ray, full opacity shows the nearest surface. Relief then shades by depth.", widgets.dim);
            }
        }
        if (widgets.beginSection(ctx, "Quality", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderInt(ctx, "Anti-aliasing samples", &flat.samples, &flat.samples_range);
        }
        widgets.separator(ctx);
        widgets.hint(ctx, "Drag pans, right-drag tilts the slice, wheel zooms at the cursor, Shift+wheel moves the slice forward and back.", widgets.dim);
    }
    layout.end(ctx, title, &flat.window_open);
}

fn buildColoring(ctx: *nk.nk_context, flat: *FlatView) void {
    editor_windows.labeledEnumCombo(ctx, "Mode", flat_view.Coloring, &flat.coloring);
    switch (flat.coloring) {
        .section => {
            widgets.sliderFloat(ctx, "Outside glow", &flat.halo, &flat.halo_range);
            editor_windows.labeledEnumCombo(ctx, "Inside", flat_view.Interior, &flat.interior);
        },
        .escape => {
            widgets.sliderFloat(ctx, "Escape radius", &flat.bailout, &flat.bailout_range);
            widgets.sliderInt(ctx, "Extra iterations", &flat.extra_iterations, &flat.extra_iterations_range);
            widgets.sliderFloat(ctx, "Bands per iteration", &flat.band_density, &flat.band_density_range);
            widgets.sliderFloat(ctx, "Band offset", &flat.band_offset, &flat.band_offset_range);
            editor_windows.labeledEnumCombo(ctx, "Inside", flat_view.Interior, &flat.interior);
            widgets.hint(ctx, "Colours each point by how fast its orbit leaves the escape radius. Formulas whose orbits never escape (primitives, most IFS) show only their inside colouring; use Distance bands for those.", widgets.dim);
        },
        .distance => {
            widgets.sliderFloat(ctx, "Bands per octave", &flat.band_density, &flat.band_density_range);
            widgets.sliderFloat(ctx, "Band offset", &flat.band_offset, &flat.band_offset_range);
            editor_windows.labeledEnumCombo(ctx, "Inside", flat_view.Interior, &flat.interior);
            widgets.hint(ctx, "Colours the outside by distance to the surface, measured in doublings of the pixel size, so the bands look the same at every zoom.", widgets.dim);
        },
        .orbit => widgets.hint(ctx, "Colours every point, inside and out, with its fractal's orbit trap. Change the trap in the fractal's editor.", widgets.dim),
    }
}

fn toScreen(bounds: nk.struct_nk_rect, unit: [2]f32) [2]f32 {
    return .{ bounds.x + (unit[0] * 0.5 + 0.5) * bounds.w, bounds.y + (unit[1] * 0.5 + 0.5) * bounds.h };
}

pub fn buildNavigatorWindow(ctx: *nk.nk_context, ws: layout.Workspace, nav: *NavigatorState, target: *const NavigatorRenderer, camera: *FreeCamera, view_aspect: f32) void {
    if (!nav.open) return;
    const title = "Navigator";
    if (layout.begin(ctx, ws, title, .{ .floating = .{ 300, 400 } })) {
        widgets.sliderFloat(ctx, "Map half-size", &nav.range, &nav.range_range);
        const side = @max(nk.nk_window_get_content_region(ctx).w - 4, 32);
        nk.nk_layout_row_dynamic(ctx, side, 1);
        var bounds: nk.struct_nk_rect = undefined;
        const state = nk.nk_widget(&bounds, ctx);
        if (state != nk.NK_WIDGET_INVALID) {
            const cam = camera.basis();
            const map = navigator_mod.Map.of(cam, nav.range);
            const canvas = nk.nk_window_get_canvas(ctx);
            const clip = canvas.*.clip;
            nk.nk_push_scissor(canvas, bounds);
            if (target.ready()) {
                const img = nk.nk_image_handle(ui_backend.imageHandle(target.image_id, target.display_view));
                nk.nk_draw_image(canvas, bounds, &img, nk.nk_rgb(255, 255, 255));
            } else {
                nk.nk_fill_rect(canvas, bounds, 0, nk.nk_rgb(20, 20, 24));
            }
            const eye = toScreen(bounds, map.toUnit(cam.pos));
            for ([_]f32{ -1, 1 }) |side_sign| {
                const ray = cam.pos.add(cam.forward.add(cam.right.scale(side_sign * view_aspect)).scale(map.range * nav_ray_units));
                const end = toScreen(bounds, map.toUnit(ray));
                nk.nk_stroke_line(canvas, eye[0], eye[1], end[0], end[1], 1.5, nav_line);
            }
            nk.nk_fill_circle(canvas, nk.nk_rect(eye[0] - nav_dot_px, eye[1] - nav_dot_px, 2 * nav_dot_px, 2 * nav_dot_px), nav_line);
            nk.nk_push_scissor(canvas, clip);

            const hovered = nk.nk_input_is_mouse_hovering_rect(&ctx.input, bounds) != 0;
            if (hovered) {
                const scroll = ctx.input.mouse.scroll_delta.y;
                if (scroll != 0) {
                    nav.range = std.math.clamp(nav.range * @exp(-scroll * navigator_mod.wheel_zoom), navigator_mod.min_range, navigator_mod.max_range);
                    ctx.input.mouse.scroll_delta.y = 0;
                }
            }
            if (nk.nk_window_has_focus(ctx) != 0 and nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_LEFT, bounds) != 0) {
                const m = ctx.input.mouse.pos;
                const ux = (m.x - bounds.x) / @max(bounds.w, 1) * 2 - 1;
                const uy = (m.y - bounds.y) / @max(bounds.h, 1) * 2 - 1;
                camera.position = map.fromUnit(ux, uy);
            }
        }
        widgets.hint(ctx, "The slice through the middle row of the 3D view, seen from above; the camera looks up the map. Click to move the camera there, wheel zooms the map.", widgets.dim);
    }
    layout.end(ctx, title, &nav.open);
}
