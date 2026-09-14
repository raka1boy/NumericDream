const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const g_error_sink = &webgpu_context.g_error_sink;
const sv = webgpu_context.sv;
pub const accel = @import("accel.zig");
const AccelGrid = accel.AccelGrid;
pub const photons = @import("photons.zig");
const PhotonMap = photons.PhotonMap;
pub const sky_texture = @import("sky_texture.zig");
const SkyTexture = sky_texture.SkyTexture;
const photon_state = @import("../app/photon_state.zig");
const sky_state = @import("../app/sky.zig");

const shader_template = @embedFile("shaders/template.wgsl");
const blit_shader_src = @embedFile("shaders/blit.wgsl");

pub const max_instances = 4;
pub const max_mixins = 3;
pub const max_color_stops = 16;
pub const max_params = 8;
pub const max_lights = 8;
pub const max_fog_emitters = 4;
pub const max_warps = 4;

const hdr_format = wgpu.WGPUTextureFormat_RGBA16Float;

const select_format = wgpu.WGPUTextureFormat_R8Unorm;

pub const builtin_formula_source = @embedFile("shaders/mandelbrot.wgsl");

pub const filler_formula_source =
    \\fn de_iterations(p: array<f32, 8>) -> i32 {
    \\    return 0;
    \\}
    \\fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    \\    return carry;
    \\}
    \\fn de_finalize(carry: IterCarry) -> f32 {
    \\    return 1e6;
    \\}
;

pub const ColorStop = extern struct {
    color: [3]f32,
    position: f32,
    glossiness: f32,
    transparency: f32,
    reflectiveness: f32,
    ior: f32,
    subsurface: f32 = 0,
    abbe: f32 = 0,
    inner_max_steps: f32 = 64,
    roughness: f32 = 0,
    film_thickness: f32 = 400,
    film_ior: f32 = 1.8,
    film_strength: f32 = 0,
    film_angle_scale: f32 = 1,
    film_perturb: f32 = 0,
    film_perturb_scale: f32 = 0.2,
    _pad_film0: f32 = 0,
    _pad_film1: f32 = 0,
};

comptime {
    // Stride must match template.wgsl's ColorStop.
    std.debug.assert(@sizeOf(ColorStop) == 80);
    std.debug.assert(@offsetOf(ColorStop, "roughness") == 44);
    std.debug.assert(@offsetOf(ColorStop, "film_thickness") == 48);
}

pub const MixinParams = extern struct {
    params0: [4]f32 = .{ 0, 0, 0, 0 },
    params1: [4]f32 = .{ 0, 0, 0, 0 },
    iterations: f32 = 1,
    _pad0: f32 = 0,
    _pad1: f32 = 0,
    _pad2: f32 = 0,
};

pub const FractalInstance = extern struct {
    offset: [3]f32,
    blend_k: f32,
    combine_mode: f32,
    color_count: f32,
    step_safety: f32 = 1.0, //< 1 = more conservative steps
    _pad_a: f32 = 0,
    scale: [3]f32 = .{ 1, 1, 1 },
    _pad_scale: f32 = 0,
    rotation: [3]f32 = .{ 0, 0, 0 },
    _pad_rot: f32 = 0,
    params0: [4]f32,
    params1: [4]f32,
    mixin_count: f32 = 0,
    hybrid_base_iters: f32 = 2,
    hybrid_total_iters: f32 = 12,
    _pad2: f32 = 0,
    mixins: [max_mixins]MixinParams,
    colors: [max_color_stops]ColorStop,
};

pub const Light = extern struct {
    color: [3]f32,
    brightness: f32,
    position_or_direction: [3]f32,
    light_type: f32, //0 = point, 1 = global/directional, 2 = ray
    shadow_softness: f32,
    cast_shadows: f32,
    hard_shadows: f32,
    spread: f32 = 0, //half-angle in radians
    ray_direction: [3]f32 = .{ 0, -1, 0 },
    waist: f32 = 0.05,
};

pub const FogEmitter = extern struct {
    position: [3]f32,
    radius: f32,
    color: [3]f32,
    density: f32,
    softness: f32,
    anisotropy: f32,
    _pad0: f32 = 0,
    _pad1: f32 = 0,
};

pub const Warp = extern struct {
    center: [3]f32 = .{ 0, 0, 0 },
    region_kind: f32 = 0,
    extent: [3]f32 = .{ 1, 1, 1 },
    falloff: f32 = 0,
    rotation: [3]f32 = .{ 0, 0, 0 },
    sub_kind: f32 = 0,
    params0: [4]f32 = .{ 0, 0, 0, 0 },
    params1: [4]f32 = .{ 0, 0, 0, 0 },
    strength: f32 = 0,
    lip_mult: f32 = 0,
    lip_grad: f32 = 0,
    safety: f32 = 1,
};

pub const Uniforms = extern struct {
    camera_pos: [3]f32,
    time: f32,
    camera_right: [3]f32,
    max_steps: f32,
    camera_up: [3]f32,
    max_dist: f32,
    camera_forward: [3]f32,
    instance_count: f32,
    resolution: [2]f32,
    light_count: f32,
    max_reflection_bounces: f32 = 1,
    high_quality: f32 = 0,
    epsilon_coefficient: f32 = 0.0005,
    epsilon_floor: f32 = 0.00005,
    hq_footprint_budget_px: f32 = 2.0,
    tile_scale: [2]f32 = .{ 1, 1 },
    tile_bias: [2]f32 = .{ 0, 0 },
    dof_enabled: f32 = 0,
    focus_distance: f32 = 3.2,
    aperture: f32 = 0,
    focus_range: f32 = 0.5,
    refine_fast: f32 = 4,
    refine_hq: f32 = 20,
    mc_enabled: f32 = 0,
    mc_sample: f32 = 0,
    instances: [max_instances]FractalInstance,
    lights: [max_lights]Light,
    fog_count: f32 = 0,
    fog_samples: f32 = 1,
    mode_2d: f32 = 0,
    slice_zoom: f32 = 2.0,
    fog_emitters: [max_fog_emitters]FogEmitter,
    light_bounces: f32 = 0,
    accel_enabled: f32 = 0,
    accel_levels: f32 = 0,
    accel_res: f32 = 0,
    accel_safety: f32 = 1.0,
    accel_z_offset: f32 = 0, //build pass only
    _pad_accel0: f32 = 0,
    _pad_accel1: f32 = 0,
    accel_params: [accel.max_cascades][4]f32 = @splat(.{ 0, 0, 0, 0 }),
    warp_count: f32 = 0,
    _pad_warp0: f32 = 0,
    _pad_warp1: f32 = 0,
    _pad_warp2: f32 = 0,
    warps: [max_warps]Warp = @splat(.{}),
    photon_enabled: f32 = 0,
    photon_radius: f32 = 0.05,
    photon_cell: f32 = 0.1,
    photon_table: f32 = 0,
    photon_paths: f32 = 0,
    photon_seed: f32 = 0,
    photon_intensity: f32 = 1,
    photon_path_offset: f32 = 0, //trace pass only
    photon_centre: [3]f32 = .{ 0, 0, 0 },
    photon_extent: f32 = 0,
    sky: Sky = .{},
    photon_pass: f32 = 0,
    photon_pool: f32 = 0,
    photon_cap_surface: f32 = 8,
    photon_fixed_unit: f32 = 1,
    photon_volume_scale: f32 = 1,
    photon_hash_salt: f32 = 0,
    photon_dispersion_soft: f32 = 0,
    debug_parts: f32 = 0,
};

pub const Sky = extern struct {
    mode: f32 = 0,
    intensity: f32 = 1,
    falloff: f32 = 1,
    photons: f32 = 0,
    zenith: [3]f32 = .{ 0.02, 0.02, 0.05 },
    sun_cos: f32 = -2, //-2 is no sun
    horizon: [3]f32 = .{ 0.04, 0.035, 0.07 },
    sun_intensity: f32 = 0,
    ground: [3]f32 = .{ 0.06, 0.05, 0.09 },
    yaw: f32 = 0, //radians
    sun_color: [3]f32 = .{ 1, 1, 1 },
    _pad0: f32 = 0,
    sun_dir: [3]f32 = .{ 0, 1, 0 },
    _pad1: f32 = 0,
};

comptime {
    std.debug.assert(@sizeOf(Uniforms) % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "accel_params") % 16 == 0);
    std.debug.assert(@sizeOf(Warp) % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "warps") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "photon_enabled") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "photon_centre") % 16 == 0);
    std.debug.assert(@sizeOf(Sky) % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "sky") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "photon_pass") % 16 == 0);
    for (.{ "zenith", "horizon", "ground", "sun_color", "sun_dir" }) |field| {
        std.debug.assert(@offsetOf(Sky, field) % 16 == 0);
    }
}

