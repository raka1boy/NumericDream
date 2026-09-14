const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const nk = @import("../bindings/nuklear.zig").c;
const file_dialog = @import("../bindings/file_dialog.zig");

const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const max_instances = fractal_gpu.max_instances;
const max_mixins = fractal_gpu.max_mixins;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;

const widgets = @import("widgets.zig");
const FormulaState = @import("../app/formula.zig").FormulaState;
const formula_library = @import("../app/formula_library.zig");
const camera_mod = @import("../app/camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const SliderRange = @import("../app/slider_range.zig").SliderRange;
const scene_state = @import("../app/scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const MixinState = scene_state.MixinState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const warp_mod = @import("../app/warp.zig");
const WarpState = warp_mod.WarpState;
const sky_mod = @import("../app/sky.zig");
const SkyState = sky_mod.SkyState;
const selection = @import("../app/selection.zig");
const export_image = @import("../app/export_image.zig");
const scene_file = @import("../app/scene_file.zig");
const StereoState = @import("../app/stereo.zig").StereoState;
const render_parts_mod = @import("../app/render_parts.zig");
const RenderParts = render_parts_mod.RenderParts;
const McRenderState = @import("../app/mc_render.zig").McRenderState;
const ProgressOverlay = @import("../gpu/progress_overlay.zig").ProgressOverlay;
const accel_gpu = @import("../gpu/accel.zig");
const AccelState = @import("../app/accel_state.zig").AccelState;
const photons_gpu = @import("../gpu/photons.zig");
const PhotonSettings = @import("../app/photon_state.zig").PhotonSettings;
const render_precision = @import("../app/render_precision.zig");
const MarchPrecision = render_precision.MarchPrecision;
const RenderSettingsState = render_precision.RenderSettingsState;
const animation = @import("../app/animation.zig");
const export_anim = @import("../app/export_anim.zig");

fn buildFormulaSection(
    ctx: *nk.nk_context,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    formula: *FormulaState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    library_panel: *formula_library.PanelState,
) void {
    widgets.sectionLabel(ctx, ".wgsl formula");
    nk.nk_layout_row_template_begin(ctx, 24);
    nk.nk_layout_row_template_push_dynamic(ctx);
    nk.nk_layout_row_template_push_static(ctx, 76);
    nk.nk_layout_row_template_end(ctx);
    _ = nk.nk_edit_string_zero_terminated(ctx, @intCast(nk.NK_EDIT_FIELD), &formula.formula_path, formula.formula_path.len, nk.nk_filter_default);
    if (nk.nk_button_label(ctx, "Browse") != 0) {
        var buf: [256]u8 = undefined;
        if (file_dialog.pickWgslFile(window, &buf)) |len| {
            const n = @min(len, formula.formula_path.len - 1);
            @memcpy(formula.formula_path[0..n], buf[0..n]);
            formula.formula_path[n] = 0;
        }
    }
    nk.nk_layout_row_dynamic(ctx, 22, 2);
    if (nk.nk_button_label(ctx, "Library") != 0) {
        library_panel.openFor(formula);
    }
    if (!fractal.isCompiling()) {
        if (nk.nk_button_label(ctx, "Compile") != 0) {
            scene_state.compileFormulaInto(allocator, gpu_ctx, fractal, formula, instances, instance_count);
        }
    } else {
        nk.nk_label(ctx, "Compiling", @intCast(nk.NK_TEXT_CENTERED));
    }
    if (formula.compile_pending) {
        nk.nk_layout_row_dynamic(ctx, 16, 1);
        nk.nk_label_colored(ctx, "Compiling shader in the background", @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(220, 200, 120));
    } else if (formula.formula_body != null) {
        nk.nk_layout_row_dynamic(ctx, 16, 1);
        nk.nk_label_colored(ctx, "Using custom formula", @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(140, 220, 140));
    }
    if (formula.formula_error_len > 0) {
        nk.nk_layout_row_dynamic(ctx, 44, 1);
        nk.nk_label_colored_wrap(ctx, formula.formula_error[0..formula.formula_error_len :0].ptr, nk.nk_rgb(230, 90, 90));
    }

    widgets.separator(ctx);

    widgets.sectionLabel(ctx, "Parameters");
    for (0..formula.custom_param_count) |i| {
        const param = &formula.custom_params[i];
        if (param.name_len == 0) continue;
        if (param.integral) {
            widgets.sliderInt(ctx, param.label(), &param.value, &param.range);
        } else {
            widgets.sliderFloat(ctx, param.label(), &param.value, &param.range);
        }
    }
}

pub fn buildFractalEditorWindow(
    ctx: *nk.nk_context,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    inst: *FractalInstanceState,
    index: usize,
    instances: []const FractalInstanceState,
    instance_count: usize,
    library_panel: *formula_library.PanelState,
) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Fractal {d} Editor", .{index + 1}, 0) catch "Fractal Editor";

    const x: f32 = 40 + @as(f32, @floatFromInt(index % 3)) * 40;
    const y: f32 = 60 + @as(f32, @floatFromInt(index % 3)) * 40;
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(x, y, 340, 980),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.sectionLabel(ctx, "Offset");
        widgets.sliderVec3(ctx, "Offset", &inst.offset, &inst.offset_range_x, &inst.offset_range_y, &inst.offset_range_z);

        widgets.sectionLabel(ctx, "Scale");
        widgets.sliderFloat(ctx, "Scale", &inst.scale_uniform, &inst.scale_uniform_range);
        widgets.sliderVec3(ctx, "Scale", &inst.scale, &inst.scale_range_x, &inst.scale_range_y, &inst.scale_range_z);

        widgets.sectionLabel(ctx, "Rotation (degrees)");
        widgets.sliderVec3(ctx, "Rotation", &inst.rotation, &inst.rotation_range_x, &inst.rotation_range_y, &inst.rotation_range_z);

        widgets.sliderFloat(ctx, "Step-size safety factor", &inst.step_safety, &inst.step_safety_range);

        if (index > 0) {
            widgets.sectionLabel(ctx, "Combine mode");
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            if (nk.nk_combo_begin_label(ctx, inst.combine_mode.label().ptr, nk.nk_vec2(nk.nk_widget_width(ctx), 200)) != 0) {
                nk.nk_layout_row_dynamic(ctx, 20, 1);
                for (scene_state.CombineMode.all) |value| {
                    if (nk.nk_combo_item_label(ctx, value.label().ptr, @intCast(nk.NK_TEXT_LEFT)) != 0) {
                        inst.combine_mode = value;
                    }
                }
                nk.nk_combo_end(ctx);
            }
            if (inst.combine_mode != .hard_union) {
                widgets.sliderFloat(ctx, "Blend smoothness", &inst.blend_k, &inst.blend_k_range);
            }
        }

        widgets.separator(ctx);
        buildFormulaSection(ctx, window, gpu_ctx, fractal, allocator, &inst.formula, instances, instance_count, library_panel);

        widgets.separator(ctx);
        widgets.sectionLabel(ctx, "Mixins");

        var remove_mixin_index: ?usize = null;
        for (0..inst.mixin_count) |j| {
            var mixin_buf: [32]u8 = undefined;
            const mixin_label: [:0]const u8 = std.fmt.bufPrintSentinel(&mixin_buf, "Mixin {d}", .{j + 1}, 0) catch "Mixin";
            if (widgets.selectableRemovableRow(ctx, mixin_label, &inst.mixins[j].window_open, 22)) {
                remove_mixin_index = j;
            }
        }

        if (remove_mixin_index) |idx| {
            if (!fractal.isCompiling()) {
                inst.mixins[idx].formula.deinit(allocator);
                var j = idx;
                while (j + 1 < inst.mixin_count) : (j += 1) inst.mixins[j] = inst.mixins[j + 1];
                inst.mixin_count -= 1;
                scene_state.rebuildAllChecked(gpu_ctx, fractal, allocator, instances, instance_count) catch |err| {
                    std.log.err("Failed to rebuild shader: {s}: {s}", .{ @errorName(err), webgpu_context.g_error_sink.message() });
                };
            }
        }

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (inst.mixin_count < max_mixins) {
            if (nk.nk_button_label(ctx, "Add mixin") != 0 and !fractal.isCompiling()) {
                inst.mixins[inst.mixin_count] = scene_state.newMixin();
                inst.mixin_count += 1;
                scene_state.rebuildAllChecked(gpu_ctx, fractal, allocator, instances, instance_count) catch |err| {
                    std.log.err("Failed to rebuild shader: {s}: {s}", .{ @errorName(err), webgpu_context.g_error_sink.message() });
                };
            }
        } else {
            nk.nk_label(ctx, "Max mixins reached", @intCast(nk.NK_TEXT_CENTERED));
        }

        if (inst.mixin_count > 0) {
            widgets.sliderInt(ctx, "Base iterations / cycle", &inst.hybrid_base_iters, &inst.hybrid_base_iters_range);
            for (0..inst.mixin_count) |j| {
                var iter_buf: [32]u8 = undefined;
                const iter_label: [:0]const u8 = std.fmt.bufPrintSentinel(&iter_buf, "Mixin {d} iterations / cycle", .{j + 1}, 0) catch "Mixin iterations / cycle";
                widgets.sliderInt(ctx, iter_label, &inst.mixins[j].iterations, &inst.mixins[j].iterations_range);
            }
            widgets.sliderInt(ctx, "Total mixed iterations", &inst.hybrid_total_iters, &inst.hybrid_total_iters_range);

            nk.nk_layout_row_dynamic(ctx, 28, 1);
            nk.nk_label_colored_wrap(ctx, "Each formula's own Iterations param is ignored while it's part of a mix", nk.nk_rgb(180, 180, 190));
        }

        widgets.separator(ctx);
        widgets.sectionLabel(ctx, "Color strip");
        widgets.colorStripWidget(ctx, inst);

        if (inst.selected_color) |sel| {
            if (sel < inst.color_count) {
                const stop = &inst.colors[sel];
                nk.nk_layout_row_dynamic(ctx, 20, 1);
                widgets.colorPickerCombo(ctx, &stop.color);
                widgets.sliderFloat(ctx, "Glossiness", &stop.glossiness, &stop.glossiness_range);
                widgets.sliderFloat(ctx, "Transparency", &stop.transparency, &stop.transparency_range);
                widgets.sliderFloat(ctx, "Reflectiveness", &stop.reflectiveness, &stop.reflectiveness_range);
                widgets.sliderFloat(ctx, "Subsurface scattering", &stop.subsurface, &stop.subsurface_range);

                widgets.separator(ctx);
                widgets.sectionLabel(ctx, "Refraction");
                widgets.sliderFloat(ctx, "IOR", &stop.ior, &stop.ior_range);
                widgets.sliderFloat(ctx, "Abbe number", &stop.abbe, &stop.abbe_range);
                widgets.sliderFloat(ctx, "Roughness", &stop.roughness, &stop.roughness_range);
                widgets.sliderInt(ctx, "Inner max steps", &stop.inner_max_steps, &stop.inner_max_steps_range);

                widgets.separator(ctx);
                widgets.sectionLabel(ctx, "Iridescence");
                widgets.sliderFloat(ctx, "Strength", &stop.film_strength, &stop.film_strength_range);
                widgets.sliderFloat(ctx, "Film thickness (nm)", &stop.film_thickness, &stop.film_thickness_range);
                widgets.sliderFloat(ctx, "Film IOR", &stop.film_ior, &stop.film_ior_range);
                widgets.sliderFloat(ctx, "Angle scale", &stop.film_angle_scale, &stop.film_angle_scale_range);
                widgets.sliderFloat(ctx, "Normal perturbation", &stop.film_perturb, &stop.film_perturb_range);
                widgets.sliderFloat(ctx, "Perturbation scale", &stop.film_perturb_scale, &stop.film_perturb_scale_range);
            } else {
                inst.selected_color = null;
            }
        }
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        inst.window_open = false;
    }
}

