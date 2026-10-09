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
const layout = @import("layout.zig");
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
const particles_mod = @import("../app/particles.zig");
const ParticleSystemState = particles_mod.ParticleSystemState;
const max_particle_systems = fractal_gpu.max_particle_systems;
const screen_shader_mod = @import("../app/screen_shader.zig");
const ScreenShaderState = screen_shader_mod.ScreenShaderState;
const max_screen_shaders = screen_shader_mod.max_screen_shaders;
const sky_mod = @import("../app/sky.zig");
const SkyState = sky_mod.SkyState;
const selection = @import("../app/selection.zig");
const export_image = @import("../app/export_image.zig");
const scene_file = @import("../app/scene_file.zig");
const StereoState = @import("../app/stereo.zig").StereoState;
const render_parts_mod = @import("../app/render_parts.zig");
const RenderParts = render_parts_mod.RenderParts;
const approximations_mod = @import("../app/approximations.zig");
const Approximations = approximations_mod.Approximations;
const McRenderState = @import("../app/mc_render.zig").McRenderState;
const oidn = @import("../bindings/oidn.zig");
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
const export_mesh = @import("../app/export_mesh.zig");
const PlayState = @import("../app/play_mode.zig").PlayState;

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
        library_panel.openFor(.{ .formula = formula });
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
    ws: layout.Workspace,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    inst: *FractalInstanceState,
    index: usize,
    instances: []FractalInstanceState,
    instance_count: usize,
    library_panel: *formula_library.PanelState,
) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Fractal {d} Editor", .{index + 1}, 0) catch "Fractal Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 340, 980 } })) {
        if (widgets.beginSection(ctx, "Formula", .open)) {
            defer widgets.endSection(ctx);
            buildFormulaSection(ctx, window, gpu_ctx, fractal, allocator, &inst.formula, instances, instance_count, library_panel);
        }

        if (widgets.beginSection(ctx, "Transform", .open)) {
            defer widgets.endSection(ctx);
            widgets.sectionLabel(ctx, "Offset");
            widgets.sliderVec3(ctx, "Offset", &inst.offset, &inst.offset_range_x, &inst.offset_range_y, &inst.offset_range_z);

            widgets.sectionLabel(ctx, "Scale");
            widgets.sliderFloat(ctx, "Scale", &inst.scale_uniform, &inst.scale_uniform_range);
            widgets.sliderVec3(ctx, "Scale", &inst.scale, &inst.scale_range_x, &inst.scale_range_y, &inst.scale_range_z);

            widgets.sectionLabel(ctx, "Rotation (degrees)");
            widgets.sliderVec3(ctx, "Rotation", &inst.rotation, &inst.rotation_range_x, &inst.rotation_range_y, &inst.rotation_range_z);

            widgets.sliderFloat(ctx, "Step-size safety factor", &inst.step_safety, &inst.step_safety_range);
        }

        if (index > 0) {
            if (widgets.beginSection(ctx, "Combine", .open)) {
                defer widgets.endSection(ctx);
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
        }

        if (widgets.beginSection(ctx, "Mixins", .closed)) {
            defer widgets.endSection(ctx);
            buildMixinList(ctx, gpu_ctx, fractal, allocator, inst, instances, instance_count);
        }

        if (widgets.beginSection(ctx, "Material", .open)) {
            defer widgets.endSection(ctx);
            buildColorStripSection(ctx, inst);
        }

        if (widgets.beginSection(ctx, "Orbit trap", .closed)) {
            defer widgets.endSection(ctx);
            buildOrbitTrapSection(ctx, &inst.trap);
        }

        if (widgets.beginSection(ctx, "FT View", .closed)) {
            defer widgets.endSection(ctx);
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            var ft_view_on: c_int = if (inst.ft_view) 1 else 0;
            _ = nk.nk_checkbox_label(ctx, "FT View (Fourier magnitude cloud)", &ft_view_on);
            if ((ft_view_on != 0) != inst.ft_view) {
                scene_state.setFtViewExclusive(instances, index, ft_view_on != 0);
            }
            if (inst.ft_view) {
                widgets.sliderFloat(ctx, "FT box radius", &inst.fft_box_radius, &inst.fft_box_radius_range);
                widgets.sliderFloat(ctx, "FT cloud density", &inst.fft_cloud_density, &inst.fft_cloud_density_range);
                widgets.sliderFloat(ctx, "FT low-pass cutoff", &inst.fft_lowpass, &inst.fft_lowpass_range);
                widgets.sliderFloat(ctx, "FT high-pass cutoff", &inst.fft_highpass, &inst.fft_highpass_range);
                nk.nk_layout_row_dynamic(ctx, 22, 1);
                var normalize_on: c_int = if (inst.fft_normalize) 1 else 0;
                _ = nk.nk_checkbox_label(ctx, "Normalize (peak = 1)", &normalize_on);
                inst.fft_normalize = normalize_on != 0;
            }
        }
    }
    layout.end(ctx, title, &inst.window_open);
}