fn isIdentChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn matchesWordAt(source: []const u8, i: usize, word: []const u8) bool {
    if (i + word.len > source.len) return false;
    if (!std.mem.eql(u8, source[i .. i + word.len], word)) return false;
    if (i > 0 and isIdentChar(source[i - 1])) return false;
    if (i + word.len < source.len and isIdentChar(source[i + word.len])) return false;
    return true;
}

fn collectTopLevelFnNames(allocator: std.mem.Allocator, source: []const u8) ![][]const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);
    var i: usize = 0;
    while (i < source.len) {
        if (matchesWordAt(source, i, "fn")) {
            var j = i + 2;
            while (j < source.len and (source[j] == ' ' or source[j] == '\t')) j += 1;
            const start = j;
            while (j < source.len and isIdentChar(source[j])) j += 1;
            if (j > start) try names.append(allocator, source[start..j]);
            i = j;
        } else {
            i += 1;
        }
    }
    return names.toOwnedSlice(allocator);
}

const contract_fn_names = [_][]const u8{ "de_step", "de_finalize", "de_iterations" };

fn appendRenamedFormula(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8, slot: usize) !void {
    const names = try collectTopLevelFnNames(allocator, source);
    defer allocator.free(names);

    var suffix_buf: [24]u8 = undefined;
    const helper_suffix = try std.fmt.bufPrint(&suffix_buf, "_f{d}", .{slot});
    var contract_suffix_buf: [24]u8 = undefined;
    const contract_suffix = try std.fmt.bufPrint(&contract_suffix_buf, "_{d}", .{slot});

    var i: usize = 0;
    outer: while (i < source.len) {
        for (names) |name| {
            if (matchesWordAt(source, i, name)) {
                try out.appendSlice(allocator, name);
                var is_contract_fn = false;
                for (contract_fn_names) |cname| {
                    if (std.mem.eql(u8, name, cname)) is_contract_fn = true;
                }
                if (is_contract_fn) {
                    try out.appendSlice(allocator, contract_suffix);
                } else {
                    try out.appendSlice(allocator, helper_suffix);
                }
                i += name.len;
                continue :outer;
            }
        }
        try out.append(allocator, source[i]);
        i += 1;
    }
}

fn appendFormulaWrapper(allocator: std.mem.Allocator, out: *std.ArrayList(u8), slot: usize) !void {
    const wrapper = try std.fmt.allocPrint(allocator,
        \\
        \\fn formula_{0}(pos: vec3f, p: array<f32, 8>) -> vec2f {{
        \\    var carry = IterCarry(pos, 1.0);
        \\    var trap = 1e6;
        \\    let iters = de_iterations_{0}(p);
        \\    for (var it = 0; it < iters; it++) {{
        \\        carry = de_step_{0}(carry, pos, p);
        \\        trap = min(trap, length(carry.z));
        \\    }}
        \\    return vec2f(de_finalize_{0}(carry), trap);
        \\}}
        \\
    , .{slot});
    defer allocator.free(wrapper);
    try out.appendSlice(allocator, wrapper);
}

const total_formula_slots = max_instances + max_instances * max_mixins;

fn mixinSlot(instance: usize, mixin: usize) usize {
    return max_instances + instance * max_mixins + mixin;
}

fn appendDispatchers(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
    try out.appendSlice(allocator, "\nfn eval_step(slot: i32, carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {\n");
    for (0..total_formula_slots) |slot| {
        const branch = try std.fmt.allocPrint(
            allocator,
            "    {s} (slot == {d}) {{ return de_step_{d}(carry, pos, p); }}\n",
            .{ if (slot == 0) "if" else "else if", slot, slot },
        );
        defer allocator.free(branch);
        try out.appendSlice(allocator, branch);
    }
    try out.appendSlice(allocator, "    return carry;\n}\n");

    try out.appendSlice(allocator, "\nfn eval_finalize(slot: i32, carry: IterCarry) -> f32 {\n");
    for (0..total_formula_slots) |slot| {
        const branch = try std.fmt.allocPrint(
            allocator,
            "    {s} (slot == {d}) {{ return de_finalize_{d}(carry); }}\n",
            .{ if (slot == 0) "if" else "else if", slot, slot },
        );
        defer allocator.free(branch);
        try out.appendSlice(allocator, branch);
    }
    try out.appendSlice(allocator, "    return 0.0;\n}\n");
}

const warp_impl_source =
    \\fn warp_domain(p: vec3f) -> Warped {
    \\    var q = p;
    \\    var scale = 1.0;
    \\    for (var i = 0; i < i32(u.warp_count); i++) {
    \\        let w = u.warps[i];
    \\        let inf = warp_influence(w, p);
    \\        if (inf <= 1e-4) {
    \\            continue;
    \\        }
    \\        q = mix(q, coord_warp_raw(w, q), inf);
    \\        let band = inf / max(w.strength, 1e-4);
    \\        let lip = 1.0 + inf * w.lip_mult + w.strength * w.lip_grad * (4.0 * band * (1.0 - band));
    \\        scale *= w.safety / lip;
    \\    }
    \\    return Warped(q, scale);
    \\}
    \\
    \\fn warp_step_limit(p: vec3f) -> f32 {
    \\    var lim = 1e30;
    \\    for (var i = 0; i < i32(u.warp_count); i++) {
    \\        let w = u.warps[i];
    \\        if (w.falloff > 1e-4 || i32(w.region_kind + 0.5) == 2) {
    \\            continue;
    \\        }
    \\        lim = min(lim, max(abs(warp_region_de(w, p)), 1e-4));
    \\    }
    \\    return lim;
    \\}
;

const warp_stub_source =
    \\fn warp_domain(p: vec3f) -> Warped {
    \\    return Warped(p, 1.0);
    \\}
    \\fn warp_step_limit(p: vec3f) -> f32 {
    \\    return 1e30;
    \\}
;

fn assembleShaderSource(allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, warps_enabled: bool) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var rest: []const u8 = shader_template;
    inline for (0..max_instances) |i| {
        const marker = std.fmt.comptimePrint("@@FORMULA_{d}@@", .{i});
        const idx = std.mem.indexOf(u8, rest, marker) orelse return error.MissingFormulaMarker;
        try out.appendSlice(allocator, rest[0..idx]);
        try appendRenamedFormula(allocator, &out, formula_sources[i], i);
        try appendFormulaWrapper(allocator, &out, i);
        rest = rest[idx + marker.len ..];
    }
    inline for (0..max_instances) |i| {
        const marker = std.fmt.comptimePrint("@@MIXINS_{d}@@", .{i});
        const idx = std.mem.indexOf(u8, rest, marker) orelse return error.MissingFormulaMarker;
        try out.appendSlice(allocator, rest[0..idx]);
        inline for (0..max_mixins) |j| {
            try appendRenamedFormula(allocator, &out, mixin_sources[i][j], mixinSlot(i, j));
        }
        rest = rest[idx + marker.len ..];
    }
    {
        const marker = "@@DISPATCHERS@@";
        const idx = std.mem.indexOf(u8, rest, marker) orelse return error.MissingFormulaMarker;
        try out.appendSlice(allocator, rest[0..idx]);
        try appendDispatchers(allocator, &out);
        rest = rest[idx + marker.len ..];
    }
    {
        const marker = "@@WARPS@@";
        const idx = std.mem.indexOf(u8, rest, marker) orelse return error.MissingFormulaMarker;
        try out.appendSlice(allocator, rest[0..idx]);
        try out.appendSlice(allocator, if (warps_enabled) warp_impl_source else warp_stub_source);
        rest = rest[idx + marker.len ..];
    }
    try out.appendSlice(allocator, rest);
    return out.toOwnedSlice(allocator);
}

pub const SampleSet = union(enum) {
    repeat: struct { uniforms: Uniforms, count: u32 },
    per_sample: []const Uniforms,

    pub fn count(self: *const SampleSet) u32 {
        return switch (self.*) {
            .repeat => |r| @max(r.count, 1),
            .per_sample => |list| @intCast(list.len),
        };
    }

    pub fn is2d(self: *const SampleSet) bool {
        if (self.count() == 0) return false;
        return self.at(0).mode_2d > 0.5;
    }

    fn at(self: *const SampleSet, index: u32) *const Uniforms {
        return switch (self.*) {
            .repeat => |*r| &r.uniforms,
            .per_sample => |list| &list[index],
        };
    }
};

pub const RenderProgress = struct {
    callback: *const fn (frac: f32, userdata: ?*anyopaque) void,
    userdata: ?*anyopaque = null,
    range_start: f32 = 0.0,
    range_end: f32 = 1.0,
    cancel_flag: ?*const bool = null,
};

