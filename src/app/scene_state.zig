const std = @import("std");
const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const GpuFractalInstance = fractal_gpu.FractalInstance;
const GpuMixinParams = fractal_gpu.MixinParams;
const GpuColorStop = fractal_gpu.ColorStop;
const GpuLight = fractal_gpu.Light;
const GpuFogEmitter = fractal_gpu.FogEmitter;
const max_instances = fractal_gpu.max_instances;
const max_mixins = fractal_gpu.max_mixins;
const max_color_stops = fractal_gpu.max_color_stops;
const max_params = fractal_gpu.max_params;
const builtin_formula_source = fractal_gpu.builtin_formula_source;
const filler_formula_source = fractal_gpu.filler_formula_source;

const SliderRange = @import("slider_range.zig").SliderRange;
const camera = @import("camera.zig");
const Vec3 = camera.Vec3;
const formula_mod = @import("formula.zig");
const FormulaState = formula_mod.FormulaState;
const CustomParam = formula_mod.CustomParam;

pub const max_formula_file_bytes: usize = 1 << 20;

pub const status_buf_len: usize = 160;

pub const ColorStopState = struct {
    position: f32,
    color: [3]f32,
    glossiness: f32 = 0.3,
    transparency: f32 = 0.0,
    reflectiveness: f32 = 0.1,
    ior: f32 = 1.5,
    subsurface: f32 = 0.0,
    abbe: f32 = 0.0, // 0 = no dispersion, lower nonzero disperses more
    inner_max_steps: f32 = 64.0,
    roughness: f32 = 0.0,
    film_thickness: f32 = 400.0, // nm
    film_ior: f32 = 1.8,
    film_strength: f32 = 0.0,
    film_angle_scale: f32 = 1.0,
    film_perturb: f32 = 0.0,
    film_perturb_scale: f32 = 0.2,
    glossiness_range: SliderRange = .{ .min = 0, .max = 1 },
    transparency_range: SliderRange = .{ .min = 0, .max = 1 },
    reflectiveness_range: SliderRange = .{ .min = 0, .max = 1 },
    ior_range: SliderRange = .{ .min = 1, .max = 3 },
    subsurface_range: SliderRange = .{ .min = 0, .max = 1 },
    abbe_range: SliderRange = .{ .min = 0, .max = 120 },
    inner_max_steps_range: SliderRange = .{ .min = 8, .max = 256 },
    roughness_range: SliderRange = .{ .min = 0, .max = 1 },
    film_thickness_range: SliderRange = .{ .min = 0, .max = 1500 },
    film_ior_range: SliderRange = .{ .min = 1, .max = 3 },
    film_strength_range: SliderRange = .{ .min = 0, .max = 1 },
    film_angle_scale_range: SliderRange = .{ .min = 0, .max = 2 },
    film_perturb_range: SliderRange = .{ .min = 0, .max = 1 },
    film_perturb_scale_range: SliderRange = .{ .min = 0.01, .max = 2 },

    fn toGpu(self: ColorStopState) GpuColorStop {
        return .{
            .color = self.color,
            .position = self.position,
            .glossiness = self.glossiness,
            .transparency = self.transparency,
            .reflectiveness = self.reflectiveness,
            .ior = self.ior,
            .subsurface = self.subsurface,
            .abbe = self.abbe,
            .inner_max_steps = self.inner_max_steps,
            .roughness = self.roughness,
            .film_thickness = self.film_thickness,
            .film_ior = self.film_ior,
            .film_strength = self.film_strength,
            .film_angle_scale = self.film_angle_scale,
            .film_perturb = self.film_perturb,
            .film_perturb_scale = self.film_perturb_scale,
        };
    }
};

pub fn defaultColors() [max_color_stops]ColorStopState {
    var arr: [max_color_stops]ColorStopState = undefined;
    arr[0] = .{ .position = 0.0, .color = .{ 0.05, 0.05, 0.22 }, .glossiness = 0.2, .reflectiveness = 0.05 };
    arr[1] = .{ .position = 0.5, .color = .{ 0.85, 0.35, 0.08 }, .glossiness = 0.5, .reflectiveness = 0.15 };
    arr[2] = .{ .position = 1.0, .color = .{ 1.0, 0.95, 0.82 }, .glossiness = 0.8, .reflectiveness = 0.25 };
    for (3..max_color_stops) |i| arr[i] = .{ .position = 0, .color = .{ 0.5, 0.5, 0.5 } };
    return arr;
}
pub fn sortedColorOrder(colors: []const ColorStopState, count: usize) [max_color_stops]usize {
    var order: [max_color_stops]usize = undefined;
    for (0..count) |i| order[i] = i;
    for (1..count) |oi| {
        var oj = oi;
        while (oj > 0 and colors[order[oj - 1]].position > colors[order[oj]].position) : (oj -= 1) {
            std.mem.swap(usize, &order[oj], &order[oj - 1]);
        }
    }
    return order;
}

