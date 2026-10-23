const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const file_dialog = @import("../bindings/file_dialog.zig");
const export_image = @import("export_image.zig");

const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const max_instances = fractal_gpu.max_instances;
const max_mixins = fractal_gpu.max_mixins;
const max_lights = fractal_gpu.max_lights;
const max_fog_emitters = fractal_gpu.max_fog_emitters;
const max_warps = fractal_gpu.max_warps;
const max_color_stops = fractal_gpu.max_color_stops;
const max_params = fractal_gpu.max_params;

const SliderRange = @import("slider_range.zig").SliderRange;
const camera_mod = @import("camera.zig");
const FreeCamera = camera_mod.FreeCamera;
const formula_mod = @import("formula.zig");
const formula_library = @import("formula_library.zig");
const FormulaState = formula_mod.FormulaState;
const CustomParam = formula_mod.CustomParam;
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const MixinState = scene_state.MixinState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("warp.zig").WarpState;
const particles_mod = @import("particles.zig");
const ParticleSystemState = particles_mod.ParticleSystemState;
const max_particle_systems = fractal_gpu.max_particle_systems;
const screen_shader = @import("screen_shader.zig");
const ScreenShaderState = screen_shader.ScreenShaderState;
const max_screen_shaders = screen_shader.max_screen_shaders;
const sky_mod = @import("sky.zig");
const SkyState = sky_mod.SkyState;
const ColorStopState = scene_state.ColorStopState;
const CombineMode = scene_state.CombineMode;
const StereoState = @import("stereo.zig").StereoState;
const McRenderState = @import("mc_render.zig").McRenderState;
const Approximations = @import("approximations.zig").Approximations;
const PhotonSettings = @import("photon_state.zig").PhotonSettings;
const render_precision = @import("render_precision.zig");
const MarchPrecision = render_precision.MarchPrecision;
const RenderSettingsState = render_precision.RenderSettingsState;
const animation = @import("animation.zig");
const TimelineState = animation.TimelineState;
const Keyframe = animation.Keyframe;

const current_version: u32 = 12;

const ParamDto = struct { name: []const u8, value: f32, range: SliderRange };

const TextDto = struct { name: []const u8, value: []const u8 };

const ScreenShaderDto = struct {
    path: []const u8,
    params: []const ParamDto,
    texts: []const TextDto = &.{},
    font: []const u8 = "",
    enabled: bool = true,
    animated: bool = false,
};

const SkyDto = struct {
    mode: sky_mod.SkyMode = .procedural,

    zenith: [3]f32 = .{ 0.02, 0.02, 0.05 },
    horizon: [3]f32 = .{ 0.04, 0.035, 0.07 },
    ground: [3]f32 = .{ 0.06, 0.05, 0.09 },
    falloff: f32 = 1.0,
    falloff_range: SliderRange = .{ .min = 0.2, .max = 8.0 },

    sun_enabled: bool = false,
    sun_direction: camera_mod.Vec3 = .{ .x = 0.4, .y = 0.55, .z = 0.3 },
    sun_direction_range_x: SliderRange = .{ .min = -1, .max = 1 },
    sun_direction_range_y: SliderRange = .{ .min = -1, .max = 1 },
    sun_direction_range_z: SliderRange = .{ .min = -1, .max = 1 },
    sun_size: f32 = 3.0,
    sun_size_range: SliderRange = .{ .min = 0.1, .max = 30.0 },
    sun_color: [3]f32 = .{ 1.0, 0.95, 0.85 },
    sun_intensity: f32 = 20.0,
    sun_intensity_range: SliderRange = .{ .min = 0.0, .max = 200.0 },

    image_path: []const u8 = "",

    intensity: f32 = 1.0,
    intensity_range: SliderRange = .{ .min = 0.0, .max = 8.0 },
    yaw: f32 = 0.0,
    yaw_range: SliderRange = .{ .min = 0.0, .max = 360.0 },

    photons: bool = false,
};