const ProgressTracker = struct {
    progress: ?RenderProgress,
    total: u32,
    done: u32 = 0,

    fn tick(self: *ProgressTracker) void {
        self.done += 1;
        const p = self.progress orelse return;
        const stride = @max(self.total / 200, 1);
        if (self.done % stride != 0 and self.done != self.total) return;
        const frac_local = @as(f32, @floatFromInt(self.done)) / @as(f32, @floatFromInt(self.total));
        const frac = p.range_start + (p.range_end - p.range_start) * frac_local;
        p.callback(frac, p.userdata);
    }
};

fn countSubTiles(width: u32, height: u32, tile_dim: u32) u32 {
    const sub_tile_size: u32 = 128;
    var total: u32 = 0;
    var tile_y: u32 = 0;
    while (tile_y < height) : (tile_y += tile_dim) {
        const tile_h = @min(tile_dim, height - tile_y);
        var tile_x: u32 = 0;
        while (tile_x < width) : (tile_x += tile_dim) {
            const tile_w = @min(tile_dim, width - tile_x);
            const sub_tiles_x = (tile_w + sub_tile_size - 1) / sub_tile_size;
            const sub_tiles_y = (tile_h + sub_tile_size - 1) / sub_tile_size;
            total += sub_tiles_x * sub_tiles_y;
        }
    }
    return @max(total, 1);
}

fn tileTransform(full_width: u32, full_height: u32, tile_x: u32, tile_y: u32, tile_w: u32, tile_h: u32) struct { scale: [2]f32, bias: [2]f32 } {
    const fw: f32 = @floatFromInt(@max(full_width, 1));
    const fh: f32 = @floatFromInt(@max(full_height, 1));
    const tw: f32 = @floatFromInt(tile_w);
    const th: f32 = @floatFromInt(tile_h);
    const tx: f32 = @floatFromInt(tile_x);
    const ty: f32 = @floatFromInt(tile_y);
    return .{
        .scale = .{ tw / fw, th / fh },
        .bias = .{ (2 * tx + tw) / fw - 1, 1 - (2 * ty + th) / fh },
    };
}

const MapState = struct {
    done: bool = false,
    status: wgpu.WGPUMapAsyncStatus = wgpu.WGPUMapAsyncStatus_Error,
};

fn onBufferMapped(
    status: wgpu.WGPUMapAsyncStatus,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;
    const state: *MapState = @ptrCast(@alignCast(userdata1.?));
    state.status = status;
    state.done = true;
}

const WorkDoneState = struct {
    done: bool = false,
    status: wgpu.WGPUQueueWorkDoneStatus = wgpu.WGPUQueueWorkDoneStatus_Error,
};

fn onQueueWorkDone(
    status: wgpu.WGPUQueueWorkDoneStatus,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;
    const state: *WorkDoneState = @ptrCast(@alignCast(userdata1.?));
    state.status = status;
    state.done = true;
}

const gpu_work_timeout_spins: u32 = 600_000;

fn waitForQueueIdle(ctx: *const Context) !void {
    var state = WorkDoneState{};
    const callback_info = wgpu.WGPUQueueWorkDoneCallbackInfo{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = onQueueWorkDone,
        .userdata1 = &state,
        .userdata2 = null,
    };
    _ = wgpu.wgpuQueueOnSubmittedWorkDone(ctx.queue, callback_info);
    _ = webgpu_context.pollUntil(ctx.instance, &state.done, gpu_work_timeout_spins);
    if (!state.done or state.status != wgpu.WGPUQueueWorkDoneStatus_Success) {
        return error.QueueWorkDoneFailed;
    }
}

const ComputeBindGroup = struct { index: u32, group: wgpu.WGPUBindGroup };

fn runComputePass(
    ctx: *const Context,
    label: []const u8,
    pipeline: wgpu.WGPUComputePipeline,
    bind_groups: []const ComputeBindGroup,
    workgroups: [3]u32,
) !void {
    const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
    const pass = wgpu.wgpuCommandEncoderBeginComputePass(encoder, &wgpu.WGPUComputePassDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .timestampWrites = null,
    }).?;
    wgpu.wgpuComputePassEncoderSetPipeline(pass, pipeline);
    for (bind_groups) |bg| {
        wgpu.wgpuComputePassEncoderSetBindGroup(pass, bg.index, bg.group, 0, null);
    }
    wgpu.wgpuComputePassEncoderDispatchWorkgroups(pass, workgroups[0], workgroups[1], workgroups[2]);
    wgpu.wgpuComputePassEncoderEnd(pass);
    wgpu.wgpuComputePassEncoderRelease(pass);

    const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
    wgpu.wgpuCommandEncoderRelease(encoder);
    wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
    wgpu.wgpuCommandBufferRelease(cmd_buffer);
    try waitForQueueIdle(ctx);
}

fn hashSources(formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, warps_enabled: bool) u64 {
    var h = std.hash.Wyhash.init(0);
    h.update(std.mem.asBytes(&warps_enabled));
    for (formula_sources) |s| {
        h.update(std.mem.asBytes(&s.len));
        h.update(s);
    }
    for (mixin_sources) |per_instance| {
        for (per_instance) |s| {
            h.update(std.mem.asBytes(&s.len));
            h.update(s);
        }
    }
    return h.final();
}

const pipeline_cache_capacity = 12;

const PipelinePair = struct {
    march: wgpu.WGPURenderPipeline = null,
    slice: wgpu.WGPURenderPipeline = null,
    simple: wgpu.WGPURenderPipeline = null,
    select: wgpu.WGPURenderPipeline = null,
    build_accel: wgpu.WGPUComputePipeline = null,
    trace_photons: wgpu.WGPUComputePipeline = null,
    clear_photons: wgpu.WGPUComputePipeline = null,
    alloc_photons: wgpu.WGPUComputePipeline = null,

    fn isComplete(self: PipelinePair) bool {
        return self.march != null and self.slice != null and self.simple != null and self.select != null and
            self.build_accel != null and self.trace_photons != null and
            self.clear_photons != null and self.alloc_photons != null;
    }

    fn release(self: PipelinePair) void {
        if (self.march != null) wgpu.wgpuRenderPipelineRelease(self.march);
        if (self.slice != null) wgpu.wgpuRenderPipelineRelease(self.slice);
        if (self.simple != null) wgpu.wgpuRenderPipelineRelease(self.simple);
        if (self.select != null) wgpu.wgpuRenderPipelineRelease(self.select);
        if (self.build_accel != null) wgpu.wgpuComputePipelineRelease(self.build_accel);
        if (self.trace_photons != null) wgpu.wgpuComputePipelineRelease(self.trace_photons);
        if (self.clear_photons != null) wgpu.wgpuComputePipelineRelease(self.clear_photons);
        if (self.alloc_photons != null) wgpu.wgpuComputePipelineRelease(self.alloc_photons);
    }
};

pub const RenderMode = enum { march, slice, simple };

const PipelineCacheEntry = struct {
    hash: u64,
    pipelines: PipelinePair,
    last_used: u64,
};

//while shader compiles nothing must touch wgpu or it will cry like a baby and explode
const PendingRebuild = struct {
    thread: std.Thread,
    shared: *Shared,
};

const Shared = struct {
    allocator: std.mem.Allocator,
    ctx: *const Context,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    accel_pipeline_layout: wgpu.WGPUPipelineLayout,
    photon_pipeline_layout: wgpu.WGPUPipelineLayout,
    formula_sources: [max_instances][]u8,
    mixin_sources: [max_instances][max_mixins][]u8,
    warps_enabled: bool,
    hash: u64,
    requester: ?*anyopaque,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    ok: bool = false,
    pipelines: PipelinePair = .{},
    err_buf: [512]u8 = undefined,
    err_len: usize = 0,
    total_ms: u64 = 0,
    source_len: usize = 0,

    fn freeSources(self: *Shared) void {
        for (self.formula_sources) |s| self.allocator.free(s);
        for (self.mixin_sources) |per_instance| {
            for (per_instance) |s| self.allocator.free(s);
        }
    }
};

pub const RebuildOutcome = struct {
    ok: bool,
    err_message: []const u8,
    requester: ?*anyopaque,
};

pub const RebuildStart = enum { cache_hit, started };

fn copyErr(shared: *Shared, msg: []const u8) usize {
    const n = @min(msg.len, shared.err_buf.len);
    @memcpy(shared.err_buf[0..n], msg[0..n]);
    return n;
}

const Layouts = struct {
    render: wgpu.WGPUPipelineLayout,
    accel: wgpu.WGPUPipelineLayout,
    photon: wgpu.WGPUPipelineLayout,
};