pub fn buildMixinEditorWindow(
    ctx: *nk.nk_context,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    mixin: *MixinState,
    instance_index: usize,
    mixin_index: usize,
    instances: []const FractalInstanceState,
    instance_count: usize,
    library_panel: *formula_library.PanelState,
) void {
    var title_buf: [48]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Fractal {d} Mixin {d} Editor", .{ instance_index + 1, mixin_index + 1 }, 0) catch "Mixin Editor";

    const slot = instance_index * max_mixins + mixin_index;
    const x: f32 = 500 + @as(f32, @floatFromInt(slot % 3)) * 40;
    const y: f32 = 80 + @as(f32, @floatFromInt(slot % 4)) * 40;
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(x, y, 320, 400),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        buildFormulaSection(ctx, window, gpu_ctx, fractal, allocator, &mixin.formula, instances, instance_count, library_panel);
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        mixin.window_open = false;
    }
}

pub fn buildLightEditorWindow(ctx: *nk.nk_context, light: *LightState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Light {d} Editor", .{index + 1}, 0) catch "Light Editor";

    const x: f32 = 420 + @as(f32, @floatFromInt(index % 3)) * 40;
    const y: f32 = 60 + @as(f32, @floatFromInt(index % 3)) * 40;
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(x, y, 300, 460),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.sectionLabel(ctx, "Type");
        nk.nk_layout_row_dynamic(ctx, 22, 3);
        if (nk.nk_option_label(ctx, "Point", if (light.kind == .point) 1 else 0) != 0) {
            light.kind = .point;
        }
        if (nk.nk_option_label(ctx, "Global", if (light.kind == .global) 1 else 0) != 0) {
            light.kind = .global;
        }
        if (nk.nk_option_label(ctx, "Ray", if (light.kind == .ray) 1 else 0) != 0) {
            light.kind = .ray;
        }

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Color");
        nk.nk_layout_row_dynamic(ctx, 20, 1);
        widgets.colorPickerCombo(ctx, &light.color);

        widgets.sliderFloat(ctx, "Brightness", &light.brightness, &light.brightness_range);

        widgets.separator(ctx);

        switch (light.kind) {
            .point => {
                widgets.sectionLabel(ctx, "Position");
                widgets.sliderVec3(ctx, "Position", &light.position, &light.position_range_x, &light.position_range_y, &light.position_range_z);
            },
            .global => {
                widgets.sectionLabel(ctx, "Direction");
                widgets.sliderVec3(ctx, "Direction", &light.direction, &light.direction_range_x, &light.direction_range_y, &light.direction_range_z);
            },
            .ray => {
                widgets.sectionLabel(ctx, "Position");
                widgets.sliderVec3(ctx, "Position", &light.position, &light.position_range_x, &light.position_range_y, &light.position_range_z);

                widgets.sectionLabel(ctx, "Direction");
                widgets.sliderVec3(ctx, "Direction", &light.direction, &light.direction_range_x, &light.direction_range_y, &light.direction_range_z);

                widgets.sliderFloat(ctx, "Spread (deg)", &light.spread, &light.spread_range);
                var hint_buf: [64]u8 = undefined;
                const hint: [:0]const u8 = std.fmt.bufPrintSentinel(
                    &hint_buf,
                    "{s} - radius {d:.2} at 5 units",
                    .{
                        if (light.spread < 1.0) "Laser" else "Flashlight",
                        scene_state.beamRadiusAt(light.spread, 5.0),
                    },
                    0,
                ) catch "";
                nk.nk_layout_row_dynamic(ctx, 16, 1);
                nk.nk_label(ctx, hint, @intCast(nk.NK_TEXT_LEFT));
            },
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const shadows_now: nk.nk_bool = if (light.cast_shadows) 1 else 0;
        light.cast_shadows = nk.nk_check_label(ctx, "Cast shadows", shadows_now) != 0;
        if (light.cast_shadows) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            const hard_now: nk.nk_bool = if (light.hard_shadows) 1 else 0;
            light.hard_shadows = nk.nk_check_label(ctx, "Hard shadows", hard_now) != 0;
            if (!light.hard_shadows) {
                widgets.sliderFloat(ctx, "Shadow softness", &light.shadow_softness, &light.shadow_softness_range);
            }
        }
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        light.window_open = false;
    }
}