fn skyToDto(sky: *const SkyState) SkyDto {
    return .{
        .mode = sky.mode,
        .zenith = sky.zenith,
        .horizon = sky.horizon,
        .ground = sky.ground,
        .falloff = sky.falloff,
        .falloff_range = sky.falloff_range,
        .sun_enabled = sky.sun_enabled,
        .sun_direction = sky.sun_direction,
        .sun_direction_range_x = sky.sun_direction_range_x,
        .sun_direction_range_y = sky.sun_direction_range_y,
        .sun_direction_range_z = sky.sun_direction_range_z,
        .sun_size = sky.sun_size,
        .sun_size_range = sky.sun_size_range,
        .sun_color = sky.sun_color,
        .sun_intensity = sky.sun_intensity,
        .sun_intensity_range = sky.sun_intensity_range,
        .image_path = sky.pathSlice(),
        .intensity = sky.intensity,
        .intensity_range = sky.intensity_range,
        .yaw = sky.yaw,
        .yaw_range = sky.yaw_range,
        .photons = sky.photons,
    };
}

fn skyFromDto(sky: *SkyState, dto: SkyDto) void {
    sky.* = .{
        .mode = dto.mode,
        .zenith = dto.zenith,
        .horizon = dto.horizon,
        .ground = dto.ground,
        .falloff = dto.falloff,
        .falloff_range = dto.falloff_range,
        .sun_enabled = dto.sun_enabled,
        .sun_direction = dto.sun_direction,
        .sun_direction_range_x = dto.sun_direction_range_x,
        .sun_direction_range_y = dto.sun_direction_range_y,
        .sun_direction_range_z = dto.sun_direction_range_z,
        .sun_size = dto.sun_size,
        .sun_size_range = dto.sun_size_range,
        .sun_color = dto.sun_color,
        .sun_intensity = dto.sun_intensity,
        .sun_intensity_range = dto.sun_intensity_range,
        .intensity = dto.intensity,
        .intensity_range = dto.intensity_range,
        .yaw = dto.yaw,
        .yaw_range = dto.yaw_range,
        .photons = dto.photons,
    };
    sky.setPath(dto.image_path);
}

const FormulaDto = struct { path: []const u8, params: []const ParamDto, image: []const u8 = "" };
const MixinDto = struct { formula: FormulaDto, iterations: f32, iterations_range: SliderRange };

const InstanceDto = struct {
    offset: camera_mod.Vec3,
    offset_range_x: SliderRange,
    offset_range_y: SliderRange,
    offset_range_z: SliderRange,
    scale: camera_mod.Vec3,
    scale_range_x: SliderRange,
    scale_range_y: SliderRange,
    scale_range_z: SliderRange,
    scale_uniform: f32 = 1.0,
    scale_uniform_range: SliderRange = .{ .min = 0.1, .max = 4.0 },
    rotation: camera_mod.Vec3,
    rotation_range_x: SliderRange,
    rotation_range_y: SliderRange,
    rotation_range_z: SliderRange,
    step_safety: f32,
    step_safety_range: SliderRange,
    combine_mode: CombineMode,
    blend_k: f32,
    blend_k_range: SliderRange,
    formula: FormulaDto,
    mixins: []const MixinDto,
    hybrid_base_iters: f32,
    hybrid_base_iters_range: SliderRange,
    hybrid_total_iters: f32,
    hybrid_total_iters_range: SliderRange,
    colors: []const ColorStopState,
    trap: scene_state.OrbitTrapState = .{},
    ft_view: bool = false,
    fft_box_radius: f32 = 2.5,
    fft_box_radius_range: SliderRange = .{ .min = 0.5, .max = 8.0 },
    fft_cloud_density: f32 = 4.0,
    fft_cloud_density_range: SliderRange = .{ .min = 0.0, .max = 20.0 },
    fft_lowpass: f32 = 1.0,
    fft_lowpass_range: SliderRange = .{ .min = 0.0, .max = 1.0 },
    fft_highpass: f32 = 0.0,
    fft_highpass_range: SliderRange = .{ .min = 0.0, .max = 1.0 },
    fft_normalize: bool = false,
    visible: bool = true,
};

