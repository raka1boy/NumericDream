const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const g_error_sink = &webgpu_context.g_error_sink;
const sv = webgpu_context.sv;
pub const accel = @import("accel.zig");
const AccelGrid = accel.AccelGrid;
pub const fft = @import("fft.zig");
const FftVolume = fft.FftVolume;
pub const photons = @import("photons.zig");
const PhotonMap = photons.PhotonMap;
pub const sky_texture = @import("sky_texture.zig");
const SkyTexture = sky_texture.SkyTexture;
pub const post_process = @import("post_process.zig");
pub const mesher = @import("mesher.zig");
pub const particles = @import("particles.zig");
const ParticleGpu = particles.ParticleGpu;
const PostChain = post_process.PostChain;
const PartsPipelines = @import("parts_pipelines.zig").PartsPipelines;
const photon_state = @import("../app/photon_state.zig");
const accel_state = @import("../app/accel_state.zig");
const sky_state = @import("../app/sky.zig");
const approximations = @import("../app/approximations.zig");
const perf_probe = @import("../app/perf_probe.zig");
const oidn = @import("../bindings/oidn.zig");

const shader_template = @embedFile("shaders/template.wgsl");
const particles_sim_source = @embedFile("shaders/particles_sim.wgsl");
const particles_lit_source = @embedFile("shaders/particles_lit.wgsl");
const particles_dots_source = @embedFile("shaders/particles_dots.wgsl");
const blit_shader_src = @embedFile("shaders/blit.wgsl");
const light_shafts_source = @embedFile("shaders/light_shafts.wgsl");

pub const max_instances = 4;
pub const max_mixins = 3;
pub const max_color_stops = 16;
pub const max_params = 8;
pub const max_lights = 8;
pub const max_fog_emitters = 4;
pub const max_warps = 4;
pub const max_carves = 16;
pub const max_particle_systems = particles.max_systems;

pub const uniform_ring_slots: u32 = 32;

const hdr_format = wgpu.WGPUTextureFormat_RGBA16Float;

pub fn accumFormat(ctx: *const Context) wgpu.WGPUTextureFormat {
    return if (ctx.float32_accum) wgpu.WGPUTextureFormat_RGBA32Float else hdr_format;
}

const select_format = wgpu.WGPUTextureFormat_R8Unorm;

const depth_format = wgpu.WGPUTextureFormat_R32Float;
const normal_format = wgpu.WGPUTextureFormat_RGBA16Float;

const adapt_stats_stride: u64 = 16;

const aov_format = wgpu.WGPUTextureFormat_RGBA16Float;
const aov_bytes_per_pixel: u32 = 8;
const aov_max_samples: u32 = 16;
const aov_sub_side: u32 = 512;

pub const builtin_formula_source = @embedFile("shaders/mandelbrot.wgsl");

pub const filler_formula_source =
    \\fn de_iterations(p: array<f32, 8>) -> i32 {
    \\    return 0;
    \\}
    \\fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    \\    return carry;
    \\}
    \\fn de_finalize(carry: IterCarry) -> f32 {
    \\    return NO_SURFACE_DE;
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
    step_safety: f32 = 1.0,
    hidden: f32 = 0,
    scale: [3]f32 = .{ 1, 1, 1 },
    _pad_scale: f32 = 0,
    rotation: [3]f32 = .{ 0, 0, 0 },
    _pad_rot: f32 = 0,
    params0: [4]f32,
    params1: [4]f32,
    mixin_count: f32 = 0,
    hybrid_base_iters: f32 = 2,
    hybrid_total_iters: f32 = 12,
    trap_repeat: f32 = 0,
    trap_center: [3]f32 = .{ 0, 0, 0 },
    trap_shape: f32 = 0,
    trap_box: [3]f32 = .{ 1, 1, 1 },
    trap_mode: f32 = 0,
    trap_radius: f32 = 1,
    trap_tube: f32 = 0,
    trap_span: f32 = 1.5,
    trap_offset: f32 = 0,
    mixins: [max_mixins]MixinParams,
    colors: [max_color_stops]ColorStop,
};

comptime {
    std.debug.assert(@offsetOf(FractalInstance, "trap_center") % 16 == 0);
    std.debug.assert(@offsetOf(FractalInstance, "trap_box") % 16 == 0);
    std.debug.assert(@offsetOf(FractalInstance, "mixins") % 16 == 0);
    std.debug.assert(@sizeOf(FractalInstance) % 16 == 0);
}

pub const Light = extern struct {
    color: [3]f32,
    brightness: f32,
    position_or_direction: [3]f32,
    light_type: f32,
    shadow_softness: f32,
    cast_shadows: f32,
    hard_shadows: f32,
    spread: f32 = 0,
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

pub const ParticleSystem = extern struct {
    center: [3]f32 = .{ 0, 0, 0 },
    mode: f32 = 0,
    dot_style: f32 = 0,
    glow: f32 = 1,
    combine_mode: f32 = 0,
    blend_k: f32 = 0,
    color_count: f32 = 0,
    generation: f32 = 0,
    glow_extent: f32 = 3,
    _pad0: f32 = 0,
    colors: [max_color_stops]ColorStop = std.mem.zeroes([max_color_stops]ColorStop),
};

comptime {
    std.debug.assert(@sizeOf(ParticleSystem) == 48 + 80 * max_color_stops);
    std.debug.assert(@offsetOf(ParticleSystem, "colors") == 48);
}

pub const ShaderVariant = struct {
    warps: bool = false,
    particles_lit: bool = false,
    particles_dots: bool = false,
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
    accel_z_offset: f32 = 0,
    fft_active: f32 = 0,
    fft_target_slot: f32 = 0,
    accel_params: [accel.max_cascades][4]f32 = @splat(.{ 0, 0, 0, 0 }),
    warp_count: f32 = 0,
    has_transparency: f32 = 0,
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
    photon_path_offset: f32 = 0,
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
    fft_axis: f32 = 0,
    fft_box_radius: f32 = 2.5,
    fft_cloud_density: f32 = 4.0,
    fft_lowpass: f32 = 1.0,
    fft_highpass: f32 = 0.0,
    fft_normalize: f32 = 0,
    photon_bounce_scale: f32 = 4,
    photon_aim: f32 = 0,
    carve_count: f32 = 0,
    hotspot_scale: f32 = 0,
    _pad_carve1: f32 = 0,
    _pad_carve2: f32 = 0,
    carves: [max_carves][4]f32 = @splat(.{ 0, 0, 0, 0 }),
    particle_systems: [max_particle_systems]ParticleSystem = @splat(.{}),
    approx_flags: f32 = 0,
    approx_caustic_strength: f32 = 1,
    approx_caustic_scale: f32 = 0.3,
    approx_bounce: f32 = 0.35,
    approx_tint: f32 = 1,
    approx_lod_start: f32 = 2,
    approx_lod_strength: f32 = 1.5,
    _pad_approx0: f32 = 0,
    adapt_enabled: f32 = 0,
    adapt_threshold: f32 = 0.02,
    adapt_min_samples: f32 = 16,
    adapt_row_width: f32 = 0,
};

pub const Sky = extern struct {
    mode: f32 = 0,
    intensity: f32 = 1,
    falloff: f32 = 1,
    photons: f32 = 0,
    zenith: [3]f32 = .{ 0.02, 0.02, 0.05 },
    sun_cos: f32 = -2,
    horizon: [3]f32 = .{ 0.04, 0.035, 0.07 },
    sun_intensity: f32 = 0,
    ground: [3]f32 = .{ 0.06, 0.05, 0.09 },
    yaw: f32 = 0,
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
    std.debug.assert(@offsetOf(Uniforms, "carves") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "particle_systems") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "approx_flags") % 16 == 0);
    std.debug.assert(@offsetOf(Uniforms, "adapt_enabled") % 16 == 0);
    std.debug.assert(max_lights == photons.aim_max_lights);
    std.debug.assert(@sizeOf(photons.AimEntry) == 16);
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

fn collectTopLevelNames(allocator: std.mem.Allocator, source: []const u8) ![][]const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);
    var depth: usize = 0;
    var i: usize = 0;
    while (i < source.len) {
        const keyword: ?[]const u8 = if (matchesWordAt(source, i, "fn"))
            "fn"
        else if (depth == 0 and matchesWordAt(source, i, "const"))
            "const"
        else
            null;
        if (keyword) |kw| {
            var j = i + kw.len;
            while (j < source.len and (source[j] == ' ' or source[j] == '\t')) j += 1;
            const start = j;
            while (j < source.len and isIdentChar(source[j])) j += 1;
            if (j > start) try names.append(allocator, source[start..j]);
            i = j;
        } else {
            switch (source[i]) {
                '{' => depth += 1,
                '}' => depth -|= 1,
                else => {},
            }
            i += 1;
        }
    }
    return names.toOwnedSlice(allocator);
}

const contract_fn_names = [_][]const u8{ "de_step", "de_finalize", "de_iterations" };

fn appendRenamedFormula(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8, slot: usize) !void {
    const names = try collectTopLevelNames(allocator, source);
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
        \\    let trap_spec = orbit_trap({0});
        \\    var trap = orbit_trap_begin(trap_spec);
        \\    let lod = lod_iterations(de_iterations_{0}(p));
        \\    let iters = i32(lod.x);
        \\    var carry_lo = carry;
        \\    for (var it = 0; it < iters; it++) {{
        \\        let z_prev = carry.z;
        \\        carry_lo = carry;
        \\        carry = de_step_{0}(carry, pos, p);
        \\        trap = orbit_trap_update(trap, trap_spec, carry.z, z_prev, it);
        \\    }}
        \\    return vec2f(de_finalize_{0}(lod_blend(carry_lo, carry, lod.y)), orbit_trap_finish(trap, trap_spec, iters));
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
    \\        if (inf <= WARP_MIN_INFLUENCE) {
    \\            continue;
    \\        }
    \\        q = mix(q, coord_warp_raw(w, q), inf);
    \\        let band = inf / max(w.strength, WARP_MIN_STRENGTH);
    \\        let lip = 1.0 + inf * w.lip_mult + w.strength * w.lip_grad * (4.0 * band * (1.0 - band));
    \\        scale *= w.safety / lip;
    \\    }
    \\    return Warped(q, scale);
    \\}
    \\
    \\fn warp_step_limit(p: vec3f) -> f32 {
    \\    var lim = INFINITE_DISTANCE;
    \\    for (var i = 0; i < i32(u.warp_count); i++) {
    \\        let w = u.warps[i];
    \\        if (w.falloff > WARP_MIN_FALLOFF || i32(w.region_kind + 0.5) == WARP_REGION_GLOBAL) {
    \\            continue;
    \\        }
    \\        lim = min(lim, max(abs(warp_region_de(w, p)), WARP_MIN_STEP_LIMIT));
    \\    }
    \\    return lim;
    \\}
;

const warp_stub_source =
    \\fn warp_domain(p: vec3f) -> Warped {
    \\    return Warped(p, 1.0);
    \\}
    \\fn warp_step_limit(p: vec3f) -> f32 {
    \\    return INFINITE_DISTANCE;
    \\}
;

const particles_lit_stub_source =
    \\fn particles_scene_de(pos: vec3f, d: f32, have: bool) -> vec2f {
    \\    return vec2f(d, select(0.0, 1.0, have));
    \\}
    \\fn particles_hit_material(pos: vec3f, sp: SurfacePoint, have: bool) -> ParticleSurface {
    \\    return ParticleSurface(sp, have);
    \\}
    \\fn particles_nearest_lit(pos: vec3f) -> vec2f {
    \\    return vec2f(INFINITE_DISTANCE, -1.0);
    \\}
    \\
;

const particles_dots_stub_source =
    \\fn particle_dots(origin: vec3f, dir: vec3f, t_max: f32, pick: bool) -> DotsHit {
    \\    return DotsHit(vec3f(0.0), -1.0, vec3f(0.0), -1.0);
    \\}
    \\
;

pub fn assembleShaderSource(allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, variant: ShaderVariant) ![]u8 {
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
        try out.appendSlice(allocator, if (variant.warps) warp_impl_source else warp_stub_source);
        rest = rest[idx + marker.len ..];
    }
    {
        const marker = "@@PARTICLES@@";
        const idx = std.mem.indexOf(u8, rest, marker) orelse return error.MissingFormulaMarker;
        try out.appendSlice(allocator, rest[0..idx]);
        try out.appendSlice(allocator, if (variant.particles_lit) particles_lit_source else particles_lit_stub_source);
        try out.appendSlice(allocator, if (variant.particles_dots) particles_dots_source else particles_dots_stub_source);
        rest = rest[idx + marker.len ..];
    }
    try out.appendSlice(allocator, rest);
    try out.appendSlice(allocator, particles_sim_source);
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

    fn allMatch(
        self: *const SampleSet,
        settings: photon_state.PhotonSettings,
        comptime hash: fn (*const Uniforms, photon_state.PhotonSettings) u64,
    ) bool {
        const list = switch (self.*) {
            .repeat => return true,
            .per_sample => |list| list,
        };
        if (list.len <= 1) return true;
        const first = hash(&list[0], settings);
        for (list[1..]) |*u| {
            if (hash(u, settings) != first) return false;
        }
        return true;
    }
};

fn accelSceneHash(u: *const Uniforms, _: photon_state.PhotonSettings) u64 {
    return accel_state.sceneHash(u);
}

fn photonSceneHash(u: *const Uniforms, settings: photon_state.PhotonSettings) u64 {
    return photon_state.sceneHash(u, settings);
}

