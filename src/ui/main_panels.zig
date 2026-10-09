const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const nk = @import("../bindings/nuklear.zig").c;

const Context = @import("../gpu/webgpu_context.zig").Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const max_instances = fractal_gpu.max_instances;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const max_particle_systems = fractal_gpu.max_particle_systems;

const widgets = @import("widgets.zig");
const layout = @import("layout.zig");
const editor_windows = @import("editor_windows.zig");
const formula_library = @import("../app/formula_library.zig");
const camera_mod = @import("../app/camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const SliderRange = @import("../app/slider_range.zig").SliderRange;
const scene_state = @import("../app/scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const warp_mod = @import("../app/warp.zig");
const WarpState = warp_mod.WarpState;
const ParticleSystemState = @import("../app/particles.zig").ParticleSystemState;
const screen_shader_mod = @import("../app/screen_shader.zig");
const ScreenShaderState = screen_shader_mod.ScreenShaderState;
const max_screen_shaders = screen_shader_mod.max_screen_shaders;
const SkyState = @import("../app/sky.zig").SkyState;
const selection = @import("../app/selection.zig");
const export_image = @import("../app/export_image.zig");
const scene_file = @import("../app/scene_file.zig");
const StereoState = @import("../app/stereo.zig").StereoState;
const RenderParts = @import("../app/render_parts.zig").RenderParts;
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
const export_mesh = @import("../app/export_mesh.zig");
const PlayState = @import("../app/play_mode.zig").PlayState;

pub const App = struct {
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    allocator: std.mem.Allocator,

    instances: *[max_instances]FractalInstanceState,
    instance_count: *usize,
    lights: *[max_lights]LightState,
    light_count: *usize,
    fog_emitters: *[max_fog_emitters]FogEmitterState,
    fog_count: *usize,
    warps: *[max_warps]WarpState,
    warp_count: *usize,
    particle_systems: *[max_particle_systems]ParticleSystemState,
    particle_count: *usize,
    screen_shaders: *[max_screen_shaders]ScreenShaderState,
    screen_shader_count: *usize,
    sky: *SkyState,

    camera: *FreeCamera,
    play: *PlayState,
    selection: *selection.State,

    render_parts: *RenderParts,
    max_steps: *f32,
    max_steps_range: *SliderRange,
    max_dist: *f32,
    max_dist_range: *SliderRange,
    preview_quality: *f32,
    preview_quality_range: *SliderRange,
    max_reflection_bounces: *f32,
    max_reflection_bounces_range: *SliderRange,
    precision: *MarchPrecision,
    render_settings: *RenderSettingsState,
    photon: *PhotonSettings,
    accel_state: *AccelState,
    mc: *McRenderState,
    mc_sample_count: *const u32,

    export_width: *i32,
    export_height: *i32,
    export_status_buf: *[scene_state.status_buf_len]u8,
    export_status: *[:0]const u8,
    scene_status_buf: *[scene_state.status_buf_len]u8,
    scene_status: *[:0]const u8,
    stereo: *StereoState,
    progress_overlay: *ProgressOverlay,
    timeline: *animation.TimelineState,
    anim_render: *animation.AnimRenderState,
    mesh_export: *export_mesh.MeshExportState,

    library_panel: *formula_library.PanelState,
    screen_library_panel: *formula_library.PanelState,
};

const Panels = struct {
    scene: bool = true,
    render: bool = true,
    camera: bool = true,
    output: bool = true,
};

var panels = Panels{};

const StatusSource = enum { none, scene, export_image };
var status_source: StatusSource = .none;

const Action = enum { save_scene, load_scene, export_image, render_animation, export_mesh };

pub fn build(ctx: *nk.nk_context, app: *const App, width: f32, height: f32) void {
    const ws = layout.Workspace{ .width = width, .height = height };

    if (buildMenuBar(ctx, app, ws)) |action| runAction(app, action);

    if (panels.scene) buildSceneWindow(ctx, app, ws);
    if (panels.render) buildRenderWindow(ctx, app, ws);
    if (panels.camera) buildCameraWindow(ctx, app, ws);
    if (panels.output) buildOutputWindow(ctx, app, ws);

    buildDialogs(ctx, app, ws);
    buildEditors(ctx, app, ws);
}

fn runAction(app: *const App, action: Action) void {
    switch (action) {
        .save_scene => {
            app.scene_status.* = scene_file.saveScene(
                app.allocator,
                app.window,
                app.camera.*,
                app.max_steps.*,
                app.max_steps_range.*,
                app.max_dist.*,
                app.max_dist_range.*,
                app.preview_quality.*,
                app.preview_quality_range.*,
                app.max_reflection_bounces.*,
                app.max_reflection_bounces_range.*,
                app.photon.*,
                app.precision.*,
                app.render_settings.*,
                app.export_width.*,
                app.export_height.*,
                app.instances[0..app.instance_count.*],
                app.lights[0..app.light_count.*],
                app.fog_emitters[0..app.fog_count.*],
                app.warps[0..app.warp_count.*],
                app.particle_systems[0..app.particle_count.*],
                app.screen_shaders[0..app.screen_shader_count.*],
                app.sky,
                app.stereo.*,
                app.mc.*,
                app.render_parts.approx,
                app.timeline.*,
                app.scene_status_buf,
            );
            status_source = .scene;
        },
        .load_scene => {
            app.scene_status.* = scene_file.loadScene(
                app.allocator,
                app.window,
                app.gpu_ctx,
                app.fractal,
                app.camera,
                app.max_steps,
                app.max_steps_range,
                app.max_dist,
                app.max_dist_range,
                app.preview_quality,
                app.preview_quality_range,
                app.max_reflection_bounces,
                app.max_reflection_bounces_range,
                app.photon,
                app.precision,
                app.render_settings,
                app.export_width,
                app.export_height,
                app.instances,
                app.instance_count,
                app.lights,
                app.light_count,
                app.fog_emitters,
                app.fog_count,
                app.warps,
                app.warp_count,
                app.particle_systems,
                app.particle_count,
                app.screen_shaders,
                app.screen_shader_count,
                app.sky,
                app.stereo,
                app.mc,
                &app.render_parts.approx,
                app.timeline,
                app.scene_status_buf,
            );
            status_source = .scene;
        },
        .export_image => {
            app.export_status.* = export_image.exportImage(
                app.allocator,
                app.window,
                app.gpu_ctx,
                app.fractal,
                app.instances[0..app.instance_count.*],
                app.lights[0..app.light_count.*],
                app.fog_emitters[0..app.fog_count.*],
                app.warps[0..app.warp_count.*],
                app.particle_systems[0..app.particle_count.*],
                app.camera.*,
                app.render_settings.max_steps,
                app.render_settings.max_dist,
                app.render_settings.max_reflection_bounces,
                app.photon.*,
                app.render_settings.precision,
                app.render_settings.fog_samples,
                app.export_width.*,
                app.export_height.*,
                app.stereo.*,
                app.mc.*,
                app.progress_overlay,
                app.export_status_buf,
            );
            status_source = .export_image;
        },
        .render_animation => {
            app.anim_render.window_open = true;
            app.anim_render.ffmpeg = null;
        },
        .export_mesh => {
            app.mesh_export.window_open = true;
            if (!app.mesh_export.bounds_seeded) export_mesh.seedBounds(app.mesh_export, app.instances[0..app.instance_count.*]);
        },
    }
}

fn menuItem(ctx: *nk.nk_context, label: [:0]const u8, enabled: bool) bool {
    if (!enabled) nk.nk_widget_disable_begin(ctx);
    defer if (!enabled) nk.nk_widget_disable_end(ctx);
    return nk.nk_menu_item_label(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT)) != 0 and enabled;
}

fn menuCheck(ctx: *nk.nk_context, label: [:0]const u8, value: *bool) bool {
    const was = value.*;
    value.* = nk.nk_check_label(ctx, label.ptr, if (was) 1 else 0) != 0;
    return value.* and !was;
}

fn menuRule(ctx: *nk.nk_context) void {
    nk.nk_layout_row_dynamic(ctx, 6, 1);
    nk.nk_rule_horizontal(ctx, nk.nk_rgb(70, 70, 70), 0);
    nk.nk_layout_row_dynamic(ctx, 22, 1);
}

fn buildMenuBar(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) ?Action {
    var action: ?Action = null;
    if (nk.nk_begin(ctx, "##menubar", nk.nk_rect(0, 0, ws.width, layout.menu_h), @intCast(nk.NK_WINDOW_NO_SCROLLBAR)) != 0) {
        nk.nk_menubar_begin(ctx);
        const row_h = layout.menu_h - 8;
        nk.nk_layout_row_begin(ctx, nk.NK_STATIC, row_h, 4);

        nk.nk_layout_row_push(ctx, 44);
        if (nk.nk_menu_begin_label(ctx, "File", @intCast(nk.NK_TEXT_LEFT), nk.nk_vec2(200, 200)) != 0) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            if (menuItem(ctx, "Save scene...", true)) action = .save_scene;
            if (menuItem(ctx, "Load scene...", true)) action = .load_scene;
            menuRule(ctx);
            if (menuItem(ctx, "Export image", true)) action = .export_image;
            if (menuItem(ctx, "Render animation...", true)) action = .render_animation;
            if (menuItem(ctx, "Export mesh...", true)) action = .export_mesh;
            nk.nk_menu_end(ctx);
        }

        nk.nk_layout_row_push(ctx, 44);
        if (nk.nk_menu_begin_label(ctx, "Add", @intCast(nk.NK_TEXT_LEFT), nk.nk_vec2(200, 200)) != 0) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            buildAddMenu(ctx, app);
            nk.nk_menu_end(ctx);
        }

        nk.nk_layout_row_push(ctx, 72);
        if (nk.nk_menu_begin_label(ctx, "Windows", @intCast(nk.NK_TEXT_LEFT), nk.nk_vec2(240, 300)) != 0) {
            nk.nk_layout_row_dynamic(ctx, 22, 1);
            _ = menuCheck(ctx, "Scene", &panels.scene);
            _ = menuCheck(ctx, "Render", &panels.render);
            _ = menuCheck(ctx, "Camera", &panels.camera);
            _ = menuCheck(ctx, "Output", &panels.output);
            menuRule(ctx);
            _ = menuCheck(ctx, "Sky", &app.sky.window_open);
            _ = menuCheck(ctx, "Simple render & approximations", &app.render_parts.window_open);
            _ = menuCheck(ctx, "Stereo settings", &app.stereo.settings_open);
            if (menuCheck(ctx, "Render animation", &app.anim_render.window_open)) action = .render_animation;
            if (menuCheck(ctx, "Mesh export", &app.mesh_export.window_open)) action = .export_mesh;
            nk.nk_menu_end(ctx);
        }

        var status_buf: [scene_state.status_buf_len + 96]u8 = undefined;
        nk.nk_layout_row_push(ctx, @max(ws.width - 44 - 44 - 72 - 32, 10));
        nk.nk_label_colored(ctx, statusText(app, &status_buf).ptr, @intCast(nk.NK_TEXT_RIGHT), widgets.dim);

        nk.nk_layout_row_end(ctx);
        nk.nk_menubar_end(ctx);
    }
    nk.nk_end(ctx);
    return action;
}