pub const SceneFile = struct {
    version: u32 = current_version,
    camera: FreeCamera,
    max_steps: f32,
    max_steps_range: SliderRange,
    max_dist: f32,
    max_dist_range: SliderRange,
    preview_quality: f32,
    preview_quality_range: SliderRange,
    max_reflection_bounces: f32,
    max_reflection_bounces_range: SliderRange,
    photon: PhotonSettings = .{},
    precision: MarchPrecision = .{},
    render_settings: RenderSettingsState = .{},
    export_width: i32,
    export_height: i32,
    instances: []const InstanceDto,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState = &.{},
    particle_systems: []const ParticleSystemState = &.{},
    screen_shaders: []const ScreenShaderDto = &.{},
    sky: SkyDto = .{},
    stereo: StereoState = .{},
    mc: McRenderState = .{},
    approximations: Approximations = .{},
    keyframes: []const Keyframe = &.{},
    timeline_duration: f32 = 10.0,
};

fn pathSlice(formula: *const FormulaState) []const u8 {
    const n = std.mem.indexOfScalar(u8, &formula.formula_path, 0) orelse formula.formula_path.len;
    return formula.formula_path[0..n];
}

fn paramToDto(p: *const CustomParam) ParamDto {
    return .{ .name = p.label(), .value = p.value, .range = p.range };
}
const InstanceScratch = struct {
    params: [max_params]ParamDto = undefined,
    mixin_params: [max_mixins][max_params]ParamDto = undefined,
    mixins: [max_mixins]MixinDto = undefined,
    colors: [max_color_stops]ColorStopState = undefined,
};

fn instanceToDto(inst: *const FractalInstanceState, scratch: *InstanceScratch) InstanceDto {
    for (0..inst.formula.custom_param_count) |i| scratch.params[i] = paramToDto(&inst.formula.custom_params[i]);
    for (0..inst.mixin_count) |j| {
        const m = &inst.mixins[j];
        for (0..m.formula.custom_param_count) |i| scratch.mixin_params[j][i] = paramToDto(&m.formula.custom_params[i]);
        scratch.mixins[j] = .{
            .formula = .{ .path = pathSlice(&m.formula), .params = scratch.mixin_params[j][0..m.formula.custom_param_count], .image = m.formula.imagePath() },
            .iterations = m.iterations,
            .iterations_range = m.iterations_range,
        };
    }
    for (0..inst.color_count) |i| scratch.colors[i] = inst.colors[i];

    return .{
        .offset = inst.offset,
        .offset_range_x = inst.offset_range_x,
        .offset_range_y = inst.offset_range_y,
        .offset_range_z = inst.offset_range_z,
        .scale = inst.scale,
        .scale_range_x = inst.scale_range_x,
        .scale_range_y = inst.scale_range_y,
        .scale_range_z = inst.scale_range_z,
        .scale_uniform = inst.scale_uniform,
        .scale_uniform_range = inst.scale_uniform_range,
        .rotation = inst.rotation,
        .rotation_range_x = inst.rotation_range_x,
        .rotation_range_y = inst.rotation_range_y,
        .rotation_range_z = inst.rotation_range_z,
        .step_safety = inst.step_safety,
        .step_safety_range = inst.step_safety_range,
        .combine_mode = inst.combine_mode,
        .blend_k = inst.blend_k,
        .blend_k_range = inst.blend_k_range,
        .formula = .{ .path = pathSlice(&inst.formula), .params = scratch.params[0..inst.formula.custom_param_count], .image = inst.formula.imagePath() },
        .mixins = scratch.mixins[0..inst.mixin_count],
        .hybrid_base_iters = inst.hybrid_base_iters,
        .hybrid_base_iters_range = inst.hybrid_base_iters_range,
        .hybrid_total_iters = inst.hybrid_total_iters,
        .hybrid_total_iters_range = inst.hybrid_total_iters_range,
        .colors = scratch.colors[0..inst.color_count],
        .trap = inst.trap,
        .ft_view = inst.ft_view,
        .fft_box_radius = inst.fft_box_radius,
        .fft_box_radius_range = inst.fft_box_radius_range,
        .fft_cloud_density = inst.fft_cloud_density,
        .fft_cloud_density_range = inst.fft_cloud_density_range,
        .fft_lowpass = inst.fft_lowpass,
        .fft_lowpass_range = inst.fft_lowpass_range,
        .fft_highpass = inst.fft_highpass,
        .fft_highpass_range = inst.fft_highpass_range,
        .fft_normalize = inst.fft_normalize,
        .visible = inst.visible,
    };
}