pub const CombineMode = enum {
    hard_union,
    de_combinate,
    smooth_max,
    smooth_inv_max,
    smooth_min_lin,
    smooth_min_nlin,
    smooth_mix,

    pub const all = std.enums.values(CombineMode);

    pub fn label(self: CombineMode) [:0]const u8 {
        return switch (self) {
            .hard_union => "Union",
            .de_combinate => "Smooth Min",
            .smooth_max => "Smooth Max",
            .smooth_inv_max => "Smooth Inv-Max",
            .smooth_min_lin => "Smooth Min-Lin",
            .smooth_min_nlin => "Smooth Min-NLin",
            .smooth_mix => "Smooth Mix",
        };
    }
};

pub const MixinState = struct {
    formula: FormulaState,

    iterations: f32,
    iterations_range: SliderRange,

    window_open: bool,
};

pub fn newMixin() MixinState {
    return .{
        .formula = FormulaState.init(),
        .iterations = 1,
        .iterations_range = .{ .min = 0, .max = 8 },
        .window_open = false,
    };
}

pub const FractalInstanceState = struct {
    offset: Vec3,
    offset_range_x: SliderRange,
    offset_range_y: SliderRange,
    offset_range_z: SliderRange,
    scale: Vec3,
    scale_range_x: SliderRange,
    scale_range_y: SliderRange,
    scale_range_z: SliderRange,
    scale_uniform: f32 = 1.0,
    scale_uniform_range: SliderRange = .{ .min = 0.1, .max = 4.0 },
    rotation: Vec3,
    rotation_range_x: SliderRange,
    rotation_range_y: SliderRange,
    rotation_range_z: SliderRange,
    step_safety: f32,
    step_safety_range: SliderRange,
    combine_mode: CombineMode,
    blend_k: f32,
    blend_k_range: SliderRange,
    formula: FormulaState,
    mixins: [max_mixins]MixinState,
    mixin_count: usize,
    hybrid_base_iters: f32,
    hybrid_base_iters_range: SliderRange,
    hybrid_total_iters: f32,
    hybrid_total_iters_range: SliderRange,

    colors: [max_color_stops]ColorStopState,
    color_count: usize,
    selected_color: ?usize,

    window_open: bool,

    pub fn toGpu(self: FractalInstanceState) GpuFractalInstance {
        const params = self.formula.packedParams();

        var mixins: [max_mixins]GpuMixinParams = undefined;
        for (0..self.mixin_count) |j| {
            const m = &self.mixins[j];
            const mp = m.formula.packedParams();
            mixins[j] = .{ .params0 = mp[0], .params1 = mp[1], .iterations = m.iterations };
        }
        for (self.mixin_count..max_mixins) |j| mixins[j] = .{};

        const order = sortedColorOrder(&self.colors, self.color_count);
        var colors: [max_color_stops]GpuColorStop = undefined;
        for (0..self.color_count) |i| colors[i] = self.colors[order[i]].toGpu();
        for (self.color_count..max_color_stops) |i| colors[i] = std.mem.zeroes(GpuColorStop);

        return .{
            .offset = .{ self.offset.x, self.offset.y, self.offset.z },
            .scale = .{
                self.scale.x * self.scale_uniform,
                self.scale.y * self.scale_uniform,
                self.scale.z * self.scale_uniform,
            },
            .rotation = .{
                std.math.degreesToRadians(self.rotation.x),
                std.math.degreesToRadians(self.rotation.y),
                std.math.degreesToRadians(self.rotation.z),
            },
            .step_safety = self.step_safety,
            .blend_k = self.blend_k,
            .combine_mode = @floatFromInt(@backingInt(self.combine_mode)),
            .color_count = @floatFromInt(self.color_count),
            .params0 = params[0],
            .params1 = params[1],
            .mixin_count = @floatFromInt(self.mixin_count),
            .hybrid_base_iters = self.hybrid_base_iters,
            .hybrid_total_iters = self.hybrid_total_iters,
            .mixins = mixins,
            .colors = colors,
        };
    }
};

