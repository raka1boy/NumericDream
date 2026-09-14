const std = @import("std");
const sdl = @import("bindings/sdl3.zig").c;
const wgpu = @import("bindings/webgpu.zig").c;

const webgpu_context = @import("gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const max_instances = fractal_gpu.max_instances;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const NuklearBackend = @import("ui/nuklear_backend.zig").NuklearBackend;
const gizmo_gpu = @import("gpu/gizmo_renderer.zig");
const GizmoRenderer = gizmo_gpu.GizmoRenderer;
const GizmoVertex = gizmo_gpu.GizmoVertex;
const gizmo = @import("app/gizmo.zig");
const OutlineRenderer = @import("gpu/outline_renderer.zig").OutlineRenderer;
const selection_mod = @import("app/selection.zig");

const camera_mod = @import("app/camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const SliderRange = @import("app/slider_range.zig").SliderRange;
const scene_state = @import("app/scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const warp_mod = @import("app/warp.zig");
const WarpState = warp_mod.WarpState;
const sky_mod = @import("app/sky.zig");
const SkyState = sky_mod.SkyState;
const editor_windows = @import("ui/editor_windows.zig");
const timeline_widget = @import("ui/timeline_widget.zig");
const formula_library = @import("app/formula_library.zig");
const StereoState = @import("app/stereo.zig").StereoState;
const RenderParts = @import("app/render_parts.zig").RenderParts;
const render_precision = @import("app/render_precision.zig");
const MarchPrecision = render_precision.MarchPrecision;
const RenderSettingsState = render_precision.RenderSettingsState;
const ProgressOverlay = @import("gpu/progress_overlay.zig").ProgressOverlay;
const export_image = @import("app/export_image.zig");
const McRenderState = @import("app/mc_render.zig").McRenderState;
const animation = @import("app/animation.zig");
const perf_probe = @import("app/perf_probe.zig");
const accel_gpu = @import("gpu/accel.zig");
const accel_policy = @import("app/accel_state.zig");
const AccelState = accel_policy.AccelState;
const photon_policy = @import("app/photon_state.zig");
const PhotonSettings = photon_policy.PhotonSettings;
const PhotonPolicy = photon_policy.PhotonPolicy;
const photons_gpu = @import("gpu/photons.zig");

const allocator = std.heap.page_allocator;

const mouse_look_sensitivity: f32 = 0.005;
const scroll_zoom_speed: f32 = 0.3;

fn anyMovementKeyDown(keys: [*c]const bool) bool {
    return keys[sdl.SDL_SCANCODE_W] or keys[sdl.SDL_SCANCODE_A] or
        keys[sdl.SDL_SCANCODE_S] or keys[sdl.SDL_SCANCODE_D] or
        keys[sdl.SDL_SCANCODE_LEFT] or keys[sdl.SDL_SCANCODE_RIGHT] or
        keys[sdl.SDL_SCANCODE_UP] or keys[sdl.SDL_SCANCODE_DOWN] or
        keys[sdl.SDL_SCANCODE_Q] or keys[sdl.SDL_SCANCODE_E] or
        keys[sdl.SDL_SCANCODE_F] or keys[sdl.SDL_SCANCODE_R];
}

pub fn main() !void {
    webgpu_context.installWgpuLogging();

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.log.err("SDL_Init failed: {s}", .{sdl.SDL_GetError()});
        return error.SdlInitFailed;
    }
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "Numeric Dreams",
        1280,
        720,
        sdl.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.log.err("SDL_CreateWindow failed: {s}", .{sdl.SDL_GetError()});
        return error.SdlCreateWindowFailed;
    };
    defer sdl.SDL_DestroyWindow(window);

    //off by default in sdl3
    _ = sdl.SDL_StartTextInput(window);

    std.debug.print("[stage] Context.init: begin\n", .{});
    var gpu_ctx = try Context.init(window);
    defer gpu_ctx.deinit();
    std.debug.print("[stage] Context.init: done\n", .{});
    webgpu_context.printAdapterInfo(&gpu_ctx);

    std.debug.print("[stage] FractalRenderer.init: begin\n", .{});
    var fractal = FractalRenderer.init(&gpu_ctx, allocator) catch |err| {
        std.log.err("shader error: {s}", .{webgpu_context.g_error_sink.message()});
        return err;
    };
    defer fractal.deinit();
    std.debug.print("[stage] FractalRenderer.init: done\n", .{});

    std.debug.print("[stage] NuklearBackend.init: begin\n", .{});
    var ui = try NuklearBackend.init(&gpu_ctx);
    defer ui.deinit();
    std.debug.print("[stage] NuklearBackend.init: done\n", .{});

    std.debug.print("[stage] GizmoRenderer.init: begin\n", .{});
    var gizmo_renderer = try GizmoRenderer.init(&gpu_ctx);
    defer gizmo_renderer.deinit();
    std.debug.print("[stage] GizmoRenderer.init: done\n", .{});

    std.debug.print("[stage] OutlineRenderer.init: begin\n", .{});
    var outline_renderer = try OutlineRenderer.init(&gpu_ctx);
    defer outline_renderer.deinit();
    std.debug.print("[stage] OutlineRenderer.init: done\n", .{});

    std.debug.print("[stage] ProgressOverlay.init: begin\n", .{});
    var progress_overlay = try ProgressOverlay.init(&gpu_ctx);
    defer progress_overlay.deinit();
    std.debug.print("[stage] ProgressOverlay.init: done\n", .{});

    std.debug.print("[stage] entering main loop\n", .{});

    var camera = FreeCamera.initial();
    var max_steps: f32 = 128;
    var max_steps_range: SliderRange = .{ .min = 32, .max = 512 };
    var max_dist: f32 = 24.0;
    var max_dist_range: SliderRange = .{ .min = 4, .max = 64 };
    var preview_quality: f32 = 1.0;
    var preview_quality_range: SliderRange = .{ .min = 0.1, .max = 1.0 };
    var render_parts = RenderParts{};
    var max_reflection_bounces: f32 = 1;
    var max_reflection_bounces_range: SliderRange = .{ .min = 0, .max = 8 };
    var precision = MarchPrecision{};
    var render_settings = RenderSettingsState{};
    var export_width: i32 = 2560;
    var export_height: i32 = 1440;
    var export_status_buf: [scene_state.status_buf_len]u8 = undefined;
    var export_status: [:0]const u8 = "";
    var scene_status_buf: [scene_state.status_buf_len]u8 = undefined;
    var scene_status: [:0]const u8 = "";
    var dragging = false;

    var selection = selection_mod.State{};
    var press_travel: f32 = 0;
    var pending_click: ?[2]f32 = null;
    var pending_deselect = false;
    const drag_travel_px: f32 = 4.0;
    var redraw_pending = false;

    var instances: [max_instances]FractalInstanceState = undefined;
    instances[0] = scene_state.newInstance();
    var instance_count: usize = 1;

    var lights: [max_lights]LightState = undefined;
    lights[0] = scene_state.newLight();
    var light_count: usize = 1;

    var fog_emitters: [max_fog_emitters]FogEmitterState = undefined;
    var fog_count: usize = 0;

    var warps: [max_warps]WarpState = undefined;
    var warp_count: usize = 0;

    var sky = SkyState{};

    var library_panel = formula_library.PanelState.init();
    var stereo = StereoState{};
    var mc = McRenderState{};
    var timeline = animation.TimelineState{};
    var anim_render = animation.AnimRenderState{};
    var accel_state = AccelState{};
    var photon_settings = PhotonSettings{};
    var photon_state = PhotonPolicy{};

    var mc_sample_count: u32 = 0;
    var last_render_uniforms = std.mem.zeroes(fractal_gpu.Uniforms);
    var has_last_uniforms = false;

    const start_ticks = sdl.SDL_GetTicks();
    var last_ticks = start_ticks;

    var running = true;
    var first_frame = true;
    var perf = perf_probe.Probe.init();
    while (running) {
        perf.maybeReport(gpu_ctx.reconfigure_count, gpu_ctx.last_acquire_status);

        if (webgpu_context.g_device_lost.load(.acquire)) {
            std.log.err("GPU device was lost -- exiting. This usually means a shader took long enough to compile that the driver decided the GPU had hung and reset it.", .{});
            scene_state.drainPendingCompile(&fractal, allocator);
            running = false;
            continue;
        }

        //bg thread that compiles takes prio now, main thread must never call into wgpu when that happends risking corrupting state.
        //keep polling window events so that os doesn't flag app as not responding
        if (fractal.isCompiling()) {
            var event: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&event)) {
                if (event.type == sdl.SDL_EVENT_QUIT) running = false;
            }
            scene_state.pollPendingCompile(&fractal, allocator);
            sdl.SDL_Delay(5);
            continue;
        }

        //while inputs don't change, dont render stuff to prevent useless renders, unless user is in mc render mode
        //in which case render will occur until target iters will be hit.
        const keys_for_wait = sdl.SDL_GetKeyboardState(null);

        const mc_active = mc.enabled and !camera.mode_2d and !render_parts.geometryOnly();
        const mc_converging = mc_active and mc_sample_count < @as(u32, @intFromFloat(@max(mc.max_samples, 1)));
        const continuous_input = (!ui.isHoveringUi() and (dragging or anyMovementKeyDown(keys_for_wait))) or mc_converging or timeline.playing or redraw_pending;
        redraw_pending = false;

        var event: sdl.SDL_Event = undefined;
        var have_event = if (continuous_input)
            sdl.SDL_WaitEventTimeout(&event, 16)
        else
            sdl.SDL_WaitEvent(&event);
        const got_any_event = have_event;
        perf.countIteration(!continuous_input);

        const camera_pos_before = camera.position;

        ui.beginInput();
        while (have_event) {
            perf.countEvent(event.type);
            ui.handleSdlEvent(&event);
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => running = false,
                sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    gpu_ctx.resize(@intCast(event.window.data1), @intCast(event.window.data2));
                },
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    if (event.button.button == @as(u8, sdl.SDL_BUTTON_LEFT) and !ui.isHoveringUi()) {
                        dragging = true;
                        press_travel = 0;
                    }
                },
                sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    if (event.button.button == @as(u8, sdl.SDL_BUTTON_LEFT)) {
                        if (dragging and press_travel < drag_travel_px) {
                            pending_click = .{ event.button.x, event.button.y };
                        }
                        dragging = false;
                    }
                },
                sdl.SDL_EVENT_MOUSE_MOTION => {
                    if (dragging) {
                        press_travel += @abs(event.motion.xrel) + @abs(event.motion.yrel);
                        camera.turnYaw(event.motion.xrel * mouse_look_sensitivity);
                        camera.turnPitch(-event.motion.yrel * mouse_look_sensitivity);
                    }
                },
                sdl.SDL_EVENT_MOUSE_WHEEL => {
                    if (!ui.isHoveringUi()) {
                        const forward = camera.basis().forward;
                        camera.position = camera.position.add(forward.scale(event.wheel.y * scroll_zoom_speed));
                    }
                },
                sdl.SDL_EVENT_KEY_DOWN => {
                    if (!ui.isHoveringUi() and !event.key.repeat) {
                        if (event.key.scancode == sdl.SDL_SCANCODE_Z) camera.slowDown();
                        if (event.key.scancode == sdl.SDL_SCANCODE_C) camera.speedUp();
                    }
                    if (!event.key.repeat and event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                        pending_deselect = true;
                    }
                },
                else => {},
            }
            have_event = sdl.SDL_PollEvent(&event);
        }
        ui.endInput();

        const should_render = continuous_input or got_any_event or first_frame;
        first_frame = false;
        if (!should_render) {
            continue;
        }

        const now_ticks = sdl.SDL_GetTicks();
        const dt: f32 = @min(@as(f32, @floatFromInt(now_ticks -| last_ticks)) / 1000.0, 1.0 / 30.0);
        last_ticks = now_ticks;

        if (!ui.isHoveringUi()) {
            const keys = sdl.SDL_GetKeyboardState(null);
            camera.tick(keys, dt);
        }
        warp_mod.transportCamera(&camera, camera_pos_before, warps[0..warp_count]);
        animation.tickPlayback(&timeline, dt);

        var win_w: c_int = 0;
        var win_h: c_int = 0;
        _ = sdl.SDL_GetWindowSizeInPixels(window, &win_w, &win_h);
        const width_f: f32 = @floatFromInt(win_w);
        const height_f: f32 = @floatFromInt(win_h);

        gpu_ctx.resize(@intCast(win_w), @intCast(win_h));

        timeline_widget.build(&ui.ctx, &timeline, instances[0..instance_count], instance_count, lights[0..light_count], light_count, fog_emitters[0..fog_count], fog_count, warps[0..warp_count], warp_count, camera, width_f, height_f);

        if (timeline.keyframe_count > 0 and timeline.dirty) {
            const snap = animation.evaluate(&timeline, timeline.playhead);
            animation.applySnapshot(&snap, instances[0..instance_count], instance_count, lights[0..light_count], light_count, fog_emitters[0..fog_count], fog_count, warps[0..warp_count], warp_count, &camera);
            timeline.dirty = false;
        }

        editor_windows.buildFractalsListUi(&ui.ctx, &gpu_ctx, &fractal, allocator, &instances, &instance_count, &render_parts, &max_steps, &max_steps_range, &max_dist, &max_dist_range, &preview_quality, &preview_quality_range, &max_reflection_bounces, &max_reflection_bounces_range, &photon_settings, &precision, &render_settings, &lights, &light_count, &fog_emitters, &fog_count, &warps, &warp_count, &sky, &camera, width_f, height_f, window, &export_width, &export_height, &export_status_buf, &export_status, &scene_status_buf, &scene_status, &stereo, &mc, mc_sample_count, &progress_overlay, &timeline, &anim_render, &accel_state, &selection);
        if (export_image.quit_requested) running = false;
        editor_windows.buildStereoSettingsWindow(&ui.ctx, &stereo);
        editor_windows.buildRenderPartsWindow(&ui.ctx, &render_parts);
        editor_windows.buildRenderSettingsWindow(&ui.ctx, &render_settings);
        editor_windows.buildAnimRenderWindow(&ui.ctx, window, &gpu_ctx, &fractal, allocator, &timeline, &anim_render, instances[0..instance_count], instance_count, lights[0..light_count], light_count, fog_emitters[0..fog_count], fog_count, warps[0..warp_count], warp_count, camera, render_settings, photon_settings, stereo, mc, &progress_overlay);
        for (0..instance_count) |i| {
            if (instances[i].window_open) {
                editor_windows.buildFractalEditorWindow(&ui.ctx, window, &gpu_ctx, &fractal, allocator, &instances[i], i, instances[0..instance_count], instance_count, &library_panel);
            }
            for (0..instances[i].mixin_count) |j| {
                if (instances[i].mixins[j].window_open) {
                    editor_windows.buildMixinEditorWindow(&ui.ctx, window, &gpu_ctx, &fractal, allocator, &instances[i].mixins[j], i, j, instances[0..instance_count], instance_count, &library_panel);
                }
            }
        }
        for (0..light_count) |i| {
            if (lights[i].window_open) {
                editor_windows.buildLightEditorWindow(&ui.ctx, &lights[i], i);
            }
        }
        for (0..fog_count) |i| {
            if (fog_emitters[i].window_open) {
                editor_windows.buildFogEmitterEditorWindow(&ui.ctx, &fog_emitters[i], i);
            }
        }
        for (0..warp_count) |i| {
            if (warps[i].window_open) {
                editor_windows.buildWarpEditorWindow(&ui.ctx, &warps[i], i);
            }
        }
        if (sky.window_open) {
            editor_windows.buildSkyEditorWindow(&ui.ctx, window, &gpu_ctx, &fractal, allocator, &sky);
        }
        editor_windows.buildFormulaLibraryWindow(&ui.ctx, &gpu_ctx, &fractal, allocator, &library_panel, instances[0..instance_count], instance_count);

        const objects = selection_mod.Objects{
            .instances = instances[0..instance_count],
            .lights = lights[0..light_count],
            .fog_emitters = fog_emitters[0..fog_count],
            .warps = warps[0..warp_count],
        };
        selection.syncWithWindows(objects);

        if (fractal.isCompiling()) {
            ui.discardFrame();
            continue;
        }

        const warps_active = warp_count > 0;
        if (warps_active != fractal.warps_enabled) {
            fractal.warps_enabled = warps_active;
            scene_state.rebuildAllAsync(&gpu_ctx, &fractal, allocator, instances[0..instance_count], instance_count);
            ui.discardFrame();
            continue;
        }

        const cam = camera.basis();
        const elapsed_ms = sdl.SDL_GetTicks() - start_ticks;

        const render_w: u32 = @intFromFloat(@max(width_f * preview_quality, 1.0));
        const render_h: u32 = @intFromFloat(@max(height_f * preview_quality, 1.0));
        fractal.ensureOffscreenSize(&gpu_ctx, render_w, render_h);

        var uniforms = export_image.buildUniforms(instances[0..instance_count], lights[0..light_count], fog_emitters[0..fog_count], warps[0..warp_count], camera, cam, max_steps, max_dist, max_reflection_bounces, photon_settings, precision, mc, 1.0, render_w, render_h);
        uniforms.high_quality = 0;
        uniforms.time = @as(f32, @floatFromInt(elapsed_ms)) / 1000.0;

        fractal.sky_settings = sky;
        fractal.stampSkyUniforms(&uniforms);

        fractal.accel_enabled = accel_state.enabled;
        fractal.accel_safety = accel_state.safety;
        const accel_wanted = accel_state.enabled and !camera.mode_2d;
        if (accel_wanted) {
            const want_res = accel_gpu.clampResolution(@intFromFloat(@max(accel_state.resolution, 1)));
            const want_levels: u32 = @intFromFloat(std.math.clamp(accel_state.levels, 1, @as(f32, @floatFromInt(accel_gpu.max_cascades))));
            if (want_res != fractal.accel.resolution or want_levels != fractal.accel.levels) {
                _ = fractal.accel.ensureSize(&gpu_ctx, want_res, want_levels);
            }
        }
        const accel_decision = accel_policy.update(
            &accel_state,
            &fractal.accel,
            accel_wanted,
            now_ticks,
            accel_policy.sceneHash(uniforms),
            uniforms.camera_pos,
            accel_gpu.recenterDistance(uniforms.max_dist),
        );
        if (accel_decision == .rebuild) {
            if (fractal.buildAccel(&gpu_ctx, uniforms)) {
                accel_policy.noteBuilt(&accel_state, &fractal.accel);
            } else |err| {
                std.debug.print("[accel] build failed: {s} -- rendering without it\n", .{@errorName(err)});
                accel_policy.noteFailed(&accel_state, now_ticks);
            }
        }
        fractal.stampAccelUniforms(&uniforms);

        fractal.photon_settings = photon_settings;
        const photon_wanted = photon_settings.enabled and !camera.mode_2d and !render_parts.geometryOnly();
        if (photon_wanted) {
            const want_grid = photon_settings.gridLog2();
            if (want_grid != fractal.photon_map.grid_log2) {
                _ = fractal.photon_map.ensureSize(&gpu_ctx, want_grid);
            }
        }
        fractal.stampPhotonUniforms(&uniforms);

        var diff_uniforms = uniforms;
        diff_uniforms.time = 0;
        diff_uniforms.mc_sample = 0;
        diff_uniforms.accel_enabled = 0;
        diff_uniforms.accel_levels = 0;
        diff_uniforms.accel_res = 0;
        diff_uniforms.accel_safety = 0;
        diff_uniforms.accel_params = @splat(.{ 0, 0, 0, 0 });
        diff_uniforms.photon_enabled = 0;
        diff_uniforms.debug_parts = render_parts.maskUniform();
        const scene_changed = !has_last_uniforms or !std.mem.eql(u8, std.mem.asBytes(&diff_uniforms), std.mem.asBytes(&last_render_uniforms));
        last_render_uniforms = diff_uniforms;
        has_last_uniforms = true;

        if (scene_changed) selection.mask_valid = false;

        var load_existing = false;
        var blend_constant: f32 = 1.0;
        if (mc_active) {
            if (scene_changed) mc_sample_count = 0;
            const target: u32 = @intFromFloat(@max(mc.max_samples, 1));
            if (mc_sample_count < target) mc_sample_count += 1;
            load_existing = mc_sample_count > 1;
            blend_constant = 1.0 / @as(f32, @floatFromInt(mc_sample_count));
            uniforms.mc_sample = @floatFromInt(mc_sample_count - 1);
        } else {
            mc_sample_count = 0;
        }

        const photon_decision = photon_policy.update(
            &photon_state,
            &fractal.photon_map,
            photon_settings,
            photon_wanted,
            now_ticks,
            photon_policy.sceneHash(uniforms, photon_settings),
            uniforms.camera_pos,
            accel_gpu.recenterDistance(uniforms.max_dist),
            uniforms.mc_sample,
        );
        if (photon_decision == .retrace) {
            if (fractal.tracePhotons(&gpu_ctx, uniforms, photon_state.seed)) {
                photon_policy.noteTraced(&photon_state, &fractal.photon_map, uniforms.mc_sample);
            } else |err| {
                std.debug.print("[photons] trace failed: {s} -- rendering with direct light only\n", .{@errorName(err)});
                photon_policy.noteFailed(&photon_state, now_ticks);
            }
            fractal.stampPhotonUniforms(&uniforms);
        }

        if (pending_deselect) {
            selection.select(objects, null);
            pending_deselect = false;
            redraw_pending = true;
        }
        if (pending_click) |click| {
            pending_click = null;
            redraw_pending = true;
            if (!camera.mode_2d) {
                var logical_w: c_int = 0;
                var logical_h: c_int = 0;
                _ = sdl.SDL_GetWindowSize(window, &logical_w, &logical_h);
                const px = click[0] / @max(@as(f32, @floatFromInt(logical_w)), 1.0) * @as(f32, @floatFromInt(render_w));
                const py = click[1] / @max(@as(f32, @floatFromInt(logical_h)), 1.0) * @as(f32, @floatFromInt(render_h));
                const cx: u32 = @intFromFloat(std.math.clamp(px, 0, @as(f32, @floatFromInt(render_w - 1))));
                const cy: u32 = @intFromFloat(std.math.clamp(py, 0, @as(f32, @floatFromInt(render_h - 1))));
                if (fractal.pickObject(&gpu_ctx, uniforms, cx, cy)) |id| {
                    selection.select(objects, selection_mod.decodeId(id));
                } else |err| {
                    std.debug.print("[select] pick failed: {s} -- selection unchanged\n", .{@errorName(err)});
                }
            }
        }

        uniforms.debug_parts = render_parts.maskUniform();
        fractal.updateUniforms(&gpu_ctx, uniforms);

        perf.renderBegin();
        const frame = gpu_ctx.beginFrame() orelse {
            perf.countSkippedFrame();
            continue;
        };

        const offscreen_pass = fractal.beginOffscreenPass(frame.encoder, load_existing);
        const render_mode: fractal_gpu.RenderMode = if (camera.mode_2d)
            .slice
        else if (render_parts.geometryOnly())
            .simple
        else
            .march;
        fractal.draw(offscreen_pass, blend_constant, render_mode);
        wgpu.wgpuRenderPassEncoderEnd(offscreen_pass);
        wgpu.wgpuRenderPassEncoderRelease(offscreen_pass);

        const outline_id = if (camera.mode_2d) 0 else selection.maskId();
        if (outline_id != 0 and !selection.mask_valid) {
            selection.mask_valid = fractal.renderSelectMask(frame.encoder);
        }

        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(frame.encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = .{ .data = null, .length = 0 },
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = frame.view,
                .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                .resolveTarget = null,
                .loadOp = wgpu.WGPULoadOp_Clear,
                .storeOp = wgpu.WGPUStoreOp_Store,
                .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            }},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;

        fractal.blit(pass);

        outline_renderer.render(
            &gpu_ctx,
            pass,
            fractal.select_view,
            fractal.offscreen_view,
            fractal.select_generation,
            width_f,
            height_f,
            if (selection.mask_valid) outline_id else 0,
        );

        var gizmo_verts: [gizmo.max_vertices]GizmoVertex = undefined;
        const gizmo_vert_count = gizmo.buildGizmoLines(&gizmo_verts, instances[0..instance_count], lights[0..light_count], fog_emitters[0..fog_count], warps[0..warp_count]);
        if (gizmo_vert_count > 0) {
            const aspect = width_f / height_f;
            gizmo_renderer.render(
                &gpu_ctx,
                pass,
                gizmo_verts[0..gizmo_vert_count],
                .{ cam.pos.x, cam.pos.y, cam.pos.z },
                .{ cam.right.x, cam.right.y, cam.right.z },
                .{ cam.up.x, cam.up.y, cam.up.z },
                .{ cam.forward.x, cam.forward.y, cam.forward.z },
                aspect,
                if (camera.mode_2d) camera.zoom_2d else 0,
            );
        }

        ui.render(&gpu_ctx, pass, width_f, height_f);

        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
        gpu_ctx.endFrame(frame);
        perf.renderEnd();
    }
}