pub fn buildFogEmitterEditorWindow(ctx: *nk.nk_context, fog: *FogEmitterState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Fog {d} Editor", .{index + 1}, 0) catch "Fog Editor";

    const x: f32 = 460 + @as(f32, @floatFromInt(index % 3)) * 40;
    const y: f32 = 100 + @as(f32, @floatFromInt(index % 3)) * 40;
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(x, y, 300, 460),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.sectionLabel(ctx, "Position");
        widgets.sliderVec3(ctx, "Position", &fog.position, &fog.position_range_x, &fog.position_range_y, &fog.position_range_z);

        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Radius", &fog.radius, &fog.radius_range);
        widgets.sliderFloat(ctx, "Density", &fog.density, &fog.density_range);
        widgets.sliderFloat(ctx, "Edge softness", &fog.softness, &fog.softness_range);
        widgets.sliderFloat(ctx, "Anisotropy", &fog.anisotropy, &fog.anisotropy_range);

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Color");
        nk.nk_layout_row_dynamic(ctx, 20, 1);
        widgets.colorPickerCombo(ctx, &fog.color);

        widgets.separator(ctx);

        //nk.nk_layout_row_dynamic(ctx, 56, 1);
        //nk.nk_label_wrap(ctx, "dklddklasdjkasjdkasd");
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        fog.window_open = false;
    }
}

pub fn buildSkyEditorWindow(
    ctx: *nk.nk_context,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    sky: *SkyState,
) void {
    const title: [:0]const u8 = "Sky";
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(540, 80, 320, 620),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.sectionLabel(ctx, "Source");
        //nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_option_label(ctx, "Procedural", if (sky.mode == .procedural) 1 else 0) != 0) {
            sky.mode = .procedural;
        }
        if (nk.nk_option_label(ctx, "Image", if (sky.mode == .image) 1 else 0) != 0) {
            sky.mode = .image;
        }

        widgets.separator(ctx);

        switch (sky.mode) {
            .procedural => {
                widgets.sectionLabel(ctx, "Preset");
                nk.nk_layout_row_dynamic(ctx, 22, 1);
                if (nk.nk_combo_begin_label(ctx, "Choose a preset", nk.nk_vec2(nk.nk_widget_width(ctx), 200)) != 0) {
                    nk.nk_layout_row_dynamic(ctx, 22, 1);
                    for (sky_mod.presets) |preset| {
                        if (nk.nk_combo_item_label(ctx, preset.name.ptr, @intCast(nk.NK_TEXT_LEFT)) != 0) {
                            sky_mod.applyPreset(sky, preset);
                        }
                    }
                    nk.nk_combo_end(ctx);
                }

                widgets.separator(ctx);

                widgets.sectionLabel(ctx, "Zenith");
                nk.nk_layout_row_dynamic(ctx, 20, 1);
                widgets.colorPickerCombo(ctx, &sky.zenith);
                widgets.sectionLabel(ctx, "Horizon");
                nk.nk_layout_row_dynamic(ctx, 20, 1);
                widgets.colorPickerCombo(ctx, &sky.horizon);
                widgets.sectionLabel(ctx, "Ground");
                nk.nk_layout_row_dynamic(ctx, 20, 1);
                widgets.colorPickerCombo(ctx, &sky.ground);

                widgets.sliderFloat(ctx, "Horizon falloff", &sky.falloff, &sky.falloff_range);

                widgets.separator(ctx);

                nk.nk_layout_row_dynamic(ctx, 22, 1);
                var sun_on: c_int = if (sky.sun_enabled) 1 else 0;
                _ = nk.nk_checkbox_label(ctx, "Sun disc", &sun_on);
                sky.sun_enabled = sun_on != 0;

                if (sky.sun_enabled) {
                    widgets.sectionLabel(ctx, "Direction");
                    widgets.sliderVec3(ctx, "Sun", &sky.sun_direction, &sky.sun_direction_range_x, &sky.sun_direction_range_y, &sky.sun_direction_range_z);
                    widgets.sliderFloat(ctx, "Sun radius", &sky.sun_size, &sky.sun_size_range);
                    widgets.sliderFloat(ctx, "Sun brightness", &sky.sun_intensity, &sky.sun_intensity_range);
                    widgets.sectionLabel(ctx, "Sun color");
                    nk.nk_layout_row_dynamic(ctx, 20, 1);
                    widgets.colorPickerCombo(ctx, &sky.sun_color);
                }
            },
            .image => {
                widgets.sectionLabel(ctx, "Equirectangular image");
                nk.nk_layout_row_template_begin(ctx, 24);
                nk.nk_layout_row_template_push_dynamic(ctx);
                nk.nk_layout_row_template_push_static(ctx, 76);
                nk.nk_layout_row_template_end(ctx);
                _ = nk.nk_edit_string_zero_terminated(ctx, @intCast(nk.NK_EDIT_FIELD), &sky.image_path, sky.image_path.len, nk.nk_filter_default);
                if (nk.nk_button_label(ctx, "Browse") != 0) {
                    var buf: [sky_mod.max_path_len]u8 = undefined;
                    if (file_dialog.pickSkyImageFile(window, &buf)) |len| {
                        sky.setPath(buf[0..len]);
                        loadSkyImage(gpu_ctx, fractal, allocator, sky);
                    }
                }

                nk.nk_layout_row_dynamic(ctx, 22, 2);
                if (nk.nk_button_label(ctx, "Load") != 0) {
                    loadSkyImage(gpu_ctx, fractal, allocator, sky);
                }
                if (nk.nk_button_label(ctx, "Clear") != 0) {
                    fractal.sky.clear(gpu_ctx);
                    sky.setPath("");
                    sky.setStatus("No image loaded.", .{});
                }

                const status = sky.statusSlice();
                if (status.len > 0) {
                    nk.nk_layout_row_dynamic(ctx, 32, 1);
                    nk.nk_label_colored_wrap(
                        ctx,
                        status.ptr,
                        if (fractal.sky.loaded) nk.nk_rgb(140, 220, 140) else nk.nk_rgb(230, 90, 90),
                    );
                }

                if (!fractal.sky.loaded) {
                    nk.nk_layout_row_dynamic(ctx, 44, 1);
                    nk.nk_label_colored_wrap(ctx, "Nothing loaded, rendering the procedural gradient instead", nk.nk_rgb(200, 180, 90));
                }

                nk.nk_layout_row_dynamic(ctx, 72, 1);
                nk.nk_label_wrap(ctx, "Use a .hdr file if you can. An 8-bit PNG or JPEG cannot store anything brighter than white, so it makes a fine backdrop but lights the scene flatly");
            },
        }

        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Sky brightness", &sky.intensity, &sky.intensity_range);
        widgets.sliderFloat(ctx, "Rotation", &sky.yaw, &sky.yaw_range);

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        var photons_on: c_int = if (sky.photons) 1 else 0;
        _ = nk.nk_checkbox_label(ctx, "Sky photons", &photons_on);
        sky.photons = photons_on != 0;
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        sky.window_open = false;
    }
}