fn buildMixinList(
    ctx: *nk.nk_context,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    inst: *FractalInstanceState,
    instances: []FractalInstanceState,
    instance_count: usize,
) void {
    var remove_mixin_index: ?usize = null;
    for (0..inst.mixin_count) |j| {
        var mixin_buf: [32]u8 = undefined;
        const mixin_label: [:0]const u8 = std.fmt.bufPrintSentinel(&mixin_buf, "Mixin {d}", .{j + 1}, 0) catch "Mixin";
        if (widgets.selectableRemovableRow(ctx, mixin_label, &inst.mixins[j].window_open, null, 22)) {
            remove_mixin_index = j;
        }
    }

    if (remove_mixin_index) |idx| {
        if (!fractal.isCompiling()) {
            inst.mixins[idx].formula.deinit(allocator);
            var j = idx;
            while (j + 1 < inst.mixin_count) : (j += 1) inst.mixins[j] = inst.mixins[j + 1];
            inst.mixin_count -= 1;
            formula_library.noteListChanged();
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
}

fn buildColorStripSection(ctx: *nk.nk_context, inst: anytype) void {
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

            if (widgets.beginSubsection(ctx, "refraction", "Refraction", .closed)) {
                defer widgets.endSection(ctx);
                widgets.sliderFloat(ctx, "IOR", &stop.ior, &stop.ior_range);
                widgets.sliderFloat(ctx, "Abbe number", &stop.abbe, &stop.abbe_range);
                widgets.sliderFloat(ctx, "Roughness", &stop.roughness, &stop.roughness_range);
                widgets.sliderInt(ctx, "Inner max steps", &stop.inner_max_steps, &stop.inner_max_steps_range);
            }

            if (widgets.beginSubsection(ctx, "iridescence", "Iridescence", .closed)) {
                defer widgets.endSection(ctx);
                widgets.sliderFloat(ctx, "Strength", &stop.film_strength, &stop.film_strength_range);
                widgets.sliderFloat(ctx, "Film thickness (nm)", &stop.film_thickness, &stop.film_thickness_range);
                widgets.sliderFloat(ctx, "Film IOR", &stop.film_ior, &stop.film_ior_range);
                widgets.sliderFloat(ctx, "Angle scale", &stop.film_angle_scale, &stop.film_angle_scale_range);
                widgets.sliderFloat(ctx, "Normal perturbation", &stop.film_perturb, &stop.film_perturb_range);
                widgets.sliderFloat(ctx, "Perturbation scale", &stop.film_perturb_scale, &stop.film_perturb_scale_range);
            }
        } else {
            inst.selected_color = null;
        }
    }
}

fn labeledEnumCombo(ctx: *nk.nk_context, label: [:0]const u8, comptime E: type, value: *E) void {
    nk.nk_layout_row_template_begin(ctx, 22);
    nk.nk_layout_row_template_push_static(ctx, 80);
    nk.nk_layout_row_template_push_dynamic(ctx);
    nk.nk_layout_row_template_end(ctx);
    nk.nk_label(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT));
    if (nk.nk_combo_begin_label(ctx, value.label().ptr, nk.nk_vec2(nk.nk_widget_width(ctx), 200)) != 0) {
        nk.nk_layout_row_dynamic(ctx, 20, 1);
        for (E.all) |v| {
            if (nk.nk_combo_item_label(ctx, v.label().ptr, @intCast(nk.NK_TEXT_LEFT)) != 0) {
                value.* = v;
            }
        }
        nk.nk_combo_end(ctx);
    }
}