fn statusText(app: *const App, buf: []u8) [:0]const u8 {
    const message: []const u8 = switch (status_source) {
        .none => "",
        .scene => app.scene_status.*,
        .export_image => app.export_status.*,
    };
    var w = std.Io.Writer.fixed(buf[0 .. buf.len - 1]);
    w.writeAll(message) catch {};
    if (app.fractal.parts.compiling()) {
        if (w.end > 0) w.writeAll("   |   ") catch {};
        w.writeAll("Specialising shader...") catch {};
    }
    if (app.mc.enabled) {
        if (w.end > 0) w.writeAll("   |   ") catch {};
        w.print("MC {d} / {d}", .{ app.mc_sample_count.*, @as(u32, @intFromFloat(@max(app.mc.max_samples, 1))) }) catch {};
    }
    buf[w.end] = 0;
    return buf[0..w.end :0];
}

fn buildAddMenu(ctx: *nk.nk_context, app: *const App) void {
    if (menuItem(ctx, "Fractal", app.instance_count.* < max_instances)) {
        app.instances[app.instance_count.*] = scene_state.newInstance();
        app.instances[app.instance_count.*].window_open = true;
        app.instance_count.* += 1;
    }
    if (menuItem(ctx, "Light", app.light_count.* < max_lights)) {
        app.lights[app.light_count.*] = scene_state.newLight();
        app.lights[app.light_count.*].window_open = true;
        app.light_count.* += 1;
    }
    if (menuItem(ctx, "Fog emitter", app.fog_count.* < max_fog_emitters)) {
        app.fog_emitters[app.fog_count.*] = scene_state.newFogEmitter();
        app.fog_emitters[app.fog_count.*].window_open = true;
        app.fog_count.* += 1;
    }
    if (menuItem(ctx, "Warp", app.warp_count.* < max_warps)) {
        app.warps[app.warp_count.*] = warp_mod.newWarp();
        app.warps[app.warp_count.*].window_open = true;
        app.warp_count.* += 1;
    }
    if (menuItem(ctx, "Particle system", app.particle_count.* < max_particle_systems)) {
        app.particle_systems[app.particle_count.*] = .{};
        app.particle_systems[app.particle_count.*].window_open = true;
        app.particle_count.* += 1;
    }
    if (menuItem(ctx, "Screen shader", app.screen_shader_count.* < max_screen_shaders)) {
        app.screen_shaders[app.screen_shader_count.*] = screen_shader_mod.newScreenShader();
        app.screen_shaders[app.screen_shader_count.*].window_open = true;
        app.screen_shader_count.* += 1;
    }
}