pub fn encodeScene(
    allocator: std.mem.Allocator,
    pretty: bool,
    camera: FreeCamera,
    max_steps: f32,
    max_steps_range: SliderRange,
    max_dist: f32,
    max_dist_range: SliderRange,
    preview_quality: f32,
    preview_quality_range: SliderRange,
    max_reflection_bounces: f32,
    max_reflection_bounces_range: SliderRange,
    photon: PhotonSettings,
    precision: MarchPrecision,
    render_settings: RenderSettingsState,
    export_width: i32,
    export_height: i32,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    particle_systems: []const ParticleSystemState,
    screen_shaders: []const ScreenShaderState,
    sky: *const SkyState,
    stereo: StereoState,
    mc: McRenderState,
    approx: Approximations,
    timeline: TimelineState,
) ![]u8 {
    const lights_ui = try allocator.dupe(LightState, lights);
    defer allocator.free(lights_ui);
    for (lights_ui) |*l| l.window_open = false;
    const fog_ui = try allocator.dupe(FogEmitterState, fog_emitters);
    defer allocator.free(fog_ui);
    for (fog_ui) |*f| f.window_open = false;
    const warps_ui = try allocator.dupe(WarpState, warps);
    defer allocator.free(warps_ui);
    for (warps_ui) |*w| w.window_open = false;
    const particles_ui = try allocator.dupe(ParticleSystemState, particle_systems);
    defer allocator.free(particles_ui);
    for (particles_ui) |*ps| {
        ps.window_open = false;
        ps.selected_color = null;
    }
    var stereo_ui = stereo;
    stereo_ui.settings_open = false;
    var camera_ui = camera;
    camera_ui.flat.window_open = false;

    var scratch: [max_instances]InstanceScratch = undefined;
    var instance_dtos: [max_instances]InstanceDto = undefined;
    for (instances, 0..) |*inst, i| instance_dtos[i] = instanceToDto(inst, &scratch[i]);

    var screen_params: [max_screen_shaders][max_params]ParamDto = undefined;
    var screen_texts: [max_screen_shaders][screen_shader.max_text_fields]TextDto = undefined;
    var screen_dtos: [max_screen_shaders]ScreenShaderDto = undefined;
    for (screen_shaders, 0..) |*s, i| {
        for (0..s.param_count) |p| screen_params[i][p] = paramToDto(&s.params[p]);
        for (0..s.text_count) |t| screen_texts[i][t] = .{ .name = s.texts[t].label(), .value = s.texts[t].text() };
        screen_dtos[i] = .{
            .path = s.pathSlice(),
            .params = screen_params[i][0..s.param_count],
            .texts = screen_texts[i][0..s.text_count],
            .font = s.fontSlice(),
            .enabled = s.enabled,
            .animated = s.animated,
        };
    }

    const scene = SceneFile{
        .camera = camera_ui,
        .max_steps = max_steps,
        .max_steps_range = max_steps_range,
        .max_dist = max_dist,
        .max_dist_range = max_dist_range,
        .preview_quality = preview_quality,
        .preview_quality_range = preview_quality_range,
        .max_reflection_bounces = max_reflection_bounces,
        .max_reflection_bounces_range = max_reflection_bounces_range,
        .photon = photon,
        .precision = precision,
        .render_settings = render_settings,
        .export_width = export_width,
        .export_height = export_height,
        .instances = instance_dtos[0..instances.len],
        .lights = lights_ui,
        .fog_emitters = fog_ui,
        .warps = warps_ui,
        .particle_systems = particles_ui,
        .screen_shaders = screen_dtos[0..screen_shaders.len],
        .sky = skyToDto(sky),
        .stereo = stereo_ui,
        .mc = mc,
        .approximations = approx,
        .keyframes = timeline.keyframes[0..timeline.keyframe_count],
        .timeline_duration = timeline.duration,
    };

    var aw = std.Io.Writer.Allocating.init(allocator);
    errdefer aw.deinit();
    try std.json.Stringify.value(scene, .{ .whitespace = if (pretty) .indent_2 else .minified }, &aw.writer);
    return aw.toOwnedSlice();
}