fn buildOrbitTrapSection(ctx: *nk.nk_context, trap: *scene_state.OrbitTrapState) void {
    labeledEnumCombo(ctx, "Shape", scene_state.TrapShape, &trap.shape);
    labeledEnumCombo(ctx, "Measure", scene_state.TrapMode, &trap.mode);

    widgets.sliderVec3(ctx, "Trap centre", &trap.center, &trap.center_range_x, &trap.center_range_y, &trap.center_range_z);
    switch (trap.shape) {
        .point, .cross => {},
        .sphere => widgets.sliderFloat(ctx, "Trap radius", &trap.radius, &trap.radius_range),
        .box => widgets.sliderVec3(ctx, "Box half-extent", &trap.box, &trap.box_range_x, &trap.box_range_y, &trap.box_range_z),
        .torus => {
            widgets.sliderFloat(ctx, "Ring radius", &trap.radius, &trap.radius_range);
            widgets.sliderFloat(ctx, "Tube radius", &trap.tube, &trap.tube_range);
        },
    }

    widgets.sliderFloat(ctx, "Strip span", &trap.span, &trap.span_range);
    widgets.sliderFloat(ctx, "Strip offset", &trap.offset, &trap.offset_range);
    labeledEnumCombo(ctx, "Past the end", scene_state.TrapRepeat, &trap.repeat);

    if (trap.mode == .iteration) {
        nk.nk_layout_row_dynamic(ctx, 28, 1);
        nk.nk_label_colored_wrap(ctx, "Iteration value runs 0..1 over the formula's iterations: span 1 covers the strip", nk.nk_rgb(180, 180, 190));
    }
}

pub fn buildMixinEditorWindow(
    ctx: *nk.nk_context,
    ws: layout.Workspace,
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

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 320, 400 } })) {
        buildFormulaSection(ctx, window, gpu_ctx, fractal, allocator, &mixin.formula, instances, instance_count, library_panel);
    }
    layout.end(ctx, title, &mixin.window_open);
}

pub fn buildLightEditorWindow(ctx: *nk.nk_context, ws: layout.Workspace, light: *LightState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Light {d} Editor", .{index + 1}, 0) catch "Light Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 300, 460 } })) {
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

        if (widgets.beginSection(ctx, "Placement", .open)) {
            defer widgets.endSection(ctx);
            buildLightPlacement(ctx, light);
        }

        if (widgets.beginSection(ctx, "Shadows", .open)) {
            defer widgets.endSection(ctx);
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
    }
    layout.end(ctx, title, &light.window_open);
}

fn buildLightPlacement(ctx: *nk.nk_context, light: *LightState) void {
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
}

pub fn buildFogEmitterEditorWindow(ctx: *nk.nk_context, ws: layout.Workspace, fog: *FogEmitterState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Fog {d} Editor", .{index + 1}, 0) catch "Fog Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 300, 460 } })) {
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
    }
    layout.end(ctx, title, &fog.window_open);
}

pub fn buildSkyEditorWindow(
    ctx: *nk.nk_context,
    ws: layout.Workspace,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    sky: *SkyState,
) void {
    const title: [:0]const u8 = "Sky";
    if (layout.begin(ctx, ws, title, .{ .floating = .{ 320, 620 } })) {
        widgets.sectionLabel(ctx, "Source");
        nk.nk_layout_row_dynamic(ctx, 22, 2);
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

                if (widgets.beginSection(ctx, "Sun", .open)) {
                    defer widgets.endSection(ctx);
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

        if (widgets.beginSection(ctx, "Lighting", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderFloat(ctx, "Sky brightness", &sky.intensity, &sky.intensity_range);
            widgets.sliderFloat(ctx, "Rotation", &sky.yaw, &sky.yaw_range);

            nk.nk_layout_row_dynamic(ctx, 22, 1);
            var photons_on: c_int = if (sky.photons) 1 else 0;
            _ = nk.nk_checkbox_label(ctx, "Sky photons", &photons_on);
            sky.photons = photons_on != 0;
        }
    }
    layout.end(ctx, title, &sky.window_open);
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

pub fn buildWarpEditorWindow(ctx: *nk.nk_context, ws: layout.Workspace, w: *WarpState, index: usize) void {
    var title_buf: [32]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Warp {d} Editor", .{index + 1}, 0) catch "Warp Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 320, 560 } })) {
        if (widgets.beginSection(ctx, "Deformation", .open)) {
            defer widgets.endSection(ctx);
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
        }

        if (widgets.beginSection(ctx, "Region of influence", .open)) {
            defer widgets.endSection(ctx);
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
        }

        if (widgets.beginSection(ctx, "Placement", .open)) {
            defer widgets.endSection(ctx);
            widgets.sectionLabel(ctx, "Centre");
            widgets.sliderVec3(ctx, "Centre", &w.center, &w.center_range_x, &w.center_range_y, &w.center_range_z);

            widgets.sectionLabel(ctx, "Orientation");
            widgets.sliderVec3(ctx, "Rotation", &w.rotation, &w.rotation_range_x, &w.rotation_range_y, &w.rotation_range_z);
        }

        if (widgets.beginSection(ctx, "Advanced", .closed)) {
            defer widgets.endSection(ctx);
            widgets.sliderFloat(ctx, "Step safety", &w.step_safety, &w.step_safety_range);
        }
    }
    layout.end(ctx, title, &w.window_open);
}