fn hiddenSuffix(visible: bool) []const u8 {
    return if (visible) "" else " (hidden)";
}

fn groupTitle(buf: []u8, name: []const u8, count: usize) [:0]const u8 {
    return std.fmt.bufPrintSentinel(buf, "{s} ({d})", .{ name, count }, 0) catch "Group";
}

fn emptyGroup(ctx: *nk.nk_context, count: usize) void {
    if (count != 0) return;
    nk.nk_layout_row_dynamic(ctx, 18, 1);
    nk.nk_label_colored(ctx, "None. Add one from the Add menu.", @intCast(nk.NK_TEXT_LEFT), widgets.dim);
}

fn removeAt(comptime T: type, items: []T, count: *usize, index: usize) void {
    var j = index;
    while (j + 1 < count.*) : (j += 1) items[j] = items[j + 1];
    count.* -= 1;
}

fn buildSceneWindow(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    const title = "Scene";
    if (layout.begin(ctx, ws, title, .{ .fixed = ws.sceneRect() })) {
        var title_buf: [48]u8 = undefined;

        if (widgets.beginSectionId(ctx, "Fractals", groupTitle(&title_buf, "Fractals", app.instance_count.*), .open)) {
            defer widgets.endSection(ctx);
            var remove_index: ?usize = null;
            for (0..app.instance_count.*) |i| {
                var buf: [32]u8 = undefined;
                const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Fractal {d}{s}", .{ i + 1, hiddenSuffix(app.instances[i].visible) }, 0) catch "Fractal";
                if (widgets.selectableRemovableRow(ctx, label, &app.instances[i].window_open, &app.instances[i].visible, 24)) {
                    remove_index = i;
                }
            }
            if (remove_index) |idx| {
                if (app.instance_count.* > 1 and !app.fractal.isCompiling()) {
                    scene_state.freeInstanceOwned(app.allocator, &app.instances[idx]);
                    removeAt(FractalInstanceState, app.instances, app.instance_count, idx);
                    formula_library.noteListChanged();
                    app.selection.noteRemoved(.fractal, idx);
                    scene_state.rebuildAll(app.gpu_ctx, app.fractal, app.allocator, app.instances[0..app.instance_count.*], app.instance_count.*);
                }
            }
        }

        if (widgets.beginSectionId(ctx, "Lights", groupTitle(&title_buf, "Lights", app.light_count.*), .open)) {
            defer widgets.endSection(ctx);
            emptyGroup(ctx, app.light_count.*);
            var remove_index: ?usize = null;
            for (0..app.light_count.*) |i| {
                var buf: [32]u8 = undefined;
                const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Light {d}{s}", .{ i + 1, hiddenSuffix(app.lights[i].visible) }, 0) catch "Light";
                if (widgets.selectableRemovableRow(ctx, label, &app.lights[i].window_open, &app.lights[i].visible, 24)) {
                    remove_index = i;
                }
            }
            if (remove_index) |idx| {
                removeAt(LightState, app.lights, app.light_count, idx);
                app.selection.noteRemoved(.light, idx);
            }
        }

        if (widgets.beginSection(ctx, "Environment", .open)) {
            defer widgets.endSection(ctx);
            var buf: [48]u8 = undefined;
            const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Sky: {s}", .{app.sky.mode.label()}, 0) catch "Sky";
            nk.nk_layout_row_dynamic(ctx, 24, 1);
            var selected: nk.nk_bool = if (app.sky.window_open) 1 else 0;
            _ = nk.nk_selectable_label(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT), &selected);
            app.sky.window_open = selected != 0;
        }

        if (widgets.beginSectionId(ctx, "Volumetric fog", groupTitle(&title_buf, "Volumetric fog", app.fog_count.*), .open)) {
            defer widgets.endSection(ctx);
            emptyGroup(ctx, app.fog_count.*);
            var remove_index: ?usize = null;
            for (0..app.fog_count.*) |i| {
                var buf: [32]u8 = undefined;
                const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Fog {d}{s}", .{ i + 1, hiddenSuffix(app.fog_emitters[i].visible) }, 0) catch "Fog";
                if (widgets.selectableRemovableRow(ctx, label, &app.fog_emitters[i].window_open, &app.fog_emitters[i].visible, 24)) {
                    remove_index = i;
                }
            }
            if (remove_index) |idx| {
                removeAt(FogEmitterState, app.fog_emitters, app.fog_count, idx);
                app.selection.noteRemoved(.fog, idx);
            }
        }

        if (widgets.beginSectionId(ctx, "Warps", groupTitle(&title_buf, "Warps", app.warp_count.*), .open)) {
            defer widgets.endSection(ctx);
            emptyGroup(ctx, app.warp_count.*);
            var remove_index: ?usize = null;
            var swap_index: ?usize = null;
            for (0..app.warp_count.*) |i| {
                var buf: [64]u8 = undefined;
                const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Warp {d}: {s}{s}", .{ i + 1, app.warps[i].coord_kind.label(), hiddenSuffix(app.warps[i].visible) }, 0) catch "Warp";
                switch (widgets.reorderableRow(ctx, label, &app.warps[i].window_open, &app.warps[i].visible, i, app.warp_count.*)) {
                    .none => {},
                    .up => swap_index = i - 1,
                    .down => swap_index = i,
                    .remove => remove_index = i,
                }
            }
            if (swap_index) |idx| {
                std.mem.swap(WarpState, &app.warps[idx], &app.warps[idx + 1]);
                app.selection.noteSwapped(.warp, idx, idx + 1);
            }
            if (remove_index) |idx| {
                removeAt(WarpState, app.warps, app.warp_count, idx);
                app.selection.noteRemoved(.warp, idx);
            }
        }

        if (widgets.beginSectionId(ctx, "Particle systems", groupTitle(&title_buf, "Particle systems", app.particle_count.*), .open)) {
            defer widgets.endSection(ctx);
            emptyGroup(ctx, app.particle_count.*);
            var remove_index: ?usize = null;
            for (0..app.particle_count.*) |i| {
                var buf: [64]u8 = undefined;
                const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Particles {d}: {s}{s}", .{ i + 1, app.particle_systems[i].render_mode.label(), hiddenSuffix(app.particle_systems[i].visible) }, 0) catch "Particles";
                if (widgets.selectableRemovableRow(ctx, label, &app.particle_systems[i].window_open, &app.particle_systems[i].visible, 24)) {
                    remove_index = i;
                }
            }
            if (remove_index) |idx| {
                removeAt(ParticleSystemState, app.particle_systems, app.particle_count, idx);
                app.selection.noteRemoved(.particles, idx);
            }
        }

        if (widgets.beginSectionId(ctx, "Screen shaders", groupTitle(&title_buf, "Screen shaders", app.screen_shader_count.*), .open)) {
            defer widgets.endSection(ctx);
            buildScreenShaderList(ctx, app);
        }
    }
    layout.end(ctx, title, &panels.scene);
}