pub fn saveScene(
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    camera: FreeCamera,
    max_steps: f32,
    max_steps_range: SliderRange,
    max_dist: f32,
    max_dist_range: SliderRange,
    preview_quality: f32,
    preview_quality_range: SliderRange,
    max_reflection_bounces: f32,
    max_reflection_bounces_range: SliderRange,
    photon: PhotonSettings,
    precision: MarchPrecision,
    render_settings: RenderSettingsState,
    export_width: i32,
    export_height: i32,
    instances: []const FractalInstanceState,
    lights: []const LightState,
    fog_emitters: []const FogEmitterState,
    warps: []const WarpState,
    particle_systems: []const ParticleSystemState,
    screen_shaders: []const ScreenShaderState,
    sky: *const SkyState,
    stereo: StereoState,
    mc: McRenderState,
    approx: Approximations,
    timeline: TimelineState,
    status_buf: []u8,

) [:0]const u8 {
    var path_buf: [export_image.max_path_len]u8 = undefined;
    const path_len = file_dialog.pickSaveDreamFile(window, &path_buf) orelse
        return std.fmt.bufPrintSentinel(status_buf, "Save canceled.", .{}, 0) catch "";
    if (path_len >= path_buf.len) {
        return std.fmt.bufPrintSentinel(status_buf, "Save path too long.", .{}, 0) catch "";
    }

    const data = encodeScene(
        allocator,
        true,
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
        lights,
        fog_emitters,
        warps,
        particle_systems,
        screen_shaders,
        sky,
        stereo,
        mc,
        approx,
        timeline,
    ) catch {
        return std.fmt.bufPrintSentinel(status_buf, "Failed to encode scene.", .{}, 0) catch "";
    };
    defer allocator.free(data);

    const io = std.Io.Threaded.global_single_threaded.io();
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path_buf[0..path_len], .data = data }) catch |err| {
        return std.fmt.bufPrintSentinel(status_buf, "Failed to save scene ({s}).", .{@errorName(err)}, 0) catch "Failed to save scene.";
    };

    return std.fmt.bufPrintSentinel(status_buf, "Saved scene.", .{}, 0) catch "Saved.";
}

fn copyPathInto(formula: *FormulaState, path: []const u8) void {
    const n = @min(path.len, formula.formula_path.len - 1);
    @memcpy(formula.formula_path[0..n], path[0..n]);
    formula.formula_path[n] = 0;
}

fn applyParamDtosTo(params: []CustomParam, count: usize, saved: []const ParamDto) void {
    for (saved) |sp| {
        for (0..count) |i| {
            const p = &params[i];
            if (std.mem.eql(u8, p.label(), sp.name)) {
                p.value = sp.value;
                p.range = sp.range;
                break;
            }
        }
    }
}

fn applyParamDtos(formula: *FormulaState, saved: []const ParamDto) void {
    applyParamDtosTo(&formula.custom_params, formula.custom_param_count, saved);
}


pub const ApplyMode = enum { load, undo };