pub fn buildParticleSystemEditorWindow(ctx: *nk.nk_context, ws: layout.Workspace, ps: *ParticleSystemState, index: usize, steps_simulated: u32) void {
    var title_buf: [40]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Particle System {d} Editor", .{index + 1}, 0) catch "Particle System Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 340, 900 } })) {
        if (widgets.beginSection(ctx, "Time", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderFloat(ctx, "t", &ps.t, &ps.t_range);
            widgets.sliderInt(ctx, "Sim steps per unit of t", &ps.sim_rate, &ps.sim_rate_range);
            var step_buf: [96]u8 = undefined;
            const step_line: [:0]const u8 = if (ps.targetSteps() >= particles_mod.max_steps)
                std.fmt.bufPrintSentinel(&step_buf, "Capped at {d} steps: t stops at {d:.2}", .{ particles_mod.max_steps, ps.effectiveT() }, 0) catch ""
            else
                std.fmt.bufPrintSentinel(&step_buf, "{d} steps simulated", .{steps_simulated}, 0) catch "";
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label(ctx, step_line.ptr, @intCast(nk.NK_TEXT_LEFT));
        }

        if (widgets.beginSection(ctx, "Spawn", .open)) {
            defer widgets.endSection(ctx);
            labeledEnumCombo(ctx, "Shape", particles_mod.SpawnShape, &ps.spawn_shape);
            widgets.sliderVec3(ctx, "Centre", &ps.center, &ps.center_range_x, &ps.center_range_y, &ps.center_range_z);
            switch (ps.spawn_shape) {
                .sphere => widgets.sliderFloat(ctx, "Radius (0 = point)", &ps.spawn_radius, &ps.spawn_radius_range),
                .disc => widgets.sliderFloat(ctx, "Disc radius", &ps.spawn_radius, &ps.spawn_radius_range),
                .rectangle => {
                    widgets.sliderFloat(ctx, "Half-extent X", &ps.extent_x, &ps.extent_x_range);
                    widgets.sliderFloat(ctx, "Half-extent Z", &ps.extent_z, &ps.extent_z_range);
                },
            }
            if (ps.spawn_shape != .sphere) {
                widgets.sliderVec3(ctx, "Rotation", &ps.rotation, &ps.rotation_range_x, &ps.rotation_range_y, &ps.rotation_range_z);
            }
            widgets.sliderInt(ctx, "Count", &ps.count, &ps.count_range);
            widgets.sliderInt(ctx, "Seed", &ps.seed, &ps.seed_range);
            widgets.sliderFloat(ctx, "Emission duration (0 = all at once)", &ps.emit_duration, &ps.emit_duration_range);
            widgets.sliderFloat(ctx, "Lifetime (0 = forever)", &ps.lifetime, &ps.lifetime_range);
        }

        if (widgets.beginSection(ctx, "Movement", .closed)) {
            defer widgets.endSection(ctx);
            labeledEnumCombo(ctx, "Velocity", particles_mod.VelocityMode, &ps.velocity_mode);
            if (ps.velocity_mode == .direction) {
                widgets.sliderVec3(ctx, "Direction", &ps.direction, &ps.direction_range_x, &ps.direction_range_y, &ps.direction_range_z);
                widgets.sliderFloat(ctx, "Cone spread (deg)", &ps.spread, &ps.spread_range);
            }
            widgets.sliderFloat(ctx, "Speed min", &ps.speed_min, &ps.speed_min_range);
            widgets.sliderFloat(ctx, "Speed max", &ps.speed_max, &ps.speed_max_range);
        }

        if (widgets.beginSection(ctx, "Physics", .closed)) {
            defer widgets.endSection(ctx);
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            const scene_now: nk.nk_bool = if (ps.stop_on_scene) 1 else 0;
            ps.stop_on_scene = nk.nk_check_label(ctx, "Stop on contact with fractals", scene_now) != 0;
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            const stick_now: nk.nk_bool = if (ps.stick) 1 else 0;
            ps.stick = nk.nk_check_label(ctx, "Stick to stopped particles", stick_now) != 0;
            widgets.sliderFloat(ctx, "Kill radius (from centre)", &ps.kill_radius, &ps.kill_radius_range);
        }

        if (widgets.beginSection(ctx, "Look", .open)) {
            defer widgets.endSection(ctx);
            widgets.sliderFloat(ctx, "Radius", &ps.size, &ps.size_range);
            widgets.sliderFloat(ctx, "Radius variation", &ps.size_variation, &ps.size_variation_range);

            labeledEnumCombo(ctx, "Render as", particles_mod.RenderMode, &ps.render_mode);
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label_colored(ctx, "Switching recompiles the shader", @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(180, 180, 190));
            switch (ps.render_mode) {
                .spheres => {
                    labeledEnumCombo(ctx, "Combine", scene_state.CombineMode, &ps.combine_mode);
                    if (ps.combine_mode != .hard_union) {
                        widgets.sliderFloat(ctx, "Blend smoothness", &ps.blend_k, &ps.blend_k_range);
                    }
                },
                .dots => {
                    labeledEnumCombo(ctx, "Style", particles_mod.DotStyle, &ps.dot_style);
                    widgets.sliderFloat(ctx, "Brightness", &ps.glow, &ps.glow_range);
                    if (ps.dot_style == .soft_glow) {
                        widgets.sliderFloat(ctx, "Glow reach (x radius)", &ps.glow_extent, &ps.glow_extent_range);
                    }
                },
            }
        }

        if (widgets.beginSection(ctx, "Material", .open)) {
            defer widgets.endSection(ctx);
            labeledEnumCombo(ctx, "Strip by", particles_mod.StripMode, &ps.strip_mode);
            if (ps.strip_mode == .distance) {
                widgets.sliderFloat(ctx, "Strip span", &ps.strip_span, &ps.strip_span_range);
            }
            widgets.sliderFloat(ctx, "Strip offset", &ps.strip_offset, &ps.strip_offset_range);
            buildColorStripSection(ctx, ps);
        }
    }
    layout.end(ctx, title, &ps.window_open);
}