fn buildScreenShaderList(ctx: *nk.nk_context, app: *const App) void {
    const shaders = app.screen_shaders;
    const count = app.screen_shader_count;
    emptyGroup(ctx, count.*);

    var remove_index: ?usize = null;
    var swap_index: ?usize = null;
    for (0..count.*) |i| {
        var buf: [64]u8 = undefined;
        const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "{d}. {s}{s}", .{
            i + 1,
            shaders[i].label(),
            if (shaders[i].enabled) "" else " (off)",
        }, 0) catch "Screen shader";

        switch (widgets.reorderableRow(ctx, label, &shaders[i].window_open, &shaders[i].enabled, i, count.*)) {
            .none => {},
            .up => swap_index = i - 1,
            .down => swap_index = i,
            .remove => remove_index = i,
        }
    }

    if (swap_index) |idx| {
        std.mem.swap(ScreenShaderState, &shaders[idx], &shaders[idx + 1]);
        formula_library.noteListChanged();
    }

    if (remove_index) |idx| {
        shaders[idx].deinit(app.allocator);
        removeAt(ScreenShaderState, shaders, count, idx);
        formula_library.noteListChanged();
    }
}

fn checkbox(ctx: *nk.nk_context, label: [:0]const u8, value: *bool) void {
    nk.nk_layout_row_dynamic(ctx, 22, 1);
    value.* = nk.nk_check_label(ctx, label.ptr, if (value.*) 1 else 0) != 0;
}