pub fn newInstance() FractalInstanceState {
    var inst = FractalInstanceState{
        .offset = .{ .x = 0, .y = 0, .z = 0 },
        .offset_range_x = .{ .min = -4, .max = 4 },
        .offset_range_y = .{ .min = -4, .max = 4 },
        .offset_range_z = .{ .min = -4, .max = 4 },
        .scale = .{ .x = 1, .y = 1, .z = 1 },
        .scale_range_x = .{ .min = 0.1, .max = 4.0 },
        .scale_range_y = .{ .min = 0.1, .max = 4.0 },
        .scale_range_z = .{ .min = 0.1, .max = 4.0 },
        .rotation = .{ .x = 0, .y = 0, .z = 0 },
        .rotation_range_x = .{ .min = -180, .max = 180 },
        .rotation_range_y = .{ .min = -180, .max = 180 },
        .rotation_range_z = .{ .min = -180, .max = 180 },
        .step_safety = 1.0,
        .step_safety_range = .{ .min = 0.05, .max = 1.0 },
        .combine_mode = .de_combinate,
        .blend_k = 0.5,
        .blend_k_range = .{ .min = 0, .max = 2 },
        .formula = FormulaState.init(),
        .mixins = undefined,
        .mixin_count = 0,
        .hybrid_base_iters = 2,
        .hybrid_base_iters_range = .{ .min = 0, .max = 8 },
        .hybrid_total_iters = 12,
        .hybrid_total_iters_range = .{ .min = 1, .max = 48 },
        .colors = defaultColors(),
        .color_count = 3,
        .selected_color = null,
        .window_open = false,
    };
    for (0..max_mixins) |j| inst.mixins[j] = newMixin();
    return inst;
}

pub fn freeInstanceOwned(allocator: std.mem.Allocator, inst: *const FractalInstanceState) void {
    inst.formula.deinit(allocator);
    for (0..inst.mixin_count) |j| inst.mixins[j].formula.deinit(allocator);
}

fn buildFormulaSources(instances: []const FractalInstanceState, instance_count: usize) [max_instances][]const u8 {
    var sources: [max_instances][]const u8 = undefined;
    for (0..max_instances) |i| {
        sources[i] = if (i < instance_count) (instances[i].formula.formula_body orelse builtin_formula_source) else filler_formula_source;
    }
    return sources;
}

fn buildMixinSources(instances: []const FractalInstanceState, instance_count: usize) [max_instances][max_mixins][]const u8 {
    var sources: [max_instances][max_mixins][]const u8 = undefined;
    for (0..max_instances) |i| {
        const mixin_count = if (i < instance_count) instances[i].mixin_count else 0;
        for (0..max_mixins) |j| {
            sources[i][j] = if (j < mixin_count) (instances[i].mixins[j].formula.formula_body orelse builtin_formula_source) else filler_formula_source;
        }
    }
    return sources;
}

pub fn drainPendingCompile(fractal: *FractalRenderer, allocator: std.mem.Allocator) void {
    if (!fractal.isCompiling()) return;
    if (fractal.pollRebuild(true)) |outcome| resolveOutcome(outcome, allocator);
}

fn resolveOutcome(outcome: fractal_gpu.RebuildOutcome, allocator: std.mem.Allocator) void {
    if (outcome.requester) |req| {
        const formula: *FormulaState = @ptrCast(@alignCast(req));
        resolveFormulaCompile(formula, allocator, outcome);
    } else if (!outcome.ok) {
        std.log.err("Failed to rebuild fractal shader: {s}", .{outcome.err_message});
    }
}

pub fn pollPendingCompile(fractal: *FractalRenderer, allocator: std.mem.Allocator) void {
    const outcome = fractal.pollRebuild(false) orelse return;
    resolveOutcome(outcome, allocator);
}

pub fn rebuildAll(ctx: *Context, fractal: *FractalRenderer, allocator: std.mem.Allocator, instances: []const FractalInstanceState, instance_count: usize) void {
    drainPendingCompile(fractal, allocator);
    fractal.rebuild(ctx, allocator, buildFormulaSources(instances, instance_count), buildMixinSources(instances, instance_count)) catch |err| {
        std.log.err("Failed to rebuild fractal shader: {s}: {s}", .{ @errorName(err), webgpu_context.g_error_sink.message() });
    };
}

pub fn rebuildAllChecked(ctx: *Context, fractal: *FractalRenderer, allocator: std.mem.Allocator, instances: []const FractalInstanceState, instance_count: usize) !void {
    drainPendingCompile(fractal, allocator);
    try fractal.rebuild(ctx, allocator, buildFormulaSources(instances, instance_count), buildMixinSources(instances, instance_count));
}