pub fn buildScreenShaderEditorWindow(
    ctx: *nk.nk_context,
    ws: layout.Workspace,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    shader: *ScreenShaderState,
    index: usize,
    library_panel: *formula_library.PanelState,
) void {
    var title_buf: [48]u8 = undefined;
    const title: [:0]const u8 = std.fmt.bufPrintSentinel(&title_buf, "Screen Shader {d} Editor", .{index + 1}, 0) catch "Screen Shader Editor";

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 330, 520 } })) {
        nk.nk_layout_row_dynamic(ctx, 22, 2);
        const on_now: nk.nk_bool = if (shader.enabled) 1 else 0;
        shader.enabled = nk.nk_check_label(ctx, "Enabled", on_now) != 0;
        const anim_now: nk.nk_bool = if (shader.animated) 1 else 0;
        shader.animated = nk.nk_check_label(ctx, "Animated", anim_now) != 0;
        if (shader.animated) {
            nk.nk_layout_row_dynamic(ctx, 30, 1);
            nk.nk_label_colored_wrap(ctx, "Keeps redrawing the preview so effects that read pp.time keep moving.", nk.nk_rgb(180, 180, 190));
        }

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, ".wgsl screen-space effect");
        nk.nk_layout_row_template_begin(ctx, 24);
        nk.nk_layout_row_template_push_dynamic(ctx);
        nk.nk_layout_row_template_push_static(ctx, 76);
        nk.nk_layout_row_template_end(ctx);
        _ = nk.nk_edit_string_zero_terminated(ctx, @intCast(nk.NK_EDIT_FIELD), &shader.path, shader.path.len, nk.nk_filter_default);
        if (nk.nk_button_label(ctx, "Browse") != 0) {
            var buf: [screen_shader_mod.max_path_len]u8 = undefined;
            if (file_dialog.pickWgslFile(window, &buf)) |len| {
                shader.setPath(buf[0..@min(len, buf.len)]);
            }
        }

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Library") != 0) {
            library_panel.openFor(.{ .screen = shader });
        }
        if (!fractal.isCompiling()) {
            if (nk.nk_button_label(ctx, "Compile") != 0) {
                screen_shader_mod.compileInto(allocator, gpu_ctx, &fractal.post, shader);
            }
        } else {
            nk.nk_label(ctx, "Busy", @intCast(nk.NK_TEXT_CENTERED));
        }

        if (shader.pipeline != null) {
            nk.nk_layout_row_dynamic(ctx, 16, 1);
            nk.nk_label_colored(ctx, "Effect compiled", @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(140, 220, 140));
        }
        if (shader.compile_error_len > 0) {
            nk.nk_layout_row_dynamic(ctx, 60, 1);
            nk.nk_label_colored_wrap(ctx, shader.compile_error[0..shader.compile_error_len :0].ptr, nk.nk_rgb(230, 90, 90));
        }

        widgets.separator(ctx);

        widgets.sectionLabel(ctx, "Parameters");
        if (shader.param_count == 0) {
            nk.nk_layout_row_dynamic(ctx, 30, 1);
            nk.nk_label_colored_wrap(ctx, "This effect declares no @param lines.", nk.nk_rgb(180, 180, 190));
        }
        for (0..shader.param_count) |i| {
            const param = &shader.params[i];
            if (param.name_len == 0) continue;
            if (param.integral) {
                widgets.sliderInt(ctx, param.label(), &param.value, &param.range);
            } else {
                widgets.sliderFloat(ctx, param.label(), &param.value, &param.range);
            }
        }
    }
    layout.end(ctx, title, &shader.window_open);
}