pub fn applyScene(
    allocator: std.mem.Allocator,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    camera: *FreeCamera,
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
    export_width: *i32,
    export_height: *i32,
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
    stereo: *StereoState,
    mc: *McRenderState,
    approx: *Approximations,
    timeline: *TimelineState,
    scene: SceneFile,
    mode: ApplyMode,
) void {
    const undo = mode == .undo;
    scene_state.drainPendingCompile(fractal, allocator);

    const old_count = instance_count.*;
    var old_instances: [max_instances]FractalInstanceState = undefined;
    for (0..old_count) |i| old_instances[i] = instances[i];
    var kept_formula: [max_instances]bool = @splat(false);
    var kept_mixin: [max_instances][max_mixins]bool = @splat(@splat(false));

    const new_instance_count = @min(scene.instances.len, max_instances);
    for (0..new_instance_count) |i| {
        const src = scene.instances[i];
        instances[i] = scene_state.newInstance();
        instances[i].offset = src.offset;
        instances[i].offset_range_x = src.offset_range_x;
        instances[i].offset_range_y = src.offset_range_y;
        instances[i].offset_range_z = src.offset_range_z;
        instances[i].scale = src.scale;
        instances[i].scale_range_x = src.scale_range_x;
        instances[i].scale_range_y = src.scale_range_y;
        instances[i].scale_range_z = src.scale_range_z;
        instances[i].scale_uniform = src.scale_uniform;
        instances[i].scale_uniform_range = src.scale_uniform_range;
        instances[i].rotation = src.rotation;
        instances[i].rotation_range_x = src.rotation_range_x;
        instances[i].rotation_range_y = src.rotation_range_y;
        instances[i].rotation_range_z = src.rotation_range_z;
        instances[i].step_safety = src.step_safety;
        instances[i].step_safety_range = src.step_safety_range;
        instances[i].combine_mode = src.combine_mode;
        instances[i].blend_k = src.blend_k;
        instances[i].blend_k_range = src.blend_k_range;
        instances[i].hybrid_base_iters = src.hybrid_base_iters;
        instances[i].hybrid_base_iters_range = src.hybrid_base_iters_range;
        instances[i].hybrid_total_iters = src.hybrid_total_iters;
        instances[i].hybrid_total_iters_range = src.hybrid_total_iters_range;
        instances[i].trap = src.trap;
        instances[i].ft_view = src.ft_view;
        instances[i].fft_box_radius = src.fft_box_radius;
        instances[i].fft_box_radius_range = src.fft_box_radius_range;
        instances[i].fft_cloud_density = src.fft_cloud_density;
        instances[i].fft_cloud_density_range = src.fft_cloud_density_range;
        instances[i].fft_lowpass = src.fft_lowpass;
        instances[i].fft_lowpass_range = src.fft_lowpass_range;
        instances[i].fft_highpass = src.fft_highpass;
        instances[i].fft_highpass_range = src.fft_highpass_range;
        instances[i].fft_normalize = src.fft_normalize;
        instances[i].visible = src.visible;

        const old: ?*const FractalInstanceState = if (undo and i < old_count) &old_instances[i] else null;

        copyPathInto(&instances[i].formula, src.formula.path);
        if (old) |o| {
            if (canKeepFormula(&o.formula, src.formula.path)) {
                instances[i].formula = o.formula;
                kept_formula[i] = true;
            }
            instances[i].window_open = o.window_open;
        }
        instances[i].formula.setImagePath(src.formula.image);

        instances[i].mixin_count = @min(src.mixins.len, max_mixins);
        for (0..instances[i].mixin_count) |j| {
            const msrc = src.mixins[j];
            instances[i].mixins[j].iterations = msrc.iterations;
            instances[i].mixins[j].iterations_range = msrc.iterations_range;
            copyPathInto(&instances[i].mixins[j].formula, msrc.formula.path);
            if (old) |o| {
                if (j < o.mixin_count) {
                    if (canKeepFormula(&o.mixins[j].formula, msrc.formula.path)) {
                        instances[i].mixins[j].formula = o.mixins[j].formula;
                        kept_mixin[i][j] = true;
                    }
                    instances[i].mixins[j].window_open = o.mixins[j].window_open;
                }
            }
            instances[i].mixins[j].formula.setImagePath(msrc.formula.image);
        }

        instances[i].color_count = @min(src.colors.len, max_color_stops);
        for (0..instances[i].color_count) |k| instances[i].colors[k] = src.colors[k];
        if (old) |o| {
            if (o.selected_color) |sel| {
                if (sel < instances[i].color_count) instances[i].selected_color = sel;
            }
        }
    }

    for (0..old_count) |i| {
        if (!(i < new_instance_count and kept_formula[i])) old_instances[i].formula.deinit(allocator);
        for (0..old_instances[i].mixin_count) |j| {
            const kept = i < new_instance_count and j < instances[i].mixin_count and kept_mixin[i][j];
            if (!kept) old_instances[i].mixins[j].formula.deinit(allocator);
        }
    }
    instance_count.* = new_instance_count;
    formula_library.noteListChanged();

    for (0..new_instance_count) |i| {
        const src = scene.instances[i];
        if (!kept_formula[i]) {
            if (src.formula.path.len > 0) scene_state.loadFormulaBodyOnly(allocator, &instances[i].formula);
        }
        applyParamDtos(&instances[i].formula, src.formula.params);

        for (0..instances[i].mixin_count) |j| {
            const msrc = src.mixins[j];
            if (!kept_mixin[i][j]) {
                if (msrc.formula.path.len > 0) scene_state.loadFormulaBodyOnly(allocator, &instances[i].mixins[j].formula);
            }
            applyParamDtos(&instances[i].mixins[j].formula, msrc.formula.params);
        }
    }

    const old_shader_count = screen_shader_count.*;
    var old_shaders: [max_screen_shaders]ScreenShaderState = undefined;
    for (0..old_shader_count) |i| old_shaders[i] = screen_shaders[i];
    var kept_shader: [max_screen_shaders]bool = @splat(false);
    screen_shader_count.* = @min(scene.screen_shaders.len, max_screen_shaders);
    for (0..screen_shader_count.*) |i| {
        const src = scene.screen_shaders[i];
        if (undo and i < old_shader_count and std.mem.eql(u8, old_shaders[i].pathSlice(), src.path) and
            (old_shaders[i].pipeline != null or src.path.len == 0))
        {
            screen_shaders[i] = old_shaders[i];
            kept_shader[i] = true;
        } else {
            screen_shaders[i] = ScreenShaderState.init();
            screen_shaders[i].setPath(src.path);
            if (src.path.len > 0) {
                screen_shader.compileInto(allocator, gpu_ctx, &fractal.post, &screen_shaders[i]);
            }
        }
        screen_shaders[i].enabled = src.enabled;
        screen_shaders[i].animated = src.animated;
        applyParamDtosTo(&screen_shaders[i].params, screen_shaders[i].param_count, src.params);
        screen_shaders[i].setFont(src.font);
        for (src.texts) |saved| {
            if (screen_shaders[i].textField(saved.name)) |field| field.setText(saved.value);
        }
    }
    for (0..old_shader_count) |i| {
        if (!kept_shader[i]) old_shaders[i].deinit(allocator);
    }

    const old_particle_count = particle_count.*;
    var old_particles: [max_particle_systems]ParticleSystemState = undefined;
    for (0..old_particle_count) |i| old_particles[i] = particle_systems[i];
    particle_count.* = @min(scene.particle_systems.len, max_particle_systems);
    for (0..particle_count.*) |i| {
        particle_systems[i] = scene.particle_systems[i];
        particle_systems[i].window_open = false;
        particle_systems[i].selected_color = null;
        particle_systems[i].color_count = @min(particle_systems[i].color_count, max_color_stops);
        if (undo and i < old_particle_count) {
            particle_systems[i].window_open = old_particles[i].window_open;
            if (old_particles[i].selected_color) |sel| {
                if (sel < particle_systems[i].color_count) particle_systems[i].selected_color = sel;
            }
        }
    }

    const old_light_count = light_count.*;
    var old_light_open: [max_lights]bool = undefined;
    for (0..old_light_count) |i| old_light_open[i] = lights[i].window_open;
    light_count.* = @min(scene.lights.len, max_lights);
    for (0..light_count.*) |i| {
        lights[i] = scene.lights[i];
        lights[i].window_open = undo and i < old_light_count and old_light_open[i];
    }

    const old_fog_count = fog_count.*;
    var old_fog_open: [max_fog_emitters]bool = undefined;
    for (0..old_fog_count) |i| old_fog_open[i] = fog_emitters[i].window_open;
    fog_count.* = @min(scene.fog_emitters.len, max_fog_emitters);
    for (0..fog_count.*) |i| {
        fog_emitters[i] = scene.fog_emitters[i];
        fog_emitters[i].window_open = undo and i < old_fog_count and old_fog_open[i];
    }

    const old_warp_count = warp_count.*;
    var old_warp_open: [max_warps]bool = undefined;
    for (0..old_warp_count) |i| old_warp_open[i] = warps[i].window_open;
    warp_count.* = @min(scene.warps.len, max_warps);
    for (0..warp_count.*) |i| {
        warps[i] = scene.warps[i];
        warps[i].window_open = undo and i < old_warp_count and old_warp_open[i];
    }

    const old_sky = sky.*;
    skyFromDto(sky, scene.sky);
    if (undo) sky.window_open = old_sky.window_open;
    if (undo and std.mem.eql(u8, old_sky.pathSlice(), sky.pathSlice())) {
        sky.image_status = old_sky.image_status;
    } else {
        fractal.sky.clear(gpu_ctx);
        if (sky.pathSlice().len > 0) {
            if (fractal.sky.loadFromFile(gpu_ctx, allocator, sky.pathSlice())) |info| {
                sky.setStatus("Loaded {d}x{d}.{s}", .{ info.width, info.height, if (info.is_hdr) " HDR." else "" });
            } else |err| {
                sky.setStatus("Could not load image ({s}).", .{@errorName(err)});
            }
        }
    }

    const stereo_open = stereo.settings_open;
    stereo.* = scene.stereo;
    stereo.settings_open = undo and stereo_open;

    mc.* = scene.mc;
    approx.* = scene.approximations;

    timeline.keyframe_count = @min(scene.keyframes.len, animation.max_keyframes);
    for (0..timeline.keyframe_count) |i| timeline.keyframes[i] = scene.keyframes[i];
    timeline.duration = scene.timeline_duration;
    if (undo) {
        timeline.playhead = @min(timeline.playhead, timeline.duration);
    } else {
        timeline.playhead = 0;
        timeline.playing = false;
        timeline.dirty = true;
    }

    const kept_camera = camera.*;
    camera.* = scene.camera;
    camera.flat.window_open = undo and kept_camera.flat.window_open;
    if (undo) {
        camera.position = kept_camera.position;
        camera.forward = kept_camera.forward;
        camera.up = kept_camera.up;
        camera.zoom_2d = kept_camera.zoom_2d;
        camera.speed_multiplier = kept_camera.speed_multiplier;
    }
    camera.zoom_2d = std.math.clamp(camera.zoom_2d, camera_mod.min_zoom_2d, camera_mod.max_zoom_2d);
    max_steps.* = scene.max_steps;
    max_steps_range.* = scene.max_steps_range;
    max_dist.* = scene.max_dist;
    max_dist_range.* = scene.max_dist_range;
    preview_quality.* = scene.preview_quality;
    preview_quality_range.* = scene.preview_quality_range;
    max_reflection_bounces.* = scene.max_reflection_bounces;
    max_reflection_bounces_range.* = scene.max_reflection_bounces_range;
    photon.* = scene.photon;
    precision.* = scene.precision;
    render_settings.* = scene.render_settings;
    export_width.* = scene.export_width;
    export_height.* = scene.export_height;
}