pub fn rebuildAllAsync(ctx: *Context, fractal: *FractalRenderer, allocator: std.mem.Allocator, instances: []const FractalInstanceState, instance_count: usize) void {
    drainPendingCompile(fractal, allocator);
    _ = fractal.rebuildAsync(ctx, allocator, buildFormulaSources(instances, instance_count), buildMixinSources(instances, instance_count), null) catch |err| {
        std.log.err("Failed to start fractal shader rebuild: {s}", .{@errorName(err)});
    };
}

const LoadedFormula = struct {
    body: []u8,
    params: [max_params]CustomParam,
    param_count: usize,
};

fn readFormulaFile(allocator: std.mem.Allocator, formula: *FormulaState) ?LoadedFormula {
    const path_len = std.mem.indexOfScalar(u8, &formula.formula_path, 0) orelse formula.formula_path.len;
    const path = formula.formula_path[0..path_len];
    if (path.len == 0) {
        formula.setError("No file path given.");
        return null;
    }

    const io = std.Io.Threaded.global_single_threaded.io();
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_formula_file_bytes)) catch |err| {
        var buf: [status_buf_len]u8 = undefined;
        formula.setError(std.fmt.bufPrint(&buf, "Could not read file ({s}).", .{@errorName(err)}) catch "Could not read file.");
        return null;
    };

    if (formula_mod.missingContractFn(content)) |sig| {
        allocator.free(content);
        var buf: [status_buf_len]u8 = undefined;
        formula.setError(std.fmt.bufPrint(&buf, "File must define `{s}`.", .{sig}) catch "File is missing part of the formula contract.");
        return null;
    }

    var loaded = LoadedFormula{ .body = content, .params = undefined, .param_count = 0 };
    formula_mod.parseFormulaParams(content, &loaded.params, &loaded.param_count);
    return loaded;
}

pub fn loadFormulaBodyOnly(allocator: std.mem.Allocator, formula: *FormulaState) void {
    const loaded = readFormulaFile(allocator, formula) orelse return;
    if (formula.formula_body) |ob| allocator.free(ob);
    formula.formula_body = loaded.body;
    formula.custom_params = loaded.params;
    formula.custom_param_count = loaded.param_count;
    formula.clearError();
}

pub fn compileFormulaInto(
    allocator: std.mem.Allocator,
    ctx: *Context,
    fractal: *FractalRenderer,
    formula: *FormulaState,
    instances: []const FractalInstanceState,
    instance_count: usize,
) void {
    if (fractal.isCompiling()) {
        formula.setError("A shader is already compiling -- try again once it finishes.");
        return;
    }

    const loaded = readFormulaFile(allocator, formula) orelse return;
    const content = loaded.body;
    const old_body = formula.formula_body;
    formula.formula_body = content;

    const start = fractal.rebuildAsync(
        ctx,
        allocator,
        buildFormulaSources(instances, instance_count),
        buildMixinSources(instances, instance_count),
        @ptrCast(formula),
    ) catch |err| {
        formula.formula_body = old_body;
        allocator.free(content);
        var buf: [status_buf_len]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Could not start compile ({s}).", .{@errorName(err)}) catch "Could not start compile.";
        formula.setError(msg);
        return;
    };

    switch (start) {
        .cache_hit => {
            if (old_body) |ob| allocator.free(ob);
            formula.custom_params = loaded.params;
            formula.custom_param_count = loaded.param_count;
            formula.clearError();
        },
        .started => {
            formula.compile_pending = true;
            formula.pending_old_body = old_body;
            formula.pending_new_body = content;
            formula.pending_params = loaded.params;
            formula.pending_param_count = loaded.param_count;
        },
    }
}

fn resolveFormulaCompile(formula: *FormulaState, allocator: std.mem.Allocator, outcome: fractal_gpu.RebuildOutcome) void {
    formula.compile_pending = false;
    const old_body = formula.pending_old_body;
    const new_body = formula.pending_new_body orelse return;
    formula.pending_old_body = null;
    formula.pending_new_body = null;

    if (outcome.ok) {
        if (old_body) |ob| allocator.free(ob);
        formula.custom_params = formula.pending_params;
        formula.custom_param_count = formula.pending_param_count;
        formula.clearError();
    } else {
        formula.formula_body = old_body;
        allocator.free(new_body);
        formula.setError(if (outcome.err_message.len > 0) outcome.err_message else "Shader failed to compile (unknown error).");
    }
}