pub fn buildStereoSettingsWindow(ctx: *nk.nk_context, ws: layout.Workspace, stereo: *StereoState) void {
    if (!stereo.settings_open) return;

    const title = "Stereoscopic Settings";
    if (layout.begin(ctx, ws, title, .{ .floating = .{ 320, 280 } })) {
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const enabled_now: nk.nk_bool = if (stereo.enabled) 1 else 0;
        stereo.enabled = nk.nk_check_label(ctx, "Render as stereoscopic", enabled_now) != 0;

        widgets.separator(ctx);

        widgets.sliderFloat(ctx, "Eye separation", &stereo.eye_separation, &stereo.eye_separation_range);
        widgets.sliderFloat(ctx, "Convergence distance", &stereo.convergence_distance, &stereo.convergence_distance_range);

        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const preview_now: nk.nk_bool = if (stereo.preview) 1 else 0;
        stereo.preview = nk.nk_check_label(ctx, "Preview (overlap both eyes)", preview_now) != 0;
    }
    layout.end(ctx, title, &stereo.settings_open);
}

pub fn buildRenderPartsWindow(ctx: *nk.nk_context, ws: layout.Workspace, parts: *RenderParts, specialising: bool) void {
    if (!parts.window_open) return;

    const title = "Simple render";
    if (layout.begin(ctx, ws, title, .{ .floating = .{ 300, 640 } })) {
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const enabled_now: nk.nk_bool = if (parts.enabled) 1 else 0;
        parts.enabled = nk.nk_check_label(ctx, "Simple render", enabled_now) != 0;

        if (parts.enabled) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            const geo_now: nk.nk_bool = if (parts.geometry_only) 1 else 0;
            parts.geometry_only = nk.nk_check_label(ctx, "Geometry only (fast)", geo_now) != 0;
            if (!parts.geometry_only) {
                const fast = parts.liteOnly();
                const note: [:0]const u8 = if (fast)
                    "Fast path: only local shading parts are on, so this renders with the quick shader."
                else if (specialising)
                    "Full path. Compiling a shader with the unticked parts left out; the view speeds up when it is ready."
                else
                    "Full path, with the unticked parts compiled out. Leave only Colour strips, Direct lights, Specular, AO, Sky and Screen shaders on for the fast path.";
                widgets.hint(ctx, note, if (fast) nk.nk_rgb(120, 200, 120) else widgets.dim);
            }

            nk.nk_layout_row_dynamic(ctx, 22, 2);
            if (nk.nk_button_label(ctx, "All on") != 0) parts.setAll(true);
            if (nk.nk_button_label(ctx, "All off") != 0) parts.setAll(false);

            for (std.enums.values(render_parts_mod.Group)) |group| {
                if (!widgets.beginSection(ctx, group.label(), .open)) continue;
                defer widgets.endSection(ctx);
                for (std.enums.values(render_parts_mod.Part)) |part| {
                    const pi = render_parts_mod.info(part);
                    if (pi.group != group) continue;
                    nk.nk_layout_row_dynamic(ctx, 22, 1);
                    const now: nk.nk_bool = if (parts.isOn(part)) 1 else 0;
                    parts.set(part, nk.nk_check_label(ctx, pi.label.ptr, now) != 0);
                    if (!parts.isOn(part)) widgets.hint(ctx, pi.off_hint, widgets.warn);
                }
            }
        } else {
            widgets.hint(ctx, "Tick Simple render to switch individual parts off.", widgets.dim);
        }

        if (widgets.beginSection(ctx, "Approximations", .open)) {
            defer widgets.endSection(ctx);
            buildApproximationsSection(ctx, &parts.approx);
        }
    }
    layout.end(ctx, title, &parts.window_open);
}