fn buildRenderWindow(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    const title = "Render";
    if (layout.begin(ctx, ws, title, .{ .fixed = ws.renderRect() })) {
        buildSimpleRenderRow(ctx, app.render_parts);

        if (widgets.beginSection(ctx, "Quality", .open)) {
            defer widgets.endSection(ctx);
            buildQualityTable(ctx, app);
        }
        if (widgets.beginSection(ctx, "Photon map", .open)) {
            defer widgets.endSection(ctx);
            buildPhotonSection(ctx, app.photon, &app.fractal.photon_map);
        }
        if (widgets.beginSection(ctx, "Monte Carlo", .open)) {
            defer widgets.endSection(ctx);
            buildMcSection(ctx, app.mc, app.mc_sample_count.*);
        }
        if (widgets.beginSection(ctx, "Empty-space accelerator", .closed)) {
            defer widgets.endSection(ctx);
            buildAccelSection(ctx, app.accel_state, &app.fractal.accel);
        }
    }
    layout.end(ctx, title, &panels.render);
}

fn buildSimpleRenderRow(ctx: *nk.nk_context, parts: *RenderParts) void {
    nk.nk_layout_row_template_begin(ctx, 22);
    nk.nk_layout_row_template_push_dynamic(ctx);
    nk.nk_layout_row_template_push_static(ctx, 120);
    nk.nk_layout_row_template_end(ctx);
    parts.enabled = nk.nk_check_label(ctx, "Simple render", if (parts.enabled) 1 else 0) != 0;
    if (nk.nk_button_label(ctx, "Parts & approx...") != 0) {
        parts.window_open = true;
    }
    const approx_count = parts.approx.activeCount();
    if (approx_count > 0) {
        var buf: [48]u8 = undefined;
        const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "Approximations on: {d}", .{approx_count}, 0) catch "Approximations on";
        nk.nk_layout_row_dynamic(ctx, 16, 1);
        nk.nk_label_colored(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT), nk.nk_rgb(120, 180, 220));
    }
}