fn loadSkyImage(gpu_ctx: *Context, fractal: *FractalRenderer, allocator: std.mem.Allocator, sky: *SkyState) void {
    const path = sky.pathSlice();
    if (path.len == 0) {
        sky.setStatus("No file chosen.", .{});
        return;
    }
    if (fractal.sky.loadFromFile(gpu_ctx, allocator, path)) |info| {
        if (info.width != info.source_width) {
            sky.setStatus("Loaded {d}x{d}, scaled down to {d}x{d}.{s}", .{
                info.source_width,
                info.source_height,
                info.width,
                info.height,
                if (info.is_hdr) "" else " 8-bit: no values above white.",
            });
        } else {
            sky.setStatus("Loaded {d}x{d}.{s}", .{
                info.width,
                info.height,
                if (info.is_hdr) " HDR." else " 8-bit: no values above white.",
            });
        }
    } else |err| {
        sky.setStatus("Could not load image ({s}).", .{@errorName(err)});
    }
}

pub fn buildWarpEditorWindow(ctx: *nk.nk_context, w: *WarpState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Warp {d} Editor", .{index + 1}, 0) catch "Warp Editor";

    const x: f32 = 500 + @as(f32, @floatFromInt(index % 3)) * 40;
    const y: f32 = 120 + @as(f32, @floatFromInt(index % 3)) * 40;
    const shown = nk.nk_begin(
        ctx,
        title.ptr,
        nk.nk_rect(x, y, 320, 560),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.sectionLabel(ctx, "Deformation");
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_combo_begin_label(ctx, w.coord_kind.label().ptr, nk.nk_vec2(nk.nk_widget_width(ctx), 200)) != 0) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            for (warp_mod.CoordKind.all) |value| {
                if (nk.nk_combo_item_label(ctx, value.label().ptr, @intCast(nk.NK_TEXT_LEFT)) != 0) {
                    w.coord_kind = value;
                }
            }
            nk.nk_combo_end(ctx);
        }

        widgets.separator(ctx);

        switch (w.coord_kind) {
            .twist => widgets.sliderFloat(ctx, "Twist rate", &w.twist_rate, &w.twist_rate_range),
            .bend => widgets.sliderFloat(ctx, "Bend rate", &w.bend_rate, &w.bend_rate_range),
            .rotate => widgets.sliderFloat(ctx, "Angle", &w.rotate_angle, &w.rotate_angle_range),
            .scale => {
                widgets.sliderVec3(ctx, "Scale", &w.scale, &w.scale_range_x, &w.scale_range_y, &w.scale_range_z);
            },
            .sphere_inversion => {
                widgets.sliderFloat(ctx, "Inversion radius", &w.inversion_radius, &w.inversion_radius_range);
                widgets.sliderFloat(ctx, "Centre clamp", &w.inversion_min, &w.inversion_min_range);
            },
            .repeat => {
                widgets.sliderVec3(ctx, "Cell", &w.repeat_cell, &w.repeat_cell_range_x, &w.repeat_cell_range_y, &w.repeat_cell_range_z);
            },
            .displace => {
                widgets.sliderFloat(ctx, "Amplitude", &w.displace_amp, &w.displace_amp_range);
                widgets.sliderVec3(ctx, "Frequency", &w.displace_freq, &w.displace_freq_range_x, &w.displace_freq_range_y, &w.displace_freq_range_z);
            },
        }
        widgets.sliderFloat(ctx, "Strength", &w.strength, &w.strength_range);

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Region of influence");
        nk.nk_layout_row_dynamic(ctx, 22, 3);
        if (nk.nk_option_label(ctx, "Sphere", if (w.region_kind == .sphere) 1 else 0) != 0) {
            w.region_kind = .sphere;
        }
        if (nk.nk_option_label(ctx, "Box", if (w.region_kind == .box) 1 else 0) != 0) {
            w.region_kind = .box;
        }
        if (nk.nk_option_label(ctx, "Global", if (w.region_kind == .global) 1 else 0) != 0) {
            w.region_kind = .global;
        }

        switch (w.region_kind) {
            .sphere => widgets.sliderFloat(ctx, "Radius", &w.radius, &w.radius_range),
            .box => {
                widgets.sliderVec3(ctx, "Half-extent", &w.extent, &w.extent_range_x, &w.extent_range_y, &w.extent_range_z);
            },
            .global => widgets.sliderFloat(ctx, "Safety radius", &w.radius, &w.radius_range),
        }

        if (w.region_kind != .global) {
            widgets.sliderFloat(ctx, "Edge falloff", &w.falloff, &w.falloff_range);
        }

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Centre");
        widgets.sliderVec3(ctx, "Centre", &w.center, &w.center_range_x, &w.center_range_y, &w.center_range_z);

        widgets.sectionLabel(ctx, "Orientation");
        widgets.sliderVec3(ctx, "Rotation", &w.rotation, &w.rotation_range_x, &w.rotation_range_y, &w.rotation_range_z);

        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Step safety", &w.step_safety, &w.step_safety_range);
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, title.ptr) != 0) {
        w.window_open = false;
    }
}

pub fn buildStereoSettingsWindow(ctx: *nk.nk_context, stereo: *StereoState) void {
    if (!stereo.settings_open) return;

    const shown = nk.nk_begin(
        ctx,
        "Stereoscopic Settings",
        nk.nk_rect(420, 220, 320, 260),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Eye separation", &stereo.eye_separation, &stereo.eye_separation_range);
        widgets.sliderFloat(ctx, "Convergence distance", &stereo.convergence_distance, &stereo.convergence_distance_range);

        widgets.separator(ctx);
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, "Stereoscopic Settings") != 0) {
        stereo.settings_open = false;
    }
}

pub fn buildRenderPartsWindow(ctx: *nk.nk_context, parts: *RenderParts) void {
    if (!parts.window_open) return;

    const shown = nk.nk_begin(
        ctx,
        "Simple render",
        nk.nk_rect(420, 40, 300, 640),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const geo_now: nk.nk_bool = if (parts.geometry_only) 1 else 0;
        parts.geometry_only = nk.nk_check_label(ctx, "Geometry only (fast)", geo_now) != 0;
        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "All on") != 0) parts.setAll(true);
        if (nk.nk_button_label(ctx, "All off") != 0) parts.setAll(false);

        for (std.enums.values(render_parts_mod.Group)) |group| {
            widgets.separator(ctx);
            nk.nk_layout_row_dynamic(ctx, 18, 1);
            nk.nk_label(ctx, group.label().ptr, @intCast(nk.NK_TEXT_LEFT));
            for (std.enums.values(render_parts_mod.Part)) |part| {
                const pi = render_parts_mod.info(part);
                if (pi.group != group) continue;
                nk.nk_layout_row_dynamic(ctx, 22, 1);
                const now: nk.nk_bool = if (parts.isOn(part)) 1 else 0;
                parts.set(part, nk.nk_check_label(ctx, pi.label.ptr, now) != 0);
                if (!parts.isOn(part)) {
                    const lines: f32 = @floatFromInt((pi.off_hint.len + 39) / 40);
                    nk.nk_layout_row_dynamic(ctx, 4 + 14 * lines, 1);
                    nk.nk_label_colored_wrap(ctx, pi.off_hint.ptr, nk.nk_rgb(200, 180, 90));
                }
            }

            widgets.separator(ctx);
        }
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, "Simple render") != 0) {
        parts.window_open = false;
    }
}