pub const LightKind = enum { point, global, ray };

//must match BEAM_WAIST in template.wgsl
pub const beam_waist: f32 = 0.05;

pub fn beamRadiusAt(spread_deg: f32, dist: f32) f32 {
    const clamped = std.math.clamp(std.math.degreesToRadians(spread_deg), 0.0, 1.5);
    return beam_waist + dist * @tan(clamped);
}

pub const LightState = struct {
    kind: LightKind,
    color: [3]f32,
    brightness: f32,
    brightness_range: SliderRange,

    position: Vec3,
    position_range_x: SliderRange,
    position_range_y: SliderRange,
    position_range_z: SliderRange,

    direction: Vec3,
    direction_range_x: SliderRange,
    direction_range_y: SliderRange,
    direction_range_z: SliderRange,

    spread: f32 = 25.0,
    spread_range: SliderRange = .{ .min = 0.0, .max = 60.0 },

    cast_shadows: bool,
    hard_shadows: bool,
    shadow_softness: f32,
    shadow_softness_range: SliderRange,

    window_open: bool,

    pub fn toGpu(self: LightState) GpuLight {
        const pos_or_dir: [3]f32 = switch (self.kind) {
            .point, .ray => .{ self.position.x, self.position.y, self.position.z },
            .global => .{ self.direction.x, self.direction.y, self.direction.z },
        };
        return .{
            .color = self.color,
            .brightness = self.brightness,
            .position_or_direction = pos_or_dir,
            .light_type = @floatFromInt(@backingInt(self.kind)),
            .shadow_softness = self.shadow_softness,
            .cast_shadows = if (self.cast_shadows) 1.0 else 0.0,
            .hard_shadows = if (self.hard_shadows) 1.0 else 0.0,
            .spread = std.math.degreesToRadians(self.spread),
            .ray_direction = .{ self.direction.x, self.direction.y, self.direction.z },
            .waist = beam_waist,
        };
    }
};

pub fn newLight() LightState {
    return .{
        .kind = .global,
        .color = .{ 1.0, 1.0, 1.0 },
        .brightness = 1.0,
        .brightness_range = .{ .min = 0.0, .max = 4.0 },
        .position = .{ .x = 2, .y = 3, .z = 2 },
        .position_range_x = .{ .min = -10, .max = 10 },
        .position_range_y = .{ .min = -10, .max = 10 },
        .position_range_z = .{ .min = -10, .max = 10 },
        .direction = .{ .x = 0.6, .y = 0.8, .z = 0.4 },
        .direction_range_x = .{ .min = -1, .max = 1 },
        .direction_range_y = .{ .min = -1, .max = 1 },
        .direction_range_z = .{ .min = -1, .max = 1 },
        .spread = 25.0,
        .spread_range = .{ .min = 0.0, .max = 60.0 },
        .cast_shadows = true,
        .hard_shadows = false,
        .shadow_softness = 8.0,
        .shadow_softness_range = .{ .min = 1.0, .max = 64.0 },
        .window_open = false,
    };
}

pub const FogEmitterState = struct {
    position: Vec3,
    position_range_x: SliderRange,
    position_range_y: SliderRange,
    position_range_z: SliderRange,
    radius: f32,
    radius_range: SliderRange,
    density: f32,
    density_range: SliderRange,
    softness: f32,
    softness_range: SliderRange,
    color: [3]f32,
    anisotropy: f32,
    anisotropy_range: SliderRange,

    window_open: bool,

    pub fn toGpu(self: FogEmitterState) GpuFogEmitter {
        return .{
            .position = .{ self.position.x, self.position.y, self.position.z },
            .radius = self.radius,
            .color = self.color,
            .density = self.density,
            .softness = self.softness,
            .anisotropy = self.anisotropy,
        };
    }
};

pub fn newFogEmitter() FogEmitterState {
    return .{
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .position_range_x = .{ .min = -10, .max = 10 },
        .position_range_y = .{ .min = -10, .max = 10 },
        .position_range_z = .{ .min = -10, .max = 10 },
        .radius = 3.0,
        .radius_range = .{ .min = 0.1, .max = 12.0 },
        .density = 1.0,
        .density_range = .{ .min = 0.0, .max = 8.0 },
        .softness = 0.6,
        .softness_range = .{ .min = 0.0, .max = 1.0 },
        .color = .{ 0.75, 0.8, 0.9 },
        .anisotropy = 0.3,
        .anisotropy_range = .{ .min = -0.9, .max = 0.9 },
        .window_open = false,
    };
}