fn buildQualityTable(ctx: *nk.nk_context, app: *const App) void {
    const rs = app.render_settings;
    widgets.sliderPairHeader(ctx, "Preview", "Final render");
    widgets.sliderPair(ctx, "Max march steps", true, .{ .value = app.max_steps, .range = app.max_steps_range }, .{ .value = &rs.max_steps, .range = &rs.max_steps_range });
    widgets.sliderPair(ctx, "Max distance", false, .{ .value = app.max_dist, .range = app.max_dist_range }, .{ .value = &rs.max_dist, .range = &rs.max_dist_range });
    widgets.sliderPair(ctx, "Reflection bounces", true, .{ .value = app.max_reflection_bounces, .range = app.max_reflection_bounces_range }, .{ .value = &rs.max_reflection_bounces, .range = &rs.max_reflection_bounces_range });
    widgets.sliderPair(ctx, "Render scale", false, .{ .value = app.preview_quality, .range = app.preview_quality_range }, null);
    widgets.sliderPair(ctx, "Fog samples", true, null, .{ .value = &rs.fog_samples, .range = &rs.fog_samples_range });

    if (widgets.beginSubsection(ctx, "precision", "Ray march precision", .closed)) {
        defer widgets.endSection(ctx);
        const p = app.precision;
        const f = &rs.precision;
        widgets.sliderPair(ctx, "Hit epsilon coefficient", false, .{ .value = &p.epsilon_coefficient, .range = &p.epsilon_coefficient_range }, .{ .value = &f.epsilon_coefficient, .range = &f.epsilon_coefficient_range });
        widgets.sliderPair(ctx, "Hit epsilon floor", false, .{ .value = &p.epsilon_floor, .range = &p.epsilon_floor_range }, .{ .value = &f.epsilon_floor, .range = &f.epsilon_floor_range });
        widgets.sliderPair(ctx, "HQ footprint budget", false, .{ .value = &p.hq_footprint_budget_px, .range = &p.hq_footprint_budget_px_range }, .{ .value = &f.hq_footprint_budget_px, .range = &f.hq_footprint_budget_px_range });
        widgets.sliderPair(ctx, "Bisection refine steps", true, .{ .value = &p.refine_fast, .range = &p.refine_fast_range }, .{ .value = &f.refine_fast, .range = &f.refine_fast_range });
        widgets.sliderPair(ctx, "Bisection refine steps (hq)", true, .{ .value = &p.refine_hq, .range = &p.refine_hq_range }, .{ .value = &f.refine_hq, .range = &f.refine_hq_range });
    }
}

fn buildPhotonSection(ctx: *nk.nk_context, photon: *PhotonSettings, map: *const photons_gpu.PhotonMap) void {
    checkbox(ctx, "Enabled", &photon.enabled);
    if (!photon.enabled) return;

    if (map.valid) {
        const stats = map.last_stats;
        if (stats.dropped_no_bucket > 0) {
            var drop_buf: [216]u8 = undefined;
            const drop_line: [:0]const u8 = std.fmt.bufPrintSentinel(
                &drop_buf,
                "{d} deposits found no free bucket and were dropped -- the scene is dimmer than it should be. Raise Grid size.",
                .{stats.dropped_no_bucket},
                0,
            ) catch "Deposits dropped";
            widgets.hint(ctx, drop_line, widgets.warn);
        }
        if (stats.dropped_no_pool > 0) {
            var drop_buf: [216]u8 = undefined;
            const drop_line: [:0]const u8 = std.fmt.bufPrintSentinel(
                &drop_buf,
                "{d} cells got no room in the pool and are unlit. Raise Grid size, or lower Photon paths.",
                .{stats.dropped_no_pool},
                0,
            ) catch "Cells dropped";
            widgets.hint(ctx, drop_line, widgets.warn);
        }
    }

    widgets.sliderInt(ctx, "Scatter bounces", &photon.bounces, &photon.bounces_range);
    widgets.sliderInt(ctx, "Photon paths", &photon.paths, &photon.paths_range);
    widgets.sliderFloat(ctx, "Gather radius", &photon.radius, &photon.radius_range);
    widgets.sliderFloat(ctx, "Photon brightness", &photon.intensity, &photon.intensity_range);

    checkbox(ctx, "Aim photons at geometry", &photon.aim);
    checkbox(ctx, "Retrace per MC Render sample", &photon.refine_per_sample);
    widgets.hint(ctx, if (photon.refine_per_sample)
        "Every accumulated sample gets its own photons"
    else
        "One trace stands for the whole accumulation", widgets.dim);

    if (photon.refine_per_sample) {
        checkbox(ctx, "Progressive radius", &photon.progressive);
        if (photon.progressive) {
            widgets.sliderFloat(ctx, "Progressive start (x)", &photon.progressive_start, &photon.progressive_start_range);
        }
    }

    if (widgets.beginSubsection(ctx, "photon advanced", "Advanced", .closed)) {
        defer widgets.endSection(ctx);
        widgets.sliderFloat(ctx, "Bounce light radius (x)", &photon.bounce_radius_scale, &photon.bounce_radius_scale_range);
        widgets.sliderFloat(ctx, "Fog cell scale", &photon.volume_scale, &photon.volume_scale_range);
        widgets.sliderFloat(ctx, "Dispersion softness", &photon.dispersion_softness, &photon.dispersion_softness_range);
        widgets.sliderInt(ctx, "Grid size (power of two)", &photon.grid_log2, &photon.grid_log2_range);
        widgets.sliderInt(ctx, "Retrace delay (ms)", &photon.debounce_ms, &photon.debounce_ms_range);
    }

    if (widgets.beginSubsection(ctx, "photon details", "Details", .closed)) {
        defer widgets.endSection(ctx);
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
        widgets.hint(ctx, status, widgets.dim);

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
            widgets.hint(ctx, pool_line, widgets.dim);
        }
    }
}