pub fn buildRenderSettingsWindow(ctx: *nk.nk_context, render_settings: *RenderSettingsState) void {
    if (!render_settings.window_open) return;

    const shown = nk.nk_begin(
        ctx,
        "Render Settings",
        nk.nk_rect(420, 220, 340, 420),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        nk.nk_layout_row_dynamic(ctx, 48, 1);
        nk.nk_label_wrap(ctx, "Applies only to HQ render");

        widgets.separator(ctx);

        widgets.sliderInt(ctx, "Max march steps", &render_settings.max_steps, &render_settings.max_steps_range);
        widgets.sliderFloat(ctx, "Max distance", &render_settings.max_dist, &render_settings.max_dist_range);
        widgets.sliderInt(ctx, "Reflection bounces", &render_settings.max_reflection_bounces, &render_settings.max_reflection_bounces_range);
        widgets.sliderInt(ctx, "Fog samples", &render_settings.fog_samples, &render_settings.fog_samples_range);

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Ray March Precision", @intCast(nk.NK_TEXT_LEFT));
        buildPrecisionSliders(ctx, &render_settings.precision);
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, "Render Settings") != 0) {
        render_settings.window_open = false;
    }
}

pub fn buildAnimRenderWindow(
    ctx: *nk.nk_context,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    timeline: *animation.TimelineState,
    anim_render: *animation.AnimRenderState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    lights: []const LightState,
    light_count: usize,
    fog_emitters: []const FogEmitterState,
    fog_count: usize,
    warps: []const WarpState,
    warp_count: usize,
    camera: FreeCamera,
    render_settings: RenderSettingsState,
    photon: PhotonSettings,
    stereo: StereoState,
    mc: McRenderState,
    progress_overlay: *ProgressOverlay,
) void {
    if (!anim_render.window_open) return;

    const shown = nk.nk_begin(
        ctx,
        "Render Animation",
        nk.nk_rect(420, 220, 340, 520),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        var info_buf: [96]u8 = undefined;
        const info: [:0]const u8 = std.fmt.bufPrintSentinel(&info_buf, "Duration: {d:.1}s  ({d} keyframes)", .{ timeline.duration, timeline.keyframe_count }, 0) catch "Duration";
        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, info.ptr, @intCast(nk.NK_TEXT_LEFT));

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_float(ctx, "FPS", anim_render.fps_range.min, &anim_render.fps, anim_render.fps_range.max, 1, 1);
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Width", 16, &anim_render.width, 16384, 16, 4);
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Height", 16, &anim_render.height, 16384, 16, 4);

        widgets.sliderInt(ctx, "Fog samples/frame", &anim_render.fog_samples, &anim_render.fog_samples_range);

        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Motion blur", &anim_render.motion_blur, &anim_render.motion_blur_range);
        if (anim_render.motion_blur > 0.0005) {
            widgets.sliderInt(ctx, "Motion blur samples", &anim_render.motion_blur_samples, &anim_render.motion_blur_samples_range);
        }
        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        var save_frames_val: c_int = if (anim_render.save_frames) 1 else 0;
        _ = nk.nk_checkbox_label(ctx, "Also save PNG frames", &save_frames_val);
        anim_render.save_frames = save_frames_val != 0;

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_button_label(ctx, "Render...") != 0) {
            anim_render.status = export_anim.renderAnimation(
                allocator,
                window,
                gpu_ctx,
                fractal,
                timeline,
                instances,
                instance_count,
                lights,
                light_count,
                fog_emitters,
                fog_count,
                warps,
                warp_count,
                camera,
                render_settings,
                photon,
                stereo,
                mc,
                anim_render.fps,
                anim_render.width,
                anim_render.height,
                anim_render.fog_samples,
                anim_render.motion_blur,
                anim_render.motion_blur_samples,
                anim_render.save_frames,
                progress_overlay,
                &anim_render.status_buf,
            );
        }
        if (anim_render.status.len > 0) {
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_wrap(ctx, anim_render.status.ptr);
        }
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, "Render Animation") != 0) {
        anim_render.window_open = false;
    }
}

fn buildPrecisionSliders(ctx: *nk.nk_context, precision: *MarchPrecision) void {
    widgets.sliderFloat(ctx, "Hit epsilon coefficient", &precision.epsilon_coefficient, &precision.epsilon_coefficient_range);
    widgets.sliderFloat(ctx, "Hit epsilon floor", &precision.epsilon_floor, &precision.epsilon_floor_range);
    widgets.sliderFloat(ctx, "HQ footprint budget", &precision.hq_footprint_budget_px, &precision.hq_footprint_budget_px_range);
    widgets.sliderInt(ctx, "Bisection refine steps", &precision.refine_fast, &precision.refine_fast_range);
    widgets.sliderInt(ctx, "Bisection refine steps (hq)", &precision.refine_hq, &precision.refine_hq_range);
}

fn buildAccelSection(ctx: *nk.nk_context, state: *AccelState, grid: *const accel_gpu.AccelGrid) void {
    nk.nk_layout_row_dynamic(ctx, 18, 1);
    nk.nk_label(ctx, "Empty-space accelerator", @intCast(nk.NK_TEXT_LEFT));

    nk.nk_layout_row_dynamic(ctx, 22, 1);
    const on_now: nk.nk_bool = if (state.enabled) 1 else 0;
    state.enabled = nk.nk_check_label(ctx, "Enabled", on_now) != 0;

    if (!state.enabled) {
        nk.nk_layout_row_dynamic(ctx, 32, 1);
        nk.nk_label_wrap(ctx, "off");
        return;
    }

    var status_buf: [192]u8 = undefined;
    const status: [:0]const u8 = if (!grid.valid)
        (std.fmt.bufPrintSentinel(&status_buf, "Rebuilding after {d:.0}ms of quiet -- marching exactly for now.", .{state.debounce_ms}, 0) catch "Rebuilding...")
    else
        (std.fmt.bufPrintSentinel(
            &status_buf,
            "Live: {d}^3 x {d} cascades ({d:.1} MB), built in {d}ms.",
            .{ grid.resolution, grid.levels, @as(f64, @floatFromInt(grid.bytes())) / (1024.0 * 1024.0), state.last_build_ms },
            0,
        ) catch "Live");
    nk.nk_layout_row_dynamic(ctx, 32, 1);
    nk.nk_label_wrap(ctx, status.ptr);

    widgets.sliderInt(ctx, "Grid resolution", &state.resolution, &state.resolution_range);
    widgets.sliderInt(ctx, "Cascades", &state.levels, &state.levels_range);
    widgets.sliderFloat(ctx, "Skip safety margin", &state.safety, &state.safety_range);
    widgets.sliderInt(ctx, "Rebuild delay (ms)", &state.debounce_ms, &state.debounce_ms_range);
}