fn buildApproximationsSection(ctx: *nk.nk_context, approx: *Approximations) void {
    widgets.hint(ctx, "Cheaper stand-ins for the expensive parts. Saved with the scene and used by exports too.", widgets.dim);

    for (std.enums.values(approximations_mod.Approx)) |a| {
        const ai = approximations_mod.info(a);
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        const now: nk.nk_bool = if (approx.isOn(a)) 1 else 0;
        approx.set(a, nk.nk_check_label(ctx, ai.label.ptr, now) != 0);
        if (!approx.isOn(a)) continue;
        widgets.hint(ctx, ai.hint, nk.nk_rgb(120, 180, 220));
        switch (a) {
            .simple_fog => widgets.sliderFloat(ctx, "Light shaft strength", &approx.shaft_strength, &approx.shaft_strength_range),
            .fake_caustics => {
                widgets.sliderFloat(ctx, "Caustic strength", &approx.caustic_strength, &approx.caustic_strength_range);
                widgets.sliderFloat(ctx, "Caustic scale", &approx.caustic_scale, &approx.caustic_scale_range);
            },
            .fake_bounce => widgets.sliderFloat(ctx, "Bounce strength", &approx.bounce_strength, &approx.bounce_strength_range),
            .tint => widgets.sliderFloat(ctx, "Absorption", &approx.tint_density, &approx.tint_density_range),
            .distance_lod => {
                widgets.sliderFloat(ctx, "LOD start distance", &approx.lod_start, &approx.lod_start_range);
                widgets.sliderFloat(ctx, "Iterations lost per doubling", &approx.lod_strength, &approx.lod_strength_range);
            },
            else => {},
        }
    }
    if (approx.replacesPhotons()) {
        widgets.hint(ctx, "Simple fog, Fake caustics and Fake bounce light together replace the photon map, so it is not traced.", nk.nk_rgb(120, 200, 120));
    }
}

pub fn buildAnimRenderWindow(
    ctx: *nk.nk_context,
    ws: layout.Workspace,
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
    screen_shaders: []const ScreenShaderState,
    particle_systems: []const ParticleSystemState,
    camera: FreeCamera,
    render_settings: RenderSettingsState,
    photon: PhotonSettings,
    stereo: StereoState,
    mc: McRenderState,
    progress_overlay: *ProgressOverlay,
) void {
    if (!anim_render.window_open) return;

    if (layout.begin(ctx, ws, "Render Animation", .{ .floating = .{ 340, 520 } })) {
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

        const ffmpeg = anim_render.ffmpeg orelse blk: {
            anim_render.ffmpeg = export_anim.probeFfmpeg(allocator);
            break :blk anim_render.ffmpeg.?;
        };
        var ffmpeg_buf: [96]u8 = undefined;
        const ffmpeg_text: [:0]const u8 = if (ffmpeg.found)
            std.fmt.bufPrintSentinel(&ffmpeg_buf, "ffmpeg found ({s}) -- output: anim.mp4", .{ffmpeg.version()}, 0) catch "ffmpeg found"
        else
            "ffmpeg not found on PATH -- only PNG frames will be saved";
        nk.nk_layout_row_dynamic(ctx, 32, 1);
        nk.nk_label_wrap(ctx, ffmpeg_text.ptr);
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_button_label(ctx, "Re-check ffmpeg") != 0) {
            anim_render.ffmpeg = null;
        }

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
                screen_shaders,
                particle_systems,
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
    layout.end(ctx, "Render Animation", &anim_render.window_open);
}

pub fn buildMeshExportWindow(
    ctx: *nk.nk_context,
    ws: layout.Workspace,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    state: *export_mesh.MeshExportState,
    scene: export_mesh.Scene,
    progress_overlay: *ProgressOverlay,
) void {
    if (!state.window_open) return;

    if (layout.begin(ctx, ws, "Mesh Export", .{ .floating = .{ 340, 560 } })) {
        nk.nk_layout_row_dynamic(ctx, 32, 1);
        nk.nk_label_wrap(ctx, "Fractal surfaces only -- lights, fog and sky are not exported.");

        widgets.separator(ctx);
        widgets.sectionLabel(ctx, "Bounds");
        widgets.sliderVec3(ctx, "Center", &state.center, &state.center_range_x, &state.center_range_y, &state.center_range_z);
        widgets.sliderVec3(ctx, "Size", &state.size, &state.size_range_x, &state.size_range_y, &state.size_range_z);
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        if (nk.nk_button_label(ctx, "Auto-fit bounds") != 0) {
            export_mesh.autoFit(state, allocator, gpu_ctx, fractal, scene, progress_overlay);
        }

        widgets.separator(ctx);
        widgets.sectionLabel(ctx, "Surface");
        widgets.sliderInt(ctx, "Resolution (cells, longest side)", &state.resolution, &state.resolution_range);
        widgets.sliderFloat(ctx, "Surface offset (cells)", &state.iso_scale, &state.iso_scale_range);
        widgets.sliderFloat(ctx, "Sharp features", &state.sharpness, &state.sharpness_range);
        widgets.sliderInt(ctx, "Drop pieces under (quads)", &state.min_piece, &state.min_piece_range);
        nk.nk_layout_row_dynamic(ctx, 22, 1);
        var colors_val: c_int = if (state.vertex_colors) 1 else 0;
        _ = nk.nk_checkbox_label(ctx, "Vertex colors", &colors_val);
        state.vertex_colors = colors_val != 0;

        widgets.separator(ctx);
        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Estimate size") != 0) {
            export_mesh.estimate(state, allocator, gpu_ctx, fractal, scene, progress_overlay);
        }
        if (nk.nk_button_label(ctx, "Export mesh...") != 0) {
            export_mesh.exportMesh(state, allocator, window, gpu_ctx, fractal, scene, progress_overlay);
        }
        if (state.info.len > 0) {
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_wrap(ctx, state.info.ptr);
        }
        if (state.status.len > 0) {
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_wrap(ctx, state.status.ptr);
        }
    }
    layout.end(ctx, "Mesh Export", &state.window_open);
}