fn buildPipelines(ctx: *const Context, layouts: Layouts, source: []const u8) !PipelinePair {
    g_error_sink.reset();
    var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
        .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
        .code = sv(source),
    };
    const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader_desc_wgsl),
        .label = sv("fractal shader"),
    }) orelse return error.ShaderModuleCreationFailed;
    defer wgpu.wgpuShaderModuleRelease(module);

    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    if (g_error_sink.has_error) return error.ShaderCompileFailed;

    const pipelines = FractalRenderer.createPipelinePair(ctx, layouts, module);
    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    if (!pipelines.isComplete() or g_error_sink.has_error) {
        pipelines.release();
        return error.PipelineCreationFailed;
    }
    return pipelines;
}

fn compileWorker(shared: *Shared) void {
    defer shared.done.store(true, .release);
    const started = sdl.SDL_GetTicks();

    var formula_sources: [max_instances][]const u8 = undefined;
    for (0..max_instances) |i| formula_sources[i] = shared.formula_sources[i];
    var mixin_sources: [max_instances][max_mixins][]const u8 = undefined;
    for (0..max_instances) |i| {
        for (0..max_mixins) |j| mixin_sources[i][j] = shared.mixin_sources[i][j];
    }

    const source = assembleShaderSource(shared.allocator, formula_sources, mixin_sources, shared.warps_enabled) catch |err| {
        shared.err_len = copyErr(shared, @errorName(err));
        return;
    };
    defer shared.allocator.free(source);
    shared.source_len = source.len;

    const layouts = Layouts{ .render = shared.pipeline_layout, .accel = shared.accel_pipeline_layout, .photon = shared.photon_pipeline_layout };
    shared.pipelines = buildPipelines(shared.ctx, layouts, source) catch |err| {
        const copied = copyErr(shared, g_error_sink.message());
        shared.err_len = if (copied > 0) copied else copyErr(shared, @errorName(err));
        return;
    };
    shared.ok = true;
    shared.total_ms = @intCast(sdl.SDL_GetTicks() -| started);
}