fn buildPhotonSection(ctx: *nk.nk_context, photon: *PhotonSettings, map: *const photons_gpu.PhotonMap) void {
    nk.nk_layout_row_dynamic(ctx, 18, 1);
    nk.nk_label(ctx, "Photon map", @intCast(nk.NK_TEXT_LEFT));

    nk.nk_layout_row_dynamic(ctx, 22, 1);
    const on_now: nk.nk_bool = if (photon.enabled) 1 else 0;
    photon.enabled = nk.nk_check_label(ctx, "Enabled", on_now) != 0;

    if (!photon.enabled) {
        nk.nk_layout_row_dynamic(ctx, 44, 1);
        nk.nk_label_wrap(ctx, "off");
        return;
    }

    var status_buf: [224]u8 = undefined;
    const status: [:0]const u8 = if (!map.valid)
        (std.fmt.bufPrintSentinel(&status_buf, "Tracing after {d:.0}ms of quiet -- direct light only for now.", .{photon.debounce_ms}, 0) catch "Tracing")
    else
        (std.fmt.bufPrintSentinel(
            &status_buf,
            "Live: {d} paths into {d} cells ({d:.1} MB), traced in {d}ms.",
            .{ map.last_paths, map.buckets, @as(f64, @floatFromInt(map.bytes())) / (1024.0 * 1024.0), map.last_trace_ms },
            0,
        ) catch "Live");
    nk.nk_layout_row_dynamic(ctx, 32, 1);
    nk.nk_label_wrap(ctx, status.ptr);

    if (map.valid) {
        const stats = map.last_stats;
        const pool = map.poolPhotons();
        var pool_buf: [192]u8 = undefined;
        const pool_line: [:0]const u8 = std.fmt.bufPrintSentinel(
            &pool_buf,
            "Fog: {d} cells, every photon summed. Surfaces: {d} cells, up to {d} each, pool {d:.0}% full.",
            .{
                stats.cells_volume,
                stats.cells_surface,
                map.stored_cap_surface,
                if (pool == 0) 0.0 else @as(f64, @floatFromInt(stats.pool_used)) * 100.0 / @as(f64, @floatFromInt(pool)),
            },
            0,
        ) catch "Pool";
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        nk.nk_label(ctx, pool_line.ptr, @intCast(nk.NK_TEXT_LEFT));

        if (stats.dropped_no_bucket > 0) {
            var drop_buf: [216]u8 = undefined;
            const drop_line: [:0]const u8 = std.fmt.bufPrintSentinel(
                &drop_buf,
                "{d} deposits found no free bucket and were dropped -- the scene is dimmer than it should be. Raise Grid size.",
                .{stats.dropped_no_bucket},
                0,
            ) catch "Deposits dropped";
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_colored_wrap(ctx, drop_line.ptr, nk.nk_rgb(200, 180, 90));
        }
        if (stats.dropped_no_pool > 0) {
            var drop_buf: [216]u8 = undefined;
            const drop_line: [:0]const u8 = std.fmt.bufPrintSentinel(
                &drop_buf,
                "{d} cells got no room in the pool and are unlit. Raise Grid size, or lower Photon paths.",
                .{stats.dropped_no_pool},
                0,
            ) catch "Cells dropped";
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_colored_wrap(ctx, drop_line.ptr, nk.nk_rgb(200, 180, 90));
        }
    }

    widgets.sliderInt(ctx, "Scatter bounces", &photon.bounces, &photon.bounces_range);
    widgets.sliderInt(ctx, "Photon paths", &photon.paths, &photon.paths_range);
    widgets.sliderFloat(ctx, "Gather radius", &photon.radius, &photon.radius_range);
    widgets.sliderFloat(ctx, "Fog cell scale", &photon.volume_scale, &photon.volume_scale_range);
    widgets.sliderFloat(ctx, "Dispersion softness (deg)", &photon.dispersion_softness, &photon.dispersion_softness_range);
    widgets.sliderFloat(ctx, "Photon brightness", &photon.intensity, &photon.intensity_range);
    widgets.sliderInt(ctx, "Grid size (power of two)", &photon.grid_log2, &photon.grid_log2_range);
    widgets.sliderInt(ctx, "Retrace delay (ms)", &photon.debounce_ms, &photon.debounce_ms_range);

    nk.nk_layout_row_dynamic(ctx, 22, 1);
    const refine_now: nk.nk_bool = if (photon.refine_per_sample) 1 else 0;
    photon.refine_per_sample = nk.nk_check_label(ctx, "Retrace per MC Render sample", refine_now) != 0;

    nk.nk_layout_row_dynamic(ctx, 58, 1);
    nk.nk_label_wrap(ctx, if (photon.refine_per_sample)
        "Every accumulated sample gets its own photons"
    else
        "One trace stands for the whole accumulation");
}