pub fn buildCrosshair(ctx: *nk.nk_context, play: *const PlayState, width: f32, height: f32) void {
    if (!play.captured) return;
    const arm: f32 = 8;
    const gap: f32 = 3;
    const cx = @round(width * 0.5);
    const cy = @round(height * 0.5);
    _ = nk.nk_style_push_style_item(ctx, &ctx.style.window.fixed_background, nk.nk_style_item_color(nk.nk_rgba(0, 0, 0, 0)));
    defer _ = nk.nk_style_pop_style_item(ctx);
    const half: f32 = arm + 24;
    const bounds = nk.nk_rect(cx - half, cy - half, 2 * half, 2 * half);
    if (nk.nk_begin(ctx, "##crosshair", bounds, @intCast(nk.NK_WINDOW_NO_INPUT | nk.NK_WINDOW_NO_SCROLLBAR | nk.NK_WINDOW_BACKGROUND)) != 0) {
        const canvas = nk.nk_window_get_canvas(ctx);
        inline for (.{ .{ 3.0, nk.nk_rgba(0, 0, 0, 160) }, .{ 1.5, nk.nk_rgba(255, 255, 255, 230) } }) |pass| {
            nk.nk_stroke_line(canvas, cx - arm, cy, cx - gap, cy, pass[0], pass[1]);
            nk.nk_stroke_line(canvas, cx + gap, cy, cx + arm, cy, pass[0], pass[1]);
            nk.nk_stroke_line(canvas, cx, cy - arm, cx, cy - gap, pass[0], pass[1]);
            nk.nk_stroke_line(canvas, cx, cy + gap, cx, cy + arm, pass[0], pass[1]);
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
    ws: layout.Workspace,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,
    panel: *formula_library.PanelState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    title: [:0]const u8,
) void {
    _ = panel.liveTarget();
    if (!panel.open) return;

    if (layout.begin(ctx, ws, title, .{ .floating = .{ 380, 560 } })) {
        if (panel.library.dir_missing) {
            var missing_buf: [96]u8 = undefined;
            const missing: [:0]const u8 = std.fmt.bufPrintSentinel(&missing_buf, "Couldn't find the {s}/ folder next to the exe.", .{panel.subdir}, 0) catch "Folder not found next to the exe.";
            nk.nk_layout_row_dynamic(ctx, 32, 1);
            nk.nk_label_colored_wrap(ctx, missing.ptr, nk.nk_rgb(230, 90, 90));
        }

        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Rescan") != 0) {
            panel.rescan();
        }
        var count_buf: [32]u8 = undefined;
        const count_label: [:0]const u8 = std.fmt.bufPrintSentinel(&count_buf, "{d} files", .{panel.library.entry_count}, 0) catch "files";
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

        widgets.sectionLabel(ctx, "Click one to load it");

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
            const path = panel.library.entries[idx].pathSlice();
            if (panel.target) |target| switch (target) {
                .formula => |formula| {
                    const n = @min(path.len, formula.formula_path.len - 1);
                    @memcpy(formula.formula_path[0..n], path[0..n]);
                    formula.formula_path[n] = 0;
                    scene_state.compileFormulaInto(allocator, gpu_ctx, fractal, formula, instances, instance_count);
                },
                .screen => |shader| {
                    shader.setPath(path);
                    screen_shader_mod.compileInto(allocator, gpu_ctx, &fractal.post, shader);
                },
            };
            panel.open = false;
        }
    }
    layout.end(ctx, title, &panel.open);
}