fn buildMcSection(ctx: *nk.nk_context, mc: *McRenderState, mc_sample_count: u32) void {
    checkbox(ctx, "MC Render", &mc.enabled);
    if (mc.enabled) {
        widgets.sliderInt(ctx, "Live preview samples", &mc.max_samples, &mc.max_samples_range);
        widgets.sliderInt(ctx, "Export samples", &mc.export_samples, &mc.export_samples_range);

        checkbox(ctx, "Adaptive sampling", &mc.adaptive);
        if (mc.adaptive) {
            widgets.sliderFloat(ctx, "Noise threshold", &mc.adaptive_threshold, &mc.adaptive_threshold_range);
            widgets.sliderInt(ctx, "Minimum samples", &mc.adaptive_min_samples, &mc.adaptive_min_samples_range);
        }

        var sample_buf: [32]u8 = undefined;
        const sample_label: [:0]const u8 = std.fmt.bufPrintSentinel(&sample_buf, "Samples: {d} / {d}", .{ mc_sample_count, @as(u32, @intFromFloat(@max(mc.max_samples, 1))) }, 0) catch "Samples";
        nk.nk_layout_row_dynamic(ctx, 16, 1);
        nk.nk_label_colored(ctx, sample_label.ptr, @intCast(nk.NK_TEXT_LEFT), widgets.dim);
    }

    widgets.separator(ctx);
    checkbox(ctx, "Denoise exports (CPU)", &mc.denoise);
    checkbox(ctx, "Denoise preview (CPU)", &mc.denoise_preview);
    if (mc.denoise or mc.denoise_preview) {
        widgets.sliderFloat(ctx, "Denoise strength", &mc.denoise_strength, &mc.denoise_strength_range);
        if (!oidn.available()) {
            var reason_buf: [128]u8 = undefined;
            const reason: [:0]const u8 = std.fmt.bufPrintSentinel(&reason_buf, "Denoiser unavailable: {s}", .{oidn.unavailableReason()}, 0) catch "Denoiser unavailable";
            widgets.hint(ctx, reason, widgets.warn);
        }
    }
}

fn buildAccelSection(ctx: *nk.nk_context, state: *AccelState, grid: *const accel_gpu.AccelGrid) void {
    checkbox(ctx, "Enabled", &state.enabled);
    if (!state.enabled) return;

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
    widgets.hint(ctx, status, widgets.dim);

    widgets.sliderInt(ctx, "Grid resolution", &state.resolution, &state.resolution_range);
    widgets.sliderInt(ctx, "Cascades", &state.levels, &state.levels_range);
    widgets.sliderFloat(ctx, "Skip safety margin", &state.safety, &state.safety_range);
    widgets.sliderInt(ctx, "Rebuild delay (ms)", &state.debounce_ms, &state.debounce_ms_range);
}

fn buildPlaySection(ctx: *nk.nk_context, play: *PlayState, camera: *FreeCamera) void {
    nk.nk_layout_row_dynamic(ctx, 22, 1);
    const play_now: nk.nk_bool = if (play.enabled) 1 else 0;
    play.enabled = nk.nk_check_label(ctx, "Play mode", play_now) != 0;
    if (play.enabled) {
        camera.mode_2d = false;
        // var buf: [96]u8 = undefined;
        // const line: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "{s}{s}", .{
        //     play.stateLabel(),
        //     if (play.captured) "  (Esc frees the mouse)" else "  (click the view to play)",
        // }, 0) catch "";
        // nk.nk_layout_row_dynamic(ctx, 16, 1);
        // nk.nk_label(ctx, line.ptr, @intCast(nk.NK_TEXT_LEFT));
        // nk.nk_layout_row_dynamic(ctx, 72, 1);
    } else if (play.status.len > 0) {
        nk.nk_layout_row_dynamic(ctx, 30, 1);
        nk.nk_label_colored_wrap(ctx, play.status.ptr, nk.nk_rgb(220, 120, 100));
    }
}