pub fn buildFractalsListUi(
    ctx: *nk.nk_context,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    instances: *[max_instances]FractalInstanceState,
    instance_count: *usize,
    render_parts: *RenderParts,
    max_steps: *f32,
    max_steps_range: *SliderRange,
    max_dist: *f32,
    max_dist_range: *SliderRange,
    preview_quality: *f32,
    preview_quality_range: *SliderRange,
    max_reflection_bounces: *f32,
    max_reflection_bounces_range: *SliderRange,
    photon: *PhotonSettings,
    precision: *MarchPrecision,
    render_settings: *RenderSettingsState,
    lights: *[max_lights]LightState,
    light_count: *usize,
    fog_emitters: *[max_fog_emitters]FogEmitterState,
    fog_count: *usize,
    warps: *[max_warps]WarpState,
    warp_count: *usize,
    sky: *SkyState,
    camera: *FreeCamera,
    width: f32,
    height: f32,
    window: *sdl.SDL_Window,
    export_width: *i32,
    export_height: *i32,
    export_status_buf: *[scene_state.status_buf_len]u8,
    export_status: *[:0]const u8,
    scene_status_buf: *[scene_state.status_buf_len]u8,
    scene_status: *[:0]const u8,
    stereo: *StereoState,
    mc: *McRenderState,
    mc_sample_count: u32,
    progress_overlay: *ProgressOverlay,
    timeline: *animation.TimelineState,
    anim_render: *animation.AnimRenderState,
    accel_state: *AccelState,
    selection_state: *selection.State,
) void {
    _ = height;
    if (nk.nk_begin(
        ctx,
        "Fractals",
        nk.nk_rect(width - 300, 20, 280, 760),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE),
    ) != 0) {
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const parts_now: nk.nk_bool = if (render_parts.enabled) 1 else 0;
        const parts_next = nk.nk_check_label(ctx, "Simple render", parts_now) != 0;
        if (parts_next != render_parts.enabled) {
            render_parts.enabled = parts_next;
            render_parts.window_open = parts_next;
        }
        if (render_parts.enabled) {
            if (!render_parts.window_open) {
                nk.nk_layout_row_dynamic(ctx, 22, 1);
                if (nk.nk_button_label(ctx, "Simple render parts...") != 0) {
                    render_parts.window_open = true;
                }
            }
        }

        widgets.separator(ctx);

        widgets.sliderInt(ctx, "Max march steps", max_steps, max_steps_range);
        widgets.sliderFloat(ctx, "Max distance", max_dist, max_dist_range);
        widgets.sliderFloat(ctx, "Preview quality (render scale)", preview_quality, preview_quality_range);
        widgets.sliderInt(ctx, "Reflection bounces", max_reflection_bounces, max_reflection_bounces_range);

        widgets.separator(ctx);

        buildPhotonSection(ctx, photon, &fractal.photon_map);

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Ray March Precision", @intCast(nk.NK_TEXT_LEFT));
        buildPrecisionSliders(ctx, precision);

        widgets.separator(ctx);

        buildAccelSection(ctx, accel_state, &fractal.accel);

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Camera", @intCast(nk.NK_TEXT_LEFT));

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const mode_2d_now: nk.nk_bool = if (camera.mode_2d) 1 else 0;
        camera.mode_2d = nk.nk_check_label(ctx, "2D mode", mode_2d_now) != 0;
        if (camera.mode_2d) {
            nk.nk_layout_row_dynamic(ctx, 44, 1);
            nk.nk_label_wrap(ctx, "Renders the flat slice the camera cuts through the fractal. F zooms in, R zooms out.");

            var zoom_buf: [64]u8 = undefined;
            const zoom_label: [:0]const u8 = std.fmt.bufPrintSentinel(
                &zoom_buf,
                "Zoom: {d:.0}x  (slice half-height {e})",
                .{ camera_mod.default_zoom_2d / camera.zoom_2d, camera.zoom_2d },
                0,
            ) catch "Zoom";
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label(ctx, zoom_label.ptr, @intCast(nk.NK_TEXT_LEFT));

            nk.nk_layout_row_dynamic(ctx, 22, 1);
            if (nk.nk_button_label(ctx, "Reset 2D zoom") != 0) {
                camera.zoom_2d = camera_mod.default_zoom_2d;
            }
        }

        //literally useless. will remove someday

        // nk.nk_layout_row_dynamic(ctx, 22, 1);
        // const follow_warp_now: nk.nk_bool = if (camera.follow_warp) 1 else 0;
        // camera.follow_warp = nk.nk_check_label(ctx, "Follow spatial warp", follow_warp_now) != 0;
        // if (camera.follow_warp) {
        //     nk.nk_layout_row_dynamic(ctx, 44, 1);
        //     if (warp_count.* == 0) {
        //         nk.nk_label_colored_wrap(ctx, "No warps in the scene yet -- this takes effect once you add one below.", nk.nk_rgb(200, 180, 90));
        //     } else {
        //         nk.nk_label_wrap(ctx, "Moves the camera through the fractal's own warped coordinates instead of straight world space: it rolls where space twists, and its speed changes where space stretches.");
        //     }
        // }

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const dof_now: nk.nk_bool = if (camera.dof_enabled) 1 else 0;
        camera.dof_enabled = nk.nk_check_label(ctx, "Depth of field", dof_now) != 0;
        if (camera.dof_enabled) {
            widgets.sliderFloat(ctx, "Focus distance", &camera.focus_distance, &camera.focus_distance_range);
            widgets.sliderFloat(ctx, "Focus range", &camera.focus_range, &camera.focus_range_range);
            widgets.sliderFloat(ctx, "Aperture)", &camera.aperture, &camera.aperture_range); //тимур попросил оставить так
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const mc_now: nk.nk_bool = if (mc.enabled) 1 else 0;
        mc.enabled = nk.nk_check_label(ctx, "MC Render", mc_now) != 0;
        if (mc.enabled) {
            widgets.sliderInt(ctx, "Live preview samples", &mc.max_samples, &mc.max_samples_range);
            widgets.sliderInt(ctx, "Export samples", &mc.export_samples, &mc.export_samples_range);

            var sample_buf: [32]u8 = undefined;
            const sample_label: [:0]const u8 = std.fmt.bufPrintSentinel(&sample_buf, "Samples: {d} / {d}", .{ mc_sample_count, @as(u32, @intFromFloat(@max(mc.max_samples, 1))) }, 0) catch "Samples";
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label(ctx, sample_label.ptr, @intCast(nk.NK_TEXT_LEFT));
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Export width", export_image.min_export_dim, export_width, export_image.max_export_dim, 16, 4);
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Export height", export_image.min_export_dim, export_height, export_image.max_export_dim, 16, 4);
        nk.nk_layout_row_dynamic(ctx, 22, 4);
        if (nk.nk_button_label(ctx, "25%") != 0) export_image.scaleExportResolution(export_width, export_height, 0.25);
        if (nk.nk_button_label(ctx, "50%") != 0) export_image.scaleExportResolution(export_width, export_height, 0.5);
        if (nk.nk_button_label(ctx, "150%") != 0) export_image.scaleExportResolution(export_width, export_height, 1.5);
        if (nk.nk_button_label(ctx, "200%") != 0) export_image.scaleExportResolution(export_width, export_height, 2.0);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const stereo_now: nk.nk_bool = if (stereo.enabled) 1 else 0;
        const stereo_next = nk.nk_check_label(ctx, "Render as stereoscopic", stereo_now) != 0;
        if (stereo_next != stereo.enabled) {
            stereo.enabled = stereo_next;
            stereo.settings_open = stereo_next;
        }

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Export hq image") != 0) {
            export_status.* = export_image.exportImage(
                allocator,
                window,
                gpu_ctx,
                fractal,
                instances[0..instance_count.*],
                lights[0..light_count.*],
                fog_emitters[0..fog_count.*],
                warps[0..warp_count.*],
                camera.*,
                render_settings.max_steps,
                render_settings.max_dist,
                render_settings.max_reflection_bounces,
                photon.*,
                render_settings.precision,
                render_settings.fog_samples,
                export_width.*,
                export_height.*,
                stereo.*,
                mc.*,
                progress_overlay,
                export_status_buf,
            );
        }
        if (nk.nk_button_label(ctx, "Render settings") != 0) {
            render_settings.window_open = true;
        }
        if (export_status.len > 0) {
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label(ctx, export_status.ptr, @intCast(nk.NK_TEXT_LEFT));
        }

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_button_label(ctx, "Render Anim") != 0) {
            anim_render.window_open = true;
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Save scene") != 0) {
            scene_status.* = scene_file.saveScene(
                allocator,
                window,
                camera.*,
                max_steps.*,
                max_steps_range.*,
                max_dist.*,
                max_dist_range.*,
                preview_quality.*,
                preview_quality_range.*,
                max_reflection_bounces.*,
                max_reflection_bounces_range.*,
                photon.*,
                precision.*,
                render_settings.*,
                export_width.*,
                export_height.*,
                instances[0..instance_count.*],
                lights[0..light_count.*],
                fog_emitters[0..fog_count.*],
                warps[0..warp_count.*],
                sky,
                stereo.*,
                mc.*,
                timeline.*,
                scene_status_buf,
            );
        }
        if (nk.nk_button_label(ctx, "Load scene") != 0) {
            scene_status.* = scene_file.loadScene(
                allocator,
                window,
                gpu_ctx,
                fractal,
                camera,
                max_steps,
                max_steps_range,
                max_dist,
                max_dist_range,
                preview_quality,
                preview_quality_range,
                max_reflection_bounces,
                max_reflection_bounces_range,
                photon,
                precision,
                render_settings,
                export_width,
                export_height,
                instances,
                instance_count,
                lights,
                light_count,
                fog_emitters,
                fog_count,
                warps,
                warp_count,
                sky,
                stereo,
                mc,
                timeline,
                scene_status_buf,
            );
        }
        if (scene_status.len > 0) {
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label(ctx, scene_status.ptr, @intCast(nk.NK_TEXT_LEFT));
        }

        widgets.separator(ctx);

        var remove_index: ?usize = null;
        for (0..instance_count.*) |i| {
            var buf: [32]u8 = undefined;
            const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Fractal {d}", .{i + 1}, 0) catch "Fractal";
            if (widgets.selectableRemovableRow(ctx, label, &instances[i].window_open, 24)) {
                remove_index = i;
            }
        }

        if (remove_index) |idx| {
            if (instance_count.* > 1 and !fractal.isCompiling()) {
                scene_state.freeInstanceOwned(allocator, &instances[idx]);
                var j = idx;
                while (j + 1 < instance_count.*) : (j += 1) instances[j] = instances[j + 1];
                instance_count.* -= 1;
                selection_state.noteRemoved(.fractal, idx);
                scene_state.rebuildAll(gpu_ctx, fractal, allocator, instances[0..instance_count.*], instance_count.*);
            }
        }

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        if (instance_count.* < max_instances) {
            if (nk.nk_button_label(ctx, "Add fractal") != 0) {
                instances[instance_count.*] = scene_state.newInstance();
                instance_count.* += 1;
            }
        } else {
            nk.nk_label(ctx, "Max fractals reached", @intCast(nk.NK_TEXT_CENTERED));
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Lights", @intCast(nk.NK_TEXT_LEFT));

        var remove_light_index: ?usize = null;
        for (0..light_count.*) |i| {
            var light_buf: [32]u8 = undefined;
            const light_label: [:0]const u8 = std.fmt.bufPrintSentinel(&light_buf, "Light {d}", .{i + 1}, 0) catch "Light";
            if (widgets.selectableRemovableRow(ctx, light_label, &lights[i].window_open, 24)) {
                remove_light_index = i;
            }
        }

        if (remove_light_index) |idx| {
            var j = idx;
            while (j + 1 < light_count.*) : (j += 1) lights[j] = lights[j + 1];
            light_count.* -= 1;
            selection_state.noteRemoved(.light, idx);
        }

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        if (light_count.* < max_lights) {
            if (nk.nk_button_label(ctx, "Add light") != 0) {
                lights[light_count.*] = scene_state.newLight();
                light_count.* += 1;
            }
        } else {
            nk.nk_label(ctx, "Max lights reached", @intCast(nk.NK_TEXT_CENTERED));
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Sky", @intCast(nk.NK_TEXT_LEFT));
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        var sky_buf: [48]u8 = undefined;
        const sky_label: [:0]const u8 = std.fmt.bufPrintSentinel(&sky_buf, "Sky: {s}", .{sky.mode.label()}, 0) catch "Sky";
        if (nk.nk_button_label(ctx, sky_label.ptr) != 0) {
            sky.window_open = !sky.window_open;
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Volumetric fog", @intCast(nk.NK_TEXT_LEFT));

        var remove_fog_index: ?usize = null;
        for (0..fog_count.*) |i| {
            var fog_buf: [32]u8 = undefined;
            const fog_label: [:0]const u8 = std.fmt.bufPrintSentinel(&fog_buf, "Fog {d}", .{i + 1}, 0) catch "Fog";
            if (widgets.selectableRemovableRow(ctx, fog_label, &fog_emitters[i].window_open, 24)) {
                remove_fog_index = i;
            }
        }

        if (remove_fog_index) |idx| {
            var j = idx;
            while (j + 1 < fog_count.*) : (j += 1) fog_emitters[j] = fog_emitters[j + 1];
            fog_count.* -= 1;
            selection_state.noteRemoved(.fog, idx);
        }

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        if (fog_count.* < max_fog_emitters) {
            if (nk.nk_button_label(ctx, "Add fog emitter") != 0) {
                fog_emitters[fog_count.*] = scene_state.newFogEmitter();
                fog_count.* += 1;
            }
        } else {
            nk.nk_label(ctx, "Max fog emitters reached", @intCast(nk.NK_TEXT_CENTERED));
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 18, 1);
        nk.nk_label(ctx, "Warps", @intCast(nk.NK_TEXT_LEFT));

        var remove_warp_index: ?usize = null;
        for (0..warp_count.*) |i| {
            var warp_buf: [48]u8 = undefined;
            const warp_label: [:0]const u8 = std.fmt.bufPrintSentinel(&warp_buf, "Warp {d}: {s}", .{ i + 1, warps[i].coord_kind.label() }, 0) catch "Warp";
            if (widgets.selectableRemovableRow(ctx, warp_label, &warps[i].window_open, 24)) {
                remove_warp_index = i;
            }
        }

        if (remove_warp_index) |idx| {
            var j = idx;
            while (j + 1 < warp_count.*) : (j += 1) warps[j] = warps[j + 1];
            warp_count.* -= 1;
            selection_state.noteRemoved(.warp, idx);
        }

        nk.nk_layout_row_dynamic(ctx, 24, 1);
        if (warp_count.* < max_warps) {
            if (nk.nk_button_label(ctx, "Add warp") != 0) {
                warps[warp_count.*] = warp_mod.newWarp();
                warp_count.* += 1;
            }
        } else {
            nk.nk_label(ctx, "Max warps reached", @intCast(nk.NK_TEXT_CENTERED));
        }

        widgets.separator(ctx);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_button_label(ctx, "Reset camera") != 0) {
            const was_2d = camera.mode_2d;
            const was_following = camera.follow_warp;
            camera.* = FreeCamera.initial();
            camera.mode_2d = was_2d;
            camera.follow_warp = was_following;
        }
    }
    nk.nk_end(ctx);
}

fn appendTrunc(buf: *[128:0]u8, pos: usize, src: []const u8) usize {
    if (pos >= buf.len - 1) return pos;
    const space = buf.len - 1 - pos;
    const n = @min(src.len, space);
    @memcpy(buf[pos .. pos + n], src[0..n]);
    return pos + n;
}

pub fn buildFormulaLibraryWindow(
    ctx: *nk.nk_context,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    panel: *formula_library.PanelState,
    instances: []const FractalInstanceState,
    instance_count: usize,
) void {
    if (!panel.open) return;

    const shown = nk.nk_begin(
        ctx,
        "Formula Library",
        nk.nk_rect(700, 60, 380, 560),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE),
    );
    if (shown != 0) {
        if (panel.library.dir_missing) {
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_colored_wrap(ctx, "Couldn't find the formulas/ folder next to the exe.", nk.nk_rgb(230, 90, 90));
        }

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Rescan") != 0) {
            panel.rescan();
        }
        var count_buf: [32]u8 = undefined;
        const count_label: [:0]const u8 = std.fmt.bufPrintSentinel(&count_buf, "{d} formulas", .{panel.library.entry_count}, 0) catch "formulas";
        nk.nk_label(ctx, count_label.ptr, @intCast(nk.NK_TEXT_RIGHT));

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Filter by label");

        const labels = formula_library.distinctLabels(&panel.library);
        const chip_cols = 3;
        var li: usize = 0;
        while (li < labels.count) {
            const remaining = @min(chip_cols, labels.count - li);
            nk.nk_layout_row_dynamic(ctx, 22, @intCast(remaining));
            for (0..remaining) |k| {
                const label = labels.slice(li + k);
                var label_buf: [formula_library.max_label_len + 1:0]u8 = std.mem.zeroes([formula_library.max_label_len + 1:0]u8);
                const n = @min(label.len, formula_library.max_label_len);
                @memcpy(label_buf[0..n], label[0..n]);
                const was_selected = panel.selected.contains(label);
                var selected: nk.nk_bool = if (was_selected) 1 else 0;
                _ = nk.nk_selectable_label(ctx, label_buf[0..n :0].ptr, @intCast(nk.NK_TEXT_CENTERED), &selected);
                if ((selected != 0) != was_selected) {
                    panel.selected.toggle(label);
                }
            }
            li += remaining;
        }

        if (panel.selected.count > 0) {
            nk.nk_layout_row_dynamic(ctx, 20, 1);
            if (nk.nk_button_label(ctx, "Clear filters") != 0) {
                panel.selected.clear();
            }
        }

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Click a formula to load it");

        var chosen: ?usize = null;
        for (0..panel.library.entry_count) |i| {
            const entry = &panel.library.entries[i];
            if (!panel.selected.matchesAll(entry)) continue;

            var row_buf: [128:0]u8 = std.mem.zeroes([128:0]u8);
            var row_len: usize = 0;
            row_len = appendTrunc(&row_buf, row_len, entry.nameSlice());
            if (entry.label_count > 0) {
                row_len = appendTrunc(&row_buf, row_len, " (");
                for (0..entry.label_count) |li2| {
                    if (li2 > 0) row_len = appendTrunc(&row_buf, row_len, ", ");
                    row_len = appendTrunc(&row_buf, row_len, entry.labelSlice(li2));
                }
                row_len = appendTrunc(&row_buf, row_len, ")");
            }
            row_buf[row_len] = 0;

            nk.nk_layout_row_dynamic(ctx, 22, 1);
            if (nk.nk_button_label(ctx, row_buf[0..row_len :0].ptr) != 0) {
                chosen = i;
            }
        }

        if (panel.library.entry_count == 0 and !panel.library.dir_missing) {
            nk.nk_layout_row_dynamic(ctx, 20, 1);
            nk.nk_label_colored(ctx, "No .wgsl files found.", @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(180, 180, 190));
        }

        if (chosen) |idx| {
            if (panel.target) |formula| {
                const entry = &panel.library.entries[idx];
                const path = entry.pathSlice();
                const n = @min(path.len, formula.formula_path.len - 1);
                @memcpy(formula.formula_path[0..n], path[0..n]);
                formula.formula_path[n] = 0;
                scene_state.compileFormulaInto(allocator, gpu_ctx, fractal, formula, instances, instance_count);
            }
            panel.open = false;
        }
    }
    nk.nk_end(ctx);
    if (nk.nk_window_is_closed(ctx, "Formula Library") != 0) {
        panel.open = false;
    }
}