pub const RenderProgress = struct {
    callback: *const fn (frac: f32, userdata: ?*anyopaque) void,
    userdata: ?*anyopaque = null,
    range_start: f32 = 0.0,
    range_end: f32 = 1.0,
    cancel_flag: ?*const bool = null,
};

const ProgressTracker = struct {
    progress: ?RenderProgress,
    total: u64,
    done: u64 = 0,

    fn tick(self: *ProgressTracker, units: u64) void {
        self.done += units;
        const p = self.progress orelse return;
        const frac_local = @as(f32, @floatFromInt(self.done)) / @as(f32, @floatFromInt(@max(self.total, 1)));
        const frac = p.range_start + (p.range_end - p.range_start) * @min(frac_local, 1.0);
        p.callback(frac, p.userdata);
    }
};

const TileTransform = struct { scale: [2]f32, bias: [2]f32 };

fn tileTransform(full_width: u32, full_height: u32, tile_x: u32, tile_y: u32, tile_w: u32, tile_h: u32) TileTransform {
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

pub const MapState = struct {
    done: bool = false,
    status: wgpu.WGPUMapAsyncStatus = wgpu.WGPUMapAsyncStatus_Error,
};

pub fn onBufferMapped(
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

pub const gpu_work_timeout_ms: u32 = 600_000;

const export_min_sub_side: u32 = 128;
const export_max_sub_side_3d: u32 = 512;
const export_max_sub_side_2d: u32 = 2048;
const export_batch_target_ms: f32 = 250;

const post_single_tile_px_budget: u64 = 16 << 20;

const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,

    fn area(self: Rect) u64 {
        return @as(u64, self.w) * self.h;
    }

    fn split(self: Rect) [2]Rect {
        if (self.w >= self.h) {
            const half = self.w / 2;
            return .{
                .{ .x = self.x, .y = self.y, .w = half, .h = self.h },
                .{ .x = self.x + half, .y = self.y, .w = self.w - half, .h = self.h },
            };
        }
        const half = self.h / 2;
        return .{
            .{ .x = self.x, .y = self.y, .w = self.w, .h = half },
            .{ .x = self.x, .y = self.y + half, .w = self.w, .h = self.h - half },
        };
    }
};

const ExportPacer = struct {
    ms_per_px: f32 = export_batch_target_ms / @as(f32, export_min_sub_side * export_min_sub_side),
    side: u32 = export_min_sub_side,
    max_side: u32,
    submits: u32 = 0,

    fn subTileSide(self: ExportPacer) u32 {
        return self.side;
    }

    fn estimateMs(self: ExportPacer, pixels: u64) f32 {
        return self.ms_per_px * @as(f32, @floatFromInt(pixels));
    }

    fn observe(self: *ExportPacer, elapsed_ms: f32, pixels: u64) void {
        if (pixels == 0) return;
        self.submits += 1;
        const measured = elapsed_ms / @as(f32, @floatFromInt(pixels));
        self.ms_per_px = if (measured > self.ms_per_px)
            measured
        else
            self.ms_per_px * 0.7 + measured * 0.3;

        const budget_px = export_batch_target_ms / @max(self.ms_per_px, 1e-12);
        const want = @min(@sqrt(@max(budget_px, 1.0)), @as(f32, @floatFromInt(self.side)) * 2.0);
        self.side = @intFromFloat(std.math.clamp(
            want,
            @as(f32, @floatFromInt(export_min_sub_side)),
            @as(f32, @floatFromInt(self.max_side)),
        ));
    }
};

fn nowMs() f64 {
    return @as(f64, @floatFromInt(sdl.SDL_GetTicksNS())) / @as(f64, std.time.ns_per_ms);
}

const ExportBatch = struct {
    cmd_encoder: wgpu.WGPUCommandEncoder = null,
    est_ms: f32 = 0,
    pixels: u64 = 0,
    first_sample: u32 = 0,

    fn encoder(self: *ExportBatch, ctx: *const Context, sample: u32) !wgpu.WGPUCommandEncoder {
        if (self.cmd_encoder == null) {
            self.cmd_encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse
                return error.EncoderCreationFailed;
            self.first_sample = sample;
        }
        return self.cmd_encoder.?;
    }

    fn discard(self: *ExportBatch) void {
        if (self.cmd_encoder) |enc| wgpu.wgpuCommandEncoderRelease(enc);
        self.* = .{};
    }

    fn flush(self: *ExportBatch, ctx: *const Context, pacer: *ExportPacer, tracker: *ProgressTracker) !void {
        const enc = self.cmd_encoder orelse return;
        const cmd_buffer = wgpu.wgpuCommandEncoderFinish(enc, null);
        wgpu.wgpuCommandEncoderRelease(enc);
        const pixels = self.pixels;
        self.* = .{};

        const start_ms = nowMs();
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
        wgpu.wgpuCommandBufferRelease(cmd_buffer);
        try waitForQueueIdle(ctx);
        pacer.observe(@floatCast(nowMs() - start_ms), pixels);

        tracker.tick(pixels);
        if (tracker.progress) |p| {
            if (p.cancel_flag) |cf| {
                if (cf.*) return error.RenderCancelled;
            }
        }
    }
};

pub fn waitForQueueIdle(ctx: *const Context) !void {
    var state = WorkDoneState{};
    const callback_info = wgpu.WGPUQueueWorkDoneCallbackInfo{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = onQueueWorkDone,
        .userdata1 = &state,
        .userdata2 = null,
    };
    _ = wgpu.wgpuQueueOnSubmittedWorkDone(ctx.queue, callback_info);
    _ = webgpu_context.pollUntil(ctx.instance, &state.done, gpu_work_timeout_ms);
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
    wait: bool,
) !void {
    const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
    const pass = wgpu.wgpuCommandEncoderBeginComputePass(encoder, &wgpu.WGPUComputePassDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .timestampWrites = null,
    }).?;
    wgpu.wgpuComputePassEncoderSetPipeline(pass, pipeline);
    for (bind_groups) |bg| {
        const slot0: u32 = 0;
        if (bg.index == 0) {
            wgpu.wgpuComputePassEncoderSetBindGroup(pass, 0, bg.group, 1, &slot0);
        } else {
            wgpu.wgpuComputePassEncoderSetBindGroup(pass, bg.index, bg.group, 0, null);
        }
    }
    wgpu.wgpuComputePassEncoderDispatchWorkgroups(pass, workgroups[0], workgroups[1], workgroups[2]);
    wgpu.wgpuComputePassEncoderEnd(pass);
    wgpu.wgpuComputePassEncoderRelease(pass);

    const cmd_buffer = wgpu.wgpuCommandEncoderFinish(encoder, null);
    wgpu.wgpuCommandEncoderRelease(encoder);
    wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
    wgpu.wgpuCommandBufferRelease(cmd_buffer);
    if (wait) try waitForQueueIdle(ctx);
}