pub const FractalRenderer = struct {
    pipelines: PipelinePair,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    accel_pipeline_layout: wgpu.WGPUPipelineLayout,
    photon_pipeline_layout: wgpu.WGPUPipelineLayout,
    bind_group: wgpu.WGPUBindGroup,
    uniform_buffer: wgpu.WGPUBuffer,

    accel: AccelGrid,
    accel_enabled: bool = true,
    accel_safety: f32 = 0.92,

    photon_map: PhotonMap,
    photon_settings: photon_state.PhotonSettings = .{},

    sky: SkyTexture,
    sky_settings: sky_state.SkyState = .{},

    warps_enabled: bool = false,

    pipeline_cache: [pipeline_cache_capacity]?PipelineCacheEntry = @splat(null),
    cache_clock: u64 = 0,

    pending: ?PendingRebuild = null,
    last_err_buf: [512]u8 = undefined,
    last_err_len: usize = 0,

    offscreen_texture: wgpu.WGPUTexture,
    offscreen_view: wgpu.WGPUTextureView,
    offscreen_width: u32,
    offscreen_height: u32,

    select_texture: wgpu.WGPUTexture,
    select_view: wgpu.WGPUTextureView,
    select_generation: u32,

    pick_texture: wgpu.WGPUTexture,
    pick_view: wgpu.WGPUTextureView,
    pick_buffer: wgpu.WGPUBuffer,

    sampler: wgpu.WGPUSampler,
    blit_pipeline: wgpu.WGPURenderPipeline,
    blit_pipeline_layout: wgpu.WGPUPipelineLayout,
    blit_bind_group_layout: wgpu.WGPUBindGroupLayout,
    blit_bind_group: wgpu.WGPUBindGroup,

    pub fn init(ctx: *const Context, allocator: std.mem.Allocator) !FractalRenderer {
        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fractal uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(Uniforms),
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;

        const bgl_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Vertex | wgpu.WGPUShaderStage_Compute,
            .bindingArraySize = 0,
            .buffer = .{
                .nextInChain = null,
                .type = wgpu.WGPUBufferBindingType_Uniform,
                .hasDynamicOffset = 0,
                .minBindingSize = @sizeOf(Uniforms),
            },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{bgl_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        defer wgpu.wgpuBindGroupLayoutRelease(bind_group_layout);

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fractal bind group"),
            .layout = bind_group_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = 0,
                .buffer = uniform_buffer,
                .offset = 0,
                .size = @sizeOf(Uniforms),
                .sampler = null,
                .textureView = null,
            }},
        }) orelse return error.BindGroupCreationFailed;

        var accel_grid = try AccelGrid.init(ctx);
        errdefer accel_grid.deinit();

        var photon_map = try PhotonMap.init(ctx);
        errdefer photon_map.deinit();

        var sky_tex = try SkyTexture.init(ctx);
        errdefer sky_tex.deinit();

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal pipeline layout"),
            .bindGroupLayoutCount = 4,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, accel_grid.render_layout, photon_map.render_layout, sky_tex.layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        const accel_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("accel build pipeline layout"),
            .bindGroupLayoutCount = 2,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, accel_grid.compute_layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        const photon_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("photon trace pipeline layout"),
            .bindGroupLayoutCount = 4,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, accel_grid.render_layout, photon_map.compute_layout, sky_tex.layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        const sampler = wgpu.wgpuDeviceCreateSampler(ctx.device, &webgpu_context.linearSamplerDesc(sv("fractal offscreen sampler"))) orelse return error.SamplerCreationFailed;

        const blit_bgl_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            .{
                .nextInChain = null,
                .binding = 0,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
                .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 1,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = .{ .nextInChain = null, .sampleType = wgpu.WGPUTextureSampleType_Float, .viewDimension = wgpu.WGPUTextureViewDimension_2D, .multisampled = 0 },
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
        };
        const blit_bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal blit bind group layout"),
            .entryCount = blit_bgl_entries.len,
            .entries = &blit_bgl_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;

        const blit_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal blit pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{blit_bind_group_layout},
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        var blit_shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(blit_shader_src),
        };
        const blit_module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&blit_shader_desc_wgsl),
            .label = sv("fractal blit shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        defer wgpu.wgpuShaderModuleRelease(blit_module);

        const blit_pipeline = createPipeline(ctx, blit_pipeline_layout, blit_module, "fractal blit pipeline", "fs_main", ctx.surface_format, false) orelse
            return error.RenderPipelineCreationFailed;

        const pick_buffer_size: u64 = 256; // bytesPerRow must be a multiple of 256
        const pick_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal pick target"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_CopySrc,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = 1, .height = 1, .depthOrArrayLayers = 1 },
            .format = select_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        errdefer wgpu.wgpuTextureRelease(pick_texture);
        const pick_view = wgpu.wgpuTextureCreateView(pick_texture, null) orelse return error.TextureViewCreationFailed;
        errdefer wgpu.wgpuTextureViewRelease(pick_view);
        const pick_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fractal pick readback"),
            .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_MapRead,
            .size = pick_buffer_size,
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;
        errdefer wgpu.wgpuBufferRelease(pick_buffer);

        var self = FractalRenderer{
            .pipelines = .{},
            .pipeline_layout = pipeline_layout,
            .accel_pipeline_layout = accel_pipeline_layout,
            .photon_pipeline_layout = photon_pipeline_layout,
            .accel = accel_grid,
            .photon_map = photon_map,
            .sky = sky_tex,
            .bind_group = bind_group,
            .uniform_buffer = uniform_buffer,
            .offscreen_texture = null,
            .offscreen_view = null,
            .offscreen_width = 0,
            .offscreen_height = 0,
            .select_texture = null,
            .select_view = null,
            .select_generation = 0,
            .pick_texture = pick_texture,
            .pick_view = pick_view,
            .pick_buffer = pick_buffer,
            .sampler = sampler,
            .blit_pipeline = blit_pipeline,
            .blit_pipeline_layout = blit_pipeline_layout,
            .blit_bind_group_layout = blit_bind_group_layout,
            .blit_bind_group = null,
        };
        self.ensureOffscreenSize(ctx, @max(ctx.width, 1), @max(ctx.height, 1));
        _ = self.accel.ensureSize(ctx, accel.default_resolution, accel.default_levels);
        _ = self.photon_map.ensureSize(ctx, photons.default_grid_log2);

        var default_sources: [max_instances][]const u8 = undefined;
        default_sources[0] = builtin_formula_source;
        for (default_sources[1..]) |*s| s.* = filler_formula_source;
        var default_mixin_sources: [max_instances][max_mixins][]const u8 = undefined;
        for (0..max_instances) |i| {
            for (0..max_mixins) |j| default_mixin_sources[i][j] = filler_formula_source;
        }
        try self.rebuild(ctx, allocator, default_sources, default_mixin_sources);
        return self;
    }

    pub fn deinit(self: *FractalRenderer) void {
        if (self.pending) |*p| {
            p.thread.join();
            p.shared.freeSources();
            p.shared.pipelines.release();
            p.shared.allocator.destroy(p.shared);
            self.pending = null;
        }

        for (self.pipeline_cache) |slot| {
            if (slot) |entry| entry.pipelines.release();
        }
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.accel_pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.photon_pipeline_layout);
        self.accel.deinit();
        self.photon_map.deinit();
        self.sky.deinit();
        wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuBufferRelease(self.uniform_buffer);

        wgpu.wgpuBindGroupRelease(self.blit_bind_group);
        wgpu.wgpuTextureViewRelease(self.offscreen_view);
        wgpu.wgpuTextureRelease(self.offscreen_texture);
        if (self.select_view != null) wgpu.wgpuTextureViewRelease(self.select_view);
        if (self.select_texture != null) wgpu.wgpuTextureRelease(self.select_texture);
        wgpu.wgpuBufferRelease(self.pick_buffer);
        wgpu.wgpuTextureViewRelease(self.pick_view);
        wgpu.wgpuTextureRelease(self.pick_texture);
        wgpu.wgpuSamplerRelease(self.sampler);
        wgpu.wgpuRenderPipelineRelease(self.blit_pipeline);
        wgpu.wgpuPipelineLayoutRelease(self.blit_pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.blit_bind_group_layout);
    }

    pub fn ensureOffscreenSize(self: *FractalRenderer, ctx: *const Context, width: u32, height: u32) void {
        const w = @max(width, 1);
        const h = @max(height, 1);
        if (w == self.offscreen_width and h == self.offscreen_height) return;

        const new_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal offscreen"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            .format = hdr_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return;
        const new_view = wgpu.wgpuTextureCreateView(new_texture, null) orelse {
            wgpu.wgpuTextureRelease(new_texture);
            return;
        };
        const new_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fractal blit bind group"),
            .layout = self.blit_bind_group_layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = self.sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = new_view },
            },
        }) orelse {
            wgpu.wgpuTextureViewRelease(new_view);
            wgpu.wgpuTextureRelease(new_texture);
            return;
        };

        if (self.offscreen_texture != null) {
            wgpu.wgpuBindGroupRelease(self.blit_bind_group);
            wgpu.wgpuTextureViewRelease(self.offscreen_view);
            wgpu.wgpuTextureRelease(self.offscreen_texture);
        }
        self.offscreen_texture = new_texture;
        self.offscreen_view = new_view;
        self.blit_bind_group = new_bind_group;
        self.offscreen_width = w;
        self.offscreen_height = h;

        if (self.select_view != null) wgpu.wgpuTextureViewRelease(self.select_view);
        if (self.select_texture != null) wgpu.wgpuTextureRelease(self.select_texture);
        self.select_generation +%= 1;
        self.select_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal selection mask"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            .format = select_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        });
        self.select_view = if (self.select_texture != null) wgpu.wgpuTextureCreateView(self.select_texture, null) else null;
        if (self.select_view == null and self.select_texture != null) {
            wgpu.wgpuTextureRelease(self.select_texture);
            self.select_texture = null;
        }
    }

    fn createPipeline(ctx: *const Context, pipeline_layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, label: []const u8, fragment_entry: []const u8, target_format: wgpu.WGPUTextureFormat, enable_blend: bool) wgpu.WGPURenderPipeline {
        const blend_state = wgpu.WGPUBlendState{
            .color = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_Constant, .dstFactor = wgpu.WGPUBlendFactor_OneMinusConstant },
            .alpha = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_One, .dstFactor = wgpu.WGPUBlendFactor_Zero },
        };
        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = target_format,
            .blend = if (enable_blend) &blend_state else null,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };
        return wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .layout = pipeline_layout,
            .vertex = .{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv("vs_main"),
                .constantCount = 0,
                .constants = null,
                .bufferCount = 0,
                .buffers = null,
            },
            .primitive = webgpu_context.default_primitive_state,
            .depthStencil = null,
            .multisample = webgpu_context.default_multisample_state,
            .fragment = &wgpu.WGPUFragmentState{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv(fragment_entry),
                .constantCount = 0,
                .constants = null,
                .targetCount = 1,
                .targets = &[_]wgpu.WGPUColorTargetState{color_target},
            },
        });
    }

    fn createPipelinePair(ctx: *const Context, lay: Layouts, module: wgpu.WGPUShaderModule) PipelinePair {
        return .{
            .march = createPipeline(ctx, lay.render, module, "fractal pipeline", "fs_main", hdr_format, true),
            .slice = createPipeline(ctx, lay.render, module, "fractal 2D slice pipeline", "fs_slice", hdr_format, true),
            .simple = createPipeline(ctx, lay.render, module, "fractal simple render pipeline", "fs_simple", hdr_format, true),
            .select = createPipeline(ctx, lay.render, module, "fractal selection id pipeline", "fs_select", select_format, false),
            .build_accel = createComputePipeline(ctx, lay.accel, module, "accel build pipeline", "cs_build_accel"),
            .trace_photons = createComputePipeline(ctx, lay.photon, module, "photon trace pipeline", "cs_trace_photons"),
            .clear_photons = createComputePipeline(ctx, lay.photon, module, "photon clear pipeline", "cs_clear_photons"),
            .alloc_photons = createComputePipeline(ctx, lay.photon, module, "photon alloc pipeline", "cs_alloc_photons"),
        };
    }

    fn createComputePipeline(
        ctx: *const Context,
        layout: wgpu.WGPUPipelineLayout,
        module: wgpu.WGPUShaderModule,
        label: []const u8,
        entry: []const u8,
    ) wgpu.WGPUComputePipeline {
        return wgpu.wgpuDeviceCreateComputePipeline(ctx.device, &wgpu.WGPUComputePipelineDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .layout = layout,
            .compute = .{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv(entry),
                .constantCount = 0,
                .constants = null,
            },
        });
    }

    fn findCachedPipeline(self: *FractalRenderer, hash: u64) ?PipelinePair {
        for (&self.pipeline_cache) |*slot| {
            if (slot.*) |*entry| {
                if (entry.hash == hash) {
                    self.cache_clock += 1;
                    entry.last_used = self.cache_clock;
                    return entry.pipelines;
                }
            }
        }
        return null;
    }

    fn cachePipeline(self: *FractalRenderer, hash: u64, pipelines: PipelinePair) void {
        self.cache_clock += 1;
        for (&self.pipeline_cache) |*slot| {
            if (slot.* == null) {
                slot.* = .{ .hash = hash, .pipelines = pipelines, .last_used = self.cache_clock };
                return;
            }
        }
        var victim_idx: usize = 0;
        var victim_used: u64 = std.math.maxInt(u64);
        for (self.pipeline_cache, 0..) |slot, i| {
            if (slot) |entry| {
                if (entry.last_used < victim_used) {
                    victim_used = entry.last_used;
                    victim_idx = i;
                }
            }
        }
        if (self.pipeline_cache[victim_idx]) |old| old.pipelines.release();
        self.pipeline_cache[victim_idx] = .{ .hash = hash, .pipelines = pipelines, .last_used = self.cache_clock };
    }

    fn pipelineLayouts(self: *const FractalRenderer) Layouts {
        return .{ .render = self.pipeline_layout, .accel = self.accel_pipeline_layout, .photon = self.photon_pipeline_layout };
    }

    pub fn rebuild(self: *FractalRenderer, ctx: *const Context, allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8) !void {
        const hash = hashSources(formula_sources, mixin_sources, self.warps_enabled);
        if (self.findCachedPipeline(hash)) |pipelines| {
            std.debug.print("[stage] rebuild: cache hit (hash={x})\n", .{hash});
            self.pipelines = pipelines;
            return;
        }

        const started = sdl.SDL_GetTicks();
        const source = try assembleShaderSource(allocator, formula_sources, mixin_sources, self.warps_enabled);
        defer allocator.free(source);
        const built = try buildPipelines(ctx, self.pipelineLayouts(), source);
        std.debug.print("[stage] rebuild: compiled {d} bytes in {d}ms\n", .{ source.len, sdl.SDL_GetTicks() -| started });
        self.pipelines = built;
        self.cachePipeline(hash, built);
    }

    pub fn rebuildAsync(self: *FractalRenderer, ctx: *const Context, allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, requester: ?*anyopaque) !RebuildStart {
        const hash = hashSources(formula_sources, mixin_sources, self.warps_enabled);
        if (self.findCachedPipeline(hash)) |pipelines| {
            std.debug.print("[stage] rebuildAsync: cache hit (hash={x})\n", .{hash});
            self.pipelines = pipelines;
            return .cache_hit;
        }

        if (self.pending != null) _ = self.pollRebuild(true);

        const shared = try allocator.create(Shared);
        errdefer allocator.destroy(shared);
        shared.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .pipeline_layout = self.pipeline_layout,
            .accel_pipeline_layout = self.accel_pipeline_layout,
            .photon_pipeline_layout = self.photon_pipeline_layout,
            .formula_sources = undefined,
            .mixin_sources = undefined,
            .warps_enabled = self.warps_enabled,
            .hash = hash,
            .requester = requester,
        };
        var formula_dup_count: usize = 0;
        errdefer for (shared.formula_sources[0..formula_dup_count]) |s| allocator.free(s);
        for (0..max_instances) |i| {
            shared.formula_sources[i] = try allocator.dupe(u8, formula_sources[i]);
            formula_dup_count = i + 1;
        }

        var mixin_instances_done: usize = 0;
        errdefer for (shared.mixin_sources[0..mixin_instances_done]) |per_instance| {
            for (per_instance) |s| allocator.free(s);
        };
        for (0..max_instances) |i| {
            var mixin_dup_count: usize = 0;
            errdefer for (shared.mixin_sources[i][0..mixin_dup_count]) |s| allocator.free(s);
            for (0..max_mixins) |j| {
                shared.mixin_sources[i][j] = try allocator.dupe(u8, mixin_sources[i][j]);
                mixin_dup_count = j + 1;
            }
            mixin_instances_done = i + 1;
        }

        const thread = try std.Thread.spawn(.{}, compileWorker, .{shared});
        self.pending = .{ .thread = thread, .shared = shared };
        std.debug.print("[stage] rebuildAsync: spawned background compile (hash={x})\n", .{hash});
        return .started;
    }

    pub fn isCompiling(self: *const FractalRenderer) bool {
        return self.pending != null;
    }

    pub fn pollRebuild(self: *FractalRenderer, wait_blocking: bool) ?RebuildOutcome {
        var p = self.pending orelse return null;
        if (!wait_blocking and !p.shared.done.load(.acquire)) return null;

        p.thread.join();
        self.pending = null;

        const shared = p.shared;
        self.last_err_len = @min(shared.err_len, self.last_err_buf.len);
        @memcpy(self.last_err_buf[0..self.last_err_len], shared.err_buf[0..self.last_err_len]);

        if (shared.ok) {
            self.pipelines = shared.pipelines;
            self.cachePipeline(shared.hash, shared.pipelines);
        }

        const outcome = RebuildOutcome{
            .ok = shared.ok,
            .err_message = self.last_err_buf[0..self.last_err_len],
            .requester = shared.requester,
        };
        std.debug.print("[stage] pollRebuild: background compile {s} (hash={x}) {d}ms source={d} bytes {s}\n", .{
            if (shared.ok) "succeeded" else "failed",
            shared.hash,
            shared.total_ms,
            shared.source_len,
            if (shared.ok) "" else outcome.err_message,
        });

        shared.freeSources();
        shared.allocator.destroy(shared);

        return outcome;
    }

    pub fn updateUniforms(self: *FractalRenderer, ctx: *const Context, uniforms: Uniforms) void {
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer, 0, &uniforms, @sizeOf(Uniforms));
    }

    pub fn stampAccelUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        const usable = self.accel_enabled and self.accel.isAllocated() and self.accel.valid;
        uniforms.accel_enabled = if (usable) 1.0 else 0.0;
        uniforms.accel_levels = @floatFromInt(self.accel.levels);
        uniforms.accel_res = @floatFromInt(self.accel.resolution);
        uniforms.accel_safety = self.accel_safety;
        uniforms.accel_params = self.accel.params;
    }

    pub fn stampPhotonUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        const usable = self.photon_settings.enabled and self.photon_map.isAllocated() and self.photon_map.valid;
        uniforms.photon_enabled = if (usable) 1.0 else 0.0;
        uniforms.photon_radius = @max(self.photon_settings.radius, 1e-4);
        uniforms.photon_cell = self.photon_settings.cellSize();
        uniforms.photon_table = @floatFromInt(self.photon_map.buckets);
        uniforms.photon_paths = @floatFromInt(self.photon_settings.pathCount());
        uniforms.photon_intensity = self.photon_settings.intensity;
        uniforms.light_bounces = self.photon_settings.bounces;
        uniforms.photon_centre = uniforms.camera_pos;
        uniforms.photon_extent = @max(uniforms.max_dist, 1e-3);
        uniforms.photon_pool = @floatFromInt(self.photon_map.poolPhotons());
        uniforms.photon_cap_surface = @floatFromInt(self.photon_map.stored_cap_surface);
        uniforms.photon_volume_scale = self.photon_map.stored_volume_scale;
        uniforms.photon_fixed_unit = self.photon_map.stored_fixed_unit;
        uniforms.photon_hash_salt = self.photon_map.stored_hash_salt;
        uniforms.photon_dispersion_soft = self.photon_settings.dispersionSoftRadians();
    }

    fn liveVolumeScale(self: *const FractalRenderer) f32 {
        return std.math.clamp(self.photon_settings.volume_scale, 1.0, 8.0);
    }

    pub fn stampSkyUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        uniforms.sky = self.sky_settings.toGpu(self.sky.loaded);
    }

    pub fn buildAccel(self: *FractalRenderer, ctx: *const Context, scene: Uniforms) !void {
        if (!self.accel.isAllocated() or self.pipelines.build_accel == null) return error.AccelNotReady;

        const started_ms = sdl.SDL_GetTicks();
        const res = self.accel.resolution;
        const levels = self.accel.levels;

        self.accel.centre = scene.camera_pos;
        self.accel.params = accel.placeCascades(scene.camera_pos, scene.max_dist, levels, res);

        var build_uniforms = scene;
        build_uniforms.accel_enabled = 0;
        build_uniforms.accel_levels = @floatFromInt(levels);
        build_uniforms.accel_res = @floatFromInt(res);
        build_uniforms.accel_safety = self.accel_safety;
        build_uniforms.accel_params = self.accel.params;

        const total_layers = res * levels;
        const layers_per_slab = accel.layersPerSubmit(res);
        const groups_xy = res / accel.workgroup_dim;

        var z: u32 = 0;
        while (z < total_layers) : (z += layers_per_slab) {
            const slab = @min(layers_per_slab, total_layers - z);
            const groups_z = (slab + accel.workgroup_dim - 1) / accel.workgroup_dim;

            build_uniforms.accel_z_offset = @floatFromInt(z);
            self.updateUniforms(ctx, build_uniforms);

            try runComputePass(ctx, "accel build pass", self.pipelines.build_accel, &.{
                .{ .index = 0, .group = self.bind_group },
                .{ .index = 1, .group = self.accel.compute_bind_group },
            }, .{ groups_xy, groups_xy, groups_z });
        }

        self.accel.valid = true;
        self.accel.last_build_ms = @intCast(sdl.SDL_GetTicks() -| started_ms);
        std.debug.print(
            "[accel] built {d}^3 x {d} cascades ({d} voxels, finest cell {d:.4}) in {d}ms\n",
            .{ res, levels, @as(u64, res) * res * res * levels, self.accel.params[0][3], self.accel.last_build_ms },
        );
    }

    pub fn tracePhotons(self: *FractalRenderer, ctx: *const Context, scene: Uniforms, seed: f32) !void {
        if (!self.photon_map.isAllocated()) return error.PhotonMapNotReady;
        if (self.pipelines.trace_photons == null or self.pipelines.clear_photons == null) return error.PhotonMapNotReady;

        const started_ms = sdl.SDL_GetTicks();
        const buckets = self.photon_map.buckets;
        const paths = self.photon_settings.pathCount();

        var trace_uniforms = scene;
        self.stampPhotonUniforms(&trace_uniforms);
        trace_uniforms.photon_enabled = 0;
        trace_uniforms.photon_seed = seed;
        trace_uniforms.photon_hash_salt = seed;
        self.photon_map.stored_hash_salt = seed;
        trace_uniforms.photon_paths = @floatFromInt(paths);
        trace_uniforms.photon_path_offset = 0;

        self.photon_map.centre = scene.camera_pos;
        trace_uniforms.photon_pool = @floatFromInt(self.photon_map.poolPhotons());
        trace_uniforms.photon_cap_surface = @floatFromInt(self.photon_map.cell_cap_surface);
        self.photon_map.stored_cap_surface = self.photon_map.cell_cap_surface;
        trace_uniforms.photon_volume_scale = self.liveVolumeScale();
        self.photon_map.stored_volume_scale = trace_uniforms.photon_volume_scale;
        trace_uniforms.photon_fixed_unit = photons.fixedUnitFor(
            trace_uniforms,
            paths,
            self.photon_settings.cellSize() * trace_uniforms.photon_volume_scale,
        );
        self.photon_map.stored_fixed_unit = trace_uniforms.photon_fixed_unit;

        const bucket_groups = (buckets + photons.workgroup_dim - 1) / photons.workgroup_dim;
        const groups_for = struct {
            fn f(chunk: u32) u32 {
                return (chunk + photons.workgroup_dim - 1) / photons.workgroup_dim;
            }
        }.f;
        const groups = [_]wgpu.WGPUBindGroup{
            self.bind_group,
            self.accel.render_bind_group,
            self.photon_map.compute_bind_group,
            self.sky.bind_group,
        };
        const binds = [_]ComputeBindGroup{
            .{ .index = 0, .group = groups[0] },
            .{ .index = 1, .group = groups[1] },
            .{ .index = 2, .group = groups[2] },
            .{ .index = 3, .group = groups[3] },
        };

        {
            self.updateUniforms(ctx, trace_uniforms);
            try runComputePass(ctx, "photon clear pass", self.pipelines.clear_photons, &binds, .{ bucket_groups, 1, 1 });
        }

        for ([_]f32{ 0, 1 }) |pass| {
            trace_uniforms.photon_pass = pass;
            var first: u32 = 0;
            while (first < paths) : (first += photons.paths_per_submit) {
                const chunk = @min(photons.paths_per_submit, paths - first);

                trace_uniforms.photon_path_offset = @floatFromInt(first);
                self.updateUniforms(ctx, trace_uniforms);

                try runComputePass(
                    ctx,
                    if (pass == 0) "photon count pass" else "photon scatter pass",
                    self.pipelines.trace_photons,
                    &binds,
                    .{ groups_for(chunk), 1, 1 },
                );
            }

            if (pass == 0) {
                trace_uniforms.photon_path_offset = 0;
                self.updateUniforms(ctx, trace_uniforms);
                try runComputePass(ctx, "photon alloc pass", self.pipelines.alloc_photons, &binds, .{ bucket_groups, 1, 1 });
            }
        }

        self.photon_map.valid = true;
        self.photon_map.last_paths = paths;
        self.photon_map.last_trace_ms = @intCast(sdl.SDL_GetTicks() -| started_ms);

        const stats = self.readPhotonStats(ctx) catch photons.TraceStats{};
        self.photon_map.noteStats(stats);

        std.debug.print(
            "[photons] traced {d} paths x {d} bounces into {d} cells (radius {d:.4}, cap {d}) in {d}ms -- pool {d}/{d}, {d} deposits had no bucket, {d} cells had no pool\n",
            .{
                paths,
                @as(u32, @intFromFloat(@max(self.photon_settings.bounces, 0))),
                stats.occupiedCells(),
                self.photon_settings.radius,
                trace_uniforms.photon_cap_surface,
                self.photon_map.last_trace_ms,
                stats.pool_used,
                self.photon_map.poolPhotons(),
                stats.dropped_no_bucket,
                stats.dropped_no_pool,
            },
        );
    }

    fn readPhotonStats(self: *FractalRenderer, ctx: *const Context) !photons.TraceStats {
        const size: u64 = @sizeOf(photons.TraceStats);
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, self.photon_map.stats, 0, self.photon_map.stats_read, 0, size);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        var map_state = MapState{};
        _ = wgpu.wgpuBufferMapAsync(self.photon_map.stats_read, wgpu.WGPUMapMode_Read, 0, size, wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onBufferMapped,
            .userdata1 = &map_state,
            .userdata2 = null,
        });
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_spins);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) {
            return error.BufferMapFailed;
        }
        defer wgpu.wgpuBufferUnmap(self.photon_map.stats_read);

        const ptr = wgpu.wgpuBufferGetConstMappedRange(self.photon_map.stats_read, 0, size) orelse return error.MappedRangeFailed;
        const words: [*]const u32 = @ptrCast(@alignCast(ptr));
        return .{
            .pool_used = words[0],
            .dropped_no_bucket = words[1],
            .dropped_no_pool = words[2],
            .cells_surface = words[3],
            .cells_volume = words[4],
        };
    }

    pub fn renderToImage(self: *FractalRenderer, ctx: *const Context, samples: *const SampleSet, width: u32, height: u32, allocator: std.mem.Allocator, progress: ?RenderProgress) ![]u8 {
        std.debug.assert(samples.count() >= 1);

        const bytes_per_pixel: u32 = 4;
        const row_align: u32 = 256;

        var tile_dim: u32 = @min(2048, @max(ctx.limits.maxTextureDimension2D, 1));
        while (tile_dim > 64) {
            const padded_row = ((tile_dim * bytes_per_pixel + row_align - 1) / row_align) * row_align;
            const buf_size = @as(u64, padded_row) * tile_dim;
            if (buf_size <= ctx.limits.maxBufferSize) break;
            tile_dim /= 2;
        }

        const pixels = try allocator.alloc(u8, @as(usize, width) * height * bytes_per_pixel);
        errdefer allocator.free(pixels);

        const one_scene = switch (samples.*) {
            .repeat => true,
            .per_sample => false,
        };
        self.accel.invalidate();
        if (self.accel_enabled and !samples.is2d() and one_scene) {
            self.buildAccel(ctx, samples.at(0).*) catch |err| {
                std.debug.print("[accel] export build failed ({s}); rendering without it\n", .{@errorName(err)});
                self.accel.invalidate();
            };
        }

        self.photon_map.invalidate();
        if (self.photon_settings.enabled and !samples.is2d() and one_scene) {
            self.tracePhotons(ctx, samples.at(0).*, 1.0) catch |err| {
                std.debug.print("[photons] export trace failed ({s}); rendering without caustics\n", .{@errorName(err)});
                self.photon_map.invalidate();
            };
        }
        defer self.accel.invalidate();
        defer self.photon_map.invalidate();

        var tracker = ProgressTracker{ .progress = progress, .total = countSubTiles(width, height, tile_dim) * samples.count() };

        var tile_y: u32 = 0;
        while (tile_y < height) : (tile_y += tile_dim) {
            const tile_h = @min(tile_dim, height - tile_y);
            var tile_x: u32 = 0;
            while (tile_x < width) : (tile_x += tile_dim) {
                const tile_w = @min(tile_dim, width - tile_x);
                try self.renderTile(ctx, samples, width, height, tile_x, tile_y, tile_w, tile_h, pixels, &tracker);
            }
        }

        return pixels;
    }

    fn renderTile(
        self: *FractalRenderer,
        ctx: *const Context,
        samples: *const SampleSet,
        full_width: u32,
        full_height: u32,
        tile_x: u32,
        tile_y: u32,
        tile_w: u32,
        tile_h: u32,
        pixels: []u8,
        tracker: *ProgressTracker,
    ) !void {
        const bytes_per_pixel: u32 = 4;
        const unpadded_bytes_per_row = tile_w * bytes_per_pixel;
        const row_align: u32 = 256;
        const padded_bytes_per_row = ((unpadded_bytes_per_row + row_align - 1) / row_align) * row_align;

        const export_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal export tile texture"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 },
            .format = hdr_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        defer wgpu.wgpuTextureRelease(export_texture);
        const export_view = wgpu.wgpuTextureCreateView(export_texture, null) orelse return error.TextureViewCreationFailed;
        defer wgpu.wgpuTextureViewRelease(export_view);

        const export_resolve_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal export resolve texture"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_CopySrc,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 },
            .format = ctx.surface_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        defer wgpu.wgpuTextureRelease(export_resolve_texture);
        const export_resolve_view = wgpu.wgpuTextureCreateView(export_resolve_texture, null) orelse return error.TextureViewCreationFailed;
        defer wgpu.wgpuTextureViewRelease(export_resolve_view);

        const resolve_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fractal export resolve bind group"),
            .layout = self.blit_bind_group_layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = self.sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = export_view },
            },
        }) orelse return error.BindGroupCreationFailed;
        defer wgpu.wgpuBindGroupRelease(resolve_bind_group);

        const tile = tileTransform(full_width, full_height, tile_x, tile_y, tile_w, tile_h);
        const tile_scale = tile.scale;
        const tile_bias = tile.bias;
        const sub_tile_size: u32 = if (samples.is2d()) 1024 else 128;
        var sub_y: u32 = 0;
        while (sub_y < tile_h) : (sub_y += sub_tile_size) {
            const sub_h = @min(sub_tile_size, tile_h - sub_y);
            var sub_x: u32 = 0;
            while (sub_x < tile_w) : (sub_x += sub_tile_size) {
                const sub_w = @min(sub_tile_size, tile_w - sub_x);

                const sample_count = samples.count();
                var s: u32 = 0;
                while (s < sample_count) : (s += 1) {
                    var uniforms = samples.at(s).*;
                    uniforms.tile_scale = tile_scale;
                    uniforms.tile_bias = tile_bias;
                    uniforms.mc_sample = @floatFromInt(s);
                    self.stampAccelUniforms(&uniforms);
                    self.stampPhotonUniforms(&uniforms);
                    self.stampSkyUniforms(&uniforms);
                    self.updateUniforms(ctx, uniforms);

                    const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
                    const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
                        .nextInChain = null,
                        .label = sv("fractal export sub-tile pass"),
                        .colorAttachmentCount = 1,
                        .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                            .nextInChain = null,
                            .view = export_view,
                            .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                            .resolveTarget = null,
                            .loadOp = if (sub_x == 0 and sub_y == 0 and s == 0) wgpu.WGPULoadOp_Clear else wgpu.WGPULoadOp_Load,
                            .storeOp = wgpu.WGPUStoreOp_Store,
                            .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
                        }},
                        .depthStencilAttachment = null,
                        .occlusionQuerySet = null,
                        .timestampWrites = null,
                    }).?;
                    wgpu.wgpuRenderPassEncoderSetScissorRect(pass, sub_x, sub_y, sub_w, sub_h);
                    const blend_constant: f32 = 1.0 / @as(f32, @floatFromInt(s + 1));
                    self.draw(pass, blend_constant, if (samples.is2d()) .slice else .march);
                    wgpu.wgpuRenderPassEncoderEnd(pass);
                    wgpu.wgpuRenderPassEncoderRelease(pass);

                    const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
                    wgpu.wgpuCommandEncoderRelease(encoder);
                    wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
                    wgpu.wgpuCommandBufferRelease(cmd_buffer);

                    try waitForQueueIdle(ctx);
                    tracker.tick();
                    if (tracker.progress) |p| {
                        if (p.cancel_flag) |cf| {
                            if (cf.*) return error.RenderCancelled;
                        }
                    }
                }
            }
        }

        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;

        const resolve_pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal export resolve pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = export_resolve_view,
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
        wgpu.wgpuRenderPassEncoderSetPipeline(resolve_pass, self.blit_pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(resolve_pass, 0, resolve_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(resolve_pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(resolve_pass);
        wgpu.wgpuRenderPassEncoderRelease(resolve_pass);

        const readback_size: u64 = @as(u64, padded_bytes_per_row) * tile_h;
        const readback_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fractal export tile readback"),
            .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_MapRead,
            .size = readback_size,
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;
        defer wgpu.wgpuBufferRelease(readback_buffer);

        var copy_src = wgpu.WGPUTexelCopyTextureInfo{
            .texture = export_resolve_texture,
            .mipLevel = 0,
            .origin = .{ .x = 0, .y = 0, .z = 0 },
            .aspect = wgpu.WGPUTextureAspect_All,
        };
        var copy_dst = wgpu.WGPUTexelCopyBufferInfo{
            .layout = .{ .offset = 0, .bytesPerRow = padded_bytes_per_row, .rowsPerImage = tile_h },
            .buffer = readback_buffer,
        };
        var copy_extent = wgpu.WGPUExtent3D{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 };
        wgpu.wgpuCommandEncoderCopyTextureToBuffer(encoder, &copy_src, &copy_dst, &copy_extent);

        const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
        wgpu.wgpuCommandBufferRelease(cmd_buffer);

        var map_state = MapState{};
        const callback_info = wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onBufferMapped,
            .userdata1 = &map_state,
            .userdata2 = null,
        };
        _ = wgpu.wgpuBufferMapAsync(readback_buffer, wgpu.WGPUMapMode_Read, 0, readback_size, callback_info);
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_spins);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) {
            return error.BufferMapFailed;
        }

        const mapped_ptr = wgpu.wgpuBufferGetConstMappedRange(readback_buffer, 0, readback_size) orelse return error.MappedRangeFailed;
        const mapped: [*]const u8 = @ptrCast(mapped_ptr);

        const full_stride = full_width * bytes_per_pixel;
        for (0..tile_h) |row| {
            const src_row = mapped[row * padded_bytes_per_row ..][0..unpadded_bytes_per_row];
            const dst_offset = (tile_y + row) * full_stride + tile_x * bytes_per_pixel;
            const dst_row = pixels[dst_offset..][0..unpadded_bytes_per_row];
            @memcpy(dst_row, src_row);
        }
        wgpu.wgpuBufferUnmap(readback_buffer);
    }

    pub fn beginOffscreenPass(self: *FractalRenderer, encoder: wgpu.WGPUCommandEncoder, load_existing: bool) wgpu.WGPURenderPassEncoder {
        return wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal offscreen pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = self.offscreen_view,
                .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                .resolveTarget = null,
                .loadOp = if (load_existing) wgpu.WGPULoadOp_Load else wgpu.WGPULoadOp_Clear,
                .storeOp = wgpu.WGPUStoreOp_Store,
                .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            }},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;
    }

    pub fn draw(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder, blend_constant: f32, mode: RenderMode) void {
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, switch (mode) {
            .march => self.pipelines.march,
            .slice => self.pipelines.slice,
            .simple => self.pipelines.simple,
        });
        self.bindSceneGroups(pass);
        wgpu.wgpuRenderPassEncoderSetBlendConstant(pass, &wgpu.WGPUColor{ .r = blend_constant, .g = blend_constant, .b = blend_constant, .a = 1.0 });
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    }

    fn bindSceneGroups(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder) void {
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 1, self.accel.render_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 2, self.photon_map.render_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 3, self.sky.bind_group, 0, null);
    }

    pub fn renderSelectMask(self: *FractalRenderer, encoder: wgpu.WGPUCommandEncoder) bool {
        if (self.pipelines.select == null or self.select_view == null) return false;
        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal selection mask pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = self.select_view,
                .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                .resolveTarget = null,
                .loadOp = wgpu.WGPULoadOp_Clear,
                .storeOp = wgpu.WGPUStoreOp_Store,
                .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            }},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }) orelse return false;
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipelines.select);
        self.bindSceneGroups(pass);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
        return true;
    }

    pub fn pickObject(self: *FractalRenderer, ctx: *const Context, uniforms: Uniforms, x: u32, y: u32) !u8 {
        if (self.pipelines.select == null) return 0;

        var pick_uniforms = uniforms;
        const tile = tileTransform(self.offscreen_width, self.offscreen_height, x, y, 1, 1);
        pick_uniforms.tile_scale = tile.scale;
        pick_uniforms.tile_bias = tile.bias;
        pick_uniforms.mc_sample = 0;
        self.updateUniforms(ctx, pick_uniforms);

        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal pick pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = self.pick_view,
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
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipelines.select);
        self.bindSceneGroups(pass);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);

        var copy_src = wgpu.WGPUTexelCopyTextureInfo{
            .texture = self.pick_texture,
            .mipLevel = 0,
            .origin = .{ .x = 0, .y = 0, .z = 0 },
            .aspect = wgpu.WGPUTextureAspect_All,
        };
        var copy_dst = wgpu.WGPUTexelCopyBufferInfo{
            .layout = .{ .offset = 0, .bytesPerRow = 256, .rowsPerImage = 1 },
            .buffer = self.pick_buffer,
        };
        var copy_extent = wgpu.WGPUExtent3D{ .width = 1, .height = 1, .depthOrArrayLayers = 1 };
        wgpu.wgpuCommandEncoderCopyTextureToBuffer(encoder, &copy_src, &copy_dst, &copy_extent);

        const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
        wgpu.wgpuCommandBufferRelease(cmd_buffer);

        var map_state = MapState{};
        const callback_info = wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onBufferMapped,
            .userdata1 = &map_state,
            .userdata2 = null,
        };
        _ = wgpu.wgpuBufferMapAsync(self.pick_buffer, wgpu.WGPUMapMode_Read, 0, 256, callback_info);
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_spins);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) {
            return error.BufferMapFailed;
        }
        defer wgpu.wgpuBufferUnmap(self.pick_buffer);

        const mapped_ptr = wgpu.wgpuBufferGetConstMappedRange(self.pick_buffer, 0, 256) orelse return error.MappedRangeFailed;
        const mapped: [*]const u8 = @ptrCast(mapped_ptr);
        return mapped[0];
    }

    pub fn blit(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder) void {
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.blit_pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.blit_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    }
};