fn canKeepFormula(old: *const FormulaState, new_path: []const u8) bool {
    if (old.compile_pending) return false;
    if (!std.mem.eql(u8, pathSlice(old), new_path)) return false;
    return old.formula_body != null or new_path.len == 0;
}

pub fn parseScene(allocator: std.mem.Allocator, content: []const u8) !std.json.Parsed(SceneFile) {
    return std.json.parseFromSlice(SceneFile, allocator, content, .{ .ignore_unknown_fields = true });
}

pub fn loadScene(
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    camera: *FreeCamera,
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
    export_width: *i32,
    export_height: *i32,
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
    stereo: *StereoState,
    mc: *McRenderState,
    approx: *Approximations,
    timeline: *TimelineState,
    status_buf: []u8,
) [:0]const u8 {
    var path_buf: [export_image.max_path_len]u8 = undefined;
    const path_len = file_dialog.pickOpenDreamFile(window, &path_buf) orelse
        return std.fmt.bufPrintSentinel(status_buf, "Load canceled.", .{}, 0) catch "";
    if (path_len >= path_buf.len) {
        return std.fmt.bufPrintSentinel(status_buf, "Load path too long.", .{}, 0) catch "";
    }

    const io = std.Io.Threaded.global_single_threaded.io();
    const content = std.Io.Dir.cwd().readFileAlloc(io, path_buf[0..path_len], allocator, .limited(1 << 24)) catch |err| {
        return std.fmt.bufPrintSentinel(status_buf, "Could not read file ({s}).", .{@errorName(err)}, 0) catch "Could not read file.";
    };
    defer allocator.free(content);

    var parsed = parseScene(allocator, content) catch |err| {
        return std.fmt.bufPrintSentinel(status_buf, "Invalid scene file ({s}).", .{@errorName(err)}, 0) catch "Invalid scene file.";
    };
    defer parsed.deinit();

    if (parsed.value.version > current_version) {
        return std.fmt.bufPrintSentinel(status_buf, "Scene file is from a newer version of the app.", .{}, 0) catch "";
    }

    applyScene(
        allocator,
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
        particle_systems,
        particle_count,
        screen_shaders,
        screen_shader_count,
        sky,
        stereo,
        mc,
        approx,
        timeline,
        parsed.value,
        .load,
    );

    return std.fmt.bufPrintSentinel(status_buf, "Loaded scene, compiling shader...", .{}, 0) catch "Loaded.";
}