pub fn hashSources(formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, variant: ShaderVariant) u64 {
    var h = std.hash.Wyhash.init(0);
    inline for (.{ variant.warps, variant.particles_lit, variant.particles_dots }) |flag| h.update(std.mem.asBytes(&flag));
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

const ParticleEntry = enum {
    reset,
    hash_clear,
    hash_insert,
    step,
    step_end,
    emit,
    grid_setup,
    grid_clear,
    grid_count,
    grid_alloc,
    grid_scatter,
    grid_dist_init,
    grid_dilate,

    fn isSim(self: ParticleEntry) bool {
        return @intFromEnum(self) <= @intFromEnum(ParticleEntry.step_end);
    }
};
const particle_entry_count = std.enums.values(ParticleEntry).len;

const PipelinePair = struct {
    march: wgpu.WGPURenderPipeline = null,
    slice: wgpu.WGPURenderPipeline = null,
    simple: wgpu.WGPURenderPipeline = null,
    select: wgpu.WGPURenderPipeline = null,
    build_accel: wgpu.WGPUComputePipeline = null,
    trace_photons: wgpu.WGPUComputePipeline = null,
    clear_photons: wgpu.WGPUComputePipeline = null,
    alloc_photons: wgpu.WGPUComputePipeline = null,
    scatter_photons: wgpu.WGPUComputePipeline = null,
    aim_photons: wgpu.WGPUComputePipeline = null,
    aov: wgpu.WGPURenderPipeline = null,
    build_fft_voxelize: wgpu.WGPUComputePipeline = null,
    build_fft_axis_seed: wgpu.WGPUComputePipeline = null,
    build_fft_axis_complex: wgpu.WGPUComputePipeline = null,
    build_fft_magnitude: wgpu.WGPUComputePipeline = null,
    build_fft_finalize: wgpu.WGPUComputePipeline = null,
    particle: [particle_entry_count]wgpu.WGPUComputePipeline = @splat(null),
    module: wgpu.WGPUShaderModule = null,

    fn has(self: PipelinePair, group: PipelineGroup) bool {
        return switch (group) {
            .core => self.march != null and self.slice != null and self.simple != null,
            .select => self.select != null,
            .accel => self.build_accel != null,
            .photons => self.trace_photons != null and self.clear_photons != null and
                self.alloc_photons != null and self.scatter_photons != null,
            .aim => self.aim_photons != null,
            .aov => self.aov != null,
            .fft => self.build_fft_voxelize != null and self.build_fft_axis_seed != null and
                self.build_fft_axis_complex != null and self.build_fft_magnitude != null and
                self.build_fft_finalize != null,
            .particles => for (self.particle) |p| {
                if (p == null) break false;
            } else true,
        };
    }

    fn builtGroups(self: PipelinePair) GroupSet {
        var set = GroupSet.empty;
        for (std.enums.values(PipelineGroup)) |g| {
            if (self.has(g)) set.insert(g);
        }
        return set;
    }

    fn release(self: PipelinePair) void {
        for (self.particle) |p| {
            if (p != null) wgpu.wgpuComputePipelineRelease(p);
        }
        if (self.module != null) wgpu.wgpuShaderModuleRelease(self.module);
        if (self.march != null) wgpu.wgpuRenderPipelineRelease(self.march);
        if (self.slice != null) wgpu.wgpuRenderPipelineRelease(self.slice);
        if (self.simple != null) wgpu.wgpuRenderPipelineRelease(self.simple);
        if (self.select != null) wgpu.wgpuRenderPipelineRelease(self.select);
        if (self.build_accel != null) wgpu.wgpuComputePipelineRelease(self.build_accel);
        if (self.trace_photons != null) wgpu.wgpuComputePipelineRelease(self.trace_photons);
        if (self.clear_photons != null) wgpu.wgpuComputePipelineRelease(self.clear_photons);
        if (self.alloc_photons != null) wgpu.wgpuComputePipelineRelease(self.alloc_photons);
        if (self.scatter_photons != null) wgpu.wgpuComputePipelineRelease(self.scatter_photons);
        if (self.aim_photons != null) wgpu.wgpuComputePipelineRelease(self.aim_photons);
        if (self.aov != null) wgpu.wgpuRenderPipelineRelease(self.aov);
        if (self.build_fft_voxelize != null) wgpu.wgpuComputePipelineRelease(self.build_fft_voxelize);
        if (self.build_fft_axis_seed != null) wgpu.wgpuComputePipelineRelease(self.build_fft_axis_seed);
        if (self.build_fft_axis_complex != null) wgpu.wgpuComputePipelineRelease(self.build_fft_axis_complex);
        if (self.build_fft_magnitude != null) wgpu.wgpuComputePipelineRelease(self.build_fft_magnitude);
        if (self.build_fft_finalize != null) wgpu.wgpuComputePipelineRelease(self.build_fft_finalize);
    }
};

pub const PipelineGroup = enum { core, select, accel, photons, aim, aov, fft, particles };
const GroupSet = std.EnumSet(PipelineGroup);

const max_pipeline_jobs = 3 + 1 + 1 + 4 + 1 + 1 + 5 + particle_entry_count;

const PipelineJob = struct {
    label: []const u8,
    entry: []const u8,
    layout: wgpu.WGPUPipelineLayout,
    out: union(enum) {
        compute: *wgpu.WGPUComputePipeline,
        render: struct { pipeline: *wgpu.WGPURenderPipeline, format: wgpu.WGPUTextureFormat, blend: bool, gbuffer: bool },
        aov: *wgpu.WGPURenderPipeline,
    },

    fn run(self: *const PipelineJob, ctx: *const Context, module: wgpu.WGPUShaderModule) void {
        switch (self.out) {
            .compute => |p| p.* = FractalRenderer.createComputePipeline(ctx, self.layout, module, self.label, self.entry),
            .render => |r| r.pipeline.* = FractalRenderer.createPipeline(ctx, self.layout, module, self.label, self.entry, r.format, r.blend, r.gbuffer),
            .aov => |p| p.* = FractalRenderer.createAovPipeline(ctx, self.layout, module),
        }
    }

    fn made(self: *const PipelineJob) bool {
        return switch (self.out) {
            .compute => |p| p.* != null,
            .render => |r| r.pipeline.* != null,
            .aov => |p| p.* != null,
        };
    }

    fn discard(self: *const PipelineJob) void {
        switch (self.out) {
            .compute => |p| if (p.* != null) {
                wgpu.wgpuComputePipelineRelease(p.*);
                p.* = null;
            },
            .render => |r| if (r.pipeline.* != null) {
                wgpu.wgpuRenderPipelineRelease(r.pipeline.*);
                r.pipeline.* = null;
            },
            .aov => |p| if (p.* != null) {
                wgpu.wgpuRenderPipelineRelease(p.*);
                p.* = null;
            },
        }
    }
};

const JobBatch = struct {
    jobs: [max_pipeline_jobs]PipelineJob = undefined,
    len: usize = 0,

    fn slice(self: *JobBatch) []PipelineJob {
        return self.jobs[0..self.len];
    }

    fn push(self: *JobBatch, job: PipelineJob) void {
        self.jobs[self.len] = job;
        self.len += 1;
    }

    fn compute(self: *JobBatch, out: *wgpu.WGPUComputePipeline, layout: wgpu.WGPUPipelineLayout, label: []const u8, entry: []const u8) void {
        if (out.* != null) return;
        self.push(.{ .label = label, .entry = entry, .layout = layout, .out = .{ .compute = out } });
    }

    fn render(self: *JobBatch, out: *wgpu.WGPURenderPipeline, layout: wgpu.WGPUPipelineLayout, label: []const u8, entry: []const u8, format: wgpu.WGPUTextureFormat, blend: bool, gbuffer: bool) void {
        if (out.* != null) return;
        self.push(.{ .label = label, .entry = entry, .layout = layout, .out = .{ .render = .{ .pipeline = out, .format = format, .blend = blend, .gbuffer = gbuffer } } });
    }

    fn addGroup(self: *JobBatch, ctx: *const Context, lay: Layouts, p: *PipelinePair, group: PipelineGroup) void {
        switch (group) {
            .core => {
                self.render(&p.march, lay.render, "fractal pipeline", "fs_main", accumFormat(ctx), true, true);
                self.render(&p.simple, lay.render, "fractal simple render pipeline", "fs_simple", accumFormat(ctx), true, true);
                self.render(&p.slice, lay.render, "fractal 2D slice pipeline", "fs_slice", accumFormat(ctx), true, true);
            },
            .select => self.render(&p.select, lay.select, "fractal selection id pipeline", "fs_select", select_format, false, false),
            .accel => self.compute(&p.build_accel, lay.accel, "accel build pipeline", "cs_build_accel"),
            .photons => {
                self.compute(&p.trace_photons, lay.photon, "photon trace pipeline", "cs_trace_photons");
                self.compute(&p.clear_photons, lay.photon, "photon clear pipeline", "cs_clear_photons");
                self.compute(&p.alloc_photons, lay.photon, "photon alloc pipeline", "cs_alloc_photons");
                self.compute(&p.scatter_photons, lay.photon, "photon scatter pipeline", "cs_scatter_photons");
            },
            .aim => self.compute(&p.aim_photons, lay.photon, "photon aim pipeline", "cs_photon_aim"),
            .aov => if (p.aov == null) self.push(.{ .label = "fractal denoise aov pipeline", .entry = "fs_aov", .layout = lay.render, .out = .{ .aov = &p.aov } }),
            .fft => {
                self.compute(&p.build_fft_voxelize, lay.fft, "fft voxelize pipeline", "cs_fft_voxelize");
                self.compute(&p.build_fft_axis_seed, lay.fft, "fft axis seed pipeline", "cs_fft_axis_seed");
                self.compute(&p.build_fft_axis_complex, lay.fft, "fft axis complex pipeline", "cs_fft_axis_complex");
                self.compute(&p.build_fft_magnitude, lay.fft, "fft magnitude pipeline", "cs_fft_magnitude");
                self.compute(&p.build_fft_finalize, lay.fft, "fft finalize pipeline", "cs_fft_finalize");
            },
            .particles => inline for (comptime std.enums.values(ParticleEntry)) |e| {
                const name = "cs_particle_" ++ @tagName(e);
                self.compute(&p.particle[@intFromEnum(e)], if (e.isSim()) lay.particle_sim else lay.particle_build, name, name);
            },
        }
    }

    fn addGroups(self: *JobBatch, ctx: *const Context, lay: Layouts, p: *PipelinePair, groups: GroupSet) void {
        var it = groups.iterator();
        while (it.next()) |g| self.addGroup(ctx, lay, p, g);
    }

    fn run(self: *JobBatch, ctx: *const Context, module: wgpu.WGPUShaderModule) bool {
        const jobs = self.slice();
        if (jobs.len == 0) return true;
        const errors_before = webgpu_context.g_error_count.load(.acquire);

        var queue = JobQueue{ .ctx = ctx, .module = module, .jobs = jobs };
        const workers = std.math.clamp(std.Thread.getCpuCount() catch 1, 1, jobs.len);
        var threads: [max_pipeline_jobs]std.Thread = undefined;
        var spawned: usize = 0;
        while (spawned + 1 < workers) : (spawned += 1) {
            threads[spawned] = std.Thread.spawn(.{}, JobQueue.drain, .{&queue}) catch break;
        }
        queue.drain();
        for (threads[0..spawned]) |t| t.join();

        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        var ok = webgpu_context.g_error_count.load(.acquire) == errors_before;
        for (jobs) |*j| {
            if (!j.made()) ok = false;
        }
        if (!ok) {
            for (jobs) |*j| j.discard();
        }
        return ok;
    }
};

const JobQueue = struct {
    ctx: *const Context,
    module: wgpu.WGPUShaderModule,
    jobs: []PipelineJob,
    next: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    fn drain(self: *JobQueue) void {
        while (true) {
            const i = self.next.fetchAdd(1, .acq_rel);
            if (i >= self.jobs.len) return;
            self.jobs[i].run(self.ctx, self.module);
        }
    }
};

fn groupNames(groups: GroupSet, buf: []u8) []const u8 {
    var len: usize = 0;
    var it = groups.iterator();
    while (it.next()) |g| {
        const name = @tagName(g);
        const sep: []const u8 = if (len == 0) "" else "+";
        if (len + sep.len + name.len > buf.len) break;
        @memcpy(buf[len..][0..sep.len], sep);
        len += sep.len;
        @memcpy(buf[len..][0..name.len], name);
        len += name.len;
    }
    return buf[0..len];
}

pub const RenderMode = enum { march, slice, simple };

const PipelineCacheEntry = struct {
    hash: u64,
    pipelines: PipelinePair,
    last_used: u64,
};

const PendingRebuild = struct {
    thread: std.Thread,
    shared: *Shared,
};

const Shared = struct {
    allocator: std.mem.Allocator,
    ctx: *const Context,
    layouts: Layouts,
    formula_sources: [max_instances][]u8,
    mixin_sources: [max_instances][max_mixins][]u8,
    variant: ShaderVariant,
    groups: GroupSet,
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
    select: wgpu.WGPUPipelineLayout,
    accel: wgpu.WGPUPipelineLayout,
    photon: wgpu.WGPUPipelineLayout,
    fft: wgpu.WGPUPipelineLayout,
    particle_sim: wgpu.WGPUPipelineLayout,
    particle_build: wgpu.WGPUPipelineLayout,
};

fn buildPipelines(ctx: *const Context, layouts: Layouts, source: []const u8, groups: GroupSet) !PipelinePair {
    g_error_sink.reset();
    var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
        .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
        .code = sv(source),
    };
    const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
        .nextInChain = @ptrCast(&shader_desc_wgsl),
        .label = sv("fractal shader"),
    }) orelse return error.ShaderModuleCreationFailed;

    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    wgpu.wgpuInstanceProcessEvents(ctx.instance);
    if (g_error_sink.has_error) {
        wgpu.wgpuShaderModuleRelease(module);
        return error.ShaderCompileFailed;
    }

    var pipelines = PipelinePair{ .module = module };
    var batch = JobBatch{};
    batch.addGroups(ctx, layouts, &pipelines, groups);
    if (!batch.run(ctx, module)) {
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

    const source = assembleShaderSource(shared.allocator, formula_sources, mixin_sources, shared.variant) catch |err| {
        shared.err_len = copyErr(shared, @errorName(err));
        return;
    };
    defer shared.allocator.free(source);
    shared.source_len = source.len;

    shared.pipelines = buildPipelines(shared.ctx, shared.layouts, source, shared.groups) catch |err| {
        const copied = copyErr(shared, g_error_sink.message());
        shared.err_len = if (copied > 0) copied else copyErr(shared, @errorName(err));
        return;
    };
    shared.ok = true;
    shared.total_ms = @intCast(sdl.SDL_GetTicks() -| started);
}

const GBuffer = struct {
    depth_texture: wgpu.WGPUTexture = null,
    depth_view: wgpu.WGPUTextureView = null,
    normal_texture: wgpu.WGPUTexture = null,
    normal_view: wgpu.WGPUTextureView = null,
};

fn createGBufferTexture(ctx: *const Context, label: []const u8, format: wgpu.WGPUTextureFormat, w: u32, h: u32) wgpu.WGPUTexture {
    return wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
        .dimension = wgpu.WGPUTextureDimension_2D,
        .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
        .format = format,
        .mipLevelCount = 1,
        .sampleCount = 1,
        .viewFormatCount = 0,
        .viewFormats = null,
    });
}

fn createGBuffer(ctx: *const Context, w: u32, h: u32) GBuffer {
    var out = GBuffer{};
    out.depth_texture = createGBufferTexture(ctx, "fractal depth target", depth_format, w, h);
    out.normal_texture = createGBufferTexture(ctx, "fractal normal target", normal_format, w, h);
    if (out.depth_texture != null) out.depth_view = wgpu.wgpuTextureCreateView(out.depth_texture, null);
    if (out.normal_texture != null) out.normal_view = wgpu.wgpuTextureCreateView(out.normal_texture, null);
    return out;
}

fn createDepthBindGroup(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, view: wgpu.WGPUTextureView) wgpu.WGPUBindGroup {
    return wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
        .nextInChain = null,
        .label = sv("selection depth bind group"),
        .layout = layout,
        .entryCount = 1,
        .entries = &[_]wgpu.WGPUBindGroupEntry{.{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = view }},
    });
}

fn releaseGBuffer(gbuf: GBuffer) void {
    if (gbuf.depth_view != null) wgpu.wgpuTextureViewRelease(gbuf.depth_view);
    if (gbuf.depth_texture != null) wgpu.wgpuTextureRelease(gbuf.depth_texture);
    if (gbuf.normal_view != null) wgpu.wgpuTextureViewRelease(gbuf.normal_view);
    if (gbuf.normal_texture != null) wgpu.wgpuTextureRelease(gbuf.normal_texture);
}

fn colorAttachment(view: wgpu.WGPUTextureView, load_existing: bool) wgpu.WGPURenderPassColorAttachment {
    return .{
        .nextInChain = null,
        .view = view,
        .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
        .resolveTarget = null,
        .loadOp = if (load_existing) wgpu.WGPULoadOp_Load else wgpu.WGPULoadOp_Clear,
        .storeOp = wgpu.WGPUStoreOp_Store,
        .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
}

const AdaptTarget = struct {
    buffer: wgpu.WGPUBuffer = null,
    group: wgpu.WGPUBindGroup = null,
    pixels: u64 = 0,

    fn release(self: *AdaptTarget) void {
        if (self.group != null) wgpu.wgpuBindGroupRelease(self.group);
        if (self.buffer != null) wgpu.wgpuBufferRelease(self.buffer);
        self.* = .{};
    }

    fn rowWidth(self: AdaptTarget, width: u32, height: u32) f32 {
        return if (self.pixels >= @as(u64, width) * height) @floatFromInt(width) else 0;
    }
};

fn createAdaptTargetSized(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, pixels: u64) AdaptTarget {
    const size = @max(pixels, 1) * adapt_stats_stride;
    var out = AdaptTarget{};
    out.buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
        .nextInChain = null,
        .label = sv("adaptive sampling stats"),
        .usage = wgpu.WGPUBufferUsage_Storage,
        .size = size,
        .mappedAtCreation = 0,
    });
    if (out.buffer == null) return out;
    out.group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
        .nextInChain = null,
        .label = sv("adaptive sampling bind group"),
        .layout = layout,
        .entryCount = 1,
        .entries = &[_]wgpu.WGPUBindGroupEntry{.{ .nextInChain = null, .binding = 1, .buffer = out.buffer, .offset = 0, .size = size, .sampler = null, .textureView = null }},
    });
    if (out.group == null) {
        out.release();
        return out;
    }
    out.pixels = @max(pixels, 1);
    return out;
}

fn createAdaptTarget(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, width: u32, height: u32) AdaptTarget {
    const pixels = @as(u64, @max(width, 1)) * @max(height, 1);
    const size = pixels * adapt_stats_stride;
    if (size <= ctx.limits.maxStorageBufferBindingSize and size <= ctx.limits.maxBufferSize) {
        const full = createAdaptTargetSized(ctx, layout, pixels);
        if (full.group != null) return full;
    }
    return createAdaptTargetSized(ctx, layout, 1);
}

fn marchAttachments(color: wgpu.WGPUTextureView, gbuf: GBuffer, load_existing: bool) [3]wgpu.WGPURenderPassColorAttachment {
    return .{
        colorAttachment(color, load_existing),
        colorAttachment(gbuf.depth_view, load_existing),
        colorAttachment(gbuf.normal_view, load_existing),
    };
}