fn buildCameraWindow(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    const title = "Camera";
    const camera = app.camera;
    if (layout.begin(ctx, ws, title, .{ .fixed = ws.cameraRect() })) {
        buildPlaySection(ctx, app.play, camera);

        checkbox(ctx, "2D mode", &camera.mode_2d);
        if (camera.mode_2d) {
            app.play.enabled = false;
            widgets.hint(ctx, "Renders the flat slice the camera cuts through the fractal. F zooms in, R zooms out.", widgets.dim);

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

        checkbox(ctx, "Depth of field", &camera.dof_enabled);
        if (camera.dof_enabled) {
            widgets.sliderFloat(ctx, "Focus distance", &camera.focus_distance, &camera.focus_distance_range);
            widgets.sliderFloat(ctx, "Focus range", &camera.focus_range, &camera.focus_range_range);
            widgets.sliderFloat(ctx, "Aperture", &camera.aperture, &camera.aperture_range);
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
    layout.end(ctx, title, &panels.camera);
}

fn buildOutputWindow(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    const title = "Output";
    var action: ?Action = null;
    if (layout.begin(ctx, ws, title, .{ .fixed = ws.outputRect() })) {
        widgets.sectionLabel(ctx, "Resolution");
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Width", export_image.min_export_dim, app.export_width, export_image.max_export_dim, 16, 4);
        nk.nk_layout_row_dynamic(ctx, 24, 1);
        _ = nk.nk_property_int(ctx, "Height", export_image.min_export_dim, app.export_height, export_image.max_export_dim, 16, 4);
        nk.nk_layout_row_dynamic(ctx, 22, 4);
        if (nk.nk_button_label(ctx, "25%") != 0) export_image.scaleExportResolution(app.export_width, app.export_height, 0.25);
        if (nk.nk_button_label(ctx, "50%") != 0) export_image.scaleExportResolution(app.export_width, app.export_height, 0.5);
        if (nk.nk_button_label(ctx, "150%") != 0) export_image.scaleExportResolution(app.export_width, app.export_height, 1.5);
        if (nk.nk_button_label(ctx, "200%") != 0) export_image.scaleExportResolution(app.export_width, app.export_height, 2.0);

        widgets.separator(ctx);
        nk.nk_layout_row_template_begin(ctx, 22);
        nk.nk_layout_row_template_push_dynamic(ctx);
        nk.nk_layout_row_template_push_static(ctx, 80);
        nk.nk_layout_row_template_end(ctx);
        app.stereo.enabled = nk.nk_check_label(ctx, "Render as stereoscopic",if (app.stereo.enabled) 1 else 0) != 0;
        if (nk.nk_button_label(ctx, "Settings...") != 0) app.stereo.settings_open = true;

        widgets.separator(ctx);
        nk.nk_layout_row_dynamic(ctx, 26, 1);
        if (nk.nk_button_label(ctx, "Export image") != 0) action = .export_image;
        nk.nk_layout_row_dynamic(ctx, 22, 2);
        if (nk.nk_button_label(ctx, "Animation...") != 0) action = .render_animation;
        if (nk.nk_button_label(ctx, "Mesh...") != 0) action = .export_mesh;

        if (app.export_status.len > 0) widgets.hint(ctx, app.export_status.*, widgets.dim);
    }
    layout.end(ctx, title, &panels.output);
    if (action) |a| runAction(app, a);
}

fn buildDialogs(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    editor_windows.buildStereoSettingsWindow(ctx, ws, app.stereo);
    editor_windows.buildRenderPartsWindow(ctx, ws, app.render_parts, app.fractal.parts.compiling());
    editor_windows.buildAnimRenderWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, app.timeline, app.anim_render, app.instances[0..app.instance_count.*], app.instance_count.*, app.lights[0..app.light_count.*], app.light_count.*, app.fog_emitters[0..app.fog_count.*], app.fog_count.*, app.warps[0..app.warp_count.*], app.warp_count.*, app.screen_shaders[0..app.screen_shader_count.*], app.particle_systems[0..app.particle_count.*], app.camera.*, app.render_settings.*, app.photon.*, app.stereo.*, app.mc.*, app.progress_overlay);
    editor_windows.buildMeshExportWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, app.mesh_export, .{ .instances = app.instances[0..app.instance_count.*], .warps = app.warps[0..app.warp_count.*], .camera = app.camera.* }, app.progress_overlay);
}

fn buildEditors(ctx: *nk.nk_context, app: *const App, ws: layout.Workspace) void {
    const instances = app.instances[0..app.instance_count.*];
    for (instances, 0..) |*inst, i| {
        if (inst.window_open) {
            editor_windows.buildFractalEditorWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, inst, i, instances, instances.len, app.library_panel);
        }
        for (0..inst.mixin_count) |j| {
            if (inst.mixins[j].window_open) {
                editor_windows.buildMixinEditorWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, &inst.mixins[j], i, j, instances, instances.len, app.library_panel);
            }
        }
    }
    for (app.lights[0..app.light_count.*], 0..) |*light, i| {
        if (light.window_open) editor_windows.buildLightEditorWindow(ctx, ws, light, i);
    }
    for (app.fog_emitters[0..app.fog_count.*], 0..) |*fog, i| {
        if (fog.window_open) editor_windows.buildFogEmitterEditorWindow(ctx, ws, fog, i);
    }
    for (app.warps[0..app.warp_count.*], 0..) |*w, i| {
        if (w.window_open) editor_windows.buildWarpEditorWindow(ctx, ws, w, i);
    }
    for (app.particle_systems[0..app.particle_count.*], 0..) |*ps, i| {
        if (ps.window_open) editor_windows.buildParticleSystemEditorWindow(ctx, ws, ps, i, app.fractal.particles.runtime[i].steps);
    }
    for (app.screen_shaders[0..app.screen_shader_count.*], 0..) |*shader, i| {
        if (shader.window_open) editor_windows.buildScreenShaderEditorWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, shader, i, app.screen_library_panel);
    }
    if (app.sky.window_open) {
        editor_windows.buildSkyEditorWindow(ctx, ws, app.window, app.gpu_ctx, app.fractal, app.allocator, app.sky);
    }
    editor_windows.buildFormulaLibraryWindow(ctx, ws, app.gpu_ctx, app.fractal, app.allocator, app.library_panel, instances, instances.len, "Formula Library");
    editor_windows.buildFormulaLibraryWindow(ctx, ws, app.gpu_ctx, app.fractal, app.allocator, app.screen_library_panel, instances, instances.len, "Screen Shader Library");
}