pub const FractalRenderer = struct {
    pipelines: PipelinePair,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    accel_pipeline_layout: wgpu.WGPUPipelineLayout,
    photon_pipeline_layout: wgpu.WGPUPipelineLayout,
    fft_pipeline_layout: wgpu.WGPUPipelineLayout,
    uniform_layout: wgpu.WGPUBindGroupLayout,
    bind_group: wgpu.WGPUBindGroup,
    uniform_buffer: wgpu.WGPUBuffer,
    uniform_slot_stride: u32,

    mesh: ?mesher.MeshGpu = null,

    accel: AccelGrid,
    accel_enabled: bool = true,
    accel_safety: f32 = 0.92,

    fft: FftVolume,

    photon_map: PhotonMap,
    photon_settings: photon_state.PhotonSettings = .{},

    sky: SkyTexture,
    sky_settings: sky_state.SkyState = .{},

    variant: ShaderVariant = .{},

    approx_settings: approximations.Approximations = .{},
    shaft_pipeline: wgpu.WGPURenderPipeline = null,
    shaft_failed: bool = false,

    adapt_layout: wgpu.WGPUBindGroupLayout,
    adapt_preview: AdaptTarget = .{},
    active_adapt_group: wgpu.WGPUBindGroup = null,

    denoise: bool = false,
    denoise_strength: f32 = 1.0,
    display_override: ?wgpu.WGPUBindGroup = null,

    particles: ParticleGpu,
    particle_sim_pipeline_layout: wgpu.WGPUPipelineLayout,
    particle_build_pipeline_layout: wgpu.WGPUPipelineLayout,

    content_generation: u32 = 0,

    pipeline_cache: [pipeline_cache_capacity]?PipelineCacheEntry = @splat(null),
    cache_clock: u64 = 0,
    failed_groups: GroupSet = GroupSet.empty,

    pending: ?PendingRebuild = null,
    parts: PartsPipelines = .{},
    last_err_buf: [512]u8 = undefined,
    last_err_len: usize = 0,

    offscreen_texture: wgpu.WGPUTexture,
    offscreen_view: wgpu.WGPUTextureView,
    offscreen_width: u32,
    offscreen_height: u32,

    depth_texture: wgpu.WGPUTexture,
    depth_view: wgpu.WGPUTextureView,
    normal_texture: wgpu.WGPUTexture,
    normal_view: wgpu.WGPUTextureView,

    post: PostChain,
    post_targets: post_process.Targets = .{},
    post_result: ?wgpu.WGPUBindGroup = null,
    post_effects: [post_process.max_effects]post_process.Effect = undefined,
    post_effect_count: usize = 0,

    select_texture: wgpu.WGPUTexture,
    select_view: wgpu.WGPUTextureView,
    select_generation: u32,

    select_pipeline_layout: wgpu.WGPUPipelineLayout,
    select_depth_layout: wgpu.WGPUBindGroupLayout,
    select_depth_bind_group: wgpu.WGPUBindGroup = null,
    pick_depth_texture: wgpu.WGPUTexture,
    pick_depth_view: wgpu.WGPUTextureView,
    pick_depth_bind_group: wgpu.WGPUBindGroup,

    pick_texture: wgpu.WGPUTexture,
    pick_view: wgpu.WGPUTextureView,
    pick_buffer: wgpu.WGPUBuffer,

    sampler: wgpu.WGPUSampler,
    blit_pipeline: wgpu.WGPURenderPipeline,
    resolve_pipeline: wgpu.WGPURenderPipeline,
    tonemap_pipeline: wgpu.WGPURenderPipeline,
    blit_pipeline_layout: wgpu.WGPUPipelineLayout,
    blit_bind_group_layout: wgpu.WGPUBindGroupLayout,
    blit_bind_group: wgpu.WGPUBindGroup,

    pub fn init(ctx: *const Context, allocator: std.mem.Allocator) !FractalRenderer {
        const slot_stride = std.mem.alignForward(u64, @sizeOf(Uniforms), @max(ctx.limits.minUniformBufferOffsetAlignment, 1));
        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fractal uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = slot_stride * uniform_ring_slots,
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
                .hasDynamicOffset = 1,
                .minBindingSize = @sizeOf(Uniforms),
            },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const particle_data_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 1,
            .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Compute,
            .bindingArraySize = 0,
            .buffer = .{ .nextInChain = null, .type = wgpu.WGPUBufferBindingType_ReadOnlyStorage, .hasDynamicOffset = 0, .minBindingSize = 0 },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal bind group layout"),
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{ bgl_entry, particle_data_entry },
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(bind_group_layout);

        var particle_gpu = try ParticleGpu.init(ctx);
        errdefer particle_gpu.deinit();

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fractal bind group"),
            .layout = bind_group_layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{
                    .nextInChain = null,
                    .binding = 0,
                    .buffer = uniform_buffer,
                    .offset = 0,
                    .size = @sizeOf(Uniforms),
                    .sampler = null,
                    .textureView = null,
                },
                .{
                    .nextInChain = null,
                    .binding = 1,
                    .buffer = particle_gpu.data,
                    .offset = 0,
                    .size = ParticleGpu.dataSize(),
                    .sampler = null,
                    .textureView = null,
                },
            },
        }) orelse return error.BindGroupCreationFailed;

        const particle_sim_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("particle sim pipeline layout"),
            .bindGroupLayoutCount = 2,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, particle_gpu.sim_layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;
        const particle_build_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("particle build pipeline layout"),
            .bindGroupLayoutCount = 2,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ particle_gpu.empty_layout, particle_gpu.build_layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        var accel_grid = try AccelGrid.init(ctx);
        errdefer accel_grid.deinit();

        var photon_map = try PhotonMap.init(ctx);
        errdefer photon_map.deinit();

        var sky_tex = try SkyTexture.init(ctx);
        errdefer sky_tex.deinit();

        var fft_volume = try FftVolume.init(ctx);
        errdefer fft_volume.deinit();

        const adapt_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 1,
            .visibility = wgpu.WGPUShaderStage_Fragment,
            .bindingArraySize = 0,
            .buffer = .{ .nextInChain = null, .type = wgpu.WGPUBufferBindingType_Storage, .hasDynamicOffset = 0, .minBindingSize = adapt_stats_stride },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const adapt_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("adaptive sampling bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{adapt_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(adapt_layout);

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal pipeline layout"),
            .bindGroupLayoutCount = 6,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, accel_grid.render_layout, photon_map.render_layout, sky_tex.layout, fft_volume.render_layout, adapt_layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        if (ctx.limits.maxBindGroups < 6) {
            std.log.err("the selection pass needs 6 bind groups; this adapter allows {d}", .{ctx.limits.maxBindGroups});
            return error.TooFewBindGroups;
        }
        const select_depth_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Fragment,
            .bindingArraySize = 0,
            .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = .{ .nextInChain = null, .sampleType = wgpu.WGPUTextureSampleType_UnfilterableFloat, .viewDimension = wgpu.WGPUTextureViewDimension_2D, .multisampled = 0 },
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const select_depth_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("selection depth bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{select_depth_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;

        const select_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fractal selection pipeline layout"),
            .bindGroupLayoutCount = 6,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, accel_grid.render_layout, photon_map.render_layout, sky_tex.layout, fft_volume.render_layout, select_depth_layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        const pick_depth_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal pick depth (march)"),
            .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = 1, .height = 1, .depthOrArrayLayers = 1 },
            .format = depth_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        const march_marker: f32 = -1;
        wgpu.wgpuQueueWriteTexture(
            ctx.queue,
            &wgpu.WGPUTexelCopyTextureInfo{ .texture = pick_depth_texture, .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
            &march_marker,
            @sizeOf(f32),
            &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = @sizeOf(f32), .rowsPerImage = 1 },
            &wgpu.WGPUExtent3D{ .width = 1, .height = 1, .depthOrArrayLayers = 1 },
        );
        const pick_depth_view = wgpu.wgpuTextureCreateView(pick_depth_texture, null) orelse return error.TextureViewCreationFailed;
        const pick_depth_bind_group = createDepthBindGroup(ctx, select_depth_layout, pick_depth_view) orelse return error.BindGroupCreationFailed;

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

        const fft_pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fft build pipeline layout"),
            .bindGroupLayoutCount = 2,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ bind_group_layout, fft_volume.compute_layout },
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

        const blit_pipeline = createPipeline(ctx, blit_pipeline_layout, blit_module, "fractal blit pipeline", "fs_main", ctx.surface_format, false, false) orelse
            return error.RenderPipelineCreationFailed;
        const resolve_pipeline = createPipeline(ctx, blit_pipeline_layout, blit_module, "fractal dof resolve pipeline", "fs_resolve", hdr_format, false, false) orelse
            return error.RenderPipelineCreationFailed;
        const tonemap_pipeline = createPipeline(ctx, blit_pipeline_layout, blit_module, "fractal tonemap pipeline", "fs_tonemap", ctx.surface_format, false, false) orelse
            return error.RenderPipelineCreationFailed;

        var post_chain = try PostChain.init(ctx, hdr_format);
        errdefer post_chain.deinit();

        const pick_buffer_size: u64 = 256;
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
            .fft_pipeline_layout = fft_pipeline_layout,
            .uniform_layout = bind_group_layout,
            .adapt_layout = adapt_layout,
            .uniform_slot_stride = @intCast(slot_stride),
            .accel = accel_grid,
            .fft = fft_volume,
            .photon_map = photon_map,
            .sky = sky_tex,
            .particles = particle_gpu,
            .particle_sim_pipeline_layout = particle_sim_pipeline_layout,
            .particle_build_pipeline_layout = particle_build_pipeline_layout,
            .bind_group = bind_group,
            .uniform_buffer = uniform_buffer,
            .offscreen_texture = null,
            .offscreen_view = null,
            .offscreen_width = 0,
            .offscreen_height = 0,
            .depth_texture = null,
            .depth_view = null,
            .normal_texture = null,
            .normal_view = null,
            .post = post_chain,
            .select_texture = null,
            .select_view = null,
            .select_generation = 0,
            .select_pipeline_layout = select_pipeline_layout,
            .select_depth_layout = select_depth_layout,
            .pick_depth_texture = pick_depth_texture,
            .pick_depth_view = pick_depth_view,
            .pick_depth_bind_group = pick_depth_bind_group,
            .pick_texture = pick_texture,
            .pick_view = pick_view,
            .pick_buffer = pick_buffer,
            .sampler = sampler,
            .blit_pipeline = blit_pipeline,
            .resolve_pipeline = resolve_pipeline,
            .tonemap_pipeline = tonemap_pipeline,
            .blit_pipeline_layout = blit_pipeline_layout,
            .blit_bind_group_layout = blit_bind_group_layout,
            .blit_bind_group = null,
        };
        self.ensureOffscreenSize(ctx, @max(ctx.width, 1), @max(ctx.height, 1));
        _ = self.accel.ensureSize(ctx, accel.default_resolution, accel.default_levels);
        _ = self.photon_map.ensureSize(ctx, photons.default_grid_log2);
        _ = self.fft.ensureAllocated(ctx);

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
        self.parts.deinit();

        for (self.pipeline_cache) |slot| {
            if (slot) |entry| entry.pipelines.release();
        }
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.accel_pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.photon_pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.fft_pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.particle_sim_pipeline_layout);
        wgpu.wgpuPipelineLayoutRelease(self.particle_build_pipeline_layout);
        if (self.mesh) |*m| m.deinit();
        wgpu.wgpuBindGroupLayoutRelease(self.uniform_layout);
        self.accel.deinit();
        self.photon_map.deinit();
        self.fft.deinit();
        self.sky.deinit();
        wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuBufferRelease(self.uniform_buffer);
        self.particles.deinit();

        self.post_targets.deinit();
        self.post.deinit();
        wgpu.wgpuBindGroupRelease(self.blit_bind_group);
        wgpu.wgpuTextureViewRelease(self.offscreen_view);
        wgpu.wgpuTextureRelease(self.offscreen_texture);
        if (self.depth_view != null) wgpu.wgpuTextureViewRelease(self.depth_view);
        if (self.depth_texture != null) wgpu.wgpuTextureRelease(self.depth_texture);
        if (self.normal_view != null) wgpu.wgpuTextureViewRelease(self.normal_view);
        if (self.normal_texture != null) wgpu.wgpuTextureRelease(self.normal_texture);
        if (self.select_view != null) wgpu.wgpuTextureViewRelease(self.select_view);
        if (self.select_texture != null) wgpu.wgpuTextureRelease(self.select_texture);
        if (self.select_depth_bind_group != null) wgpu.wgpuBindGroupRelease(self.select_depth_bind_group);
        wgpu.wgpuBindGroupRelease(self.pick_depth_bind_group);
        wgpu.wgpuTextureViewRelease(self.pick_depth_view);
        wgpu.wgpuTextureRelease(self.pick_depth_texture);
        wgpu.wgpuPipelineLayoutRelease(self.select_pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.select_depth_layout);
        wgpu.wgpuBufferRelease(self.pick_buffer);
        wgpu.wgpuTextureViewRelease(self.pick_view);
        wgpu.wgpuTextureRelease(self.pick_texture);
        wgpu.wgpuSamplerRelease(self.sampler);
        wgpu.wgpuRenderPipelineRelease(self.blit_pipeline);
        wgpu.wgpuRenderPipelineRelease(self.resolve_pipeline);
        wgpu.wgpuRenderPipelineRelease(self.tonemap_pipeline);
        wgpu.wgpuPipelineLayoutRelease(self.blit_pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.blit_bind_group_layout);
        self.adapt_preview.release();
        wgpu.wgpuBindGroupLayoutRelease(self.adapt_layout);
        if (self.shaft_pipeline != null) wgpu.wgpuRenderPipelineRelease(self.shaft_pipeline);
    }

    pub fn ensureOffscreenSize(self: *FractalRenderer, ctx: *const Context, width: u32, height: u32) void {
        const w = @max(width, 1);
        const h = @max(height, 1);
        if (w == self.offscreen_width and h == self.offscreen_height) return;

        const new_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fractal offscreen"),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopySrc,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            .format = accumFormat(ctx),
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
        self.content_generation +%= 1;

        if (self.depth_view != null) wgpu.wgpuTextureViewRelease(self.depth_view);
        if (self.depth_texture != null) wgpu.wgpuTextureRelease(self.depth_texture);
        if (self.normal_view != null) wgpu.wgpuTextureViewRelease(self.normal_view);
        if (self.normal_texture != null) wgpu.wgpuTextureRelease(self.normal_texture);
        const gbuf = createGBuffer(ctx, w, h);
        self.depth_texture = gbuf.depth_texture;
        self.depth_view = gbuf.depth_view;
        self.normal_texture = gbuf.normal_texture;
        self.normal_view = gbuf.normal_view;

        if (self.select_depth_bind_group != null) wgpu.wgpuBindGroupRelease(self.select_depth_bind_group);
        self.select_depth_bind_group = if (self.depth_view != null) createDepthBindGroup(ctx, self.select_depth_layout, self.depth_view) else null;

        self.adapt_preview.release();
        self.adapt_preview = createAdaptTarget(ctx, self.adapt_layout, w, h);
        self.active_adapt_group = self.adapt_preview.group;

        self.post_targets.deinit();

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

    fn createPipeline(ctx: *const Context, pipeline_layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, label: []const u8, fragment_entry: []const u8, target_format: wgpu.WGPUTextureFormat, enable_blend: bool, gbuffer: bool) wgpu.WGPURenderPipeline {
        return createPipelineWith(ctx, pipeline_layout, module, label, fragment_entry, target_format, enable_blend, gbuffer, &.{});
    }

    pub fn createPartsPipeline(ctx: *const Context, pipeline_layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, parts_off: u32) wgpu.WGPURenderPipeline {
        const constants = [_]wgpu.WGPUConstantEntry{
            .{ .nextInChain = null, .key = sv("PARTS_FIXED"), .value = 1 },
            .{ .nextInChain = null, .key = sv("PARTS_FIXED_OFF"), .value = @floatFromInt(parts_off) },
        };
        return createPipelineWith(ctx, pipeline_layout, module, "fractal parts pipeline", "fs_main", accumFormat(ctx), true, true, &constants);
    }

    fn createPipelineWith(ctx: *const Context, pipeline_layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, label: []const u8, fragment_entry: []const u8, target_format: wgpu.WGPUTextureFormat, enable_blend: bool, gbuffer: bool, constants: []const wgpu.WGPUConstantEntry) wgpu.WGPURenderPipeline {
        const blend_state = wgpu.WGPUBlendState{
            .color = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_Constant, .dstFactor = wgpu.WGPUBlendFactor_OneMinusConstant },
            .alpha = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_One, .dstFactor = wgpu.WGPUBlendFactor_Zero },
        };
        const color_targets = [_]wgpu.WGPUColorTargetState{
            .{
                .nextInChain = null,
                .format = target_format,
                .blend = if (enable_blend) &blend_state else null,
                .writeMask = wgpu.WGPUColorWriteMask_All,
            },
            .{ .nextInChain = null, .format = depth_format, .blend = null, .writeMask = wgpu.WGPUColorWriteMask_All },
            .{ .nextInChain = null, .format = normal_format, .blend = null, .writeMask = wgpu.WGPUColorWriteMask_All },
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
                .constantCount = constants.len,
                .constants = if (constants.len > 0) constants.ptr else null,
                .targetCount = if (gbuffer) color_targets.len else 1,
                .targets = &color_targets,
            },
        });
    }

    pub fn ensureGroup(self: *FractalRenderer, ctx: *const Context, group: PipelineGroup) !void {
        if (self.pipelines.has(group)) return;
        const module = self.pipelines.module orelse return error.PipelinesNotReady;
        if (self.failed_groups.contains(group)) return error.PipelineCreationFailed;
        const started = sdl.SDL_GetTicks();
        g_error_sink.reset();
        var p = self.pipelines;
        var batch = JobBatch{};
        batch.addGroup(ctx, self.pipelineLayouts(), &p, group);
        if (!batch.run(ctx, module)) {
            if (self.pending == null) self.failed_groups.insert(group);
            std.debug.print("[pipelines] on-demand {s} build failed: {s}\n", .{ @tagName(group), g_error_sink.message() });
            return error.PipelineCreationFailed;
        }
        std.debug.print("[pipelines] built {s} on demand ({d} pipelines) in {d}ms\n", .{ @tagName(group), batch.len, sdl.SDL_GetTicks() -| started });

        self.pipelines = p;
        for (&self.pipeline_cache) |*slot| {
            if (slot.*) |*entry| {
                if (entry.pipelines.module == module) entry.pipelines = p;
            }
        }
    }

    fn createAovPipeline(ctx: *const Context, layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule) wgpu.WGPURenderPipeline {
        const average = wgpu.WGPUBlendComponent{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_Constant, .dstFactor = wgpu.WGPUBlendFactor_OneMinusConstant };
        const blend_state = wgpu.WGPUBlendState{ .color = average, .alpha = average };
        const targets = [_]wgpu.WGPUColorTargetState{
            .{ .nextInChain = null, .format = aov_format, .blend = &blend_state, .writeMask = wgpu.WGPUColorWriteMask_All },
            .{ .nextInChain = null, .format = aov_format, .blend = &blend_state, .writeMask = wgpu.WGPUColorWriteMask_All },
        };
        return wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("fractal denoise aov pipeline"),
            .layout = layout,
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
                .entryPoint = sv("fs_aov"),
                .constantCount = 0,
                .constants = null,
                .targetCount = targets.len,
                .targets = &targets,
            },
        });
    }

    fn particlePipeline(self: *const FractalRenderer, e: ParticleEntry) wgpu.WGPUComputePipeline {
        return self.pipelines.particle[@intFromEnum(e)];
    }

    fn dispatchParticles(self: *const FractalRenderer, pass: wgpu.WGPUComputePassEncoder, e: ParticleEntry, group1: wgpu.WGPUBindGroup, threads: u32) void {
        wgpu.wgpuComputePassEncoderSetPipeline(pass, self.particlePipeline(e));
        if (e.isSim()) {
            const slot0: u32 = 0;
            wgpu.wgpuComputePassEncoderSetBindGroup(pass, 0, self.bind_group, 1, &slot0);
        } else {
            wgpu.wgpuComputePassEncoderSetBindGroup(pass, 0, self.particles.empty_group, 0, null);
        }
        wgpu.wgpuComputePassEncoderSetBindGroup(pass, 1, group1, 0, null);
        wgpu.wgpuComputePassEncoderDispatchWorkgroups(pass, (@max(threads, 1) + particles.workgroup - 1) / particles.workgroup, 1, 1);
    }

    fn submitParticlePass(ctx: *const Context, encoder: wgpu.WGPUCommandEncoder, pass: wgpu.WGPUComputePassEncoder) void {
        wgpu.wgpuComputePassEncoderEnd(pass);
        wgpu.wgpuComputePassEncoderRelease(pass);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);
    }

    fn beginParticlePass(ctx: *const Context, label: []const u8) !struct { encoder: wgpu.WGPUCommandEncoder, pass: wgpu.WGPUComputePassEncoder } {
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        const pass = wgpu.wgpuCommandEncoderBeginComputePass(encoder, &wgpu.WGPUComputePassDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .timestampWrites = null,
        }) orelse {
            wgpu.wgpuCommandEncoderRelease(encoder);
            return error.EncoderCreationFailed;
        };
        return .{ .encoder = encoder, .pass = pass };
    }

    pub fn updateParticles(self: *FractalRenderer, ctx: *const Context, jobs: *const [max_particle_systems]?particles.Job, scene: Uniforms) !bool {
        var built = false;
        var scene_written = false;
        for (jobs, 0..) |maybe_job, s| {
            const job = maybe_job orelse continue;
            const rt = &self.particles.runtime[s];
            const resim = !rt.has_sim or rt.sim_key != job.sim_key or job.target_steps < rt.steps;
            const stepping = resim or job.target_steps > rt.steps;
            if (!stepping and rt.has_build and rt.build_key == job.build_key and rt.build_steps == rt.steps) continue;

            try self.ensureGroup(ctx, .particles);
            if (!scene_written) {
                self.updateUniforms(ctx, scene);
                scene_written = true;
            }
            const started = sdl.SDL_GetTicks();
            const count: u32 = @intFromFloat(std.math.clamp(job.params.count, 0, @as(f32, @floatFromInt(particles.max_particles))));
            var params = job.params;
            params.system = @floatFromInt(s);

            if (resim) {
                rt.has_sim = false;
                params.steps_done = 0;
                self.particles.writeParams(ctx, params);
                const b = try beginParticlePass(ctx, "particle reset pass");
                self.dispatchParticles(b.pass, .reset, self.particles.sim_ba, particles.max_particles);
                submitParticlePass(ctx, b.encoder, b.pass);
                rt.steps = 0;
                rt.sim_key = job.sim_key;
                rt.has_sim = true;
            } else {
                self.particles.writeParams(ctx, params);
            }
            const first_step = rt.steps;

            while (rt.steps < job.target_steps) {
                const chunk = @min(particles.steps_per_submit, job.target_steps - rt.steps);
                const b = try beginParticlePass(ctx, "particle step pass");
                for (0..chunk) |k| {
                    const group = self.particles.simGroup(rt.steps + @as(u32, @intCast(k)));
                    self.dispatchParticles(b.pass, .hash_clear, group, particles.hash_buckets);
                    self.dispatchParticles(b.pass, .hash_insert, group, count);
                    self.dispatchParticles(b.pass, .step, group, count);
                    self.dispatchParticles(b.pass, .step_end, group, 1);
                }
                submitParticlePass(ctx, b.encoder, b.pass);
                rt.steps += chunk;
            }

            params.steps_done = @floatFromInt(rt.steps);
            self.particles.writeParams(ctx, params);
            self.particles.resetBuildCounters(ctx, s);
            {
                const group = self.particles.buildGroup(rt.steps);
                const b = try beginParticlePass(ctx, "particle grid build pass");
                self.dispatchParticles(b.pass, .emit, group, particles.max_particles);
                self.dispatchParticles(b.pass, .grid_setup, group, 1);
                self.dispatchParticles(b.pass, .grid_clear, group, particles.max_cells);
                self.dispatchParticles(b.pass, .grid_count, group, count);
                self.dispatchParticles(b.pass, .grid_alloc, group, particles.max_cells);
                self.dispatchParticles(b.pass, .grid_scatter, group, count);
                self.dispatchParticles(b.pass, .grid_dist_init, group, particles.max_cells);
                for (0..particles.dist_cap - 1) |_| self.dispatchParticles(b.pass, .grid_dilate, group, particles.max_cells);
                submitParticlePass(ctx, b.encoder, b.pass);
            }

            rt.build_key = job.build_key;
            rt.build_steps = rt.steps;
            rt.has_build = true;
            rt.generation +%= 1;
            built = true;
            if (rt.steps != first_step or resim) {
                std.debug.print("[particles] system {d}: {s}{d} -> {d} steps of {d} particles, encoded in {d}ms\n", .{
                    s + 1,
                    if (resim) "resim, " else "",
                    first_step,
                    rt.steps,
                    count,
                    sdl.SDL_GetTicks() -| started,
                });
            }
        }
        if (built) self.content_generation +%= 1;
        return built;
    }

    pub fn stampParticleUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        self.particles.stampGenerations(&uniforms.particle_systems);
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

    pub fn imageGeneration(self: *const FractalRenderer) u32 {
        return self.content_generation +% self.sky.generation;
    }

    fn usePipelines(self: *FractalRenderer, pipelines: PipelinePair) void {
        self.pipelines = pipelines;
        self.failed_groups = GroupSet.empty;
        self.content_generation +%= 1;
    }

    fn pipelineLayouts(self: *const FractalRenderer) Layouts {
        return .{
            .render = self.pipeline_layout,
            .select = self.select_pipeline_layout,
            .accel = self.accel_pipeline_layout,
            .photon = self.photon_pipeline_layout,
            .fft = self.fft_pipeline_layout,
            .particle_sim = self.particle_sim_pipeline_layout,
            .particle_build = self.particle_build_pipeline_layout,
        };
    }

    fn rebuildGroups(self: *const FractalRenderer) GroupSet {
        var groups = self.pipelines.builtGroups();
        groups.insert(.core);
        return groups;
    }

    pub fn rebuild(self: *FractalRenderer, ctx: *const Context, allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8) !void {
        self.parts.waitIdle();
        const hash = hashSources(formula_sources, mixin_sources, self.variant);
        if (self.findCachedPipeline(hash)) |pipelines| {
            std.debug.print("[stage] rebuild: cache hit (hash={x})\n", .{hash});
            self.usePipelines(pipelines);
            return;
        }

        const started = sdl.SDL_GetTicks();
        const source = try assembleShaderSource(allocator, formula_sources, mixin_sources, self.variant);
        defer allocator.free(source);
        const groups = self.rebuildGroups();
        const built = try buildPipelines(ctx, self.pipelineLayouts(), source, groups);
        var names_buf: [96]u8 = undefined;
        std.debug.print("[stage] rebuild: compiled {d} bytes ({s}) in {d}ms\n", .{ source.len, groupNames(groups, &names_buf), sdl.SDL_GetTicks() -| started });
        self.usePipelines(built);
        self.cachePipeline(hash, built);
    }

    pub fn rebuildAsync(self: *FractalRenderer, ctx: *const Context, allocator: std.mem.Allocator, formula_sources: [max_instances][]const u8, mixin_sources: [max_instances][max_mixins][]const u8, requester: ?*anyopaque) !RebuildStart {
        self.parts.waitIdle();
        const hash = hashSources(formula_sources, mixin_sources, self.variant);
        if (self.findCachedPipeline(hash)) |pipelines| {
            std.debug.print("[stage] rebuildAsync: cache hit (hash={x})\n", .{hash});
            self.usePipelines(pipelines);
            return .cache_hit;
        }

        if (self.pending != null) _ = self.pollRebuild(true);

        const shared = try allocator.create(Shared);
        errdefer allocator.destroy(shared);
        shared.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .layouts = self.pipelineLayouts(),
            .formula_sources = undefined,
            .mixin_sources = undefined,
            .variant = self.variant,
            .groups = self.rebuildGroups(),
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
            self.usePipelines(shared.pipelines);
            self.cachePipeline(shared.hash, shared.pipelines);
        }

        const outcome = RebuildOutcome{
            .ok = shared.ok,
            .err_message = self.last_err_buf[0..self.last_err_len],
            .requester = shared.requester,
        };
        var names_buf: [96]u8 = undefined;
        std.debug.print("[stage] pollRebuild: background compile {s} (hash={x}) {d}ms source={d} bytes groups={s} {s}\n", .{
            if (shared.ok) "succeeded" else "failed",
            shared.hash,
            shared.total_ms,
            shared.source_len,
            groupNames(shared.groups, &names_buf),
            if (shared.ok) "" else outcome.err_message,
        });

        shared.freeSources();
        shared.allocator.destroy(shared);

        return outcome;
    }

    pub fn updateUniforms(self: *FractalRenderer, ctx: *const Context, uniforms: Uniforms) void {
        var stamped = uniforms;
        stamped.adapt_row_width = self.adapt_preview.rowWidth(self.offscreen_width, self.offscreen_height);
        self.writeUniformSlot(ctx, 0, stamped);
    }

    pub fn stampApproxUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        const a = self.approx_settings;
        uniforms.approx_flags = @floatFromInt(a.mask());
        uniforms.approx_caustic_strength = a.caustic_strength;
        uniforms.approx_caustic_scale = a.caustic_scale;
        uniforms.approx_bounce = a.bounce_strength;
        uniforms.approx_tint = a.tint_density;
        uniforms.approx_lod_start = a.lod_start;
        uniforms.approx_lod_strength = a.lod_strength;
    }

    pub fn photonsReplaced(self: *const FractalRenderer) bool {
        return self.approx_settings.replacesPhotons();
    }

    pub fn shaftEffect(self: *FractalRenderer, ctx: *const Context, allocator: std.mem.Allocator, params: [8]f32) ?post_process.Effect {
        if (self.shaft_pipeline == null and !self.shaft_failed) {
            self.shaft_pipeline = self.post.compile(ctx, allocator, light_shafts_source) catch |err| blk: {
                std.debug.print("[shafts] light shaft effect failed to compile ({s}): {s}\n", .{ @errorName(err), g_error_sink.message() });
                self.shaft_failed = true;
                break :blk null;
            };
        }
        if (self.shaft_pipeline == null) return null;
        return .{ .pipeline = self.shaft_pipeline, .params0 = params[0..4].*, .params1 = params[4..8].* };
    }

    fn writeUniformSlot(self: *FractalRenderer, ctx: *const Context, slot: u32, uniforms: Uniforms) void {
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer, self.uniformOffset(slot), &uniforms, @sizeOf(Uniforms));
    }

    pub fn uniformOffset(self: *const FractalRenderer, slot: u32) u32 {
        return slot * self.uniform_slot_stride;
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
        uniforms.photon_radius = self.photon_map.stored_radius;
        uniforms.photon_cell = self.photon_map.stored_radius * 2.0;
        uniforms.photon_bounce_scale = self.photon_map.stored_bounce_scale;
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
        uniforms.photon_dispersion_soft = self.photon_settings.dispersionSoftness();
    }

    fn liveVolumeScale(self: *const FractalRenderer) f32 {
        return std.math.clamp(self.photon_settings.volume_scale, 1.0, 8.0);
    }

    pub fn stampSkyUniforms(self: *const FractalRenderer, uniforms: *Uniforms) void {
        uniforms.sky = self.sky_settings.toGpu(self.sky.loaded);
    }

    pub const FftSettings = struct {
        box_radius: f32 = 2.5,
        cloud_density: f32 = 4.0,
        lowpass: f32 = 1.0,
        highpass: f32 = 0.0,
        normalize: bool = false,
    };

    pub fn stampFftUniforms(uniforms: *Uniforms, active_slot: ?usize, settings: FftSettings) void {
        if (active_slot) |slot| {
            uniforms.fft_active = 1.0;
            uniforms.fft_target_slot = @floatFromInt(slot);
            uniforms.fft_box_radius = @max(settings.box_radius, 0.05);
            uniforms.fft_cloud_density = @max(settings.cloud_density, 0.0);
            uniforms.fft_lowpass = std.math.clamp(settings.lowpass, 0.0, 1.0);
            uniforms.fft_highpass = std.math.clamp(settings.highpass, 0.0, 1.0);
            uniforms.fft_normalize = if (settings.normalize) 1.0 else 0.0;
        } else {
            uniforms.fft_active = 0.0;
        }
    }

    pub fn buildFftVolume(self: *FractalRenderer, ctx: *const Context, scene: Uniforms) !void {
        if (!self.fft.isAllocated() or scene.fft_active < 0.5) return error.FftNotReady;
        try self.ensureGroup(ctx, .fft);

        const started_ms = sdl.SDL_GetTicks();
        const groups3d = fft.groups3d();
        const groups2d = fft.groups2d();

        var build_uniforms = scene;
        build_uniforms.fft_axis = 0;

        const binds = [_]ComputeBindGroup{
            .{ .index = 0, .group = self.bind_group },
            .{ .index = 1, .group = self.fft.compute_bind_group },
        };

        self.updateUniforms(ctx, build_uniforms);
        try runComputePass(ctx, "fft voxelize pass", self.pipelines.build_fft_voxelize, &binds, .{ groups3d, groups3d, groups3d }, false);
        try runComputePass(ctx, "fft axis-x pass", self.pipelines.build_fft_axis_seed, &binds, .{ groups2d, groups2d, 1 }, false);

        build_uniforms.fft_axis = 1;
        self.updateUniforms(ctx, build_uniforms);
        try runComputePass(ctx, "fft axis-y pass", self.pipelines.build_fft_axis_complex, &binds, .{ groups2d, groups2d, 1 }, false);

        build_uniforms.fft_axis = 2;
        self.updateUniforms(ctx, build_uniforms);
        try runComputePass(ctx, "fft axis-z pass", self.pipelines.build_fft_axis_complex, &binds, .{ groups2d, groups2d, 1 }, false);

        try runComputePass(ctx, "fft magnitude pass", self.pipelines.build_fft_magnitude, &binds, .{ groups3d, groups3d, groups3d }, false);
        try runComputePass(ctx, "fft finalize pass", self.pipelines.build_fft_finalize, &binds, .{ groups3d, groups3d, groups3d }, true);

        self.fft.valid = true;
        self.content_generation +%= 1;
        std.debug.print(
            "[fft] built {d}^3 volume in {d}ms\n",
            .{ fft.resolution, sdl.SDL_GetTicks() -| started_ms },
        );
    }

    pub fn buildAccel(self: *FractalRenderer, ctx: *const Context, scene: Uniforms) !void {
        if (!self.accel.isAllocated()) return error.AccelNotReady;
        try self.ensureGroup(ctx, .accel);

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
            }, .{ groups_xy, groups_xy, groups_z }, z + slab >= total_layers);
        }

        self.accel.valid = true;
        self.content_generation +%= 1;
        self.accel.last_build_ms = @intCast(sdl.SDL_GetTicks() -| started_ms);
        std.debug.print(
            "[accel] built {d}^3 x {d} cascades ({d} voxels, finest cell {d:.4}) in {d}ms\n",
            .{ res, levels, @as(u64, res) * res * res * levels, self.accel.params[0][3], self.accel.last_build_ms },
        );
    }

    pub fn meshGpu(
        self: *FractalRenderer,
        ctx: *const Context,
        allocator: std.mem.Allocator,
        formula_sources: [max_instances][]const u8,
        mixin_sources: [max_instances][max_mixins][]const u8,
    ) !*mesher.MeshGpu {
        if (self.mesh == null) self.mesh = try mesher.MeshGpu.init(ctx, self.uniform_layout);
        const m = &self.mesh.?;
        const hash = hashSources(formula_sources, mixin_sources, self.variant);
        if (m.hasModule(hash)) return m;

        const started = sdl.SDL_GetTicks();
        const template_part = try assembleShaderSource(allocator, formula_sources, mixin_sources, self.variant);
        defer allocator.free(template_part);
        const source = try std.mem.concat(allocator, u8, &.{ template_part, mesher.shader_source });
        defer allocator.free(source);
        try m.buildModule(ctx, source, hash);
        std.debug.print("[mesh] compiled mesh module ({d} bytes) in {d}ms\n", .{ source.len, sdl.SDL_GetTicks() -| started });
        return m;
    }

    pub fn tracePhotons(self: *FractalRenderer, ctx: *const Context, scene: Uniforms, seed: f32, radius: f32) !void {
        if (!self.photon_map.isAllocated()) return error.PhotonMapNotReady;
        try self.ensureGroup(ctx, .photons);

        const started_ms = sdl.SDL_GetTicks();
        const buckets = self.photon_map.buckets;
        const paths = self.photon_settings.pathCount();

        self.photon_map.stored_radius = @max(radius, 1e-4);
        self.photon_map.stored_bounce_scale = self.photon_settings.bounceScale();

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
            trace_uniforms.photon_cell * trace_uniforms.photon_volume_scale,
        );
        self.photon_map.stored_fixed_unit = trace_uniforms.photon_fixed_unit;

        const bucket_groups = (buckets + photons.workgroup_dim - 1) / photons.workgroup_dim;
        const staging_capacity = self.photon_map.poolPhotons();
        const staging_groups = (staging_capacity + photons.workgroup_dim - 1) / photons.workgroup_dim;
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

        trace_uniforms.photon_aim = 0;
        if (self.photon_settings.aim) {
            const key = photon_state.aimKey(&trace_uniforms);
            if (!self.photon_map.aim_valid or key != self.photon_map.aim_key) {
                self.photon_map.aim_valid = false;
                if (self.buildPhotonAim(ctx, trace_uniforms, &binds)) {
                    self.photon_map.aim_key = key;
                    self.photon_map.aim_valid = true;
                } else |err| {
                    std.debug.print("[photons] aim pilot failed ({s}); emitting uniformly\n", .{@errorName(err)});
                }
            }
            if (self.photon_map.aim_valid) trace_uniforms.photon_aim = 1;
        }

        {
            self.updateUniforms(ctx, trace_uniforms);
            try runComputePass(ctx, "photon clear pass", self.pipelines.clear_photons, &binds, .{ bucket_groups, 1, 1 }, false);
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
                    if (pass == 0) "photon count pass" else "photon retrace pass",
                    self.pipelines.trace_photons,
                    &binds,
                    .{ groups_for(chunk), 1, 1 },
                    false,
                );
            }

            if (pass == 0) {
                trace_uniforms.photon_path_offset = 0;
                self.updateUniforms(ctx, trace_uniforms);
                try runComputePass(ctx, "photon alloc pass", self.pipelines.alloc_photons, &binds, .{ bucket_groups, 1, 1 }, false);
                try runComputePass(ctx, "photon scatter pass", self.pipelines.scatter_photons, &binds, .{ staging_groups, 1, 1 }, false);
            }
        }

        const stats = self.readPhotonStats(ctx) catch photons.TraceStats{};
        self.photon_map.noteStats(stats);
        const retraced = stats.staged > staging_capacity;

        self.photon_map.valid = true;
        self.content_generation +%= 1;
        self.photon_map.last_paths = paths;
        self.photon_map.last_trace_ms = @intCast(sdl.SDL_GetTicks() -| started_ms);

        std.debug.print(
            "[photons] traced {d} paths x {d} bounces into {d} cells (radius {d:.4}, cap {d}) in {d}ms -- pool {d}/{d}, {d} deposits had no bucket, {d} cells had no pool, {d} staged{s}\n",
            .{
                paths,
                @as(u32, @intFromFloat(@max(self.photon_settings.bounces, 0))),
                stats.occupiedCells(),
                self.photon_map.stored_radius,
                trace_uniforms.photon_cap_surface,
                self.photon_map.last_trace_ms,
                stats.pool_used,
                self.photon_map.poolPhotons(),
                stats.dropped_no_bucket,
                stats.dropped_no_pool,
                stats.staged,
                if (retraced) " (overflowed staging: traced twice)" else "",
            },
        );
    }

    fn buildPhotonAim(self: *FractalRenderer, ctx: *const Context, scene: Uniforms, binds: []const ComputeBindGroup) !void {
        try self.ensureGroup(ctx, .aim);
        const started_ms = sdl.SDL_GetTicks();
        const light_count: u32 = @intFromFloat(std.math.clamp(scene.light_count, 0, @as(f32, @floatFromInt(max_lights))));
        if (light_count == 0) return;
        const cells = light_count * photons.aim_cells;

        self.updateUniforms(ctx, scene);
        try runComputePass(ctx, "photon aim pilot", self.pipelines.aim_photons, binds, .{ (cells + photons.workgroup_dim - 1) / photons.workgroup_dim, 1, 1 }, false);

        const size: u64 = @as(u64, cells) * @sizeOf(f32);
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, self.photon_map.aim_weights, 0, self.photon_map.aim_read, 0, size);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        var map_state = MapState{};
        _ = wgpu.wgpuBufferMapAsync(self.photon_map.aim_read, wgpu.WGPUMapMode_Read, 0, size, wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onBufferMapped,
            .userdata1 = &map_state,
            .userdata2 = null,
        });
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_ms);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) {
            return error.BufferMapFailed;
        }
        defer wgpu.wgpuBufferUnmap(self.photon_map.aim_read);
        const ptr = wgpu.wgpuBufferGetConstMappedRange(self.photon_map.aim_read, 0, size) orelse return error.MappedRangeFailed;
        const raw: [*]const f32 = @ptrCast(@alignCast(ptr));

        const allocator = std.heap.page_allocator;
        const table = try allocator.alloc(photons.AimEntry, cells);
        defer allocator.free(table);
        const scaled = try allocator.alloc(f64, photons.aim_cells);
        defer allocator.free(scaled);
        const idx = try allocator.alloc(u32, photons.aim_cells);
        defer allocator.free(idx);

        var aimed: u32 = 0;
        for (0..light_count) |li| {
            const lo = li * photons.aim_cells;
            const out = table[lo..][0..photons.aim_cells];
            const kind = scene.lights[li].light_type;
            const built = kind < 1.5 and photons.buildAimTable(raw[lo..][0..photons.aim_cells], kind < 0.5, scaled, idx, out);
            if (built) aimed += 1 else photons.uniformAimTable(out);
        }
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.photon_map.aim_table, 0, table.ptr, @as(usize, cells) * @sizeOf(photons.AimEntry));

        std.debug.print("[photons] aimed {d}/{d} lights at the scene in {d}ms\n", .{ aimed, light_count, sdl.SDL_GetTicks() -| started_ms });
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
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_ms);
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
            .staged = words[5],
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

        if ((self.post_effect_count > 0 or self.denoiseWanted(samples)) and tile_dim < @max(width, height)) {
            const padded_row = ((width * bytes_per_pixel + row_align - 1) / row_align) * row_align;
            const one_tile = @max(width, height);
            if (one_tile <= ctx.limits.maxTextureDimension2D and
                @as(u64, padded_row) * height <= ctx.limits.maxBufferSize and
                @as(u64, width) * height <= post_single_tile_px_budget)
            {
                tile_dim = one_tile;
            } else {
                std.debug.print(
                    "[export] {d}x{d} is too large to render in one piece; screen-space effects and denoising will seam at {d}px tile edges\n",
                    .{ width, height, tile_dim },
                );
            }
        }

        const pixels = try allocator.alloc(u8, @as(usize, width) * height * bytes_per_pixel);
        errdefer allocator.free(pixels);

        var first = samples.at(0).*;
        self.stampApproxUniforms(&first);

        self.accel.invalidate();
        if (self.accel_enabled and !samples.is2d() and samples.allMatch(self.photon_settings, accelSceneHash)) {
            self.buildAccel(ctx, first) catch |err| {
                std.debug.print("[accel] export build failed ({s}); rendering without it\n", .{@errorName(err)});
                self.accel.invalidate();
            };
        }

        self.photon_map.invalidate();
        if (self.photon_settings.enabled and !self.photonsReplaced() and !samples.is2d() and samples.allMatch(self.photon_settings, photonSceneHash)) {
            self.tracePhotons(ctx, first, 1.0, self.photon_settings.baseRadius()) catch |err| {
                std.debug.print("[photons] export trace failed ({s}); rendering without caustics\n", .{@errorName(err)});
                self.photon_map.invalidate();
            };
        }
        defer self.accel.invalidate();
        defer self.photon_map.invalidate();

        var tracker = ProgressTracker{
            .progress = progress,
            .total = @as(u64, width) * height * samples.count(),
        };

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
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding |
                wgpu.WGPUTextureUsage_CopySrc | wgpu.WGPUTextureUsage_CopyDst,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 },
            .format = accumFormat(ctx),
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        defer wgpu.wgpuTextureRelease(export_texture);
        const export_view = wgpu.wgpuTextureCreateView(export_texture, null) orelse return error.TextureViewCreationFailed;
        defer wgpu.wgpuTextureViewRelease(export_view);

        const tile_gbuf = createGBuffer(ctx, tile_w, tile_h);
        defer releaseGBuffer(tile_gbuf);
        if (tile_gbuf.depth_view == null or tile_gbuf.normal_view == null) return error.TextureCreationFailed;

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

        var tile_adapt = createAdaptTarget(ctx, self.adapt_layout, tile_w, tile_h);
        defer tile_adapt.release();
        if (tile_adapt.group == null) return error.BufferCreationFailed;
        const tile_adapt_width = tile_adapt.rowWidth(tile_w, tile_h);
        const preview_adapt_group = self.active_adapt_group;
        self.active_adapt_group = tile_adapt.group;
        defer self.active_adapt_group = preview_adapt_group;

        const tile_start_ms = nowMs();
        const tile = tileTransform(full_width, full_height, tile_x, tile_y, tile_w, tile_h);
        const is_2d = samples.is2d();
        var pacer = ExportPacer{
            .max_side = if (is_2d) export_max_sub_side_2d else export_max_sub_side_3d,
        };
        var batch = ExportBatch{};
        errdefer batch.discard();
        var cleared = false;

        const sample_count = samples.count();
        var s: u32 = 0;
        while (s < sample_count) : (s += 1) {
            if (batch.cmd_encoder != null and s - batch.first_sample >= uniform_ring_slots) {
                try batch.flush(ctx, &pacer, tracker);
            }
            const slot = s % uniform_ring_slots;
            var uniforms = samples.at(s).*;
            uniforms.tile_scale = tile.scale;
            uniforms.tile_bias = tile.bias;
            uniforms.mc_sample = @floatFromInt(s);
            uniforms.adapt_row_width = tile_adapt_width;
            self.stampAccelUniforms(&uniforms);
            self.stampPhotonUniforms(&uniforms);
            self.stampSkyUniforms(&uniforms);
            self.stampApproxUniforms(&uniforms);
            self.writeUniformSlot(ctx, slot, uniforms);

            const blend_constant: f32 = 1.0 / @as(f32, @floatFromInt(s + 1));
            var stack: [64]Rect = undefined;
            stack[0] = .{ .x = 0, .y = 0, .w = tile_w, .h = tile_h };
            var stack_len: usize = 1;

            while (stack_len > 0) {
                stack_len -= 1;
                var rect = stack[stack_len];
                const side = pacer.subTileSide();
                while ((rect.w > side or rect.h > side) and stack_len < stack.len) {
                    const halves = rect.split();
                    stack[stack_len] = halves[1];
                    stack_len += 1;
                    rect = halves[0];
                }

                const encoder = try batch.encoder(ctx, s);
                const attachments = marchAttachments(export_view, tile_gbuf, cleared);
                const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
                    .nextInChain = null,
                    .label = sv("fractal export sub-tile pass"),
                    .colorAttachmentCount = attachments.len,
                    .colorAttachments = &attachments,
                    .depthStencilAttachment = null,
                    .occlusionQuerySet = null,
                    .timestampWrites = null,
                }).?;
                cleared = true;
                wgpu.wgpuRenderPassEncoderSetScissorRect(pass, rect.x, rect.y, rect.w, rect.h);
                self.drawSlot(pass, blend_constant, if (is_2d) .slice else .march, slot);
                wgpu.wgpuRenderPassEncoderEnd(pass);
                wgpu.wgpuRenderPassEncoderRelease(pass);

                batch.pixels += rect.area();
                batch.est_ms += pacer.estimateMs(rect.area());
                if (batch.est_ms >= export_batch_target_ms) try batch.flush(ctx, &pacer, tracker);
            }
        }
        try batch.flush(ctx, &pacer, tracker);

        if (perf_probe.enabled()) {
            std.debug.print("[perf] export tile {d}x{d} x{d} samples: {d} submits, sub-tile settled at {d}px, {d:.0}ms\n", .{
                tile_w, tile_h, sample_count, pacer.submits, pacer.side, nowMs() - tile_start_ms,
            });
        }

        if (self.denoiseWanted(samples)) {
            self.denoiseTile(ctx, samples, tile, export_texture, tile_w, tile_h) catch |err| {
                std.debug.print("[denoise] tile {d}x{d} left noisy ({s})\n", .{ tile_w, tile_h, @errorName(err) });
            };
        }

        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;

        var tile_post = post_process.Targets{};
        defer tile_post.deinit();
        var chained: ?wgpu.WGPUBindGroup = null;
        const effects = self.postEffects();
        if (effects.len > 0) {
            tile_post = self.post.createTargets(
                ctx,
                self.blit_bind_group_layout,
                self.sampler,
                tile_w,
                tile_h,
                tile_gbuf.depth_view,
                tile_gbuf.normal_view,
            );
            var frame = postFrameInfo(samples.at(0).*, tile_w, tile_h);
            frame.tile_scale = tile.scale;
            frame.tile_bias = tile.bias;
            chained = self.post.apply(ctx, encoder, &tile_post, self.resolve_pipeline, resolve_bind_group, effects, frame);
            if (chained == null) {
                std.debug.print("[post] could not allocate screen-space targets for this tile -- effects skipped\n", .{});
            }
        }

        const resolve_pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal export resolve pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{colorAttachment(export_resolve_view, false)},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;
        if (chained) |group| {
            wgpu.wgpuRenderPassEncoderSetPipeline(resolve_pass, self.tonemap_pipeline);
            wgpu.wgpuRenderPassEncoderSetBindGroup(resolve_pass, 0, group, 0, null);
        } else {
            wgpu.wgpuRenderPassEncoderSetPipeline(resolve_pass, self.blit_pipeline);
            wgpu.wgpuRenderPassEncoderSetBindGroup(resolve_pass, 0, resolve_bind_group, 0, null);
        }
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
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_ms);
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

    fn denoiseWanted(self: *const FractalRenderer, samples: *const SampleSet) bool {
        return self.denoise and !samples.is2d() and oidn.available();
    }

    fn aovSampleCount(samples: *const SampleSet) u32 {
        const first = samples.at(0);
        const lens = first.dof_enabled > 0.5 and first.aperture > 0.0001;
        const moving = std.meta.activeTag(samples.*) == .per_sample;
        return if (lens or moving) @min(samples.count(), aov_max_samples) else 1;
    }

    pub fn createAovTexture(ctx: *const Context, label: []const u8, w: u32, h: u32) wgpu.WGPUTexture {
        return wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_CopySrc,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            .format = aov_format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        });
    }

    pub fn encodeAovPass(
        self: *FractalRenderer,
        encoder: wgpu.WGPUCommandEncoder,
        albedo_view: wgpu.WGPUTextureView,
        normal_view: wgpu.WGPUTextureView,
        load_existing: bool,
        slot: u32,
        blend: f64,
        scissor: ?Rect,
    ) void {
        const attachments = [_]wgpu.WGPURenderPassColorAttachment{
            colorAttachment(albedo_view, load_existing),
            colorAttachment(normal_view, load_existing),
        };
        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal denoise aov pass"),
            .colorAttachmentCount = attachments.len,
            .colorAttachments = &attachments,
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;
        if (scissor) |r| wgpu.wgpuRenderPassEncoderSetScissorRect(pass, r.x, r.y, r.w, r.h);
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipelines.aov);
        self.bindSceneGroupsSlot(pass, slot);
        wgpu.wgpuRenderPassEncoderSetBlendConstant(pass, &wgpu.WGPUColor{ .r = blend, .g = blend, .b = blend, .a = blend });
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
    }

    fn renderAovs(
        self: *FractalRenderer,
        ctx: *const Context,
        samples: *const SampleSet,
        tile: TileTransform,
        albedo_view: wgpu.WGPUTextureView,
        normal_view: wgpu.WGPUTextureView,
        tile_w: u32,
        tile_h: u32,
        aov_samples: u32,
    ) !void {
        const count = samples.count();
        var cleared = false;
        var k: u32 = 0;
        while (k < aov_samples) : (k += 1) {
            const index = k * count / aov_samples;
            var uniforms = samples.at(index).*;
            uniforms.tile_scale = tile.scale;
            uniforms.tile_bias = tile.bias;
            uniforms.mc_sample = @floatFromInt(index);
            self.stampAccelUniforms(&uniforms);
            self.stampPhotonUniforms(&uniforms);
            self.stampSkyUniforms(&uniforms);
            self.stampApproxUniforms(&uniforms);
            const slot = k % uniform_ring_slots;
            self.writeUniformSlot(ctx, slot, uniforms);
            const blend: f64 = 1.0 / @as(f64, @floatFromInt(k + 1));

            var y: u32 = 0;
            while (y < tile_h) : (y += aov_sub_side) {
                var x: u32 = 0;
                while (x < tile_w) : (x += aov_sub_side) {
                    const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
                    self.encodeAovPass(encoder, albedo_view, normal_view, cleared, slot, blend, .{
                        .x = x,
                        .y = y,
                        .w = @min(aov_sub_side, tile_w - x),
                        .h = @min(aov_sub_side, tile_h - y),
                    });
                    cleared = true;

                    const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
                    wgpu.wgpuCommandEncoderRelease(encoder);
                    wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
                    wgpu.wgpuCommandBufferRelease(cmd);
                }
            }
        }
        try waitForQueueIdle(ctx);
    }

    fn denoiseTile(
        self: *FractalRenderer,
        ctx: *const Context,
        samples: *const SampleSet,
        tile: TileTransform,
        color_texture: wgpu.WGPUTexture,
        tile_w: u32,
        tile_h: u32,
    ) !void {
        const started_ms = nowMs();
        try self.ensureGroup(ctx, .aov);

        const albedo_texture = createAovTexture(ctx, "fractal denoise albedo", tile_w, tile_h) orelse return error.TextureCreationFailed;
        defer wgpu.wgpuTextureRelease(albedo_texture);
        const normal_texture = createAovTexture(ctx, "fractal denoise normal", tile_w, tile_h) orelse return error.TextureCreationFailed;
        defer wgpu.wgpuTextureRelease(normal_texture);
        const albedo_view = wgpu.wgpuTextureCreateView(albedo_texture, null) orelse return error.TextureViewCreationFailed;
        defer wgpu.wgpuTextureViewRelease(albedo_view);
        const normal_view = wgpu.wgpuTextureCreateView(normal_texture, null) orelse return error.TextureViewCreationFailed;
        defer wgpu.wgpuTextureViewRelease(normal_view);

        const aov_samples = aovSampleCount(samples);
        try self.renderAovs(ctx, samples, tile, albedo_view, normal_view, tile_w, tile_h, aov_samples);
        const aov_done_ms = nowMs();

        const color_bpp: u32 = if (ctx.float32_accum) 16 else 8;
        const textures = [3]wgpu.WGPUTexture{ color_texture, albedo_texture, normal_texture };
        const bpps = [3]u32{ color_bpp, aov_bytes_per_pixel, aov_bytes_per_pixel };
        var rows: [3]u32 = undefined;
        var sizes: [3]u64 = undefined;
        var buffers: [3]wgpu.WGPUBuffer = .{ null, null, null };
        var mapped: [3]bool = .{ false, false, false };
        defer for (buffers, mapped) |buffer, is_mapped| {
            if (buffer == null) continue;
            if (is_mapped) wgpu.wgpuBufferUnmap(buffer);
            wgpu.wgpuBufferRelease(buffer);
        };

        for (0..3) |i| {
            rows[i] = std.mem.alignForward(u32, tile_w * bpps[i], 256);
            sizes[i] = @as(u64, rows[i]) * tile_h;
            if (sizes[i] > ctx.limits.maxBufferSize) return error.TileTooLargeToDenoise;
            buffers[i] = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
                .nextInChain = null,
                .label = sv("fractal denoise readback"),
                .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_MapRead,
                .size = sizes[i],
                .mappedAtCreation = 0,
            }) orelse return error.BufferCreationFailed;
        }

        {
            const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
            for (0..3) |i| {
                wgpu.wgpuCommandEncoderCopyTextureToBuffer(
                    encoder,
                    &wgpu.WGPUTexelCopyTextureInfo{ .texture = textures[i], .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
                    &wgpu.WGPUTexelCopyBufferInfo{ .layout = .{ .offset = 0, .bytesPerRow = rows[i], .rowsPerImage = tile_h }, .buffer = buffers[i] },
                    &wgpu.WGPUExtent3D{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 },
                );
            }
            const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
            wgpu.wgpuCommandEncoderRelease(encoder);
            wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
            wgpu.wgpuCommandBufferRelease(cmd);
        }

        var map_states: [3]MapState = .{ .{}, .{}, .{} };
        for (0..3) |i| {
            _ = wgpu.wgpuBufferMapAsync(buffers[i], wgpu.WGPUMapMode_Read, 0, sizes[i], wgpu.WGPUBufferMapCallbackInfo{
                .nextInChain = null,
                .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
                .callback = onBufferMapped,
                .userdata1 = &map_states[i],
                .userdata2 = null,
            });
        }
        var views: [3][*]u8 = undefined;
        for (0..3) |i| {
            _ = webgpu_context.pollUntil(ctx.instance, &map_states[i].done, gpu_work_timeout_ms);
            if (!map_states[i].done or map_states[i].status != wgpu.WGPUMapAsyncStatus_Success) return error.BufferMapFailed;
            mapped[i] = true;
            const ptr = wgpu.wgpuBufferGetConstMappedRange(buffers[i], 0, sizes[i]) orelse return error.MappedRangeFailed;
            views[i] = @ptrCast(@constCast(ptr));
        }

        const color_size: usize = @intCast(sizes[0]);
        const result = try std.heap.page_allocator.alloc(u8, color_size);
        defer std.heap.page_allocator.free(result);
        @memcpy(result, views[0][0..color_size]);
        const readback_done_ms = nowMs();

        const color_format: oidn.Format = if (ctx.float32_accum) .float3 else .half3;
        const raw_image = oidn.Image{ .ptr = views[0], .format = color_format, .pixel_stride = color_bpp, .row_stride = rows[0] };
        const out_image = oidn.Image{ .ptr = result.ptr, .format = color_format, .pixel_stride = color_bpp, .row_stride = rows[0] };
        try oidn.denoise(.{
            .width = tile_w,
            .height = tile_h,
            .color = raw_image,
            .albedo = .{ .ptr = views[1], .format = .half3, .pixel_stride = aov_bytes_per_pixel, .row_stride = rows[1] },
            .normal = .{ .ptr = views[2], .format = .half3, .pixel_stride = aov_bytes_per_pixel, .row_stride = rows[2] },
            .clean_aux = aov_samples == 1,
            .output = out_image,
        });
        oidn.blendTowardRaw(out_image, raw_image, tile_w, tile_h, self.denoise_strength);
        const denoise_done_ms = nowMs();

        wgpu.wgpuQueueWriteTexture(
            ctx.queue,
            &wgpu.WGPUTexelCopyTextureInfo{ .texture = color_texture, .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
            result.ptr,
            color_size,
            &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = rows[0], .rowsPerImage = tile_h },
            &wgpu.WGPUExtent3D{ .width = tile_w, .height = tile_h, .depthOrArrayLayers = 1 },
        );

        std.debug.print("[denoise] tile {d}x{d}: albedo/normal x{d} {d:.0}ms, readback {d:.0}ms, CPU denoise {d:.0}ms\n", .{
            tile_w,
            tile_h,
            aov_samples,
            aov_done_ms - started_ms,
            readback_done_ms - aov_done_ms,
            denoise_done_ms - readback_done_ms,
        });
    }

    fn gbufferViews(self: *const FractalRenderer) GBuffer {
        return .{
            .depth_texture = self.depth_texture,
            .depth_view = self.depth_view,
            .normal_texture = self.normal_texture,
            .normal_view = self.normal_view,
        };
    }

    pub fn beginOffscreenPass(self: *FractalRenderer, encoder: wgpu.WGPUCommandEncoder, load_existing: bool) wgpu.WGPURenderPassEncoder {
        const attachments = marchAttachments(self.offscreen_view, self.gbufferViews(), load_existing);
        return wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("fractal offscreen pass"),
            .colorAttachmentCount = attachments.len,
            .colorAttachments = &attachments,
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;
    }

    fn ensurePostTargets(self: *FractalRenderer, ctx: *const Context) bool {
        if (self.post_targets.isReady() and
            self.post_targets.width == self.offscreen_width and
            self.post_targets.height == self.offscreen_height) return true;

        self.post_targets.deinit();
        self.post_targets = self.post.createTargets(
            ctx,
            self.blit_bind_group_layout,
            self.sampler,
            self.offscreen_width,
            self.offscreen_height,
            self.depth_view,
            self.normal_view,
        );
        return self.post_targets.isReady();
    }

    pub fn setPostEffects(self: *FractalRenderer, effects: []const post_process.Effect) void {
        self.post_effect_count = @min(effects.len, post_process.max_effects);
        for (0..self.post_effect_count) |i| self.post_effects[i] = effects[i];
    }

    pub fn postEffects(self: *const FractalRenderer) []const post_process.Effect {
        return self.post_effects[0..self.post_effect_count];
    }

    pub fn runPostChain(
        self: *FractalRenderer,
        ctx: *const Context,
        encoder: wgpu.WGPUCommandEncoder,
        frame: post_process.FrameInfo,
    ) void {
        self.post_result = null;
        const effects = self.postEffects();
        if (effects.len == 0) return;
        if (!self.ensurePostTargets(ctx)) {
            std.debug.print("[post] could not allocate screen-space targets -- effects skipped\n", .{});
            return;
        }
        self.post_result = self.post.apply(
            ctx,
            encoder,
            &self.post_targets,
            self.resolve_pipeline,
            self.displaySource(),
            effects,
            frame,
        );
    }

    fn displaySource(self: *const FractalRenderer) wgpu.WGPUBindGroup {
        return self.display_override orelse self.blit_bind_group;
    }

    pub fn postFrameInfo(uniforms: Uniforms, width: u32, height: u32) post_process.FrameInfo {
        return .{
            .resolution = .{ @floatFromInt(@max(width, 1)), @floatFromInt(@max(height, 1)) },
            .time = uniforms.time,
            .frame = uniforms.mc_sample,
            .camera_pos = uniforms.camera_pos,
            .max_dist = uniforms.max_dist,
            .camera_right = uniforms.camera_right,
            .camera_up = uniforms.camera_up,
            .camera_forward = uniforms.camera_forward,
            .aspect = uniforms.resolution[0] / @max(uniforms.resolution[1], 1.0),
            .tile_scale = uniforms.tile_scale,
            .tile_bias = uniforms.tile_bias,
        };
    }

    pub fn partsPipeline(self: *FractalRenderer, ctx: *const Context, parts_off: u32) wgpu.WGPURenderPipeline {
        if (self.isCompiling()) return null;
        return self.parts.lookup(ctx, self.pipeline_layout, self.pipelines.module, parts_off);
    }

    pub fn draw(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder, blend_constant: f32, mode: RenderMode, parts_pipeline: wgpu.WGPURenderPipeline) void {
        if (mode == .march and parts_pipeline != null) {
            self.drawPipeline(pass, blend_constant, parts_pipeline, 0);
        } else {
            self.drawSlot(pass, blend_constant, mode, 0);
        }
    }

    fn drawSlot(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder, blend_constant: f32, mode: RenderMode, slot: u32) void {
        self.drawPipeline(pass, blend_constant, switch (mode) {
            .march => self.pipelines.march,
            .slice => self.pipelines.slice,
            .simple => self.pipelines.simple,
        }, slot);
    }

    fn drawPipeline(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder, blend_constant: f32, pipeline: wgpu.WGPURenderPipeline, slot: u32) void {
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, pipeline);
        self.bindSceneGroupsSlot(pass, slot);
        wgpu.wgpuRenderPassEncoderSetBlendConstant(pass, &wgpu.WGPUColor{ .r = blend_constant, .g = blend_constant, .b = blend_constant, .a = 1.0 });
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    }

    pub fn drawOffscreenNow(self: *FractalRenderer, ctx: *const Context, load_existing: bool, blend_constant: f32, mode: RenderMode, parts_pipeline: wgpu.WGPURenderPipeline) void {
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return;
        const pass = self.beginOffscreenPass(encoder, load_existing);
        self.draw(pass, blend_constant, mode, parts_pipeline);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd});
        wgpu.wgpuCommandBufferRelease(cmd);
    }

    fn bindSceneGroups(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder) void {
        self.bindSceneGroupsSlot(pass, 0);
    }

    fn bindSceneGroupsSlot(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder, slot: u32) void {
        const offset = self.uniformOffset(slot);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 1, &offset);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 1, self.accel.render_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 2, self.photon_map.render_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 3, self.sky.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 4, self.fft.render_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 5, self.active_adapt_group, 0, null);
    }

    pub fn renderSelectMask(self: *FractalRenderer, ctx: *const Context, encoder: wgpu.WGPUCommandEncoder) bool {
        if (self.select_view == null or self.select_depth_bind_group == null) return false;
        self.ensureGroup(ctx, .select) catch return false;
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
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 5, self.select_depth_bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
        return true;
    }

    pub fn pickObject(self: *FractalRenderer, ctx: *const Context, uniforms: Uniforms, x: u32, y: u32) !u8 {
        try self.ensureGroup(ctx, .select);

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
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 5, self.pick_depth_bind_group, 0, null);
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
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, gpu_work_timeout_ms);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) {
            return error.BufferMapFailed;
        }
        defer wgpu.wgpuBufferUnmap(self.pick_buffer);

        const mapped_ptr = wgpu.wgpuBufferGetConstMappedRange(self.pick_buffer, 0, 256) orelse return error.MappedRangeFailed;
        const mapped: [*]const u8 = @ptrCast(mapped_ptr);
        return mapped[0];
    }

    pub fn blit(self: *FractalRenderer, pass: wgpu.WGPURenderPassEncoder) void {
        const chained = self.post_result;
        self.post_result = null;
        if (chained) |group| {
            wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.tonemap_pipeline);
            wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, group, 0, null);
        } else {
            wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.blit_pipeline);
            wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.displaySource(), 0, null);
        }
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    }
};
