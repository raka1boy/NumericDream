struct ColorStop {
    color: vec3f,
    position: f32,
    glossiness: f32,
    transparency: f32,
    reflectiveness: f32,
    ior: f32,
    subsurface: f32,
    abbe: f32,
    inner_max_steps: f32,
    roughness: f32,
    film_thickness: f32,
    film_ior: f32,
    film_strength: f32,
    film_angle_scale: f32,
    film_perturb: f32,
    film_perturb_scale: f32,
    subsurface_radius: f32,
    _pad_film1: f32,
}

const MAX_INSTANCES = 4;
const MAX_MIXINS = 3;
const MAX_COLOR_STOPS = 16;
const MAX_PARAMS = 16;
const PARAM_VEC4S = 4;
const MAX_LIGHTS = 8;
const FOG_VIS_LIGHT_VEC4S = 2;
const MAX_FOG_EMITTERS = 4;
const MAX_WARPS = 4;
const MAX_CASCADES = 8;
const MAX_CARVES = 16;
const MAX_PARTICLE_SYSTEMS = 2;
const FFT_N: u32 = 64u;

const PD_HEADER_WORDS: u32 = 16u;
const PD_MAX_PARTICLES: u32 = 16384u;
const PD_RECORD_WORDS: u32 = 8u;
const PD_MAX_CELLS: u32 = 524288u;
const PD_MAX_DIM: u32 = 128u;
const PD_INSERTS_PER_PARTICLE: u32 = 8u;
const PD_RECORDS: u32 = 32u;
const PD_CELLS: u32 = PD_RECORDS + MAX_PARTICLE_SYSTEMS * PD_MAX_PARTICLES * PD_RECORD_WORDS;
const PD_INDEX: u32 = PD_CELLS + MAX_PARTICLE_SYSTEMS * PD_MAX_CELLS * PD_CELL_WORDS;
const PD_DIST_CAP: u32 = 10u;
const PD_CELL_CAP: u32 = 32u;
const PD_HEADER_CELL: u32 = 3u;
const PD_HEADER_DIMS: u32 = 4u;
const PD_HEADER_VALID: u32 = 7u;
const PD_RECORD_RADIUS: u32 = 3u;
const PD_RECORD_STRIP: u32 = 4u;
const PD_RECORD_ALIVE: u32 = 5u;
const PD_CELL_WORDS: u32 = 2u;
const PD_CELL_COUNT_WORD: u32 = 1u;
const PD_CELL_COUNT_MASK: u32 = 0xffffu;
const PD_CELL_SKIP_SHIFT: u32 = 16u;
const PD_SKIP_MIN_DIST: u32 = 2u;

const PI = 3.14159265;
const TAU = 6.28318530718;
const SQRT3 = 1.7320508;
const HALF_SQRT3 = 0.8660254;
const GOLDEN_RATIO_FRACT = 0.61803399;
const INFINITE_DISTANCE = 1e30;
const NO_SURFACE_DE = 1e6;
const EPSILON = 1e-4;
const EPSILON_FINE = 1e-6;
const EPSILON_TINY = 1e-12;
const UNORM8_MAX = 255.0;
const LUMA_WEIGHTS = vec3f(0.2126, 0.7152, 0.0722);
const CUBE_CORNERS = 8;

const U32_MAX = 0xffffffffu;
const U32_SIGN_BIT = 0x80000000u;
const U32_RANGE = 4294967296.0;
const INV_U32_RANGE = 2.3283064365386963e-10;
const PCG_MULTIPLIER = 747796405u;
const PCG_INCREMENT = 2891336453u;
const PCG_OUTPUT_MULTIPLIER = 277803737u;
const LCG_MULTIPLIER = 1664525u;
const LCG_INCREMENT = 1013904223u;
const KNUTH_MULTIPLIER = 2654435761u;
const GOLDEN_RATIO_U32 = 0x9e3779b9u;
const GOLDEN_RATIO_U16 = 40503u;
const SPATIAL_PRIME_X = 73856093u;
const SPATIAL_PRIME_Y = 19349663u;
const SPATIAL_PRIME_Z = 83492791u;

const VOXEL_WORKGROUP_SIZE = 4;
const FFT_LINE_WORKGROUP_SIZE = 8;
const LINEAR_WORKGROUP_SIZE = 64;

// The state a formula's de_step receives and returns. z is the folded point; dr is the
// accumulated stretch factor (the running derivative), starting at 1.0. In a hybrid the
// carry may come from a different formula's step, and only the base formula's de_finalize
// runs at the end, so a step should rebuild what it needs from z and dr alone.
struct IterCarry {
    z: vec3f,
    dr: f32,
}

// A formula's slider values, one per @param line in declaration order: p[0] is the first
// declared, p[1] the second, and so on up to p[MAX_PARAMS - 1]. Undeclared entries are 0.
alias Params = array<f32, MAX_PARAMS>;

struct MixinParams {
    params: array<vec4f, PARAM_VEC4S>,
    iterations: f32,
    code: f32,
    formula_key: f32,
    _pad0: f32,
}

struct FractalInstance {
    offset: vec3f,
    blend_k: f32,
    combine_mode: f32,
    color_count: f32,
    step_safety: f32,
    hidden: f32,
    scale: vec3f,
    code: f32,
    rotation: vec3f,
    formula_key: f32,
    params: array<vec4f, PARAM_VEC4S>,
    mixin_count: f32,
    hybrid_base_iters: f32,
    hybrid_total_iters: f32,
    trap_repeat: f32,
    trap_center: vec3f,
    trap_shape: f32,
    trap_box: vec3f,
    trap_mode: f32,
    trap_radius: f32,
    trap_tube: f32,
    trap_span: f32,
    trap_offset: f32,
    mixins: array<MixinParams, MAX_MIXINS>,
    colors: array<ColorStop, MAX_COLOR_STOPS>,
    frame: mat3x3f,
}

struct Light {
    color: vec3f,
    brightness: f32,
    position_or_direction: vec3f,
    light_type: f32,
    shadow_softness: f32,
    cast_shadows: f32,
    hard_shadows: f32,
    spread: f32,
    ray_direction: vec3f,
    waist: f32,
}

struct FogEmitter {
    position: vec3f,
    radius: f32,
    color: vec3f,
    density: f32,
    softness: f32,
    anisotropy: f32,
    _pad0: f32,
    _pad1: f32,
}

struct Warp {
    center: vec3f,
    region_kind: f32,
    extent: vec3f,
    falloff: f32,
    rotation: vec3f,
    sub_kind: f32,
    params0: vec4f,
    params1: vec4f,
    strength: f32,
    lip_mult: f32,
    lip_grad: f32,
    safety: f32,
    frame: mat3x3f,
}

struct ParticleSystem {
    center: vec3f,
    mode: f32,
    dot_style: f32,
    glow: f32,
    combine_mode: f32,
    blend_k: f32,
    color_count: f32,
    generation: f32,
    glow_extent: f32,
    _pad0: f32,
    colors: array<ColorStop, MAX_COLOR_STOPS>,
}

struct Uniforms {
    camera_pos: vec3f,
    time: f32,
    camera_right: vec3f,
    max_steps: f32,
    camera_up: vec3f,
    max_dist: f32,
    camera_forward: vec3f,
    instance_count: f32,
    resolution: vec2f,
    light_count: f32,
    max_reflection_bounces: f32,
    high_quality: f32,
    epsilon_coefficient: f32,
    epsilon_floor: f32,
    hq_footprint_budget_px: f32,
    tile_scale: vec2f,
    tile_bias: vec2f,
    dof_enabled: f32,
    focus_distance: f32,
    aperture: f32,
    focus_range: f32,
    refine_fast: f32,
    refine_hq: f32,
    mc_enabled: f32,
    mc_sample: f32,
    instances: array<FractalInstance, MAX_INSTANCES>,
    lights: array<Light, MAX_LIGHTS>,
    fog_count: f32,
    fog_samples: f32,
    mode_2d: f32,
    slice_zoom: f32,
    fog_emitters: array<FogEmitter, MAX_FOG_EMITTERS>,
    light_bounces: f32,
    accel_enabled: f32,
    accel_levels: f32,
    accel_res: f32,
    accel_safety: f32,
    accel_z_offset: f32,
    fft_active: f32,
    fft_target_slot: f32,
    accel_params: array<vec4f, MAX_CASCADES>,
    warp_count: f32,
    has_transparency: f32,
    photon_prefilter: f32,
    march_verify: f32,
    warps: array<Warp, MAX_WARPS>,
    photon_enabled: f32,
    photon_radius: f32,
    photon_cell: f32,
    photon_table: f32,
    photon_paths: f32,
    photon_seed: f32,
    photon_intensity: f32,
    photon_path_offset: f32,
    photon_centre: vec3f,
    photon_extent: f32,
    sky: Sky,
    photon_pass: f32,
    photon_pool: f32,
    photon_cap_surface: f32,
    photon_fixed_unit: f32,
    photon_volume_scale: f32,
    photon_hash_salt: f32,
    photon_dispersion_soft: f32,
    debug_parts: f32,
    fft_axis: f32,
    fft_box_radius: f32,
    fft_cloud_density: f32,
    fft_lowpass: f32,
    fft_highpass: f32,
    fft_normalize: f32,
    photon_bounce_scale: f32,
    photon_aim: f32,
    carve_count: f32,
    hotspot_scale: f32,
    hotspot_sources: f32,
    overstep_scale: f32,
    carves: array<vec4f, MAX_CARVES>,
    particle_systems: array<ParticleSystem, MAX_PARTICLE_SYSTEMS>,
    approx_flags: f32,
    approx_caustic_strength: f32,
    approx_caustic_scale: f32,
    approx_bounce: f32,
    approx_tint: f32,
    approx_lod_start: f32,
    approx_lod_strength: f32,
    mc_light_pick: f32,
    adapt_enabled: f32,
    adapt_threshold: f32,
    adapt_min_samples: f32,
    adapt_row_width: f32,
    flat_coloring: f32,
    flat_interior: f32,
    flat_bailout: f32,
    flat_extra_iters: f32,
    flat_band_density: f32,
    flat_band_offset: f32,
    flat_relief: f32,
    flat_light_angle: f32,
    flat_contours: f32,
    flat_contour_density: f32,
    flat_slab_slices: f32,
    flat_slab_depth: f32,
    flat_slab_opacity: f32,
    flat_samples: f32,
    flat_halo: f32,
    mc_inner_samples: f32,
    fog_tracking: f32,
    primary_cache_key: f32,
    fog_vis_enabled: f32,
    fog_vis_layers: f32,
    fog_vis_origin: vec3f,
    fog_vis_cell: f32,
    fog_vis_dims: vec3f,
    fog_vis_z_offset: f32,
    fog_vis_light_layer: array<vec4f, FOG_VIS_LIGHT_VEC4S>,
    fog_vis_layer_light: array<vec4f, FOG_VIS_LIGHT_VEC4S>,
}

const APPROX_SIMPLE_FOG: u32 = 1u << 0u;
const APPROX_FAKE_CAUSTICS: u32 = 1u << 1u;
const APPROX_FAKE_BOUNCE: u32 = 1u << 2u;
const APPROX_SKY_AMBIENT: u32 = 1u << 3u;
const APPROX_THIN_GLASS: u32 = 1u << 4u;
const APPROX_TINT: u32 = 1u << 5u;
const APPROX_CHEAP_DISPERSION: u32 = 1u << 6u;
const APPROX_COARSE_SECONDARY: u32 = 1u << 7u;
const APPROX_DISTANCE_LOD: u32 = 1u << 8u;
const APPROX_SKY_REFLECTIONS: u32 = 1u << 9u;

fn approx_on(flag: u32) -> bool {
    return (u32(u.approx_flags) & flag) != 0u;
}

const PART_COLOR_STRIPS: u32 = 1u << 0u;
const PART_DIRECT_LIGHTS: u32 = 1u << 1u;
const PART_SPECULAR: u32 = 1u << 2u;
const PART_SHADOWS: u32 = 1u << 3u;
const PART_AMBIENT_OCCLUSION: u32 = 1u << 4u;
const PART_FOG: u32 = 1u << 5u;
const PART_REFLECTIONS: u32 = 1u << 6u;
const PART_REFRACTION: u32 = 1u << 7u;
const PART_PHOTON_MAP: u32 = 1u << 8u;
const PART_SUBSURFACE: u32 = 1u << 9u;
const PART_IRIDESCENCE: u32 = 1u << 10u;
const PART_DISPERSION: u32 = 1u << 11u;
const PART_SKY: u32 = 1u << 12u;
const PART_DEPTH_OF_FIELD: u32 = 1u << 13u;
const PART_MC_INDIRECT: u32 = 1u << 14u;
const PART_GEOMETRY_ONLY: u32 = 1u << 16u;
const PART_HOTSPOTS: u32 = 1u << 17u;
const PART_OVERSTEP: u32 = 1u << 18u;

const HOT_PRIMARY: u32 = 1u << 0u;
const HOT_NORMALS: u32 = 1u << 1u;
const HOT_MATERIALS: u32 = 1u << 2u;
const HOT_SHADOWS: u32 = 1u << 3u;
const HOT_AO: u32 = 1u << 4u;
const HOT_FOG: u32 = 1u << 5u;
const HOT_SECONDARY: u32 = 1u << 6u;
const HOT_SUBSURFACE: u32 = 1u << 7u;
const HOT_MC_INDIRECT: u32 = 1u << 8u;
const HOT_DOF: u32 = 1u << 9u;
const HOT_OWNERS: u32 = HOT_SHADOWS | HOT_FOG | HOT_SUBSURFACE | HOT_MC_INDIRECT | HOT_DOF;

var<private> g_hot_src: u32 = 0u;
var<private> g_hot_evals: f32 = 0.0;

fn hot_enter(src: u32) -> u32 {
    let prev = g_hot_src;
    if ((prev & HOT_OWNERS) == 0u) {
        g_hot_src = src;
    }
    return prev;
}

fn hot_count() {
    if ((g_hot_src & u32(u.hotspot_sources)) != 0u) {
        g_hot_evals += 1.0;
    }
}

override PARTS_FIXED: bool = false;
override PARTS_FIXED_OFF: u32 = 0u;

fn part_on(part: u32) -> bool {
    if (PARTS_FIXED) {
        return (PARTS_FIXED_OFF & part) == 0u;
    }
    return (u32(u.debug_parts) & part) == 0u;
}

fn photons_on() -> bool {
    return u.photon_enabled > 0.5 && part_on(PART_PHOTON_MAP);
}

fn apply_part_mask(in_mat: ColorStop) -> ColorStop {
    var mat = in_mat;
    if (!part_on(PART_COLOR_STRIPS)) { mat.color = SIMPLE_ALBEDO; }
    if (!part_on(PART_REFLECTIONS)) { mat.reflectiveness = 0.0; }
    if (!part_on(PART_REFRACTION)) { mat.transparency = 0.0; }
    if (!part_on(PART_SUBSURFACE)) { mat.subsurface = 0.0; }
    if (!part_on(PART_IRIDESCENCE)) { mat.film_strength = 0.0; }
    if (!part_on(PART_DISPERSION)) { mat.abbe = 0.0; }
    return mat;
}

struct Sky {
    mode: f32,
    intensity: f32,
    falloff: f32,
    photons: f32,
    zenith: vec3f,
    sun_cos: f32,
    horizon: vec3f,
    sun_intensity: f32,
    ground: vec3f,
    yaw: f32,
    sun_color: vec3f,
    _pad0: f32,
    sun_dir: vec3f,
    _pad1: f32,
}

@group(0) @binding(0) var<uniform> u: Uniforms;
@group(0) @binding(1) var<storage, read> particle_data: array<u32>;
@group(0) @binding(2) var<storage, read> image_data: array<u32>;

@group(1) @binding(0) var accel_tex: texture_3d<f32>;

fn accel_skip(p: vec3f) -> f32 {
    if (u.accel_enabled < 0.5) {
        return 0.0;
    }
    let res = i32(u.accel_res);
    let levels = min(i32(u.accel_levels), MAX_CASCADES);
    for (var l = 0; l < levels; l++) {
        let prm = u.accel_params[l];
        let cell = prm.w;
        if (cell <= 0.0) {
            continue;
        }
        let c = vec3i(floor((p - prm.xyz) / cell));
        if (c.x < 0 || c.y < 0 || c.z < 0 || c.x >= res || c.y >= res || c.z >= res) {
            continue;
        }
        return textureLoad(accel_tex, vec3i(c.x, c.y, c.z + l * res), 0).r;
    }
    return 0.0;
}

struct Photon {
    pos: vec3f,
    _pad0: f32,
    power: vec3f,
    _pad1: f32,
    normal: vec3f,
    _pad2: f32,
}

@group(2) @binding(0) var<storage, read> photon_cells: array<vec4f>;
@group(2) @binding(1) var<storage, read> photon_counts: array<u32>;
@group(2) @binding(2) var<storage, read> photon_keys: array<u32>;
@group(2) @binding(3) var<storage, read> photon_offsets: array<u32>;
@group(2) @binding(10) var<storage, read> photon_volume: array<u32>;

const PHOTON_GRID_SURFACE: u32 = 0u;
const PHOTON_GRID_VOLUME: u32 = 1u;
const PHOTON_GRID_HAZE: u32 = 2u;
const PHOTON_GRID_BOUNCE: u32 = 3u;
const PHOTON_HAZE_SCALE = 4.0;
const PHOTON_MIN_CELL = 1e-6;
const PHOTON_HASH_KIND_PRIME = 2971215073u;
const XXH_PRIME32_1 = 2654435761u;
const XXH_PRIME32_2 = 2246822519u;
const XXH_PRIME32_3 = 3266489917u;
const PHOTON_TAG_KIND_PRIME = 1900403167u;
const PHOTON_TAG_OCCUPIED_BIT = 4u;
const PHOTON_TAG_HASH_MASK = 0xfffffffcu;
const PHOTON_TAG_KIND_MASK = 3u;
const PHOTON_SURFACE_GRID_COUNT = 2u;
const PHOTON_GATHER_RADIUS_CELLS = 0.5;
const PHOTON_NORMAL_MIN_COS = 0.7;
const PHOTON_CONE_FILTER_NORM = 3.0;

fn photon_kind_is_surface(kind: u32) -> bool {
    return kind == PHOTON_GRID_SURFACE || kind == PHOTON_GRID_BOUNCE;
}

fn photon_volume_cell() -> f32 {
    return max(u.photon_cell * max(u.photon_volume_scale, 1.0), PHOTON_MIN_CELL);
}

fn photon_grid_edge(kind: u32) -> f32 {
    if (kind == PHOTON_GRID_SURFACE) {
        return max(u.photon_cell, PHOTON_MIN_CELL);
    }
    if (kind == PHOTON_GRID_BOUNCE) {
        return max(u.photon_cell * max(u.photon_bounce_scale, 1.0), PHOTON_MIN_CELL);
    }
    return photon_volume_cell() * select(1.0, PHOTON_HAZE_SCALE, kind == PHOTON_GRID_HAZE);
}

fn photon_lattice_offset() -> vec3f {
    var h = u32(max(u.photon_hash_salt, 0.0)) * PCG_MULTIPLIER + PCG_INCREMENT;
    var o = vec3f(0.0);
    for (var i = 0; i < 3; i++) {
        h = h * PCG_MULTIPLIER + PCG_INCREMENT;
        let word = ((h >> ((h >> 28u) + 4u)) ^ h) * PCG_OUTPUT_MULTIPLIER;
        o[i] = f32((word >> 22u) ^ word) * INV_U32_RANGE;
    }
    return o;
}

fn photon_grid_cell(p: vec3f, kind: u32) -> vec3i {
    let q = p / photon_grid_edge(kind);
    return vec3i(floor(select(q - photon_lattice_offset(), q, photon_kind_is_surface(kind))));
}

fn photon_hash(c: vec3i, kind: u32) -> u32 {
    let h = (u32(c.x) * SPATIAL_PRIME_X) ^ (u32(c.y) * SPATIAL_PRIME_Y) ^
            (u32(c.z) * SPATIAL_PRIME_Z) ^ (kind * PHOTON_HASH_KIND_PRIME) ^
            (u32(max(u.photon_hash_salt, 0.0)) * KNUTH_MULTIPLIER);
    return h & (u32(u.photon_table) - 1u);
}

fn photon_cell_tag(c: vec3i, kind: u32) -> u32 {
    var h = (u32(c.x) * XXH_PRIME32_1) ^ (u32(c.y) * XXH_PRIME32_2) ^
            (u32(c.z) * XXH_PRIME32_3) ^ (kind * PHOTON_TAG_KIND_PRIME);
    h ^= h >> 15u;
    h *= XXH_PRIME32_2;
    h ^= h >> 13u;
    return ((h | PHOTON_TAG_OCCUPIED_BIT) & PHOTON_TAG_HASH_MASK) | (kind & PHOTON_TAG_KIND_MASK);
}

fn photon_cap_surface() -> u32 {
    return max(u32(u.photon_cap_surface), 1u);
}

const PHOTON_PROBES: u32 = 8u;

const PHOTON_OCTANTS = 8u;
const PHOTON_OCTANT_BITS = 10u;
const PHOTON_OCTANT_MASK = 0x3ffu;
const PHOTON_OCTANTS_PER_WORD = 3u;
const PHOTON_OCTANT_HEADER_PHOTONS = 3u;

fn photon_octant(p: vec3f, kind: u32) -> u32 {
    let q = p / photon_grid_edge(kind);
    let upper = (q - floor(q)) >= vec3f(0.5);
    return select(0u, 1u, upper.x) | select(0u, 2u, upper.y) | select(0u, 4u, upper.z);
}

const PHOTON_POOL_SECTIONS = 3u;
const PHOTON_NO_PICK = 0xffffffffu;

fn photon_power_index(i: u32) -> u32 {
    return arrayLength(&photon_cells) / PHOTON_POOL_SECTIONS + i;
}

fn photon_prefiltered_index(i: u32) -> u32 {
    return arrayLength(&photon_cells) / PHOTON_POOL_SECTIONS * 2u + i;
}

fn photon_octant_start(base: u32, o: u32, kept: u32) -> u32 {
    if (o == 0u) {
        return 0u;
    }
    if (o >= PHOTON_OCTANTS) {
        return kept;
    }
    let i = o - 1u;
    let packed = bitcast<u32>(photon_cells[photon_power_index(base + i / PHOTON_OCTANTS_PER_WORD)].w);
    return min((packed >> ((i % PHOTON_OCTANTS_PER_WORD) * PHOTON_OCTANT_BITS)) & PHOTON_OCTANT_MASK, kept);
}

fn photon_scan(base: u32, begin: u32, end: u32, pos: vec3f, normal: vec3f, r: f32) -> vec3f {
    var sum = vec3f(0.0);
    for (var s = base + begin; s < base + end; s++) {
        let geo = photon_cells[s];
        let d = geo.xyz - pos;
        let d2 = dot(d, d);
        if (d2 > r * r || dot(oct_decode(bitcast<u32>(geo.w)), normal) < PHOTON_NORMAL_MIN_COS) {
            continue;
        }
        sum += photon_cells[photon_power_index(s)].xyz * (1.0 - sqrt(d2) / r);
    }
    return sum;
}

const PHOTON_NO_BUCKET: u32 = 0xffffffffu;

fn photon_bucket_find(c: vec3i, kind: u32) -> u32 {
    let tag = photon_cell_tag(c, kind);
    let mask = u32(u.photon_table) - 1u;
    var b = photon_hash(c, kind);
    for (var i = 0u; i < PHOTON_PROBES; i++) {
        let k = photon_keys[b];
        if (k == tag) {
            return b;
        }
        if (k == 0u) {
            return PHOTON_NO_BUCKET;
        }
        b = (b + 1u) & mask;
    }
    return PHOTON_NO_BUCKET;
}

fn photon_gather_kind(pos: vec3f, normal: vec3f, kind: u32) -> vec3f {
    let edge = photon_grid_edge(kind);
    let r = PHOTON_GATHER_RADIUS_CELLS * edge;
    let qlo = (pos - vec3f(r)) / edge;
    let qhi = (pos + vec3f(r)) / edge;
    let lo = vec3i(floor(qlo));
    let hi = vec3i(floor(qhi));

    var sum = vec3f(0.0);
    for (var z = lo.z; z <= hi.z; z++) {
        for (var y = lo.y; y <= hi.y; y++) {
            for (var x = lo.x; x <= hi.x; x++) {
                let h = photon_bucket_find(vec3i(x, y, z), kind);
                if (h == PHOTON_NO_BUCKET) {
                    continue;
                }
                let stored = photon_counts[h];
                if (stored == 0u) {
                    continue;
                }
                let kept = min(stored, photon_cap_surface());
                let overflow = f32(stored) / f32(kept);
                let base = photon_offsets[h];
                if (kept < PHOTON_OCTANT_HEADER_PHOTONS) {
                    sum += photon_scan(base, 0u, kept, pos, normal, r) * overflow;
                    continue;
                }
                let mid = vec3f(vec3i(x, y, z)) + 0.5;
                let first = select(vec3u(0u), vec3u(1u), qlo >= mid);
                let last = select(vec3u(0u), vec3u(1u), qhi >= mid);
                for (var oz = first.z; oz <= last.z; oz++) {
                    for (var oy = first.y; oy <= last.y; oy++) {
                        let row = (oy << 1u) | (oz << 2u);
                        let begin = photon_octant_start(base, row | first.x, kept);
                        let end = photon_octant_start(base, (row | last.x) + 1u, kept);
                        sum += photon_scan(base, begin, end, pos, normal, r) * overflow;
                    }
                }
            }
        }
    }
    return sum / (r * r);
}

fn photon_bounce_prefiltered(pos: vec3f, normal: vec3f) -> vec3f {
    let kind = PHOTON_GRID_BOUNCE;
    let h = photon_bucket_find(photon_grid_cell(pos, kind), kind);
    if (h == PHOTON_NO_BUCKET) {
        return vec3f(0.0);
    }
    let stored = photon_counts[h];
    if (stored == 0u) {
        return vec3f(0.0);
    }
    let kept = min(stored, photon_cap_surface());
    let base = photon_offsets[h];
    var begin = 0u;
    var end = kept;
    if (kept >= PHOTON_OCTANT_HEADER_PHOTONS) {
        let o = photon_octant(pos, kind);
        begin = photon_octant_start(base, o, kept);
        end = photon_octant_start(base, o + 1u, kept);
    }
    var pick = PHOTON_NO_PICK;
    var best = INFINITE_DISTANCE;
    for (var attempt = 0u; attempt < 2u; attempt++) {
        for (var s = base + begin; s < base + end; s++) {
            let geo = photon_cells[s];
            let d = geo.xyz - pos;
            let d2 = dot(d, d);
            if (d2 < best && dot(oct_decode(bitcast<u32>(geo.w)), normal) >= PHOTON_NORMAL_MIN_COS) {
                best = d2;
                pick = s;
            }
        }
        if (pick != PHOTON_NO_PICK || (begin == 0u && end == kept)) {
            break;
        }
        begin = 0u;
        end = kept;
    }
    if (pick == PHOTON_NO_PICK) {
        return vec3f(0.0);
    }
    return photon_cells[photon_prefiltered_index(pick)].xyz;
}

fn photon_gather_surface(pos: vec3f, normal: vec3f) -> vec3f {
    if (!photons_on()) {
        return vec3f(0.0);
    }
    var total = vec3f(0.0);
    for (var g = 0u; g < PHOTON_SURFACE_GRID_COUNT; g++) {
        let bounce = g == 1u;
        if (approx_on(select(APPROX_FAKE_CAUSTICS, APPROX_FAKE_BOUNCE, bounce))) {
            continue;
        }
        if (bounce && u.photon_prefilter > 0.5) {
            total += photon_bounce_prefiltered(pos, normal);
            continue;
        }
        total += photon_gather_kind(pos, normal, select(PHOTON_GRID_SURFACE, PHOTON_GRID_BOUNCE, bounce));
    }
    return gamut_fit(total) * u.photon_intensity * PHOTON_CONE_FILTER_NORM / PI;
}

const SPECTRAL_COUNT = 8.0;

const SPECTRAL_BAND_LO = 380.0;
const SPECTRAL_BAND_HI = 730.0;

const SPECTRAL_BLUE_EDGE = 498.09;
const SPECTRAL_BLUE_WIDTH = 13.50;
const SPECTRAL_RED_EDGE = 600.31;
const SPECTRAL_RED_WIDTH = 8.00;
const SPECTRAL_GREEN_MU = 530.00;
const SPECTRAL_GREEN_SIGMA = 25.00;
const SPECTRAL_GREEN_GAIN = 2.49;

const SPECTRAL_FOLD_R = vec3f( 0.99575300, -0.00656071,  0.01080772);
const SPECTRAL_FOLD_G = vec3f(-0.00755455,  1.00830220, -0.00074766);
const SPECTRAL_FOLD_B = vec3f( 0.02732810, -0.00674214,  0.97941404);
const SPECTRAL_STRATA_LO = vec4f(0.0, 0.125, 0.25, 0.375);
const SPECTRAL_STRATA_HI = vec4f(0.5, 0.625, 0.75, 0.875);
const SPEC_LANES = 4;
const SPEC_LAST_LANE = 3;
const NM_TO_UM = 0.001;

const CIE_X1_GAIN = 1.056;
const CIE_X1_PEAK = 599.8;
const CIE_X1_SIGMA_LO = 37.9;
const CIE_X1_SIGMA_HI = 31.0;
const CIE_X2_GAIN = 0.362;
const CIE_X2_PEAK = 442.0;
const CIE_X2_SIGMA_LO = 16.0;
const CIE_X2_SIGMA_HI = 26.7;
const CIE_X3_GAIN = 0.065;
const CIE_X3_PEAK = 501.1;
const CIE_X3_SIGMA_LO = 20.4;
const CIE_X3_SIGMA_HI = 26.2;
const CIE_Y1_GAIN = 0.821;
const CIE_Y1_PEAK = 568.8;
const CIE_Y1_SIGMA_LO = 46.9;
const CIE_Y1_SIGMA_HI = 40.5;
const CIE_Y2_GAIN = 0.286;
const CIE_Y2_PEAK = 530.9;
const CIE_Y2_SIGMA_LO = 16.3;
const CIE_Y2_SIGMA_HI = 31.1;
const CIE_Z1_GAIN = 1.217;
const CIE_Z1_PEAK = 437.0;
const CIE_Z1_SIGMA_LO = 11.8;
const CIE_Z1_SIGMA_HI = 36.0;
const CIE_Z2_GAIN = 0.681;
const CIE_Z2_PEAK = 459.0;
const CIE_Z2_SIGMA_LO = 26.0;
const CIE_Z2_SIGMA_HI = 13.8;

const XYZ_TO_R_X = 3.2404542;
const XYZ_TO_R_Y = -1.5371385;
const XYZ_TO_R_Z = -0.4985314;
const XYZ_TO_G_X = -0.9692660;
const XYZ_TO_G_Y = 1.8760108;
const XYZ_TO_G_Z = 0.0415560;
const XYZ_TO_B_X = 0.0556434;
const XYZ_TO_B_Y = -0.2040259;
const XYZ_TO_B_Z = 1.0572252;

struct Spec {
    lo: vec4f,
    hi: vec4f,
}

var<private> spec_lambda_lo: vec4f;
var<private> spec_lambda_hi: vec4f;
var<private> spec_basis_r: Spec;
var<private> spec_basis_g: Spec;
var<private> spec_basis_b: Spec;
var<private> spec_weight_r: Spec;
var<private> spec_weight_g: Spec;
var<private> spec_weight_b: Spec;

struct Band4 {
    a: vec4f,
    b: vec4f,
    c: vec4f,
}

fn spectral_prebasis(l: vec4f) -> Band4 {
    let blue = vec4f(1.0) / (vec4f(1.0) + exp((l - vec4f(SPECTRAL_BLUE_EDGE)) / SPECTRAL_BLUE_WIDTH));
    let red = vec4f(1.0) / (vec4f(1.0) + exp((vec4f(SPECTRAL_RED_EDGE) - l) / SPECTRAL_RED_WIDTH));
    let t = (l - vec4f(SPECTRAL_GREEN_MU)) / SPECTRAL_GREEN_SIGMA;
    let green = SPECTRAL_GREEN_GAIN * exp(-0.5 * t * t);
    let sum = red + green + blue;
    return Band4(red / sum, green / sum, blue / sum);
}

fn spectral_lobe(l: vec4f, mu: f32, s_lo: f32, s_hi: f32) -> vec4f {
    let s = select(vec4f(s_hi), vec4f(s_lo), l < vec4f(mu));
    let t = (l - vec4f(mu)) / s;
    return exp(-0.5 * t * t);
}

fn spectral_cie(l: vec4f) -> Band4 {
    let x = CIE_X1_GAIN * spectral_lobe(l, CIE_X1_PEAK, CIE_X1_SIGMA_LO, CIE_X1_SIGMA_HI)
          + CIE_X2_GAIN * spectral_lobe(l, CIE_X2_PEAK, CIE_X2_SIGMA_LO, CIE_X2_SIGMA_HI)
          - CIE_X3_GAIN * spectral_lobe(l, CIE_X3_PEAK, CIE_X3_SIGMA_LO, CIE_X3_SIGMA_HI);
    let y = CIE_Y1_GAIN * spectral_lobe(l, CIE_Y1_PEAK, CIE_Y1_SIGMA_LO, CIE_Y1_SIGMA_HI)
          + CIE_Y2_GAIN * spectral_lobe(l, CIE_Y2_PEAK, CIE_Y2_SIGMA_LO, CIE_Y2_SIGMA_HI);
    let z = CIE_Z1_GAIN * spectral_lobe(l, CIE_Z1_PEAK, CIE_Z1_SIGMA_LO, CIE_Z1_SIGMA_HI)
          + CIE_Z2_GAIN * spectral_lobe(l, CIE_Z2_PEAK, CIE_Z2_SIGMA_LO, CIE_Z2_SIGMA_HI);
    return Band4(x, y, z);
}

fn spectral_setup(hero: f32) {
    let span = SPECTRAL_BAND_HI - SPECTRAL_BAND_LO;
    let base = fract(hero);
    spec_lambda_lo = SPECTRAL_BAND_LO + span * fract(base + SPECTRAL_STRATA_LO);
    spec_lambda_hi = SPECTRAL_BAND_LO + span * fract(base + SPECTRAL_STRATA_HI);

    let pb_lo = spectral_prebasis(spec_lambda_lo);
    let pb_hi = spectral_prebasis(spec_lambda_hi);
    spec_basis_r = Spec(pb_lo.a * SPECTRAL_FOLD_R.x + pb_lo.b * SPECTRAL_FOLD_G.x + pb_lo.c * SPECTRAL_FOLD_B.x,
                        pb_hi.a * SPECTRAL_FOLD_R.x + pb_hi.b * SPECTRAL_FOLD_G.x + pb_hi.c * SPECTRAL_FOLD_B.x);
    spec_basis_g = Spec(pb_lo.a * SPECTRAL_FOLD_R.y + pb_lo.b * SPECTRAL_FOLD_G.y + pb_lo.c * SPECTRAL_FOLD_B.y,
                        pb_hi.a * SPECTRAL_FOLD_R.y + pb_hi.b * SPECTRAL_FOLD_G.y + pb_hi.c * SPECTRAL_FOLD_B.y);
    spec_basis_b = Spec(pb_lo.a * SPECTRAL_FOLD_R.z + pb_lo.b * SPECTRAL_FOLD_G.z + pb_lo.c * SPECTRAL_FOLD_B.z,
                        pb_hi.a * SPECTRAL_FOLD_R.z + pb_hi.b * SPECTRAL_FOLD_G.z + pb_hi.c * SPECTRAL_FOLD_B.z);

    let xyz_lo = spectral_cie(spec_lambda_lo);
    let xyz_hi = spectral_cie(spec_lambda_hi);
    var wr = Spec(XYZ_TO_R_X * xyz_lo.a + XYZ_TO_R_Y * xyz_lo.b + XYZ_TO_R_Z * xyz_lo.c,
                  XYZ_TO_R_X * xyz_hi.a + XYZ_TO_R_Y * xyz_hi.b + XYZ_TO_R_Z * xyz_hi.c);
    var wg = Spec(XYZ_TO_G_X * xyz_lo.a + XYZ_TO_G_Y * xyz_lo.b + XYZ_TO_G_Z * xyz_lo.c,
                  XYZ_TO_G_X * xyz_hi.a + XYZ_TO_G_Y * xyz_hi.b + XYZ_TO_G_Z * xyz_hi.c);
    var wb = Spec(XYZ_TO_B_X * xyz_lo.a + XYZ_TO_B_Y * xyz_lo.b + XYZ_TO_B_Z * xyz_lo.c,
                  XYZ_TO_B_X * xyz_hi.a + XYZ_TO_B_Y * xyz_hi.b + XYZ_TO_B_Z * xyz_hi.c);

    let sum_r = dot(wr.lo, vec4f(1.0)) + dot(wr.hi, vec4f(1.0));
    let sum_g = dot(wg.lo, vec4f(1.0)) + dot(wg.hi, vec4f(1.0));
    let sum_b = dot(wb.lo, vec4f(1.0)) + dot(wb.hi, vec4f(1.0));
    spec_weight_r = Spec(wr.lo / sum_r, wr.hi / sum_r);
    spec_weight_g = Spec(wg.lo / sum_g, wg.hi / sum_g);
    spec_weight_b = Spec(wb.lo / sum_b, wb.hi / sum_b);
}

fn spec_splat(v: f32) -> Spec {
    return Spec(vec4f(v), vec4f(v));
}

fn spec_add(a: Spec, b: Spec) -> Spec {
    return Spec(a.lo + b.lo, a.hi + b.hi);
}

fn spec_mul(a: Spec, b: Spec) -> Spec {
    return Spec(a.lo * b.lo, a.hi * b.hi);
}

fn spec_scale(a: Spec, s: f32) -> Spec {
    return Spec(a.lo * s, a.hi * s);
}

fn spec_max(a: Spec) -> f32 {
    let m = max(a.lo, a.hi);
    return max(max(m.x, m.y), max(m.z, m.w));
}

fn spec_from_rgb(c: vec3f) -> Spec {
    let lo = c.r * spec_basis_r.lo + c.g * spec_basis_g.lo + c.b * spec_basis_b.lo;
    let hi = c.r * spec_basis_r.hi + c.g * spec_basis_g.hi + c.b * spec_basis_b.hi;
    return Spec(max(lo, vec4f(0.0)), max(hi, vec4f(0.0)));
}

fn spec_to_rgb(s: Spec) -> vec3f {
    return vec3f(dot(s.lo, spec_weight_r.lo) + dot(s.hi, spec_weight_r.hi),
                 dot(s.lo, spec_weight_g.lo) + dot(s.hi, spec_weight_g.hi),
                 dot(s.lo, spec_weight_b.lo) + dot(s.hi, spec_weight_b.hi));
}

fn spec_lambda_um(k: i32) -> f32 {
    let a = spec_lambda_lo[clamp(k, 0, SPEC_LAST_LANE)];
    let b = spec_lambda_hi[clamp(k - SPEC_LANES, 0, SPEC_LAST_LANE)];
    return select(a, b, k >= SPEC_LANES) * NM_TO_UM;
}

fn spec_collapse_mask(k: i32) -> Spec {
    let idx = vec4i(0, 1, 2, 3);
    return Spec(select(vec4f(0.0), vec4f(SPECTRAL_COUNT), idx == vec4i(k)),
                select(vec4f(0.0), vec4f(SPECTRAL_COUNT), idx == vec4i(k - SPEC_LANES)));
}


fn gamut_fit(c: vec3f) -> vec3f {
    let y = dot(c, LUMA_WEIGHTS);
    if (y <= 0.0) {
        return vec3f(0.0);
    }
    let m = min(c.r, min(c.g, c.b));
    if (m >= 0.0) {
        return c;
    }
    return mix(vec3f(y), c, y / (y - m));
}

struct VertexOut {
    @builtin(position) clip_pos: vec4f,
    @location(0) uv: vec2f,
}

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOut {
    var positions = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f(3.0, -1.0),
        vec2f(-1.0, 3.0),
    );
    let p = positions[idx];
    var out: VertexOut;
    out.clip_pos = vec4f(p, 0.0, 1.0);
    let p_full = p * u.tile_scale + u.tile_bias;
    out.uv = vec2f(p_full.x, -p_full.y);
    return out;
}

fn pack_params(v: array<vec4f, PARAM_VEC4S>) -> Params {
    return Params(
        v[0].x, v[0].y, v[0].z, v[0].w,
        v[1].x, v[1].y, v[1].z, v[1].w,
        v[2].x, v[2].y, v[2].z, v[2].w,
        v[3].x, v[3].y, v[3].z, v[3].w,
    );
}

fn instance_params(slot: i32) -> Params {
    return pack_params(u.instances[slot].params);
}

fn instance_mixin_params(slot: i32, idx: i32) -> Params {
    return pack_params(u.instances[slot].mixins[idx].params);
}

// Mandelbox outer fold: each component beyond +-limit is reflected back across that
// plane, i.e. clamp(z, -limit, limit) * 2 - z. A piecewise reflection; dr unchanged.
fn box_fold(z: vec3f, limit: f32) -> vec3f {
    return clamp(z, vec3f(-limit), vec3f(limit)) * 2.0 - z;
}

// Mandelbox inner fold: sphere inversion with a floor. Both radii are SQUARED.
// r^2 < min_radius2:                 scaled by the constant fixed_radius2 / min_radius2.
// min_radius2 <= r^2 < fixed_radius2: inverted, scaled by fixed_radius2 / r^2.
// otherwise:                         passed through.
// Returns the new point in .xyz and dr multiplied by the applied factor in .w; always
// take dr from .w rather than tracking the factor yourself.
fn sphere_fold(z: vec3f, dr: f32, min_radius2: f32, fixed_radius2: f32) -> vec4f {
    let r2 = dot(z, z);
    if (r2 < min_radius2) {
        let t = fixed_radius2 / min_radius2;
        return vec4f(z * t, dr * t);
    } else if (r2 < fixed_radius2) {
        let t = fixed_radius2 / r2;
        return vec4f(z * t, dr * t);
    }
    return vec4f(z, dr);
}

// Plain inversion in the sphere of SQUARED radius radius2 about center (the Kleinian
// fold): points inside are mapped to center + d * radius2 / |d|^2, points outside pass
// through. |d|^2 is floored at EPSILON_FINE so the centre itself is safe. Returns the
// point in .xyz and dr times radius2 / |d|^2 in .w, like sphere_fold.
fn sphere_invert_offset(z: vec3f, dr: f32, center: vec3f, radius2: f32) -> vec4f {
    let d = z - center;
    let r2 = max(dot(d, d), EPSILON_FINE);
    if (r2 < radius2) {
        let t = radius2 / r2;
        return vec4f(center + d * t, dr * t);
    }
    return vec4f(z, dr);
}

// Wraps p into the cube of side cell centred on the origin, so everything after it repeats
// on an infinite lattice. cell must be non-zero. A translation; dr unchanged.
fn lattice_wrap(p: vec3f, cell: f32) -> vec3f {
    return p - cell * round(p / cell);
}

// de_finalize for escape-time folds (box, inversion, lattice) that add pos each step and
// diverge: length(z) / abs(dr). The abs keeps negative scales working.
fn de_finalize_scaled(carry: IterCarry) -> f32 {
    return length(carry.z) / abs(carry.dr);
}

// de_finalize for bounded folds whose attractor passes through the origin (Sierpinski,
// icosahedral IFS): length(z) / dr. No abs, so dr must stay positive.
fn de_finalize_plain(carry: IterCarry) -> f32 {
    return length(carry.z) / carry.dr;
}

// de_finalize for power maps, paired with bulb_power_step: 0.5 * log(r) * r / dr, capped
// at r so it never exceeds the distance to the origin. r and dr are floored at
// EPSILON_FINE.
fn bulb_log_escape(carry: IterCarry) -> f32 {
    let r = length(carry.z);
    let log_est = 0.5 * log(max(r, EPSILON_FINE)) * r / max(carry.dr, EPSILON_FINE);
    return min(log_est, r);
}

// Escape radius used by bulb_power_step; also usable as a bail-out in custom power maps.
const BULB_BAILOUT = 2.0;

// One Mandelbulb iteration in spherical coordinates (theta measured from +z, phi =
// atan2(y, x)): z -> z^power + add, dr -> power * r^(power - 1) * dr + 1. Pass pos as add
// for a Mandelbulb, a constant for a Juliabulb. Once r > BULB_BAILOUT the carry is
// returned unchanged, so it is safe to keep calling after escape (e.g. inside a hybrid).
fn bulb_power_step(carry: IterCarry, add: vec3f, power: f32) -> IterCarry {
    let r = length(carry.z);
    if (r > BULB_BAILOUT) {
        return carry;
    }
    let theta = acos(clamp(carry.z.z / r, -1.0, 1.0)) * power;
    let phi = atan2(carry.z.y, carry.z.x) * power;
    let rp = pow(r, power - 1.0);
    let zr = rp * r;
    let dr = rp * power * carry.dr + 1.0;
    let z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + add;
    return IterCarry(z, dr);
}

// Cubic-symmetry fold (Menger sponge): abs(z), then the components sorted so that
// x >= y >= z, folding all of space into one 48th of it. Mirrors and axis swaps only;
// dr unchanged.
fn sort_desc_abs(z: vec3f) -> vec3f {
    var v = abs(z);
    if (v.x < v.y) {
        let t = v.x;
        v.x = v.y;
        v.y = t;
    }
    if (v.x < v.z) {
        let t = v.x;
        v.x = v.z;
        v.z = t;
    }
    if (v.y < v.z) {
        let t = v.y;
        v.y = v.z;
        v.z = t;
    }
    return v;
}

// Tetrahedral-symmetry fold (Sierpinski tetrahedron): conditional mirrors across the
// planes x + y = 0, x + z = 0 and y + z = 0, applied in that order. dr unchanged.
fn tetra_fold(z: vec3f) -> vec3f {
    var v = z;
    if (v.x + v.y < 0.0) {
        let t = -v.y;
        v.y = -v.x;
        v.x = t;
    }
    if (v.x + v.z < 0.0) {
        let t = -v.z;
        v.z = -v.x;
        v.x = t;
    }
    if (v.y + v.z < 0.0) {
        let t = -v.z;
        v.z = -v.y;
        v.y = t;
    }
    return v;
}

// Reduces angle a into [0, period), also for negative a. The building block of a polar
// wedge fold: wrap atan2(z.y, z.x) by TAU / n, mirror the upper half, rebuild z.
fn wrap_angle(a: f32, period: f32) -> f32 {
    return a - period * floor(a / period);
}

// Rotates z by the Euler angles deg, in DEGREES, about x then y then z (rot_z * rot_y *
// rot_x, the instance rotation's order). Returns z untouched when all three are 0, so
// rotation sliders cost nothing at their default. A rotation; dr unchanged.
fn rotate_xyz_deg(z: vec3f, deg: vec3f) -> vec3f {
    if (all(deg == vec3f(0.0))) {
        return z;
    }
    let a = radians(deg);
    return rot_z(a.z) * (rot_y(a.y) * (rot_x(a.x) * z));
}

// Returns 1: the whole body of de_iterations for a single-shape primitive formula.
fn primitive_de_iterations() -> i32 {
    return 1;
}

// The de_step for a primitive: rescales the carry so de_finalize can measure a unit-sized
// shape. z is divided by size and by the incoming |dr| (so a primitive mixed after other
// formulas stays the right size in their stretched space), and dr is REPLACED by
// 1 / size. The matching de_finalize is the unit shape's exact signed distance at z
// divided by abs(dr). size is floored at EPSILON, |dr| at EPSILON_FINE.
fn primitive_de_step(carry: IterCarry, size: f32) -> IterCarry {
    let unit_dr = 1.0 / max(size, EPSILON);
    let f = unit_dr / max(abs(carry.dr), EPSILON_FINE);
    return IterCarry(carry.z * f, unit_dr);
}

const IMAGE_SLOTS_PER_FRACTAL = 1 + MAX_MIXINS;
const IMAGE_HEADER_WORDS = 8;
const IMAGE_TEXEL_WORDS = 4u;
const IMAGE_U16_MASK = 0xffffu;
const IMAGE_U16_SCALE = 1.0 / 65535.0;
const IMAGE_U8_MASK = 0xffu;
const IMAGE_SLOPE_STEPS_PER_OCTAVE = 16.0;
const IMAGE_SLOPE_CODE_MAX = 255.0;
const IMAGE_SLOPE_CODE_MAX_LOG2 = 1.0;

// How far, in texels, the two local slopes from image_sample stay valid bounds.
const IMAGE_SLOPE_RADIUS_NEAR = 8.0;
const IMAGE_SLOPE_RADIUS_FAR = 64.0;

var<private> g_image_slot: i32 = -1;

// The image loaded for this formula (a formula asks for one with a `// @image Label` line).
// size is in texels and is (0, 0) when nothing is loaded. The four channels are R, G and
// B premultiplied by alpha (so transparent pixels read 0), then alpha itself, all in
// [0, 1]. slope holds, per channel, the largest change between neighbouring texels
// anywhere in the image; for a height built as dot(k, value), dot(abs(k), slope) / texel
// size bounds its gradient.
struct ImageInfo {
    base: u32,
    size: vec2u,
    slope: vec4f,
}

fn image_info() -> ImageInfo {
    if (g_image_slot < 0) {
        return ImageInfo(0u, vec2u(0u), vec4f(0.0));
    }
    let h = u32(g_image_slot * IMAGE_HEADER_WORDS);
    let slope = bitcast<vec4f>(vec4u(image_data[h + 3u], image_data[h + 4u], image_data[h + 5u], image_data[h + 6u]));
    return ImageInfo(image_data[h], vec2u(image_data[h + 1u], image_data[h + 2u]), slope);
}

// One image_sample result: value is the four channels; near and far bound, per channel,
// the change per texel everywhere within IMAGE_SLOPE_RADIUS_NEAR and
// IMAGE_SLOPE_RADIUS_FAR texels. Combine them with the same weights as value, but
// absolute: dot(abs(k), near).
struct ImageSample {
    value: vec4f,
    near: vec4f,
    far: vec4f,
}

fn image_slope_decode(packed: u32) -> vec4f {
    let code = vec4f(vec4u(packed, packed >> 8u, packed >> 16u, packed >> 24u) & vec4u(IMAGE_U8_MASK));
    let slope = exp2((code - IMAGE_SLOPE_CODE_MAX) / IMAGE_SLOPE_STEPS_PER_OCTAVE + IMAGE_SLOPE_CODE_MAX_LOG2);
    return select(slope, vec4f(0.0), code == vec4f(0.0));
}

fn image_texel(info: ImageInfo, x: u32, y: u32) -> ImageSample {
    let i = info.base + (y * info.size.x + x) * IMAGE_TEXEL_WORDS;
    let rg = image_data[i];
    let ba = image_data[i + 1u];
    let value = vec4f(vec4u(rg, rg >> 16u, ba, ba >> 16u) & vec4u(IMAGE_U16_MASK)) * IMAGE_U16_SCALE;
    return ImageSample(value, image_slope_decode(image_data[i + 2u]), image_slope_decode(image_data[i + 3u]));
}

fn image_mix(a: ImageSample, b: ImageSample, t: f32) -> ImageSample {
    return ImageSample(mix(a.value, b.value, t), mix(a.near, b.near, t), mix(a.far, b.far, t));
}

// Bilinear lookup at uv in [0, 1]^2 (u right, v down the image, clamped at the edges).
// Away from sharp edges near and far are much smaller than info.slope. Returns zeros
// when no image is loaded.
fn image_sample(info: ImageInfo, uv: vec2f) -> ImageSample {
    if (info.size.x == 0u || info.size.y == 0u) {
        return ImageSample(vec4f(0.0), vec4f(0.0), vec4f(0.0));
    }
    let last = info.size - vec2u(1u);
    let t = clamp(uv * vec2f(info.size) - 0.5, vec2f(0.0), vec2f(last));
    let i0 = min(vec2u(t), last);
    let i1 = min(i0 + vec2u(1u), last);
    let f = t - vec2f(i0);
    let top = image_mix(image_texel(info, i0.x, i0.y), image_texel(info, i1.x, i0.y), f.x);
    let bottom = image_mix(image_texel(info, i0.x, i1.y), image_texel(info, i1.x, i1.y), f.x);
    return image_mix(top, bottom, f.y);
}

const TRAP_SPHERE = 1;
const TRAP_BOX = 2;
const TRAP_CROSS = 3;
const TRAP_TORUS = 4;

const TRAP_MAX = 1;
const TRAP_AVERAGE = 2;
const TRAP_LAST = 3;
const TRAP_ITERATION = 4;
const TRAP_STRIP_REPEAT = 1;
const TRAP_STRIP_MIRROR = 2;
const TRAP_INITIAL_DISTANCE = 1e6;
const TRAP_MIN_SPAN = 1e-4;

struct OrbitTrap {
    center: vec3f,
    shape: i32,
    box: vec3f,
    mode: i32,
    radius: f32,
    tube: f32,
}

fn orbit_trap(slot: i32) -> OrbitTrap {
    return OrbitTrap(
        u.instances[slot].trap_center,
        i32(u.instances[slot].trap_shape + 0.5),
        u.instances[slot].trap_box,
        i32(u.instances[slot].trap_mode + 0.5),
        u.instances[slot].trap_radius,
        u.instances[slot].trap_tube,
    );
}

fn orbit_trap_distance(t: OrbitTrap, z: vec3f) -> f32 {
    let q = z - t.center;
    var d: f32;
    switch t.shape {
        case TRAP_SPHERE: {
            d = abs(length(q) - t.radius);
        }
        case TRAP_BOX: {
            let e = abs(q) - t.box;
            d = abs(length(max(e, vec3f(0.0))) + min(max(e.x, max(e.y, e.z)), 0.0));
        }
        case TRAP_CROSS: {
            d = min(abs(q.x), min(abs(q.y), abs(q.z)));
        }
        case TRAP_TORUS: {
            d = abs(length(vec2f(length(q.xz) - t.radius, q.y)) - t.tube);
        }
        default: {
            d = length(q);
        }
    }
    return d;
}

fn orbit_trap_begin(t: OrbitTrap) -> vec4f {
    let starts_high = t.mode != TRAP_MAX && t.mode != TRAP_AVERAGE;
    return vec4f(select(0.0, TRAP_INITIAL_DISTANCE, starts_high), 0.0, 0.0, TRAP_INITIAL_DISTANCE);
}

fn orbit_trap_update(acc: vec4f, t: OrbitTrap, z: vec3f, z_prev: vec3f, it: i32) -> vec4f {
    let d = orbit_trap_distance(t, z);
    var a = acc;
    a.w = d;
    if (t.mode == TRAP_MAX) {
        a.x = max(a.x, d);
    } else if (t.mode == TRAP_AVERAGE) {
        if (any(z != z_prev)) {
            a.x += d;
            a.y += 1.0;
        }
    } else if (t.mode == TRAP_ITERATION) {
        if (d < a.x) {
            a.x = d;
            a.z = f32(it);
        }
    } else {
        a.x = min(a.x, d);
    }
    return a;
}

fn orbit_trap_finish(acc: vec4f, t: OrbitTrap, iters: i32) -> f32 {
    if (t.mode == TRAP_AVERAGE) {
        return select(acc.w, acc.x / max(acc.y, 1.0), acc.y > 0.5);
    }
    if (t.mode == TRAP_LAST) {
        return acc.w;
    }
    if (t.mode == TRAP_ITERATION) {
        return (acc.z + 1.0) / f32(max(iters, 1));
    }
    return acc.x;
}

const LOD_MIN_FRACTION = 0.25;
const LOD_MIN_START = 1e-3;

var<private> g_lod_dist: f32 = 0.0;

fn lod_iterations(n: i32) -> vec2f {
    if (!approx_on(APPROX_DISTANCE_LOD) || n <= 1) {
        return vec2f(f32(n), 1.0);
    }
    let start = max(u.approx_lod_start, LOD_MIN_START);
    let drop = max(u.approx_lod_strength, 0.0) * log2(max(g_lod_dist / start, 1.0));
    let lowest = max(1.0, ceil(f32(n) * LOD_MIN_FRACTION));
    let keep = clamp(f32(n) - drop, lowest, f32(n));
    let hi = ceil(keep);
    return vec2f(hi, 1.0 - (hi - keep));
}

fn lod_blend(lo: IterCarry, hi: IterCarry, frac: f32) -> IterCarry {
    if (frac >= 1.0) {
        return hi;
    }
    return IterCarry(mix(lo.z, hi.z, frac), mix(lo.dr, hi.dr, frac));
}

@@FORMULAS@@

fn instance_code(slot: i32) -> i32 {
    return i32(u.instances[slot].code);
}

fn mixin_code(slot: i32, idx: i32) -> i32 {
    return i32(u.instances[slot].mixins[idx].code);
}

struct HybridStep {
    code: i32,
    p: Params,
    image_slot: i32,
    have: bool,
}

fn hybrid_cycle_len(slot: i32, base_n: i32, mixin_count: i32) -> i32 {
    var cycle_len = base_n;
    for (var j = 0; j < mixin_count; j++) {
        cycle_len += max(i32(u.instances[slot].mixins[j].iterations), 0);
    }
    return max(cycle_len, 1);
}

fn hybrid_step(slot: i32, it: i32, base_n: i32, cycle_len: i32, mixin_count: i32, base_code: i32, base_p: Params) -> HybridStep {
    var st = HybridStep(base_code, base_p, slot * IMAGE_SLOTS_PER_FRACTAL, true);
    var pos_in_cycle = it % cycle_len;
    if (pos_in_cycle >= base_n) {
        pos_in_cycle -= base_n;
        st.have = false;
        for (var j = 0; j < mixin_count; j++) {
            let n_j = max(i32(u.instances[slot].mixins[j].iterations), 0);
            if (pos_in_cycle < n_j) {
                st.code = mixin_code(slot, j);
                st.p = instance_mixin_params(slot, j);
                st.image_slot += 1 + j;
                st.have = true;
                break;
            }
            pos_in_cycle -= n_j;
        }
    }
    return st;
}

fn eval_mixed(pos: vec3f, base_slot: i32) -> vec2f {
    var carry = IterCarry(pos, 1.0);
    let trap_spec = orbit_trap(base_slot);
    var trap = orbit_trap_begin(trap_spec);

    let base_p = instance_params(base_slot);
    let base_code = instance_code(base_slot);
    let base_n = max(i32(u.instances[base_slot].hybrid_base_iters), 0);
    let mixin_count = min(i32(u.instances[base_slot].mixin_count), MAX_MIXINS);
    let cycle_len = hybrid_cycle_len(base_slot, base_n, mixin_count);

    let lod = lod_iterations(max(i32(u.instances[base_slot].hybrid_total_iters), 0));
    let total = i32(lod.x);
    var carry_lo = carry;
    for (var it = 0; it < total; it++) {
        carry_lo = carry;
        let st = hybrid_step(base_slot, it, base_n, cycle_len, mixin_count, base_code, base_p);
        let z_prev = carry.z;
        if (st.have) {
            g_image_slot = st.image_slot;
            carry = eval_step(st.code, carry, pos, st.p);
        }

        trap = orbit_trap_update(trap, trap_spec, carry.z, z_prev, it);
    }

    g_image_slot = base_slot * IMAGE_SLOTS_PER_FRACTAL;
    return vec2f(eval_finalize(base_code, lod_blend(carry_lo, carry, lod.y)), orbit_trap_finish(trap, trap_spec, total));
}

// Right-handed rotation matrices by a radians about the x, y and z axes; apply as
// rot_y(a) * z. The instance rotation composes them as rot_z * rot_y * rot_x. Rotations
// preserve distances; dr unchanged.
fn rot_x(a: f32) -> mat3x3f {
    let c = cos(a);
    let s = sin(a);
    return mat3x3f(vec3f(1.0, 0.0, 0.0), vec3f(0.0, c, s), vec3f(0.0, -s, c));
}
fn rot_y(a: f32) -> mat3x3f {
    let c = cos(a);
    let s = sin(a);
    return mat3x3f(vec3f(c, 0.0, -s), vec3f(0.0, 1.0, 0.0), vec3f(s, 0.0, c));
}
fn rot_z(a: f32) -> mat3x3f {
    let c = cos(a);
    let s = sin(a);
    return mat3x3f(vec3f(c, s, 0.0), vec3f(-s, c, 0.0), vec3f(0.0, 0.0, 1.0));
}

fn instance_rotation(slot: i32) -> mat3x3f {
    return u.instances[slot].frame;
}

fn warp_frame(w: Warp) -> mat3x3f {
    return w.frame;
}

const WARP_REGION_SPHERE = 0;
const WARP_REGION_BOX = 1;
const WARP_REGION_GLOBAL = 2;
const WARP_TWIST = 0;
const WARP_BEND = 1;
const WARP_ROTATE = 2;
const WARP_SCALE = 3;
const WARP_SPHERE_INVERSION = 4;
const WARP_REPEAT = 5;
const WARP_GLOBAL_DEPTH = 1e20;
const WARP_MIN_EXTENT = 1e-4;
const WARP_MIN_FALLOFF = 1e-4;
const WARP_MIN_SCALE = 1e-3;
const WARP_MIN_INVERSION_RADIUS = 1e-3;
const WARP_MIN_REPEAT_CELL = 1e-4;
const WARP_MIN_INFLUENCE = 1e-4;
const WARP_MIN_STRENGTH = 1e-4;
const WARP_MIN_STEP_LIMIT = 1e-4;

fn warp_region_de(w: Warp, p: vec3f) -> f32 {
    let rk = i32(w.region_kind + 0.5);
    if (rk == WARP_REGION_GLOBAL) {
        return -WARP_GLOBAL_DEPTH;
    }
    let q = transpose(warp_frame(w)) * (p - w.center);
    if (rk == WARP_REGION_SPHERE) {
        return length(q) - max(w.extent.x, WARP_MIN_EXTENT);
    }
    let e = max(w.extent, vec3f(WARP_MIN_EXTENT));
    let d = abs(q) - e;
    return length(max(d, vec3f(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0);
}

fn warp_influence(w: Warp, p: vec3f) -> f32 {
    let rk = i32(w.region_kind + 0.5);
    if (rk == WARP_REGION_GLOBAL) {
        return w.strength;
    }
    let de = warp_region_de(w, p);
    if (w.falloff <= WARP_MIN_FALLOFF) {
        return select(0.0, w.strength, de <= 0.0);
    }
    return w.strength * (1.0 - smoothstep(-w.falloff, 0.0, de));
}

fn coord_warp_raw(w: Warp, p: vec3f) -> vec3f {
    let frame = warp_frame(w);
    var q = transpose(frame) * (p - w.center);
    let sk = i32(w.sub_kind + 0.5);
    if (sk == WARP_TWIST) {
        let a = w.params0.x * q.y;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.z, q.y, s * q.x + c * q.z);
    } else if (sk == WARP_BEND) {
        let a = w.params0.x * q.x;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.y, s * q.x + c * q.y, q.z);
    } else if (sk == WARP_ROTATE) {
        let a = w.params0.x;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.z, q.y, s * q.x + c * q.z);
    } else if (sk == WARP_SCALE) {
        q = q / max(abs(w.params0.xyz), vec3f(WARP_MIN_SCALE));
    } else if (sk == WARP_SPHERE_INVERSION) {
        let r_min = max(w.params0.y, WARP_MIN_INVERSION_RADIUS);
        let r2 = max(dot(q, q), r_min * r_min);
        q = q * (w.params0.x * w.params0.x / r2);
    } else if (sk == WARP_REPEAT) {
        let c = w.params0.xyz;
        var f = q;
        if (c.x > WARP_MIN_REPEAT_CELL) { f.x = q.x - c.x * round(q.x / c.x); }
        if (c.y > WARP_MIN_REPEAT_CELL) { f.y = q.y - c.y * round(q.y / c.y); }
        if (c.z > WARP_MIN_REPEAT_CELL) { f.z = q.z - c.z * round(q.z / c.z); }
        q = f;
    } else {
        let a = w.params0.x;
        q = q + a * sin(w.params1.xyz * q.yzx);
    }
    return frame * q + w.center;
}

struct Warped {
    p: vec3f,
    de_scale: f32,
}

@@WARPS@@

const PARTICLE_MODE_OFF = 0u;
const PARTICLE_MODE_SPHERES = 1u;
const PARTICLE_MODE_DOTS = 2u;

struct ParticleGrid {
    origin: vec3f,
    cell: f32,
    dims: vec3i,
    valid: bool,
}

fn particle_grid(s: u32) -> ParticleGrid {
    let h = s * PD_HEADER_WORDS;
    var g: ParticleGrid;
    g.origin = vec3f(bitcast<f32>(particle_data[h]), bitcast<f32>(particle_data[h + 1u]), bitcast<f32>(particle_data[h + 2u]));
    g.cell = bitcast<f32>(particle_data[h + PD_HEADER_CELL]);
    g.dims = vec3i(i32(particle_data[h + PD_HEADER_DIMS]), i32(particle_data[h + PD_HEADER_DIMS + 1u]), i32(particle_data[h + PD_HEADER_DIMS + 2u]));
    g.valid = particle_data[h + PD_HEADER_VALID] != 0u && u32(u.particle_systems[s].mode + 0.5) != PARTICLE_MODE_OFF;
    return g;
}

fn particle_in_grid(g: ParticleGrid, c: vec3i) -> bool {
    return all(c >= vec3i(0)) && all(c < g.dims);
}

fn particle_cell(s: u32, g: ParticleGrid, c: vec3i) -> vec3u {
    let a = PD_CELLS + (s * PD_MAX_CELLS + u32(c.x + g.dims.x * (c.y + g.dims.y * c.z))) * PD_CELL_WORDS;
    let w1 = particle_data[a + PD_CELL_COUNT_WORD];
    return vec3u(particle_data[a], w1 & PD_CELL_COUNT_MASK, w1 >> PD_CELL_SKIP_SHIFT);
}

fn particle_entry(s: u32, slot: u32) -> u32 {
    return particle_data[PD_INDEX + s * PD_MAX_PARTICLES * PD_INSERTS_PER_PARTICLE + slot];
}

fn particle_sphere(s: u32, i: u32) -> vec4f {
    let a = PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS;
    return vec4f(
        bitcast<f32>(particle_data[a]),
        bitcast<f32>(particle_data[a + 1u]),
        bitcast<f32>(particle_data[a + 2u]),
        bitcast<f32>(particle_data[a + PD_RECORD_RADIUS]),
    );
}

fn particle_strip(s: u32, i: u32) -> f32 {
    return bitcast<f32>(particle_data[PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS + PD_RECORD_STRIP]);
}

fn particle_gradient(s: u32, t: f32) -> ColorStop {
    let count = min(i32(u.particle_systems[s].color_count), MAX_COLOR_STOPS);
    if (count <= 0) {
        return default_material();
    }
    if (count == 1 || t <= u.particle_systems[s].colors[0].position) {
        return u.particle_systems[s].colors[0];
    }
    if (t >= u.particle_systems[s].colors[count - 1].position) {
        return u.particle_systems[s].colors[count - 1];
    }
    for (var i = 0; i < count - 1; i++) {
        let a = u.particle_systems[s].colors[i];
        let b = u.particle_systems[s].colors[i + 1];
        if (t >= a.position && t <= b.position) {
            let f = (t - a.position) / max(b.position - a.position, GRADIENT_MIN_SPAN);
            return mix_material(a, b, 1.0 - f);
        }
    }
    return u.particle_systems[s].colors[count - 1];
}

var<private> particles_off: bool = false;

struct ParticleSurface {
    sp: SurfacePoint,
    have: bool,
}

struct DotsHit {
    emit: vec3f,
    hit_t: f32,
    hit_color: vec3f,
    hit_sys: f32,
}

@@PARTICLES@@


const MIN_INSTANCE_SCALE = 0.001;
const MIN_STEP_SAFETY = 0.001;

fn instance_local_de(local: vec3f, slot: i32) -> vec2f {
    if (u.instances[slot].mixin_count > 0.5) {
        return eval_mixed(local, slot);
    }
    return eval_formula(instance_code(slot), slot, local, instance_params(slot));
}

fn instance_scale_magnitude(slot: i32) -> vec3f {
    return max(abs(u.instances[slot].scale), vec3f(MIN_INSTANCE_SCALE));
}

fn instance_local(pos: vec3f, slot: i32) -> vec3f {
    let mag = instance_scale_magnitude(slot);
    let s = select(mag, -mag, u.instances[slot].scale < vec3f(0.0));
    return (transpose(instance_rotation(slot)) * (pos - u.instances[slot].offset)) / s;
}

fn instance_de_factor(slot: i32) -> f32 {
    let mag = instance_scale_magnitude(slot);
    return min(mag.x, min(mag.y, mag.z)) * clamp(u.instances[slot].step_safety, MIN_STEP_SAFETY, 1.0);
}

fn instance_ft_hidden(slot: i32) -> bool {
    return u.fft_active > 0.5 && slot == i32(u.fft_target_slot + 0.5);
}

fn instance_de_trap(pos: vec3f, slot: i32) -> vec2f {
    g_lod_dist = distance(pos, u.camera_pos);
    let result = instance_local_de(instance_local(pos, slot), slot);
    return vec2f(result.x * instance_de_factor(slot), result.y);
}

fn instance_de_trap_ft(pos: vec3f, slot: i32) -> vec2f {
    if (instance_ft_hidden(slot)) {
        return vec2f(NO_SURFACE_DE, 0.0);
    }
    return instance_de_trap(pos, slot);
}

const SMOOTH_K_MIN = 0.0001;
const COMBINE_UNION = 0;
const COMBINE_SMOOTH_MIN = 1;
const COMBINE_SMOOTH_MAX = 2;
const COMBINE_SMOOTH_INV_MAX = 3;
const COMBINE_SMOOTH_MIN_LIN = 4;
const COMBINE_SMOOTH_MIN_NLIN = 5;
const COMBINE_SMOOTH_MIX = 6;

// Smooth combine family behind the instance combine modes, also usable inside a formula
// (e.g. to build a primitive from two shapes in de_finalize before dividing by dr).
// k is the blend radius in distance units; k <= SMOOTH_K_MIN gives the hard operation.

// Smooth union, polynomial blend: min(a, b) rounded off across a seam of width k.
fn smin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return min(a, b);
    }
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Smooth intersection: max(a, b) with a rounded inner edge.
fn smax(a: f32, b: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return max(a, b);
    }
    let h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

// Smooth subtraction: carves cut out of base, max(-cut, base) with a rounded rim.
// Note the argument order: the shape being removed comes first.
fn ssub(cut: f32, base: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return max(-cut, base);
    }
    let h = clamp(0.5 - 0.5 * (base + cut) / k, 0.0, 1.0);
    return mix(base, -cut, h) + k * h * (1.0 - h);
}

// Smooth union with a linear, chamfer-like seam: a + b - k where both are within k.
fn smin_lin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return min(a, b);
    }
    return min(b - max(k - a, 0.0), a - max(k - b, 0.0));
}

// Smooth union with a rounder, nonlinear seam than smin_lin.
fn smin_nlin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return min(a, b);
    }
    let ra = max(k - a, 0.0);
    let rb = max(k - b, 0.0);
    return min(b - ra * (k - rb) / k, a - rb * (k - ra) / k);
}

// Crossfade between a and b across a seam of width k. Softer than smin and not a true
// union: inside the seam the result can exceed min(a, b), so it may overestimate there.
fn smix(a: f32, b: f32, k: f32) -> f32 {
    if (k <= SMOOTH_K_MIN) {
        return min(a, b);
    }
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h);
}

fn combine_de(mode: i32, d: f32, di: f32, k: f32) -> vec2f {
    let hard = k <= SMOOTH_K_MIN;
    let closer = select(1.0, 0.0, di < d);
    if (mode == COMBINE_UNION) {
        return vec2f(min(d, di), closer);
    }
    if (mode == COMBINE_SMOOTH_MIN || mode == COMBINE_SMOOTH_MIX) {
        let h = select(clamp(0.5 + 0.5 * (di - d) / k, 0.0, 1.0), closer, hard);
        return vec2f(select(smin(d, di, k), smix(d, di, k), mode == COMBINE_SMOOTH_MIX), h);
    }
    if (mode == COMBINE_SMOOTH_MAX) {
        let h = select(clamp(0.5 - 0.5 * (di - d) / k, 0.0, 1.0), select(1.0, 0.0, di > d), hard);
        return vec2f(smax(d, di, k), h);
    }
    if (mode == COMBINE_SMOOTH_INV_MAX) {
        let h = select(1.0 - clamp(0.5 - 0.5 * (d + di) / k, 0.0, 1.0), select(1.0, 0.0, -di > d), hard);
        return vec2f(ssub(di, d, k), h);
    }
    if (mode == COMBINE_SMOOTH_MIN_LIN) {
        return vec2f(smin_lin(d, di, k), closer);
    }
    return vec2f(smin_nlin(d, di, k), closer);
}


fn instance_hidden(i: i32) -> bool {
    return u.instances[i].hidden > 0.5;
}

fn empty_scene_de() -> f32 {
    return u.max_dist * 2.0 + 1.0;
}

const CARVE_BLEND = 0.2;
var<private> carves_off: bool = false;

fn apply_carves(pos: vec3f, d: f32) -> f32 {
    if (carves_off) {
        return d;
    }
    var out = d;
    for (var i = 0; i < min(i32(u.carve_count), MAX_CARVES); i++) {
        let c = u.carves[i];
        out = ssub(length(pos - c.xyz) - c.w, out, CARVE_BLEND * c.w);
    }
    return out;
}

fn scene_de(pos: vec3f) -> f32 {
    hot_count();
    let wp = warp_domain(pos);
    let count = max(i32(u.instance_count), 1);
    var d = empty_scene_de();
    var first = true;
    for (var i = 0; i < count; i++) {
        if (instance_hidden(i)) {
            continue;
        }
        let di = instance_de_trap_ft(wp.p, i).x;
        if (first) {
            d = di;
            first = false;
        } else {
            d = combine_de(i32(u.instances[i].combine_mode + 0.5), d, di, u.instances[i].blend_k).x;
        }
    }
    let pd = particles_scene_de(pos, select(d * wp.de_scale, d, first), !first);
    if (pd.y < 0.5) {
        return empty_scene_de();
    }
    return apply_carves(pos, pd.x);
}

const TETRAHEDRAL_TAPS = 4;

fn estimate_normal(pos: vec3f, t: f32) -> vec3f {
    let hot_prev = hot_enter(HOT_NORMALS);
    let grad = tetra_gradient(pos, march_epsilon(t));
    g_hot_src = hot_prev;
    return normalize(grad);
}

fn tetra_gradient(pos: vec3f, e: f32) -> vec3f {
    var grad = vec3f(0.0);
    for (var i = 0; i < TETRAHEDRAL_TAPS; i++) {
        var k = vec3f(1.0, -1.0, -1.0);
        if (i == 1) {
            k = vec3f(-1.0, -1.0, 1.0);
        } else if (i == 2) {
            k = vec3f(-1.0, 1.0, -1.0);
        } else if (i == 3) {
            k = vec3f(1.0, 1.0, 1.0);
        }
        grad += k * scene_de(pos + k * e);
    }
    return grad;
}

struct MarchResult {
    hit: bool,
    dist: f32,
    steps: f32,
    evals: f32,
}

fn march_epsilon(t: f32) -> f32 {
    return u.epsilon_coefficient * t + u.epsilon_floor;
}

const AO_RADIUS_PER_DIST = 0.04;
const AO_MIN_RADIUS = 0.003;
const AO_MAX_RADIUS = 0.25;
const AO_SAMPLES = 5;
const AO_STEP_FRACTION = 0.2;
const AO_WEIGHT_DECAY = 0.6;
const AO_STRENGTH = 2.0;

fn calc_ao(pos: vec3f, normal: vec3f, t: f32) -> f32 {
    if (!part_on(PART_AMBIENT_OCCLUSION)) {
        return 1.0;
    }
    let hot_prev = hot_enter(HOT_AO);
    let radius = clamp(t * AO_RADIUS_PER_DIST, AO_MIN_RADIUS, AO_MAX_RADIUS);
    var occlusion = 0.0;
    var weight = 1.0;
    for (var i = 0; i < AO_SAMPLES; i++) {
        let step_dist = radius * (AO_STEP_FRACTION + AO_STEP_FRACTION * f32(i));
        let d = scene_de(pos + normal * step_dist);
        occlusion += max(step_dist - d, 0.0) * weight;
        weight *= AO_WEIGHT_DECAY;
    }
    g_hot_src = hot_prev;
    return clamp(1.0 - AO_STRENGTH * occlusion / radius, 0.0, 1.0);
}

fn march(origin: vec3f, dir: vec3f) -> MarchResult {
    return march_to(origin, dir, u.max_dist);
}

const COARSE_EPS_SCALE = 4.0;
const COARSE_MIN_STEPS = 16;
const COARSE_STEP_DIVISOR = 2;

var<private> g_coarse_march: bool = false;

const OVERSTEP_TOLERANCE = 0.02;

var<private> g_overstep_watch: bool = false;
var<private> g_overstep_worst: f32 = 0.0;
var<private> g_overstep_count: f32 = 0.0;

fn march_to(origin: vec3f, dir: vec3f, max_t: f32) -> MarchResult {
    let coarse = g_coarse_march;
    let max_steps = select(i32(u.max_steps), max(i32(u.max_steps) / COARSE_STEP_DIVISOR, COARSE_MIN_STEPS), coarse);
    let hq = u.high_quality > 0.5 && !coarse;
    let eps_scale = select(1.0, COARSE_EPS_SCALE, coarse);
    let budget = max(select(max(select(i32(u.refine_fast), i32(u.refine_hq), hq), 0), 0, coarse), select(0, 1, g_overstep_watch));
    let on_hit = u.march_verify < 0.5 && !g_overstep_watch;
    let refine_budget = select(budget, 0, on_hit);
    let bisect_budget = select(0, budget, on_hit);
    let footprint_per_unit_t = u.hq_footprint_budget_px * 2.0 / max(u.resolution.y, 1.0);

    var t = 0.0;
    var i = 0;
    var probing = true;
    var bisecting = false;
    var lo = 0.0;
    var hi = 0.0;
    var refines = 0;
    var resolved = false;
    var evals = 0;

    let max_samples = max_steps * (1 + refine_budget) + bisect_budget;
    for (var n = 0; n < max_samples; n++) {
        let sample_t = select(0.5 * (lo + hi), t, probing);
        let eps = march_epsilon(sample_t) * eps_scale;

        var step_lim = INFINITE_DISTANCE;
        if (probing) {
            step_lim = warp_step_limit(origin + dir * sample_t);
        }

        if (probing) {
            let skip = min(accel_skip(origin + dir * sample_t), step_lim);
            if (skip > eps) {
                lo = sample_t;
                t = sample_t + skip;
                i++;
                if (t > max_t || i >= max_steps) {
                    break;
                }
                continue;
            }
        }

        let d = scene_de(origin + dir * sample_t);
        evals++;
        if (bisecting) {
            if (d < eps) {
                hi = sample_t;
            } else {
                lo = sample_t;
            }
            refines++;
            if (hi - lo <= eps || refines >= bisect_budget) {
                return MarchResult(true, hi, f32(i), f32(evals));
            }
            continue;
        }
        if (g_overstep_watch && !probing) {
            let claimed = hi - sample_t;
            if (claimed > eps && d < claimed * (1.0 - OVERSTEP_TOLERANCE)) {
                g_overstep_worst = max(g_overstep_worst, 1.0 - d / claimed);
                g_overstep_count += 1.0;
            }
        }
        if (d < eps) {
            if (on_hit && bisect_budget > 0 && sample_t - lo > eps) {
                bisecting = true;
                probing = false;
                hi = sample_t;
                refines = 0;
                continue;
            }
            return MarchResult(true, sample_t, f32(i), f32(evals));
        }

        if (probing) {
            lo = t;
            hi = t + min(d, step_lim);
            refines = 0;
            resolved = false;
            probing = false;
        } else {
            if (d >= hi - sample_t) {
                resolved = true;
            } else {
                hi = sample_t;
            }
            refines++;
        }

        if (resolved || refines >= refine_budget) {
            if (hq && !resolved && refine_budget > 0) {
                hi = min(hi, lo + max(t, 1.0) * footprint_per_unit_t);
            }
            t = hi;
            i++;
            if (t > max_t || i >= max_steps) {
                break;
            }
            probing = true;
        }
    }
    return MarchResult(false, t, f32(max_steps), f32(evals));
}

const DEFAULT_ALBEDO = vec3f(0.8, 0.8, 0.85);
const DEFAULT_GLOSSINESS = 0.3;
const DEFAULT_IOR = 1.5;
const DEFAULT_INNER_STEPS = 64.0;
const DEFAULT_FILM_THICKNESS_NM = 400.0;
const DEFAULT_FILM_IOR = 1.8;
const DEFAULT_FILM_ANGLE_SCALE = 1.0;
const DEFAULT_FILM_PERTURB_SCALE = 0.2;
const DEFAULT_SSS_RADIUS = 0.1;
const GRADIENT_MIN_SPAN = 0.0001;

fn default_material() -> ColorStop {
    return ColorStop(DEFAULT_ALBEDO, 0.0, DEFAULT_GLOSSINESS, 0.0, 0.0, DEFAULT_IOR, 0.0, 0.0, DEFAULT_INNER_STEPS, 0.0, DEFAULT_FILM_THICKNESS_NM, DEFAULT_FILM_IOR, 0.0, DEFAULT_FILM_ANGLE_SCALE, 0.0, DEFAULT_FILM_PERTURB_SCALE, DEFAULT_SSS_RADIUS, 0.0);
}

fn mix_material(a: ColorStop, b: ColorStop, h: f32) -> ColorStop {
    var result: ColorStop;
    result.color = mix(b.color, a.color, h);
    result.position = mix(b.position, a.position, h);
    result.glossiness = mix(b.glossiness, a.glossiness, h);
    result.transparency = mix(b.transparency, a.transparency, h);
    result.reflectiveness = mix(b.reflectiveness, a.reflectiveness, h);
    result.ior = mix(b.ior, a.ior, h);
    result.subsurface = mix(b.subsurface, a.subsurface, h);
    result.abbe = mix(b.abbe, a.abbe, h);
    result.inner_max_steps = mix(b.inner_max_steps, a.inner_max_steps, h);
    result.roughness = mix(b.roughness, a.roughness, h);
    result.film_thickness = mix(b.film_thickness, a.film_thickness, h);
    result.film_ior = mix(b.film_ior, a.film_ior, h);
    result.film_strength = mix(b.film_strength, a.film_strength, h);
    result.film_angle_scale = mix(b.film_angle_scale, a.film_angle_scale, h);
    result.film_perturb = mix(b.film_perturb, a.film_perturb, h);
    result.film_perturb_scale = mix(b.film_perturb_scale, a.film_perturb_scale, h);
    result.subsurface_radius = mix(b.subsurface_radius, a.subsurface_radius, h);
    result._pad_film1 = 0.0;
    return result;
}

fn sample_gradient(slot: i32, t: f32) -> ColorStop {
    let count = min(i32(u.instances[slot].color_count), MAX_COLOR_STOPS);
    if (count <= 0) {
        return default_material();
    }
    if (count == 1 || t <= u.instances[slot].colors[0].position) {
        return u.instances[slot].colors[0];
    }
    if (t >= u.instances[slot].colors[count - 1].position) {
        return u.instances[slot].colors[count - 1];
    }
    for (var i = 0; i < count - 1; i++) {
        let a = u.instances[slot].colors[i];
        let b = u.instances[slot].colors[i + 1];
        if (t >= a.position && t <= b.position) {
            let f = (t - a.position) / max(b.position - a.position, GRADIENT_MIN_SPAN);
            return mix_material(a, b, 1.0 - f);
        }
    }
    return u.instances[slot].colors[count - 1];
}

fn orbit_trap_to_strip(slot: i32, v: f32) -> f32 {
    let x = v / max(u.instances[slot].trap_span, TRAP_MIN_SPAN) + u.instances[slot].trap_offset;
    let rep = i32(u.instances[slot].trap_repeat + 0.5);
    if (rep == TRAP_STRIP_REPEAT) {
        return fract(x);
    }
    if (rep == TRAP_STRIP_MIRROR) {
        return 1.0 - abs(fract(x * 0.5) * 2.0 - 1.0);
    }
    return clamp(x, 0.0, 1.0);
}

@group(3) @binding(0) var sky_samp: sampler;
@group(3) @binding(1) var sky_tex: texture_2d<f32>;

@group(4) @binding(0) var fft_magnitude_tex: texture_3d<f32>;

const SKY_INV_TWO_PI = 0.15915494309189535;
const SKY_INV_PI = 0.3183098861837907;
const SKY_IMAGE = 1;
const SKY_MIN_FALLOFF = 0.01;
const SKY_NO_SUN_COS = -1.0;
const SKY_SUN_EDGE = 0.15;
const SKY_SUN_MEAN_EDGE = 0.075;

fn sky_rotate(dir: vec3f) -> vec3f {
    let c = cos(u.sky.yaw);
    let s = sin(u.sky.yaw);
    return vec3f(c * dir.x - s * dir.z, dir.y, s * dir.x + c * dir.z);
}

fn sky_gradient(dir: vec3f) -> vec3f {
    if (dir.y >= 0.0) {
        let t = pow(clamp(dir.y, 0.0, 1.0), 1.0 / max(u.sky.falloff, SKY_MIN_FALLOFF));
        return mix(u.sky.horizon, u.sky.zenith, t);
    }
    return mix(u.sky.horizon, u.sky.ground, clamp(-dir.y, 0.0, 1.0));
}

fn sky_procedural(dir: vec3f) -> vec3f {
    var base = sky_gradient(dir);
    if (u.sky.sun_cos > SKY_NO_SUN_COS) {
        let d = dot(dir, normalize(u.sky.sun_dir));
        let inner = mix(u.sky.sun_cos, 1.0, SKY_SUN_EDGE);
        base += u.sky.sun_color * u.sky.sun_intensity * smoothstep(u.sky.sun_cos, inner, d);
    }
    return base;
}

fn sky_image(dir: vec3f) -> vec3f {
    let uv = vec2f(
        atan2(dir.z, dir.x) * SKY_INV_TWO_PI + 0.5,
        acos(clamp(dir.y, -1.0, 1.0)) * SKY_INV_PI,
    );
    return textureSampleLevel(sky_tex, sky_samp, uv, 0.0).rgb;
}

fn sky_color(dir: vec3f) -> vec3f {
    if (!part_on(PART_SKY)) {
        return vec3f(0.0);
    }
    let d = sky_rotate(dir);
    var c: vec3f;
    if (i32(u.sky.mode + 0.5) == SKY_IMAGE) {
        c = sky_image(d);
    } else {
        c = sky_procedural(d);
    }
    return max(c * u.sky.intensity, vec3f(0.0));
}

fn sky_ambient(normal: vec3f) -> vec3f {
    if (!part_on(PART_SKY)) {
        return vec3f(0.0);
    }
    let d = sky_rotate(normal);
    var c: vec3f;
    if (i32(u.sky.mode + 0.5) == SKY_IMAGE) {
        c = sky_image(d);
    } else {
        c = sky_gradient(d);
        if (u.sky.sun_cos > SKY_NO_SUN_COS) {
            let solid = 2.0 * (1.0 - mix(u.sky.sun_cos, 1.0, SKY_SUN_MEAN_EDGE));
            c += u.sky.sun_color * u.sky.sun_intensity * solid * max(dot(d, normalize(u.sky.sun_dir)), 0.0);
        }
    }
    return max(c * u.sky.intensity, vec3f(0.0));
}

const STEP_AO_REFERENCE = 128.0;

fn step_ao(steps: f32) -> f32 {
    if (!part_on(PART_AMBIENT_OCCLUSION)) {
        return 1.0;
    }
    return clamp(1.0 - steps / STEP_AO_REFERENCE, 0.0, 1.0);
}

struct SurfacePoint {
    mat: ColorStop,
    de: f32,
}

fn hit_material(hit_pos: vec3f) -> SurfacePoint {
    let hot_prev = hot_enter(HOT_MATERIALS);
    hot_count();
    g_hot_src = hot_prev;
    let wp = warp_domain(hit_pos);
    let count = max(i32(u.instance_count), 1);
    var d = empty_scene_de();
    var first = true;
    var mat = default_material();
    for (var i = 0; i < count; i++) {
        if (instance_hidden(i)) {
            continue;
        }
        let dt = instance_de_trap_ft(wp.p, i);
        let mat_i = sample_gradient(i, orbit_trap_to_strip(i, dt.y));
        if (first) {
            d = dt.x;
            mat = mat_i;
            first = false;
            continue;
        }
        let c = combine_de(i32(u.instances[i].combine_mode + 0.5), d, dt.x, u.instances[i].blend_k);
        mat = mix_material(mat, mat_i, c.y);
        d = c.x;
    }
    let ps = particles_hit_material(hit_pos, SurfacePoint(mat, select(d * wp.de_scale, d, first)), !first);
    return SurfacePoint(ps.sp.mat, apply_carves(hit_pos, ps.sp.de));
}

struct LightSample {
    dir: vec3f,
    color: vec3f,
    dist: f32,
}
const BEAM_WAIST = 0.05;

const LIGHT_POINT = 0;
const LIGHT_GLOBAL = 1;
const LIGHT_RAY = 2;
const LIGHT_MIN_DIST_SQ = 0.01;
const RAY_LIGHT_MAX_SPREAD = 1.5;
const ERF_WINITZKI_A = 0.147;

fn erf_approx(x: f32) -> f32 {
    let a = ERF_WINITZKI_A;
    let x2 = x * x;
    let inner = x2 * (4.0 / PI + a * x2) / (1.0 + a * x2);
    return sign(x) * sqrt(max(1.0 - exp(-inner), 0.0));
}

fn light_sample_ex(light: Light, surf_pos: vec3f, seg_dir: vec3f, seg_len: f32) -> LightSample {
    var s: LightSample;
    if (i32(light.light_type + 0.5) == LIGHT_POINT) {
        let to_light = light.position_or_direction - surf_pos;
        let dist = length(to_light);
        s.dir = to_light / max(dist, EPSILON);
        s.color = light.color * light.brightness / max(dist * dist, LIGHT_MIN_DIST_SQ);
        s.dist = dist;
    } else if (i32(light.light_type + 0.5) == LIGHT_GLOBAL) {
        s.dir = normalize(light.position_or_direction);
        s.color = light.color * light.brightness;
        s.dist = u.max_dist * 2.0;
    } else {
        let axis = light.ray_direction / max(length(light.ray_direction), EPSILON_FINE);
        let to_light = light.position_or_direction - surf_pos;
        let dist = length(to_light);
        s.dir = to_light / max(dist, EPSILON);
        s.dist = dist;

        let u0 = -to_light;
        let t0 = dot(u0, axis);
        let perp0 = u0 - axis * t0;

        let d_perp = seg_dir - axis * dot(seg_dir, axis);
        let a_quad = dot(d_perp, d_perp);
        let crossing = seg_len > EPSILON_FINE && a_quad > EPSILON_TINY;

        let s_star = select(0.0, -dot(perp0, d_perp) / max(a_quad, EPSILON_TINY), crossing);
        let s_eval = clamp(s_star, -0.5 * seg_len, 0.5 * seg_len);
        let t_eval = t0 + dot(seg_dir, axis) * s_eval;
        let w = light.waist + max(t_eval, 0.0) * tan(clamp(light.spread, 0.0, RAY_LIGHT_MAX_SPREAD));
        let perp_star = perp0 + d_perp * s_star;

        var profile: f32;
        if (crossing) {
            let k = sqrt(a_quad) / w;
            let hi = erf_approx(k * (0.5 * seg_len - s_star));
            let lo = erf_approx(k * (-0.5 * seg_len - s_star));
            let integral = (w / sqrt(a_quad)) * 0.5 * sqrt(PI) * (hi - lo);
            profile = exp(-dot(perp_star, perp_star) / (w * w)) * integral / seg_len;
        } else {
            profile = exp(-dot(perp0, perp0) / (w * w));
        }

        let front = select(0.0, 1.0, t_eval > 0.0);
        s.color = light.color * light.brightness * profile * front / (w * w);
    }
    return s;
}

fn light_sample(light: Light, surf_pos: vec3f) -> LightSample {
    return light_sample_ex(light, surf_pos, vec3f(0.0, 0.0, 1.0), 0.0);
}

var<private> scene_has_transparency: bool = true;

fn total_light_count() -> i32 {
    if (!part_on(PART_DIRECT_LIGHTS)) {
        return 0;
    }
    return min(i32(u.light_count), MAX_LIGHTS);
}

const MC_MAX_INNER_SAMPLES = 32;

fn mc_inner_count(non_mc: i32) -> i32 {
    if (u.mc_enabled > 0.5) {
        return clamp(i32(u.mc_inner_samples), 1, MC_MAX_INNER_SAMPLES);
    }
    return non_mc;
}

struct VisParams {
    k: f32,
    t0: f32,
    hit_eps: f32,
    exit_slope: f32,
    exit_bias: f32,
    step_floor: f32,
    floor_growth: f32,
    min_step: f32,
    tint_cut: f32,
    steps: i32,
    caustics: bool,
}

const CAUSTIC_MIN_SCALE = 1e-3;
const CAUSTIC_OCTAVE_GAIN = 0.5;
const CAUSTIC_OCTAVE_SCALE = 2.03;
const CAUSTIC_OCTAVE_OFFSET = vec3f(17.1, 3.7, 9.2);
const CAUSTIC_RIDGE_SCALE = 0.75;
const CAUSTIC_FLOOR = 0.35;
const CAUSTIC_LINE_GAIN = 3.0;
const CAUSTIC_LINE_SHARPNESS = 8.0;
const SHADOW_OPAQUE_ALPHA = 0.01;

fn fake_caustic(p: vec3f) -> f32 {
    let q = p / max(u.approx_caustic_scale, CAUSTIC_MIN_SCALE);
    let n = film_noise(q) + CAUSTIC_OCTAVE_GAIN * film_noise(q * CAUSTIC_OCTAVE_SCALE + CAUSTIC_OCTAVE_OFFSET);
    let ridge = 1.0 - clamp(abs(n.x + n.y) * CAUSTIC_RIDGE_SCALE, 0.0, 1.0);
    let lines = CAUSTIC_FLOOR + CAUSTIC_LINE_GAIN * pow(ridge, CAUSTIC_LINE_SHARPNESS);
    return max(mix(1.0, lines, max(u.approx_caustic_strength, 0.0)), 0.0);
}

fn visibility_march(origin: vec3f, light_dir: vec3f, light_dist: f32, vp: VisParams) -> Spec {
    let fake_caustics = approx_on(APPROX_FAKE_CAUSTICS);
    let opaque_only = !scene_has_transparency || (photons_on() && !fake_caustics);
    var caustic_pending = vp.caustics && fake_caustics;
    var t = vp.t0;
    var res = 1.0;
    var tint = spec_splat(1.0);
    var in_solid = false;
    var step_floor = vp.step_floor;
    for (var i = 0; i < vp.steps; i++) {
        if (t >= light_dist) {
            break;
        }
        let p = origin + light_dir * t;

        if (!in_solid) {
            let skip = accel_skip(p);
            if (skip > vp.min_step && vp.k * skip >= res * t) {
                t += skip;
                continue;
            }
        }

        let d = scene_de(p);

        if (in_solid) {
            if (d > vp.exit_slope * t + vp.exit_bias) {
                in_solid = false;
            }
            t += max(abs(d), step_floor);
            step_floor *= vp.floor_growth;
            continue;
        }

        if (d < vp.hit_eps) {
            if (opaque_only) {
                return spec_splat(0.0);
            }
            let mat = hit_material(p).mat;
            let a = clamp(mat.transparency, 0.0, 1.0);
            if (a < SHADOW_OPAQUE_ALPHA) {
                return spec_splat(0.0);
            }
            tint = spec_mul(tint, spec_scale(spec_from_rgb(mix(vec3f(1.0), mat.color, a)), a));
            if (caustic_pending) {
                tint = spec_scale(tint, fake_caustic(p));
                caustic_pending = false;
            }
            if (spec_max(tint) < vp.tint_cut) {
                return spec_splat(0.0);
            }
            in_solid = true;
            t += step_floor;
            continue;
        }

        res = min(res, vp.k * d / t);
        t += max(d, vp.min_step);
    }
    return spec_scale(tint, clamp(res, 0.0, 1.0));
}

const SHADOW_BIAS = 0.004;
const SHADOW_HARD_K = 512.0;
const SHADOW_HIT_EPS = 0.0005;
const SHADOW_EXIT_SLOPE = 0.001;
const SHADOW_EXIT_BIAS = 0.0005;
const SHADOW_STEP_FLOOR = 0.004;
const SHADOW_FLOOR_GROWTH = 1.15;
const SHADOW_MIN_STEP = 0.001;
const SHADOW_TINT_CUT = 0.004;
const SHADOW_MAX_STEPS = 40;

const FOG_VIS_K = 12.0;
const FOG_VIS_T0 = 0.03;
const FOG_VIS_HIT_EPS = 0.001;
const FOG_VIS_EXIT_SLOPE = 0.002;
const FOG_VIS_EXIT_BIAS = 0.001;
const FOG_VIS_STEP_FLOOR = 0.02;
const FOG_VIS_FLOOR_GROWTH = 1.3;
const FOG_VIS_MIN_STEP = 0.08;
const FOG_VIS_TINT_CUT = 0.01;

fn shadow_factor(surf_pos: vec3f, normal: vec3f, light: Light, light_dir: vec3f, light_dist: f32) -> Spec {
    if (light.cast_shadows < 0.5) {
        return spec_splat(1.0);
    }
    let bias = SHADOW_BIAS;
    let vp = VisParams(mix(light.shadow_softness, SHADOW_HARD_K, light.hard_shadows), bias, SHADOW_HIT_EPS, SHADOW_EXIT_SLOPE, SHADOW_EXIT_BIAS, SHADOW_STEP_FLOOR, SHADOW_FLOOR_GROWTH, SHADOW_MIN_STEP, SHADOW_TINT_CUT, min(i32(u.max_steps), SHADOW_MAX_STEPS), true);
    let hot_prev = hot_enter(HOT_SHADOWS);
    let vis = visibility_march(surf_pos + normal * bias, light_dir, light_dist, vp);
    g_hot_src = hot_prev;
    return vis;
}

fn fog_light_visibility(pos: vec3f, light_dir: vec3f, light_dist: f32, steps: i32) -> Spec {
    let vp = VisParams(FOG_VIS_K, FOG_VIS_T0, FOG_VIS_HIT_EPS, FOG_VIS_EXIT_SLOPE, FOG_VIS_EXIT_BIAS, FOG_VIS_STEP_FLOOR, FOG_VIS_FLOOR_GROWTH, FOG_VIS_MIN_STEP, FOG_VIS_TINT_CUT, steps, false);
    return visibility_march(pos, light_dir, light_dist, vp);
}

@group(4) @binding(1) var fog_vis_tex: texture_3d<f32>;
@group(4) @binding(2) var fog_vis_samp: sampler;

fn fog_vis_layer(li: i32) -> i32 {
    if (u.fog_vis_enabled < 0.5) {
        return -1;
    }
    return i32(u.fog_vis_light_layer[li / 4][li % 4]);
}

fn fog_vis_sample(pos: vec3f, layer: i32) -> vec3f {
    let dims = u.fog_vis_dims;
    let local = clamp((pos - u.fog_vis_origin) / u.fog_vis_cell, vec3f(0.5), dims - vec3f(0.5));
    let uvw = vec3f(local.xy / dims.xy, (local.z + f32(layer) * dims.z) / (dims.z * u.fog_vis_layers));
    return textureSampleLevel(fog_vis_tex, fog_vis_samp, uvw, 0.0).rgb;
}

fn fog_shadow(li: i32, pos: vec3f, ls: LightSample, steps: i32) -> Spec {
    let layer = fog_vis_layer(li);
    if (layer >= 0) {
        return spec_from_rgb(fog_vis_sample(pos, layer));
    }
    return fog_light_visibility(pos, ls.dir, ls.dist, steps);
}


const IGN_SCALE = 52.9829189;
const IGN_WEIGHTS = vec2f(0.06711056, 0.00583715);

// Interleaved gradient noise in [0, 1). Built for integer pixel coordinates, where it is
// well spread; on arbitrary floats it shows banding, so prefer hash12w or hash33 there.
fn hash12(p: vec2f) -> f32 {
    return fract(IGN_SCALE * fract(dot(p, IGN_WEIGHTS)));
}

// White-noise hash of the raw float bits of p, in [0, 1). Any input works, but values
// differing by a single ulp hash unrelated, so it is not continuous: never feed it into a
// distance estimate directly, only into choices made per lattice cell (floor(p) first).
fn hash12w(p: vec2f) -> f32 {
    return f32(hash_u32(p)) * INV_U32_RANGE;
}

fn hash_u32(p: vec2f) -> u32 {
    var v = vec2u(bitcast<u32>(p.x), bitcast<u32>(p.y));
    v = v * LCG_MULTIPLIER + LCG_INCREMENT;
    v.x += v.y * LCG_MULTIPLIER;
    v.y += v.x * LCG_MULTIPLIER;
    v ^= v >> vec2u(16u);
    v.x += v.y * LCG_MULTIPLIER;
    v.y += v.x * LCG_MULTIPLIER;
    v ^= v >> vec2u(16u);
    return v.x ^ v.y;
}

fn phase_hg(cos_theta: f32, g: f32) -> f32 {
    let g2 = g * g;
    let denom = 1.0 + g2 - 2.0 * g * cos_theta;
    return (1.0 - g2) / (4.0 * PI * pow(max(denom, EPSILON), 1.5));
}

const PHOTON_VOLUME_WORDS: u32 = 12u;

fn fixed64_to_f32(lo: u32, hi: u32) -> f32 {
    if ((hi & U32_SIGN_BIT) == 0u) {
        return f32(hi) * U32_RANGE + f32(lo);
    }
    let mag_lo = ~lo + 1u;
    let mag_hi = ~hi + select(0u, 1u, mag_lo == 0u);
    return -(f32(mag_hi) * U32_RANGE + f32(mag_lo));
}

fn photon_volume_read(h: u32) -> mat2x3f {
    let base = h * PHOTON_VOLUME_WORDS;
    let unit = u.photon_fixed_unit;
    return mat2x3f(
        vec3f(fixed64_to_f32(photon_volume[base + 0u], photon_volume[base + 1u]),
              fixed64_to_f32(photon_volume[base + 2u], photon_volume[base + 3u]),
              fixed64_to_f32(photon_volume[base + 4u], photon_volume[base + 5u])) * unit,
        vec3f(fixed64_to_f32(photon_volume[base + 6u], photon_volume[base + 7u]),
              fixed64_to_f32(photon_volume[base + 8u], photon_volume[base + 9u]),
              fixed64_to_f32(photon_volume[base + 10u], photon_volume[base + 11u])) * unit);
}

const PHOTON_MIN_CORNER_WEIGHT = 1e-4;
const PHOTON_BEAM_ALIGNMENT = 0.5;

fn photon_volume_sample(pos: vec3f, kind: u32) -> mat2x3f {
    let edge = photon_grid_edge(kind);
    let q = pos / edge - photon_lattice_offset() - vec3f(0.5);
    let base = floor(q);
    let f = q - base;
    let cell0 = vec3i(base);

    var flux = vec3f(0.0);
    var vector = vec3f(0.0);
    for (var i = 0; i < CUBE_CORNERS; i++) {
        let corner = vec3i(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        let wv = mix(vec3f(1.0) - f, f, vec3f(corner));
        let w = wv.x * wv.y * wv.z;
        if (w < PHOTON_MIN_CORNER_WEIGHT) {
            continue;
        }
        let h = photon_bucket_find(cell0 + corner, kind);
        if (h == PHOTON_NO_BUCKET) {
            continue;
        }
        let sums = photon_volume_read(h);
        flux += sums[0] * w;
        vector += sums[1] * w;
    }
    let inv_volume = 1.0 / (edge * edge * edge);
    return mat2x3f(flux * inv_volume, vector * inv_volume);
}

fn photon_gather_volume_at(pos: vec3f, view_dir: vec3f, anisotropy: f32) -> vec3f {
    if (!photons_on()) {
        return vec3f(0.0);
    }
    var beam = photon_volume_sample(pos, PHOTON_GRID_VOLUME);
    let haze = photon_volume_sample(pos, PHOTON_GRID_HAZE);

    let beam_lum = dot(beam[0], LUMA_WEIGHTS);
    let beam_vlen = length(beam[1]);
    if (beam_lum > 0.0 && beam_vlen > PHOTON_BEAM_ALIGNMENT * beam_lum) {
        let along = beam[1] / beam_vlen * photon_grid_edge(PHOTON_GRID_VOLUME);
        let fwd = photon_volume_sample(pos + along, PHOTON_GRID_VOLUME);
        let back = photon_volume_sample(pos - along, PHOTON_GRID_VOLUME);
        beam = mat2x3f((beam[0] + fwd[0] + back[0]) / 3.0, (beam[1] + fwd[1] + back[1]) / 3.0);
    }

    let flux = beam[0] + haze[0];
    let vector = beam[1] + haze[1];

    let lum = dot(flux, LUMA_WEIGHTS);
    if (lum <= 0.0) {
        return vec3f(0.0);
    }
    let vlen = length(vector);
    let align = clamp(vlen / lum, 0.0, 1.0);
    let mean_dir = select(view_dir, vector / max(vlen, EPSILON_TINY), vlen > EPSILON_TINY);
    let phase = phase_hg(dot(view_dir, mean_dir), anisotropy * align);
    return gamut_fit(flux) * (phase * u.photon_intensity);
}

const PHOTON_VOLUME_SUBSTEPS = 24;

fn photon_gather_volume(pos: vec3f, view_dir: vec3f, anisotropy: f32, span: f32, jitter: f32) -> vec3f {
    if (!photons_on()) {
        return vec3f(0.0);
    }
    let edge = photon_volume_cell();
    let n = clamp(i32(ceil(span / edge)), 1, PHOTON_VOLUME_SUBSTEPS);
    var sum = vec3f(0.0);
    for (var i = 0; i < n; i++) {
        let t = (f32(i) + jitter) / f32(n) * span;
        sum += photon_gather_volume_at(pos + view_dir * t, view_dir, anisotropy);
    }
    return sum / f32(n);
}

struct FogSample {
    extinction: f32,
    color: vec3f,
    anisotropy: f32,
}

const FOG_MIN_SOFTNESS = 0.001;
const FOG_MIN_DENSITY = 0.0001;
const VOLUME_MIN_TRANSMITTANCE = 0.003;
const VOLUME_MIN_EXTINCTION = 0.0005;
const VOLUME_MIN_SIGMA = 1e-5;
const FOG_LIGHT_CUTOFF = 1e-6;
const FOG_SEED_STRIDE_X = 13.37;
const FOG_SEED_STRIDE_Y = 71.13;
const FOG_ANALYTIC_SOFT_SHRINK = 0.5;

fn sample_fog(pos: vec3f) -> FogSample {
    var total = 0.0;
    var color_accum = vec3f(0.0);
    var g_accum = 0.0;
    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    for (var i = 0; i < count; i++) {
        let fog = u.fog_emitters[i];
        let dist = length(pos - fog.position);
        if (dist >= fog.radius) {
            continue;
        }
        let edge = clamp(fog.softness, FOG_MIN_SOFTNESS, 1.0);
        let inner = fog.radius * (1.0 - edge);
        let falloff = 1.0 - smoothstep(inner, fog.radius, dist);
        let d = falloff * max(fog.density, 0.0);
        total += d;
        color_accum += fog.color * d;
        g_accum += fog.anisotropy * d;
    }
    var result: FogSample;
    result.extinction = total;
    result.color = select(vec3f(1.0), color_accum / total, total > FOG_MIN_DENSITY);
    result.anisotropy = select(0.0, g_accum / total, total > FOG_MIN_DENSITY);
    return result;
}

struct VolumeResult {
    color: Spec,
    transmittance: f32,
}

const FOG_STEPS_FAST = 28;
const FOG_STEPS_HQ = 64;
const FOG_SHADOW_STEPS_FAST = 10;
const FOG_SHADOW_STEPS_HQ = 24;

const FOG_TRACK_MIN_POINTS = 32.0;
const FOG_TRACK_MAX_POINTS = 256;
const FOG_TRACK_MIN_MAJORANT = 1e-5;

struct FogTrack {
    transmittance: f32,
    window: f32,
    photon_weight: f32,
    photon_pos: vec3f,
    photon_color: vec3f,
    photon_g: f32,
    light_weight: f32,
    light_pos: vec3f,
    light_color: vec3f,
    light_g: f32,
}

fn fog_tracking_on() -> bool {
    return u.mc_enabled > 0.5 && u.fog_tracking > 0.5;
}

fn fog_light_weight(light: Light, pos: vec3f, dir: vec3f, window: f32, color: vec3f, g: f32) -> f32 {
    let ls = light_sample_ex(light, pos, dir, window);
    if (max(ls.color.r, max(ls.color.g, ls.color.b)) < FOG_LIGHT_CUTOFF) {
        return 0.0;
    }
    return dot(color * ls.color, LUMA_WEIGHTS) * phase_hg(dot(dir, ls.dir), g);
}

fn fog_track(origin: vec3f, dir: vec3f, span: f32, rng: ptr<function, u32>) -> FogTrack {
    var tr: FogTrack;
    tr.transmittance = 1.0;

    var majorant = 0.0;
    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    for (var i = 0; i < count; i++) {
        let fog = u.fog_emitters[i];
        if (ray_meets_fog(origin, dir, span, fog)) {
            majorant += max(fog.density, 0.0);
        }
    }
    if (majorant < FOG_TRACK_MIN_MAJORANT || span <= 0.0) {
        return tr;
    }
    let rate = max(majorant, FOG_TRACK_MIN_POINTS / span);
    tr.window = 1.0 / rate;

    let light_count = total_light_count();
    let gather = photons_on();
    var t = 0.0;
    for (var i = 0; i < FOG_TRACK_MAX_POINTS; i++) {
        t += -log(max(rand_from(rng), MIN_UNIFORM_SAMPLE)) / rate;
        if (t >= span || tr.transmittance < VOLUME_MIN_TRANSMITTANCE) {
            break;
        }
        let pos = origin + dir * t;
        let fog = sample_fog(pos);
        if (fog.extinction <= 0.0) {
            continue;
        }
        let ratio = min(fog.extinction / rate, 1.0);
        let a = tr.transmittance * ratio;
        tr.transmittance *= 1.0 - ratio;

        if (gather) {
            tr.photon_weight += a;
            if (rand_from(rng) * tr.photon_weight < a) {
                tr.photon_pos = pos;
                tr.photon_color = fog.color;
                tr.photon_g = fog.anisotropy;
            }
        }

        var lit = 0.0;
        for (var li = 0; li < light_count; li++) {
            lit += fog_light_weight(u.lights[li], pos, dir, tr.window, fog.color, fog.anisotropy);
        }
        let h = a * lit;
        if (h > 0.0) {
            tr.light_weight += h;
            if (rand_from(rng) * tr.light_weight < h) {
                tr.light_pos = pos;
                tr.light_color = fog.color;
                tr.light_g = fog.anisotropy;
            }
        }
    }
    return tr;
}

fn march_fog_once(origin: vec3f, dir: vec3f, max_t: f32, jitter: f32, steps: i32, shadow_steps: i32, seed: vec2f) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;

    let tracked = fog_tracking_on();
    var rng = hash_u32(seed);
    var tr: FogTrack;
    if (tracked) {
        tr = fog_track(origin, dir, max_t, &rng);
    }

    let step_size = max_t / f32(steps);
    var t = step_size * jitter;

    let light_count = total_light_count();
    let points = select(steps, 1, tracked);
    for (var i = 0; i < points; i++) {
        var p_pos: vec3f;
        var p_color: vec3f;
        var p_g: f32;
        var p_weight: f32;
        var p_span = 0.0;
        var l_pos: vec3f;
        var l_color: vec3f;
        var l_g: f32;
        var l_weight: f32;
        var seg: f32;
        var li_lo = 0;
        var li_hi = light_count;

        if (tracked) {
            p_pos = tr.photon_pos;
            p_color = tr.photon_color;
            p_g = tr.photon_g;
            p_weight = tr.photon_weight;
            l_pos = tr.light_pos;
            l_color = tr.light_color;
            l_g = tr.light_g;
            seg = tr.window;
            l_weight = 0.0;
            li_hi = 0;
            if (tr.light_weight > 0.0) {
                var weights: array<f32, MAX_LIGHTS>;
                var total = 0.0;
                for (var li = 0; li < light_count; li++) {
                    weights[li] = fog_light_weight(u.lights[li], l_pos, dir, seg, l_color, l_g);
                    total += weights[li];
                }
                if (total > 0.0) {
                    let pick_at = rand_from(&rng) * total;
                    var pick = 0;
                    var running = 0.0;
                    for (var li = 0; li < light_count; li++) {
                        if (weights[li] <= 0.0) {
                            continue;
                        }
                        pick = li;
                        running += weights[li];
                        if (running > pick_at) {
                            break;
                        }
                    }
                    li_lo = pick;
                    li_hi = pick + 1;
                    l_weight = tr.light_weight / weights[pick];
                }
            }
        } else {
            if (t >= max_t || result.transmittance < VOLUME_MIN_TRANSMITTANCE) {
                break;
            }
            let pos = origin + dir * t;
            t += step_size;
            let fog = sample_fog(pos);
            if (fog.extinction <= VOLUME_MIN_EXTINCTION) {
                continue;
            }
            let sigma_t = fog.extinction;
            let step_transmittance = exp(-sigma_t * step_size);
            let integ = (1.0 - step_transmittance) / max(sigma_t, VOLUME_MIN_SIGMA);
            let w = result.transmittance * sigma_t * integ;
            result.transmittance *= step_transmittance;
            p_pos = pos;
            p_color = fog.color;
            p_g = fog.anisotropy;
            p_weight = w;
            p_span = step_size;
            l_pos = pos;
            l_color = fog.color;
            l_g = fog.anisotropy;
            l_weight = w;
            seg = step_size;
        }

        var photon_in = vec3f(0.0);
        if (p_weight > 0.0) {
            if (p_span > 0.0) {
                photon_in = photon_gather_volume(p_pos, dir, p_g, p_span, jitter);
            } else {
                photon_in = photon_gather_volume_at(p_pos, dir, p_g);
            }
        }

        var light_in = spec_splat(0.0);
        for (var li = li_lo; li < li_hi; li++) {
            let light = u.lights[li];
            let ls = light_sample_ex(light, l_pos, dir, seg);
            if (max(ls.color.r, max(ls.color.g, ls.color.b)) < FOG_LIGHT_CUTOFF) {
                continue;
            }
            var vis = spec_splat(1.0);
            if (light.cast_shadows > 0.5 && part_on(PART_SHADOWS)) {
                vis = fog_shadow(li, l_pos, ls, shadow_steps);
            }
            let phase = phase_hg(dot(dir, ls.dir), l_g);
            light_in = spec_add(light_in, spec_scale(spec_mul(spec_from_rgb(ls.color), vis), phase));
        }

        result.color = spec_add(result.color, spec_add(
            spec_scale(spec_mul(spec_from_rgb(p_color), spec_from_rgb(photon_in)), p_weight),
            spec_scale(spec_mul(spec_from_rgb(l_color), light_in), l_weight)));
    }

    if (tracked) {
        result.transmittance = tr.transmittance;
    }
    return result;
}

const FOG_MAX_SAMPLES = 32;

fn fog_ray_span(origin: vec3f, dir: vec3f, max_t: f32) -> vec2f {
    var lo = max_t;
    var hi = 0.0;
    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    for (var i = 0; i < count; i++) {
        let oc = origin - u.fog_emitters[i].position;
        let b = dot(oc, dir);
        let r = u.fog_emitters[i].radius;
        let disc = b * b - (dot(oc, oc) - r * r);
        if (disc <= 0.0) {
            continue;
        }
        let sq = sqrt(disc);
        let t0 = max(-b - sq, 0.0);
        let t1 = min(-b + sq, max_t);
        if (t1 > t0) {
            lo = min(lo, t0);
            hi = max(hi, t1);
        }
    }
    return vec2f(lo, hi);
}

fn march_fog_analytic(origin: vec3f, dir: vec3f, max_t: f32) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;
    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    let light_count = total_light_count();
    for (var i = 0; i < count; i++) {
        let fog = u.fog_emitters[i];
        let r = fog.radius * (1.0 - FOG_ANALYTIC_SOFT_SHRINK * clamp(fog.softness, 0.0, 1.0));
        let oc = origin - fog.position;
        let b = dot(oc, dir);
        let disc = b * b - (dot(oc, oc) - r * r);
        if (disc <= 0.0) {
            continue;
        }
        let sq = sqrt(disc);
        let t0 = max(-b - sq, 0.0);
        let t1 = min(-b + sq, max_t);
        if (t1 <= t0) {
            continue;
        }
        let chord = t1 - t0;
        let seg_t = exp(-max(fog.density, 0.0) * chord);
        let mid = origin + dir * (0.5 * (t0 + t1));
        var inscatter = vec3f(0.0);
        for (var li = 0; li < light_count; li++) {
            let ls = light_sample_ex(u.lights[li], mid, dir, chord);
            inscatter += ls.color * phase_hg(dot(dir, ls.dir), fog.anisotropy);
        }
        result.color = spec_add(result.color, spec_from_rgb(fog.color * inscatter * (result.transmittance * (1.0 - seg_t))));
        result.transmittance *= seg_t;
    }
    return result;
}

fn march_fog(origin: vec3f, dir: vec3f, max_t: f32, screen_pos: vec2f) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;

    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    if (count == 0 || max_t <= 0.0 || !part_on(PART_FOG)) {
        return result;
    }
    if (approx_on(APPROX_SIMPLE_FOG)) {
        return march_fog_analytic(origin, dir, min(max_t, u.max_dist));
    }

    let hq = u.high_quality > 0.5;
    let steps = select(FOG_STEPS_FAST, FOG_STEPS_HQ, hq);
    let shadow_steps = select(FOG_SHADOW_STEPS_FAST, FOG_SHADOW_STEPS_HQ, hq);
    let span = fog_ray_span(origin, dir, min(max_t, u.max_dist));
    if (span.y <= span.x) {
        return result;
    }
    let span_origin = origin + dir * span.x;
    let samples = mc_inner_count(clamp(i32(u.fog_samples), 1, FOG_MAX_SAMPLES));

    let hot_prev = hot_enter(HOT_FOG);
    var accum_color = spec_splat(0.0);
    var accum_transmittance = 0.0;
    for (var s = 0; s < samples; s++) {
        let seed = screen_pos + vec2f(f32(s) * FOG_SEED_STRIDE_X, f32(s) * FOG_SEED_STRIDE_Y);
        let one = march_fog_once(span_origin, dir, span.y - span.x, hash12(seed), steps, shadow_steps, seed);
        accum_color = spec_add(accum_color, one.color);
        accum_transmittance += one.transmittance;
    }
    g_hot_src = hot_prev;
    result.color = spec_scale(accum_color, 1.0 / f32(samples));
    result.transmittance = accum_transmittance / f32(samples);
    return result;
}

const FFT_MIN_BOX_RADIUS = 0.05;
const FFT_JITTER_SEED_OFFSET = vec2f(83.71, 21.19);
const FFT_VOXEL_SIGMA_CELLS = 1.5;
const FFT_MIN_SIGMA = 1e-5;
const FFT_AXIS_Y = 1;

fn fft_sphere_intersect(origin: vec3f, dir: vec3f, center: vec3f, radius: f32) -> vec2f {
    let oc = origin - center;
    let b = dot(oc, dir);
    let c = dot(oc, oc) - radius * radius;
    let disc = b * b - c;
    if (disc < 0.0) {
        return vec2f(-1.0, -1.0);
    }
    let sq = sqrt(disc);
    return vec2f(-b - sq, -b + sq);
}

fn fft_magnitude_load(coord: vec3i) -> f32 {
    let c = clamp(coord, vec3i(0), vec3i(i32(FFT_N) - 1));
    return textureLoad(fft_magnitude_tex, c, 0).r;
}

fn sample_fft_magnitude(local: vec3f, box_radius: f32) -> f32 {
    let b = max(box_radius, FFT_MIN_BOX_RADIUS);
    let cell = (2.0 * b) / f32(FFT_N);
    let g = (local + vec3f(b)) / cell - vec3f(0.5);
    let g0 = floor(g);
    let f = g - g0;
    let c0 = vec3i(g0);
    var acc = 0.0;
    for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 2; j++) {
            for (var k = 0; k < 2; k++) {
                let w = select(1.0 - f.x, f.x, i == 1) * select(1.0 - f.y, f.y, j == 1) * select(1.0 - f.z, f.z, k == 1);
                acc += w * fft_magnitude_load(c0 + vec3i(i, j, k));
            }
        }
    }
    return acc;
}

const FFT_CLOUD_STEPS = 40;

fn march_fft_cloud(origin: vec3f, dir: vec3f, max_t: f32, screen_pos: vec2f) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;

    if (u.fft_active < 0.5 || max_t <= 0.0) {
        return result;
    }

    let slot = i32(u.fft_target_slot + 0.5);
    let offset = u.instances[slot].offset;
    let box_radius = max(u.fft_box_radius, FFT_MIN_BOX_RADIUS);
    let s = instance_scale_magnitude(slot);
    let s_signed = select(s, -s, u.instances[slot].scale < vec3f(0.0));
    let sphere_r = box_radius * max(s.x, max(s.y, s.z)) * SQRT3;

    let hit = fft_sphere_intersect(origin, dir, offset, sphere_r);
    let t0 = max(hit.x, 0.0);
    let t1 = min(hit.y, min(max_t, u.max_dist));
    if (hit.y < 0.0 || t1 <= t0) {
        return result;
    }

    let rot = instance_rotation(slot);
    let tint = spec_from_rgb(u.instances[slot].colors[0].color);
    let density_scale = max(u.fft_cloud_density, 0.0);

    let step_size = (t1 - t0) / f32(FFT_CLOUD_STEPS);
    let jitter = hash12(screen_pos + FFT_JITTER_SEED_OFFSET);
    var t = t0 + step_size * jitter;

    for (var i = 0; i < FFT_CLOUD_STEPS; i++) {
        if (t >= t1 || result.transmittance < VOLUME_MIN_TRANSMITTANCE) {
            break;
        }
        let pos = origin + dir * t;
        let local = (transpose(rot) * (pos - offset)) / s_signed;
        if (all(abs(local) <= vec3f(box_radius))) {
            let mag = sample_fft_magnitude(local, box_radius);
            let sigma_t = mag * density_scale;
            if (sigma_t > VOLUME_MIN_EXTINCTION) {
                let step_transmittance = exp(-sigma_t * step_size);
                let integ = (1.0 - step_transmittance) / max(sigma_t, VOLUME_MIN_SIGMA);
                result.color = spec_add(result.color, spec_scale(tint, result.transmittance * sigma_t * integ));
                result.transmittance *= step_transmittance;
            }
        }
        t += step_size;
    }

    return result;
}

const AMBIENT_INTENSITY = 0.15;

struct InsideMarch {
    exited: bool,
    dist: f32,
}

const INSIDE_STEP_GROWTH = 6.0;
const INSIDE_MIN_STEP = 0.0005;
const INSIDE_WARMUP_STEPS = 1;
const INSIDE_EXIT_SLOPE = 0.0005;
const INSIDE_EXIT_BIAS = 0.00005;
const INSIDE_STEP_BASE = 0.004;

fn march_inside(origin: vec3f, dir: vec3f, max_inner_steps: i32, step_base: f32, max_t: f32) -> InsideMarch {
    var t = 0.0;
    let steps = max(max_inner_steps, 1);
    let growth = 1.0 + INSIDE_STEP_GROWTH / f32(steps);
    var step_floor = max(step_base, INSIDE_MIN_STEP);
    for (var i = 0; i < steps; i++) {
        let pos = origin + dir * t;
        let d = scene_de(pos);
        if (i > INSIDE_WARMUP_STEPS && inside_exited(d, t)) {
            return InsideMarch(true, t);
        }
        t += max(abs(d), step_floor);
        step_floor *= growth;
        if (t > max_t) {
            break;
        }
    }
    return InsideMarch(false, t);
}

fn inside_exited(d: f32, t: f32) -> bool {
    return d > INSIDE_EXIT_SLOPE * t + INSIDE_EXIT_BIAS;
}

fn refine_inside_exit(origin: vec3f, dir: vec3f, inside_t: f32, outside_t: f32, iterations: i32) -> f32 {
    var lo = inside_t;
    var hi = outside_t;
    for (var i = 0; i < iterations; i++) {
        let mid = 0.5 * (lo + hi);
        if (inside_exited(scene_de(origin + dir * mid), mid)) {
            hi = mid;
        } else {
            lo = mid;
        }
    }
    return hi;
}

const SSS_WRAP = 0.75;
const SSS_REACH_FLOOR = 0.05;
const SSS_MIN_RADIUS = 0.0005;
const SSS_BLUR_PER_RADIUS = 0.5;
const SSS_BLUR_TAP_FRACTION = 0.5;
const SSS_PROBE_STEP_PER_RADIUS = 0.05;
const SSS_PROBE_DEPTH_RADII = 6.0;
const SSS_MAX_STEPS = 64;
const SSS_PATH_MAX_STEPS = 128;
const SSS_EXIT_REFINE_STEPS = 7;
const SPEC_POWER_MIN = 4.0;
const SPEC_POWER_MAX = 128.0;
const MATERIAL_EPSILON = 0.001;
const SURFACE_LIGHT_CUTOFF = 1e-5;

struct LightTerms {
    ndotl: f32,
    specular: f32,
}

fn light_terms(ls: LightSample, normal: vec3f, view_dir: vec3f, spec_power: f32, glossiness: f32) -> LightTerms {
    let ndotl = max(dot(normal, ls.dir), 0.0);
    let half_dir = normalize(ls.dir + view_dir);
    let specular = select(0.0, pow(max(dot(normal, half_dir), 0.0), spec_power) * glossiness, part_on(PART_SPECULAR));
    return LightTerms(ndotl, specular);
}

struct Subsurface {
    amount: f32,
    radius: f32,
    reach: Spec,
    blur_normal: vec3f,
}

fn subsurface_setup(pos: vec3f, normal: vec3f, mat: ColorStop, albedo: Spec) -> Subsurface {
    var s: Subsurface;
    s.amount = clamp(mat.subsurface, 0.0, 1.0);
    s.radius = max(mat.subsurface_radius, SSS_MIN_RADIUS);
    s.blur_normal = normal;
    if (s.amount <= MATERIAL_EPSILON) {
        s.amount = 0.0;
        return s;
    }
    let peak = max(spec_max(albedo), EPSILON);
    let rel_lo = albedo.lo / peak;
    let rel_hi = albedo.hi / peak;
    s.reach = Spec(max(rel_lo * rel_lo, vec4f(SSS_REACH_FLOOR)), max(rel_hi * rel_hi, vec4f(SSS_REACH_FLOOR)));

    let hot_prev = hot_enter(HOT_SUBSURFACE);
    let blur = s.radius * SSS_BLUR_PER_RADIUS;
    let grad = tetra_gradient(pos + normal * blur, blur * SSS_BLUR_TAP_FRACTION);
    g_hot_src = hot_prev;
    let len = length(grad);
    if (len > EPSILON_TINY) {
        s.blur_normal = grad / len;
    }
    return s;
}

fn subsurface_wrap_lanes(ndl_fine: f32, ndl_blur: f32, reach: vec4f) -> vec4f {
    let ndl = mix(vec4f(ndl_fine), vec4f(ndl_blur), reach);
    let w = SSS_WRAP * reach;
    return max(ndl + w, vec4f(0.0)) / (vec4f(1.0) + w);
}

fn subsurface_wrap(s: Subsurface, ndl_fine: f32, light_dir: vec3f) -> Spec {
    let ndl_blur = dot(s.blur_normal, light_dir);
    return Spec(subsurface_wrap_lanes(ndl_fine, ndl_blur, s.reach.lo), subsurface_wrap_lanes(ndl_fine, ndl_blur, s.reach.hi));
}

fn diffuse_weight(s: Subsurface, ndl: f32, light_dir: vec3f) -> Spec {
    if (s.amount <= 0.0) {
        return spec_splat(max(ndl, 0.0));
    }
    let profile = spec_add(subsurface_wrap(s, ndl, light_dir), spec_splat(max(-ndl, 0.0)));
    return spec_add(spec_splat((1.0 - s.amount) * max(ndl, 0.0)), spec_scale(profile, s.amount));
}

fn subsurface_transmit(s: Subsurface, depth: f32) -> Spec {
    return Spec(exp(-depth / (s.radius * s.reach.lo)), exp(-depth / (s.radius * s.reach.hi)));
}

fn subsurface_light_path(pos: vec3f, normal: vec3f, start_inside: bool, s: Subsurface, light: Light, ls: LightSample, occlusion: bool) -> Spec {
    if (!start_inside && !occlusion) {
        return spec_splat(1.0);
    }
    let dir = ls.dir;
    let origin = select(pos + normal * SHADOW_BIAS, pos, start_inside);
    let cap = s.radius * SSS_PROBE_DEPTH_RADII;
    let step_base = max(s.radius * SSS_PROBE_STEP_PER_RADIUS, INSIDE_MIN_STEP);
    let growth = 1.0 + INSIDE_STEP_GROWTH / f32(SSS_MAX_STEPS);
    let steps = min(i32(u.max_steps), SSS_PATH_MAX_STEPS);
    var inside = start_inside;
    var t = 0.0;
    var prev = 0.0;
    var entry = 0.0;
    var depth = 0.0;
    var inner = 0;
    var step_floor = step_base;
    let hot_prev = hot_enter(HOT_SUBSURFACE);
    for (var i = 0; i < steps; i++) {
        if (t >= ls.dist) {
            break;
        }
        let p = origin + dir * t;
        if (!inside) {
            let skip = accel_skip(p);
            if (skip > SHADOW_MIN_STEP) {
                t += skip;
                continue;
            }
        }
        let d = scene_de(p);

        if (inside) {
            if (inner > INSIDE_WARMUP_STEPS && inside_exited(d, t)) {
                let exit_t = refine_inside_exit(origin, dir, prev, t, SSS_EXIT_REFINE_STEPS);
                depth += exit_t - entry;
                inside = false;
                if (!occlusion) {
                    break;
                }
                t = exit_t + SHADOW_BIAS;
                continue;
            }
            prev = t;
            t += max(abs(d), step_floor);
            step_floor *= growth;
            inner += 1;
            if (depth + t - entry > cap) {
                g_hot_src = hot_prev;
                return spec_splat(0.0);
            }
            continue;
        }

        if (d < SHADOW_HIT_EPS) {
            if (apply_part_mask(hit_material(p).mat).subsurface <= MATERIAL_EPSILON) {
                let rest = shadow_factor(p - dir * (2.0 * SHADOW_BIAS), dir, light, dir, ls.dist - t + 2.0 * SHADOW_BIAS);
                g_hot_src = hot_prev;
                return spec_mul(subsurface_transmit(s, depth), rest);
            }
            inside = true;
            entry = t;
            prev = t;
            inner = 1;
            step_floor = step_base;
            t += step_floor;
            continue;
        }
        t += max(d, SHADOW_MIN_STEP);
    }
    g_hot_src = hot_prev;
    if (inside) {
        depth += min(t, ls.dist) - entry;
    }
    return subsurface_transmit(s, depth);
}

const LIGHT_PICK_SEED_OFFSET = vec2f(47.23, 113.91);

fn shade_local(pos: vec3f, dir: vec3f, normal: vec3f, mat: ColorStop, ambient_light: Spec, use_shadows: bool, seed: vec2f) -> Spec {
    let view_dir = -dir;
    let spec_power = mix(SPEC_POWER_MIN, SPEC_POWER_MAX, clamp(mat.glossiness, 0.0, 1.0));
    var albedo = spec_from_rgb(mat.color);

    var film = spec_splat(1.0);
    if (mat.film_strength > MATERIAL_EPSILON) {
        film = thin_film_tint(dot(view_dir, film_normal(normal, pos, mat)), mat);
        albedo = spec_mul(albedo, film);
    }
    g_shade_albedo = albedo;

    let sss = subsurface_setup(pos, normal, mat, albedo);

    var diffuse_accum = spec_from_rgb(photon_gather_surface(pos, normal));
    var specular_accum = spec_splat(0.0);
    let fake_bounce = approx_on(APPROX_FAKE_BOUNCE);
    let light_count = total_light_count();
    let shadows_on = use_shadows && part_on(PART_SHADOWS);
    let pick_one = shadows_on && u.mc_enabled > 0.5 && u.mc_light_pick > 0.5 && light_count > 1;
    var pick_weights: array<f32, MAX_LIGHTS>;
    var pick_total = 0.0;
    for (var i = 0; i < light_count; i++) {
        let light = u.lights[i];
        let ls = light_sample(light, pos);
        if (max(ls.color.r, max(ls.color.g, ls.color.b)) < SURFACE_LIGHT_CUTOFF) {
            continue;
        }
        let light_spec = spec_from_rgb(ls.color);

        if (fake_bounce) {
            let facing_away = 0.5 - 0.5 * dot(normal, ls.dir);
            diffuse_accum = spec_add(diffuse_accum, spec_mul(albedo, spec_scale(light_spec, u.approx_bounce * facing_away)));
        }

        let terms = light_terms(ls, normal, view_dir, spec_power, mat.glossiness);
        if (sss.amount > 0.0) {
            let ndl = dot(normal, ls.dir);
            let sss_w = diffuse_weight(sss, ndl, ls.dir);
            let sss_spec = select(0.0, terms.specular, ndl > 0.0);
            if (spec_max(sss_w) <= 0.0 && sss_spec <= 0.0) {
                continue;
            }
            let occlusion = shadows_on && light.cast_shadows > 0.5;
            let reaching = spec_mul(light_spec, subsurface_light_path(pos, normal, ndl <= 0.0, sss, light, ls, occlusion));
            diffuse_accum = spec_add(diffuse_accum, spec_mul(reaching, sss_w));
            specular_accum = spec_add(specular_accum, spec_scale(reaching, sss_spec));
            continue;
        }

        if (terms.ndotl <= 0.0) {
            continue;
        }
        let diffuse_w = diffuse_weight(sss, terms.ndotl, ls.dir);
        if (pick_one && light.cast_shadows > 0.5) {
            let w = (ls.color.r + ls.color.g + ls.color.b) * (spec_max(diffuse_w) + terms.specular);
            pick_weights[i] = w;
            pick_total += w;
            continue;
        }
        var shadow = spec_splat(1.0);
        if (shadows_on) {
            if (WF_DEFER && g_wf_shadow_light < 0 && light.cast_shadows > 0.5) {
                g_wf_shadow_light = i;
                g_wf_shadow_w = spec_mul(light_spec, spec_add(spec_mul(albedo, diffuse_w), spec_scale(film, terms.specular)));
                continue;
            }
            shadow = shadow_factor(pos, normal, light, ls.dir, ls.dist);
            if (spec_max(shadow) <= 0.0) {
                continue;
            }
        }
        let reaching = spec_mul(light_spec, shadow);
        diffuse_accum = spec_add(diffuse_accum, spec_mul(reaching, diffuse_w));
        specular_accum = spec_add(specular_accum, spec_scale(reaching, terms.specular));
    }

    if (pick_total > 0.0) {
        let pick_at = hash12w(seed + LIGHT_PICK_SEED_OFFSET) * pick_total;
        var pick = 0;
        var running = 0.0;
        for (var i = 0; i < light_count; i++) {
            if (pick_weights[i] <= 0.0) {
                continue;
            }
            pick = i;
            running += pick_weights[i];
            if (running > pick_at) {
                break;
            }
        }
        let light = u.lights[pick];
        let ls = light_sample(light, pos);
        let terms = light_terms(ls, normal, view_dir, spec_power, mat.glossiness);
        let diffuse_w = diffuse_weight(sss, terms.ndotl, ls.dir);
        let pick_scale = pick_total / pick_weights[pick];
        if (WF_DEFER) {
            g_wf_shadow_light = pick;
            g_wf_shadow_w = spec_scale(spec_mul(spec_from_rgb(ls.color), spec_add(spec_mul(albedo, diffuse_w), spec_scale(film, terms.specular))), pick_scale);
        } else {
            let shadow = shadow_factor(pos, normal, light, ls.dir, ls.dist);
            let reaching = spec_scale(spec_mul(spec_from_rgb(ls.color), shadow), pick_scale);
            diffuse_accum = spec_add(diffuse_accum, spec_mul(reaching, diffuse_w));
            specular_accum = spec_add(specular_accum, spec_scale(reaching, terms.specular));
        }
    }

    return spec_add(spec_mul(albedo, spec_add(ambient_light, diffuse_accum)),
                    spec_mul(specular_accum, film));
}

const HEMISPHERE_SEED_OFFSET = vec2f(91.73, 31.13);
const BASIS_POLE_COS = 0.99;
const INDIRECT_RAY_BIAS = 0.004;

fn cosine_hemisphere_sample(normal: vec3f, seed: vec2f) -> vec3f {
    return cosine_hemisphere_from(normal, hash12w(seed), hash12w(seed + HEMISPHERE_SEED_OFFSET));
}

fn cosine_hemisphere_from(normal: vec3f, u1: f32, u2: f32) -> vec3f {
    let r = sqrt(u1);
    let phi = u2 * TAU;
    let local = vec3f(r * cos(phi), r * sin(phi), sqrt(max(1.0 - u1, 0.0)));

    let up = select(vec3f(0.0, 0.0, 1.0), vec3f(1.0, 0.0, 0.0), abs(normal.z) > BASIS_POLE_COS);
    let tangent = normalize(cross(up, normal));
    let bitangent = cross(normal, tangent);
    return normalize(tangent * local.x + bitangent * local.y + normal * local.z);
}

fn indirect_light(pos: vec3f, normal: vec3f, seed: vec2f) -> Spec {
    let hot_prev = hot_enter(HOT_MC_INDIRECT);
    let light = indirect_light_traced(pos, normal, seed);
    g_hot_src = hot_prev;
    return light;
}

fn indirect_light_traced(pos: vec3f, normal: vec3f, seed: vec2f) -> Spec {
    let dir = cosine_hemisphere_sample(normal, seed);
    let origin = pos + normal * INDIRECT_RAY_BIAS;
    let coarse_before = g_coarse_march;
    g_coarse_march = approx_on(APPROX_COARSE_SECONDARY);
    let bounce = march(origin, dir);
    g_coarse_march = coarse_before;
    if (!bounce.hit) {
        return spec_from_rgb(sky_color(dir));
    }
    if (photons_on()) {
        return spec_splat(0.0);
    }
    let hit_pos = origin + dir * bounce.dist;
    let hit_normal = estimate_normal(hit_pos, bounce.dist);
    var hit_mat = apply_part_mask(hit_material(hit_pos).mat);
    hit_mat.subsurface = 0.0;
    return shade_local(hit_pos, dir, hit_normal, hit_mat, spec_splat(AMBIENT_INTENSITY), false, seed);
}

struct Refraction {
    dir: vec3f,
    tir: bool,
}

const REFRACT_TIR_EPSILON = 0.0001;
const MIN_ROUGHNESS = 0.0001;

fn refract_safe(dir: vec3f, raw_normal: vec3f, eta: f32) -> Refraction {
    let n = select(raw_normal, -raw_normal, dot(dir, raw_normal) > 0.0);
    let r = refract(dir, n, eta);
    if (dot(r, r) > REFRACT_TIR_EPSILON) {
        return Refraction(r, false);
    }
    return Refraction(reflect(dir, n), true);
}

fn perturb_normal(n: vec3f, alpha: f32, seed: vec2f) -> vec3f {
    if (alpha <= MIN_ROUGHNESS) {
        return n;
    }
    return normalize(mix(n, cosine_hemisphere_sample(n, seed), alpha));
}

const DISPERSION_INV_LAMBDA_D2 = 2.89626;
const DISPERSION_INV_LAMBDA_F2_MINUS_C2 = 1.9099;

fn cauchy_ior(ior_d: f32, abbe: f32, lambda: f32) -> f32 {
    let b = (ior_d - 1.0) / (max(abbe, 1.0) * DISPERSION_INV_LAMBDA_F2_MINUS_C2);
    return ior_d + b * (1.0 / (lambda * lambda) - DISPERSION_INV_LAMBDA_D2);
}

const SCATTER_ABSORBED: i32 = 0;
const SCATTER_REFLECT: i32 = 1;
const SCATTER_TRANSMIT: i32 = 2;
const SCATTER_DIFFUSE: i32 = 3;

struct Scatter {
    dir: vec3f,
    weight: Spec,
    kind: i32,
    local_share: f32,
    disp_ang2: Spec,
}

fn fresnel_schlick(cos_theta: f32, ior: f32) -> f32 {
    let r0root = (1.0 - ior) / (1.0 + ior);
    let r0 = r0root * r0root;
    let c = clamp(1.0 - abs(cos_theta), 0.0, 1.0);
    let c2 = c * c;
    return r0 + (1.0 - r0) * c2 * c2 * c;
}

const FILM_PI = 3.14159265358979;
const FILM_MAX_ANGLE = 1.5607;
const FILM_MIN_PEAK = 1e-5;

// Integer-lattice hash: three values in [0, 1) per integer cell. p is truncated toward
// zero, so pass floor(p) (or other integer-valued vectors) or the cells either side of 0
// merge.
fn hash33(p: vec3f) -> vec3f {
    var v = bitcast<vec3u>(vec3i(p));
    v = v * LCG_MULTIPLIER + LCG_INCREMENT;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> vec3u(16u);
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return vec3f(v) * INV_U32_RANGE;
}

// Smooth 3-channel value noise in [-1, 1] on a unit lattice (hash33 at the corners,
// smoothstep-weighted trilinear blend). Each partial derivative is at most 3, so
// displacing a distance by amount * film_noise(p * freq).x needs the result divided by
// about 1 + 5.2 * amount * freq to stay a safe estimate.
fn film_noise(p: vec3f) -> vec3f {
    let i = floor(p);
    let f = p - i;
    let w = f * f * (3.0 - 2.0 * f);
    let x00 = mix(hash33(i + vec3f(0.0, 0.0, 0.0)), hash33(i + vec3f(1.0, 0.0, 0.0)), w.x);
    let x10 = mix(hash33(i + vec3f(0.0, 1.0, 0.0)), hash33(i + vec3f(1.0, 1.0, 0.0)), w.x);
    let x01 = mix(hash33(i + vec3f(0.0, 0.0, 1.0)), hash33(i + vec3f(1.0, 0.0, 1.0)), w.x);
    let x11 = mix(hash33(i + vec3f(0.0, 1.0, 1.0)), hash33(i + vec3f(1.0, 1.0, 1.0)), w.x);
    let y0 = mix(x00, x10, w.y);
    let y1 = mix(x01, x11, w.y);
    return mix(y0, y1, w.z) * 2.0 - 1.0;
}

fn film_normal(n: vec3f, pos: vec3f, mat: ColorStop) -> vec3f {
    let amount = clamp(mat.film_perturb, 0.0, 1.0);
    if (amount <= MATERIAL_EPSILON) {
        return n;
    }
    let bend = film_noise(pos / max(mat.film_perturb_scale, EPSILON));
    return normalize(n + bend * amount);
}

fn airy_reflectance(r12: f32, r23: f32, cos_delta: vec4f) -> vec4f {
    let cross = 2.0 * r12 * r23 * cos_delta;
    return (r12 * r12 + r23 * r23 + cross) / (1.0 + r12 * r12 * r23 * r23 + cross);
}
fn airy_peak(r12: f32, r23: f32) -> f32 {
    let a = (abs(r12) + abs(r23)) / (1.0 + abs(r12 * r23));
    return a * a;
}

fn thin_film_tint(cos_view: f32, mat: ColorStop) -> Spec {
    let strength = clamp(mat.film_strength, 0.0, 1.0);

    let theta = acos(clamp(cos_view, 0.0, 1.0)) * max(mat.film_angle_scale, 0.0);
    let c1 = cos(min(theta, FILM_MAX_ANGLE));
    let s1 = sqrt(max(1.0 - c1 * c1, 0.0));

    let n2 = max(mat.film_ior, 1.0);
    let n3 = max(mat.ior, 1.0);
    let s2 = s1 / n2;
    let c2 = sqrt(max(1.0 - s2 * s2, 0.0));
    let s3 = s1 / n3;
    let c3 = sqrt(max(1.0 - s3 * s3, 0.0));

    let r12s = (c1 - n2 * c2) / (c1 + n2 * c2);
    let r12p = (n2 * c1 - c2) / (n2 * c1 + c2);
    let r23s = (n2 * c2 - n3 * c3) / (n2 * c2 + n3 * c3);
    let r23p = (n3 * c2 - n2 * c3) / (n3 * c2 + n2 * c3);

    let peak = 0.5 * (airy_peak(r12s, r23s) + airy_peak(r12p, r23p));
    if (peak < FILM_MIN_PEAK) {
        return spec_splat(1.0);
    }

    let path = 4.0 * FILM_PI * n2 * max(mat.film_thickness, 0.0) * c2;
    let cd_lo = cos(vec4f(path) / spec_lambda_lo);
    let cd_hi = cos(vec4f(path) / spec_lambda_hi);
    let r_lo = 0.5 * (airy_reflectance(r12s, r23s, cd_lo) + airy_reflectance(r12p, r23p, cd_lo));
    let r_hi = 0.5 * (airy_reflectance(r12s, r23s, cd_hi) + airy_reflectance(r12p, r23p, cd_hi));

    return Spec(mix(vec4f(1.0), r_lo / peak, strength),
                mix(vec4f(1.0), r_hi / peak, strength));
}

fn dispersion_angles2(in_dir: vec3f, n: vec3f, mat: ColorStop, inside: bool, hero_dir: vec3f) -> Spec {
    let ior_d = max(mat.ior, 1.0);
    var a_lo = vec4f(0.0);
    var a_hi = vec4f(0.0);
    for (var k = 0; k < i32(SPECTRAL_COUNT); k++) {
        let ior_k = max(cauchy_ior(ior_d, mat.abbe, spec_lambda_um(k)), 1.0);
        let eta_k = select(1.0 / ior_k, ior_k, inside);
        let d_k = refract_safe(in_dir, n, eta_k).dir;
        let a = 2.0 * (1.0 - clamp(dot(hero_dir, d_k), -1.0, 1.0));
        if (k < SPEC_LANES) {
            a_lo[k] = a;
        } else {
            a_hi[k - SPEC_LANES] = a;
        }
    }
    return Spec(a_lo, a_hi);
}

fn dispersion_weights(dist2: Spec, sigma: f32) -> Spec {
    let k = -0.5 / max(sigma * sigma, EPSILON_TINY);
    let g_lo = exp(dist2.lo * k);
    let g_hi = exp(dist2.hi * k);
    let total = dot(g_lo, vec4f(1.0)) + dot(g_hi, vec4f(1.0));
    let scale = SPECTRAL_COUNT / max(total, EPSILON_FINE);
    return Spec(g_lo * scale, g_hi * scale);
}

const MIN_ABBE = 0.5;
const ROUGHNESS_SEED_OFFSET = vec2f(5.19, 12.73);
const DIFFUSE_SEED_OFFSET = vec2f(61.7, 17.3);

fn scatter_at(pos: vec3f, in_dir: vec3f, raw_normal: vec3f, mat: ColorStop, inside: bool, lambda: f32, seed: vec2f, allow_diffuse: bool, dispersion_soft: f32) -> Scatter {
    let n = select(raw_normal, -raw_normal, dot(in_dir, raw_normal) > 0.0);

    var ior = max(mat.ior, 1.0);
    if (lambda > 0.0 && mat.abbe > MIN_ABBE) {
        ior = max(cauchy_ior(ior, mat.abbe, lambda), 1.0);
    }
    let eta = select(1.0 / ior, ior, inside);

    let rough = clamp(mat.roughness, 0.0, 1.0);
    let n_rough = perturb_normal(n, rough * rough, seed + ROUGHNESS_SEED_OFFSET);

    let f = fresnel_schlick(dot(in_dir, n_rough), ior);

    var film = spec_splat(1.0);
    if (!inside && mat.film_strength > MATERIAL_EPSILON) {
        film = thin_film_tint(dot(-in_dir, film_normal(n_rough, pos, mat)), mat);
    }
    let transparency = clamp(mat.transparency, 0.0, 1.0);
    let spec = clamp(mat.reflectiveness, 0.0, 1.0);

    let p_reflect = clamp(mix(spec, 1.0, f), 0.0, 1.0);
    let rest = 1.0 - p_reflect;
    let p_transmit = rest * transparency;
    let p_diffuse = rest * (1.0 - transparency);

    var s: Scatter;
    s.local_share = select(p_diffuse, 0.0, allow_diffuse);
    s.disp_ang2 = spec_splat(0.0);

    let p_cont = p_reflect + p_transmit;
    let span = select(p_cont, 1.0, allow_diffuse);
    let scale = select(p_cont, 1.0, allow_diffuse);
    let r = hash12w(seed) * span;

    if (r < p_reflect) {
        s.dir = reflect(in_dir, n_rough);
        s.weight = spec_scale(spec_mul(spec_from_rgb(mix(mat.color, vec3f(1.0), f)), film), scale);
        s.kind = SCATTER_REFLECT;
        return s;
    }

    if (r < p_reflect + p_transmit) {
        let refr = refract_safe(in_dir, n_rough, eta);
        s.dir = refr.dir;
        if (dispersion_soft > 0.0 && lambda > 0.0 && mat.abbe > MIN_ABBE) {
            s.disp_ang2 = dispersion_angles2(in_dir, n_rough, mat, inside, s.dir);
        }
        s.weight = spec_scale(spec_from_rgb(mat.color), scale);
        s.kind = select(SCATTER_TRANSMIT, SCATTER_REFLECT, refr.tir);
        return s;
    }

    if (allow_diffuse && p_diffuse > MATERIAL_EPSILON) {
        s.dir = cosine_hemisphere_sample(n, seed + DIFFUSE_SEED_OFFSET);
        s.weight = spec_mul(spec_from_rgb(mat.color), film);
        s.kind = SCATTER_DIFFUSE;
        return s;
    }

    s.dir = in_dir;
    s.weight = spec_splat(0.0);
    s.kind = SCATTER_ABSORBED;
    return s;
}

fn detect_scene_transparency() {
    scene_has_transparency = u.has_transparency > 0.5 && part_on(PART_REFRACTION);
}

struct DispersionRecord {
    valid: bool,
    in_dir: vec3f,
    normal: vec3f,
    ior: f32,
    abbe: f32,
    inside: bool,
}

const RGB_WAVELENGTHS_UM = vec3f(0.61, 0.55, 0.465);

fn escape_sky(dir: vec3f, rec: DispersionRecord) -> vec3f {
    if (!rec.valid) {
        return sky_color(dir);
    }
    let lambdas = RGB_WAVELENGTHS_UM;
    var c = vec3f(0.0);
    for (var k = 0; k < 3; k++) {
        let ior_k = max(cauchy_ior(rec.ior, rec.abbe, lambdas[k]), 1.0);
        let r = refract_safe(rec.in_dir, rec.normal, select(1.0 / ior_k, ior_k, rec.inside));
        c[k] = sky_color(r.dir)[k];
    }
    return c;
}

const TINT_PROBES = 12;
const TINT_EXIT_BIAS = 0.003;
const TINT_MIN_TRANSMISSION = 0.01;

fn tint_beer(color: vec3f, thickness: f32) -> Spec {
    let sigma = -log(clamp(color, vec3f(TINT_MIN_TRANSMISSION), vec3f(1.0))) * max(u.approx_tint, 0.0);
    return spec_from_rgb(exp(-sigma * thickness));
}

const PATH_MAX_VERTICES = 16;
const PATH_TRANSPARENCY_FLOOR = 8;
const PATH_RR_START = 4;
const PATH_DEFAULT_INNER_STEPS = 64;
const MIN_INNER_STEPS = 4;
const MAX_INNER_STEPS = 512;
const PATH_MIN_THROUGHPUT = 0.002;
const SURFACE_EXIT_BIAS = 0.003;
const PHOTON_EXIT_BIAS = 0.004;
const EXIT_BIAS_EPS_SCALE = 2.0;
const RR_MIN_SURVIVAL = 0.05;
const MIN_LOCAL_SHARE = 0.001;
const HERO_WAVELENGTH_SEED_OFFSET = vec2f(19.31, 47.11);
const PATH_SEED_RATE_X = 27.31;
const PATH_SEED_RATE_Y = 45.17;
const PATH_DEPTH_SEED_STRIDE_X = 17.77;
const PATH_DEPTH_SEED_OFFSET_X = 3.1;
const PATH_DEPTH_SEED_STRIDE_Y = 41.13;
const PATH_DEPTH_SEED_OFFSET_Y = 7.7;
const DISPERSION_PICK_SEED_OFFSET = vec2f(3.71, 8.13);
const INDIRECT_SEED_OFFSET = vec2f(13.13, 71.71);
const RR_SEED_OFFSET = vec2f(59.3, 23.9);
var<private> g_primary_dist: f32 = 0.0;
var<private> g_primary_normal: vec3f = vec3f(0.0);
var<private> g_primary_slot: i32 = -1;
var<private> g_second_slot: i32 = -1;

const CACHE_HIT_BIT: u32 = 0x80000000u;
const CACHE_NORMAL_BIT: u32 = 0x40000000u;
const CACHE_STEPS_MASK: u32 = 0x3fffffffu;

struct CachedHit {
    valid: bool,
    hit: bool,
    has_normal: bool,
    dist: f32,
    steps: f32,
    normal: vec3f,
}

fn oct_project(n: vec3f) -> vec2f {
    var p = n.xy / (abs(n.x) + abs(n.y) + abs(n.z));
    if (n.z < 0.0) {
        p = (vec2f(1.0) - abs(p.yx)) * select(vec2f(-1.0), vec2f(1.0), p >= vec2f(0.0));
    }
    return p;
}

fn oct_unproject(f: vec2f) -> vec3f {
    var n = vec3f(f, 1.0 - abs(f.x) - abs(f.y));
    let t = max(-n.z, 0.0);
    n.x += select(t, -t, n.x >= 0.0);
    n.y += select(t, -t, n.y >= 0.0);
    return normalize(n);
}

fn oct_encode(n: vec3f) -> u32 {
    return pack2x16snorm(oct_project(n));
}

fn oct_decode(packed: u32) -> vec3f {
    return oct_unproject(unpack2x16snorm(packed));
}

fn hit_cache_on() -> bool {
    return g_primary_slot >= 0 || g_second_slot >= 0;
}

fn hit_cache_load() -> CachedHit {
    var h = CachedHit(false, false, false, 0.0, 0.0, vec3f(0.0));
    var e: vec4u;
    if (g_primary_slot >= 0) {
        e = adapt_stats[g_primary_slot].primary;
    } else if (g_second_slot >= 0) {
        e = adapt_stats[g_second_slot].second;
    } else {
        return h;
    }
    if (e.x != u32(u.primary_cache_key)) {
        return h;
    }
    h.valid = true;
    h.hit = (e.w & CACHE_HIT_BIT) != 0u;
    h.has_normal = (e.w & CACHE_NORMAL_BIT) != 0u;
    h.dist = bitcast<f32>(e.y);
    h.steps = f32(e.w & CACHE_STEPS_MASK);
    h.normal = oct_decode(e.z);
    return h;
}

fn hit_cache_store(hit: bool, dist: f32, steps: f32, normal: u32, has_normal: bool) {
    var flags = u32(max(steps, 0.0)) & CACHE_STEPS_MASK;
    if (hit) {
        flags |= CACHE_HIT_BIT;
    }
    if (has_normal) {
        flags |= CACHE_NORMAL_BIT;
    }
    let e = vec4u(u32(u.primary_cache_key), bitcast<u32>(dist), normal, flags);
    if (g_primary_slot >= 0) {
        adapt_stats[g_primary_slot].primary = e;
    } else if (g_second_slot >= 0) {
        adapt_stats[g_second_slot].second = e;
    }
}

struct FragOut {
    @location(0) color: vec4f,
    @location(1) depth: f32,
    @location(2) normal: vec4f,
}

fn frag_out(color: vec4f, dist: f32, normal: vec3f) -> FragOut {
    var out: FragOut;
    out.color = color;
    out.depth = dist;
    out.normal = vec4f(normal, select(0.0, 1.0, dist > 0.0));
    return out;
}

struct PathState {
    radiance: Spec,
    throughput: Spec,
    pos: vec3f,
    dir: vec3f,
    seed: vec2f,
    hero: f32,
    depth: i32,
    alive: bool,
    in_solid: bool,
    inner_steps: i32,
    lambda: f32,
    reflected: bool,
    disp: DispersionRecord,
    slab: bool,
    slab_sky: bool,
    slab_dir: vec3f,
    slab_color: vec3f,
}

struct PathSegment {
    hit_t: f32,
    hit_ok: bool,
    steps: f32,
}

override WF_DEFER: bool = false;
override WF_SURFACE_SPLIT: bool = false;
var<private> g_wf_normal: vec3f;
var<private> g_wf_mat: ColorStop;
var<private> g_wf_ao: f32 = 1.0;
var<private> g_wf_shadow_light: i32 = -1;
var<private> g_wf_shadow_w: Spec;
var<private> g_wf_indirect: bool = false;
var<private> g_wf_indirect_w: Spec;
var<private> g_wf_shade_pos: vec3f;
var<private> g_wf_shade_normal: vec3f;
var<private> g_shade_albedo: Spec;

fn path_hero(screen_pos: vec2f) -> f32 {
    return hash12w(screen_pos + HERO_WAVELENGTH_SEED_OFFSET) + u.mc_sample * GOLDEN_RATIO_FRACT;
}

fn path_begin(ray_origin: vec3f, ray_dir: vec3f, screen_pos: vec2f) -> PathState {
    var st: PathState;
    st.radiance = spec_splat(0.0);
    st.throughput = spec_splat(1.0);
    st.pos = ray_origin;
    st.dir = ray_dir;
    st.seed = screen_pos + vec2f(u.mc_sample * PATH_SEED_RATE_X, u.mc_sample * PATH_SEED_RATE_Y);
    st.hero = path_hero(screen_pos);
    st.depth = 0;
    st.alive = true;
    st.in_solid = false;
    st.inner_steps = PATH_DEFAULT_INNER_STEPS;
    st.lambda = 0.0;
    st.reflected = false;
    st.disp = DispersionRecord(false, vec3f(0.0), vec3f(0.0), 1.0, 0.0, false);
    st.slab = false;
    st.slab_sky = false;
    st.slab_dir = vec3f(0.0);
    st.slab_color = vec3f(1.0);
    return st;
}

fn path_max_depth() -> i32 {
    return clamp(i32(u.max_reflection_bounces) + PATH_TRANSPARENCY_FLOOR, 1, PATH_MAX_VERTICES);
}

fn path_seed(base_seed: vec2f, depth: i32) -> vec2f {
    return base_seed + vec2f(f32(depth) * PATH_DEPTH_SEED_STRIDE_X + PATH_DEPTH_SEED_OFFSET_X, f32(depth) * PATH_DEPTH_SEED_STRIDE_Y + PATH_DEPTH_SEED_OFFSET_Y);
}

fn path_enter(depth: i32) {
    g_coarse_march = depth > 0 && approx_on(APPROX_COARSE_SECONDARY);
    g_hot_src = select(HOT_SECONDARY, HOT_PRIMARY, depth == 0);
    if (depth >= 1) {
        g_primary_slot = -1;
    }
    if (depth != 1) {
        g_second_slot = -1;
    }
}

fn path_extend(st: PathState) -> PathSegment {
    path_enter(st.depth);
    var seg = PathSegment(0.0, false, 0.0);
    let primary = hit_cache_load();
    if (st.in_solid) {
        let ins = march_inside(st.pos, st.dir, st.inner_steps, INSIDE_STEP_BASE, u.max_dist);
        seg.hit_t = ins.dist;
        seg.hit_ok = ins.exited;
    } else if (primary.valid) {
        seg.hit_t = primary.dist;
        seg.hit_ok = primary.hit;
        seg.steps = primary.steps;
    } else {
        let m = march(st.pos, st.dir);
        seg.hit_t = m.dist;
        seg.hit_ok = m.hit;
        seg.steps = m.steps;
        if (!m.hit) {
            hit_cache_store(false, m.dist, m.steps, 0u, false);
        }
    }
    return seg;
}

fn path_normal(hit_pos: vec3f, hit_t: f32, seg_steps: f32, in_solid: bool) -> vec3f {
    let primary = hit_cache_load();
    if (primary.valid && primary.has_normal) {
        return primary.normal;
    }
    var normal = estimate_normal(hit_pos, hit_t);
    if (hit_cache_on() && !in_solid) {
        let packed = oct_encode(normal);
        normal = oct_decode(packed);
        hit_cache_store(true, hit_t, seg_steps, packed, true);
    }
    return normal;
}

fn path_needs_ao(depth: i32, reflected: bool) -> bool {
    return !approx_on(APPROX_SKY_AMBIENT) && !(depth == 0 && u.mc_enabled > 0.5 && part_on(PART_MC_INDIRECT)) && !reflected;
}

fn path_shade(st_in: PathState, seg: PathSegment) -> PathState {
    var st = st_in;
    let depth = st.depth;
    path_enter(depth);
    let seed = path_seed(st.seed, depth);
    let pos = st.pos;
    let dir = st.dir;
    let hit_t = seg.hit_t;
    let hit_ok = seg.hit_ok;
    let seg_steps = seg.steps;
    let in_solid = st.in_solid;

    var radiance = spec_splat(0.0);
    var throughput = st.throughput;
    var seg_len = select(min(u.max_dist, max(hit_t, 0.0)), hit_t, hit_ok);
    st.alive = false;

    var dots = DotsHit(vec3f(0.0), -1.0, vec3f(0.0), -1.0);
    if (!in_solid) {
        dots = particle_dots(pos, dir, seg_len, false);
        radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(dots.emit)));
        if (dots.hit_t >= 0.0) {
            seg_len = dots.hit_t;
        }
    }

    let vol = march_fog(pos, dir, seg_len, seed);
    radiance = spec_add(radiance, spec_mul(throughput, vol.color));
    throughput = spec_scale(throughput, vol.transmittance);

    let fft_vol = march_fft_cloud(pos, dir, seg_len, seed);
    radiance = spec_add(radiance, spec_mul(throughput, fft_vol.color));
    throughput = spec_scale(throughput, fft_vol.transmittance);
    st.throughput = throughput;

    if (dots.hit_t >= 0.0) {
        radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(dots.hit_color)));
        if (depth == 0) {
            g_primary_dist = dots.hit_t;
            g_primary_normal = -dir;
        }
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }

    if (st.slab) {
        st.slab = false;
        st.in_solid = false;
        if (!hit_ok) {
            st.radiance = spec_add(st.radiance, radiance);
        return st;
        }
        throughput = spec_mul(throughput, tint_beer(st.slab_color, hit_t));
        st.throughput = throughput;
        if (st.slab_sky) {
            radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(escape_sky(dir, st.disp))));
            st.radiance = spec_add(st.radiance, radiance);
        return st;
        }
        st.disp.valid = false;
        st.pos = pos + dir * hit_t + st.slab_dir * TINT_EXIT_BIAS;
        st.dir = st.slab_dir;
        st.depth = depth + 1;
        st.alive = true;
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }

    if (!hit_ok) {
        radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(escape_sky(dir, st.disp))));
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }
    if (spec_max(throughput) < PATH_MIN_THROUGHPUT) {
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }

    let hit_pos = pos + dir * hit_t;
    var normal: vec3f;
    var mat: ColorStop;
    if (WF_SURFACE_SPLIT) {
        normal = g_wf_normal;
        mat = g_wf_mat;
    } else {
        normal = path_normal(hit_pos, hit_t, seg_steps, in_solid);
        mat = apply_part_mask(hit_material(hit_pos).mat);
    }
    if (depth == 0) {
        g_primary_dist = hit_t;
        g_primary_normal = normal;
    }

    let soft = radians(0.5 * u.photon_dispersion_soft);
    var disp_weight = spec_splat(1.0);
    let cheap_disp = approx_on(APPROX_CHEAP_DISPERSION);
    if (st.lambda == 0.0 && mat.abbe > MIN_ABBE && !cheap_disp) {
        let pick = min(i32(hash12w(seed + DISPERSION_PICK_SEED_OFFSET) * SPECTRAL_COUNT), i32(SPECTRAL_COUNT) - 1);
        st.lambda = spec_lambda_um(pick);
        if (soft <= 0.0) {
            disp_weight = spec_collapse_mask(pick);
        }
    }

    let sc = scatter_at(hit_pos, dir, normal, mat, in_solid, st.lambda, seed, false, soft);

    if (sc.local_share > MIN_LOCAL_SHARE) {
        var ambient_light = spec_splat(AMBIENT_INTENSITY);
        var defer_indirect = false;
        if (approx_on(APPROX_SKY_AMBIENT)) {
            ambient_light = spec_from_rgb(sky_ambient(normal) * step_ao(seg_steps));
        } else if (depth == 0 && u.mc_enabled > 0.5 && part_on(PART_MC_INDIRECT)) {
            if (WF_DEFER) {
                ambient_light = spec_splat(0.0);
                defer_indirect = true;
            } else {
                ambient_light = indirect_light(hit_pos, normal, seed + INDIRECT_SEED_OFFSET);
            }
        } else if (!st.reflected) {
            if (WF_SURFACE_SPLIT) {
                ambient_light = spec_scale(ambient_light, g_wf_ao);
            } else {
                ambient_light = spec_scale(ambient_light, calc_ao(hit_pos, normal, hit_t));
            }
        }
        let lit = shade_local(hit_pos, dir, normal, mat, ambient_light, !st.reflected, seed);
        radiance = spec_add(radiance, spec_scale(spec_mul(throughput, lit), sc.local_share));
        if (WF_DEFER) {
            g_wf_shade_pos = hit_pos;
            g_wf_shade_normal = normal;
            if (g_wf_shadow_light >= 0) {
                g_wf_shadow_w = spec_scale(spec_mul(throughput, g_wf_shadow_w), sc.local_share);
            }
            if (defer_indirect) {
                g_wf_indirect = true;
                g_wf_indirect_w = spec_scale(spec_mul(throughput, g_shade_albedo), sc.local_share);
            }
        }
    }

    if (sc.kind == SCATTER_ABSORBED) {
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }
    if (sc.kind == SCATTER_REFLECT && !in_solid && !part_on(PART_REFLECTIONS)) {
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }
    if (spec_max(sc.disp_ang2) > 0.0) {
        disp_weight = dispersion_weights(sc.disp_ang2, soft);
    }

    st.disp.valid = sc.kind == SCATTER_TRANSMIT && cheap_disp && mat.abbe > MIN_ABBE;
    if (st.disp.valid) {
        st.disp = DispersionRecord(true, dir, normal, max(mat.ior, 1.0), mat.abbe, in_solid);
    }

    if (sc.kind == SCATTER_REFLECT && !in_solid && approx_on(APPROX_SKY_REFLECTIONS)) {
        throughput = spec_mul(throughput, spec_mul(disp_weight, sc.weight));
        st.throughput = throughput;
        radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(escape_sky(sc.dir, st.disp) * step_ao(seg_steps))));
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }

    let thin_glass = approx_on(APPROX_THIN_GLASS);
    let tint_approx = approx_on(APPROX_TINT);
    if (sc.kind == SCATTER_TRANSMIT && !in_solid && (thin_glass || tint_approx)) {
        if (!tint_approx) {
            throughput = spec_mul(throughput, spec_mul(disp_weight, sc.weight));
            st.throughput = throughput;
            radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(escape_sky(sc.dir, st.disp))));
            st.radiance = spec_add(st.radiance, radiance);
        return st;
        }
        throughput = spec_mul(throughput, disp_weight);
        st.throughput = throughput;
        st.slab = true;
        st.slab_sky = thin_glass;
        st.slab_dir = dir;
        st.slab_color = mat.color;
        st.in_solid = true;
        st.inner_steps = TINT_PROBES;
        st.pos = hit_pos + sc.dir * max(SURFACE_EXIT_BIAS, EXIT_BIAS_EPS_SCALE * march_epsilon(hit_t));
        st.dir = sc.dir;
        st.depth = depth + 1;
        st.alive = true;
        st.radiance = spec_add(st.radiance, radiance);
        return st;
    }

    throughput = spec_mul(throughput, spec_mul(disp_weight, sc.weight));
    st.reflected = st.reflected || sc.kind == SCATTER_REFLECT;

    if (sc.kind == SCATTER_TRANSMIT) {
        st.in_solid = !in_solid;
        if (st.in_solid) {
            st.inner_steps = clamp(i32(mat.inner_max_steps), MIN_INNER_STEPS, MAX_INNER_STEPS);
        }
    }

    let bias = max(SURFACE_EXIT_BIAS, EXIT_BIAS_EPS_SCALE * march_epsilon(hit_t));
    st.pos = hit_pos + sc.dir * bias;
    st.dir = sc.dir;

    if (depth >= PATH_RR_START) {
        let survive = clamp(spec_max(throughput), RR_MIN_SURVIVAL, 1.0);
        if (hash12w(seed + RR_SEED_OFFSET) > survive) {
            st.throughput = throughput;
            st.radiance = spec_add(st.radiance, radiance);
        return st;
        }
        throughput = spec_scale(throughput, 1.0 / survive);
    }
    let rough = clamp(mat.roughness, 0.0, 1.0);
    let mirror = depth == 0 && !in_solid && sc.kind == SCATTER_REFLECT && rough * rough <= MIN_ROUGHNESS;
    g_second_slot = select(-1, g_primary_slot, mirror);
    st.throughput = throughput;
    st.depth = depth + 1;
    st.alive = true;
    st.radiance = spec_add(st.radiance, radiance);
        return st;
}

fn trace_path(ray_origin: vec3f, ray_dir: vec3f, screen_pos: vec2f) -> vec3f {
    var st = path_begin(ray_origin, ray_dir, screen_pos);
    spectral_setup(st.hero);
    let max_depth = path_max_depth();
    for (var depth = 0; depth < max_depth; depth++) {
        st = path_shade(st, path_extend(st));
        if (!st.alive) {
            break;
        }
    }
    return gamut_fit(spec_to_rgb(st.radiance));
}

fn undo_tonemap(color: vec3f) -> vec3f {
    let c = clamp(color, vec3f(0.0), vec3f(1.0));
    return c / max(vec3f(1.0) - c, vec3f(1.0 / UNORM8_MAX));
}

const FLAT_SECTION = 0;
const FLAT_ESCAPE = 1;
const FLAT_DISTANCE = 2;
const FLAT_ORBIT = 3;
const FLAT_INTERIOR_RADIUS = 1;
const FLAT_INTERIOR_DARK = 2;
const FLAT_HALO_PIXELS = 24.0;
const FLAT_MIN_BAILOUT = 1.0001;
const FLAT_MAX_EXTRA_ITERS = 256;
const FLAT_MAX_SLICES = 32;
const FLAT_DISTANCE_FLOOR_PX = 0.01;
const FLAT_ESCAPE_HEIGHT = 0.1;
const FLAT_DISTANCE_HEIGHT = 0.25;
const FLAT_SECTION_RIM = 0.5;
const FLAT_RELIEF_MAX_SLOPE = 4.0;
const FLAT_LIGHT_COS = 0.70710678;
const FLAT_LIGHT_SIN = 0.70710678;
const FLAT_DEG_TO_RAD = PI / 180.0;
const FLAT_CONTOUR_WIDTH_PX = 1.0;
const FLAT_SLAB_FADE = 0.6;
const FLAT_SLAB_MIN_TRANSMIT = 0.004;
const FLAT_JITTER_R3 = vec3f(0.81917251, 0.67104360, 0.54970047);

struct FlatOrbit {
    de: f32,
    trap: f32,
    escape: f32,
    min_r: f32,
}

fn flat_escape_at(it: f32, r_lo: f32, r_hi: f32, bail: f32) -> f32 {
    let lo = log(max(r_lo, EPSILON_FINE));
    let hi = log(max(r_hi, EPSILON_FINE));
    return max(it + clamp((log(bail) - lo) / max(hi - lo, EPSILON_FINE), 0.0, 1.0), 0.0);
}

fn flat_orbit(local: vec3f, slot: i32) -> FlatOrbit {
    let base_code = instance_code(slot);
    let base_p = instance_params(slot);
    let mixed = u.instances[slot].mixin_count > 0.5;
    let mixin_count = select(0, min(i32(u.instances[slot].mixin_count), MAX_MIXINS), mixed);
    let plain_n = max(eval_iterations(base_code, base_p), 0);
    let base_n = select(plain_n, max(i32(u.instances[slot].hybrid_base_iters), 0), mixed);
    let total = select(plain_n, max(i32(u.instances[slot].hybrid_total_iters), 0), mixed);
    let cycle_len = hybrid_cycle_len(slot, base_n, mixin_count);
    let extra = clamp(i32(u.flat_extra_iters + 0.5), 0, FLAT_MAX_EXTRA_ITERS);
    let bail = max(u.flat_bailout, FLAT_MIN_BAILOUT);

    let trap_spec = orbit_trap(slot);
    var trap = orbit_trap_begin(trap_spec);
    var carry = IterCarry(local, 1.0);
    var kept = carry;
    var escape_bail = -1.0;
    var escape_bulb = -1.0;
    var froze = false;
    var r_prev = length(local);
    var min_r = r_prev;
    for (var it = 0; it < total + extra; it++) {
        let st = hybrid_step(slot, it, base_n, cycle_len, mixin_count, base_code, base_p);
        let z_prev = carry.z;
        if (st.have) {
            g_image_slot = st.image_slot;
            carry = eval_step(st.code, carry, local, st.p);
        }
        if (it < total) {
            trap = orbit_trap_update(trap, trap_spec, carry.z, z_prev, it);
            kept = carry;
        }
        let r = length(carry.z);
        froze = froze || (st.have && r > BULB_BAILOUT && all(carry.z == z_prev));
        if (escape_bulb < 0.0 && r > BULB_BAILOUT) {
            escape_bulb = flat_escape_at(f32(it), r_prev, r, BULB_BAILOUT);
        }
        if (escape_bail < 0.0 && r > bail) {
            escape_bail = flat_escape_at(f32(it), r_prev, r, bail);
        }
        min_r = min(min_r, r);
        r_prev = r;
    }
    g_image_slot = slot * IMAGE_SLOTS_PER_FRACTAL;
    return FlatOrbit(eval_finalize(base_code, kept), orbit_trap_finish(trap, trap_spec, total), select(escape_bail, escape_bulb, froze), min_r);
}

fn flat_instance(pos: vec3f, slot: i32) -> FlatOrbit {
    if (instance_ft_hidden(slot)) {
        return FlatOrbit(NO_SURFACE_DE, 0.0, -1.0, 0.0);
    }
    var o = flat_orbit(instance_local(pos, slot), slot);
    o.de *= instance_de_factor(slot);
    return o;
}

struct FlatPoint {
    de: f32,
    mat: ColorStop,
    slot: i32,
    orbit: FlatOrbit,
}

fn flat_point(pos: vec3f) -> FlatPoint {
    let wp = warp_domain(pos);
    let count = max(i32(u.instance_count), 1);
    var d = empty_scene_de();
    var first = true;
    var mat = default_material();
    var slot = -1;
    var orbit = FlatOrbit(NO_SURFACE_DE, 0.0, -1.0, 0.0);
    for (var i = 0; i < count; i++) {
        if (instance_hidden(i)) {
            continue;
        }
        let o = flat_instance(wp.p, i);
        let mat_i = sample_gradient(i, orbit_trap_to_strip(i, o.trap));
        if (first) {
            d = o.de;
            mat = mat_i;
            slot = i;
            orbit = o;
            first = false;
            continue;
        }
        let c = combine_de(i32(u.instances[i].combine_mode + 0.5), d, o.de, u.instances[i].blend_k);
        mat = mix_material(mat, mat_i, c.y);
        if (c.y < 0.5) {
            slot = i;
            orbit = o;
        }
        d = c.x;
    }
    let ps = particles_hit_material(pos, SurfacePoint(mat, select(d * wp.de_scale, d, first)), !first);
    return FlatPoint(apply_carves(pos, ps.sp.de), ps.sp.mat, slot, orbit);
}

fn flat_strip(slot: i32, v: f32) -> f32 {
    if (slot < 0) {
        return 0.0;
    }
    return orbit_trap_to_strip(slot, v);
}

fn flat_gradient(slot: i32, t: f32) -> vec3f {
    if (slot < 0) {
        return default_material().color;
    }
    return sample_gradient(slot, t).color;
}

fn flat_band(v: f32) -> f32 {
    return fract(v * u.flat_band_density + u.flat_band_offset);
}

fn flat_solid(de: f32, px: f32) -> f32 {
    return 1.0 - smoothstep(0.0, px, de);
}

fn flat_octaves(de: f32, px: f32) -> f32 {
    return log2(max(de, px * FLAT_DISTANCE_FLOOR_PX) / px);
}

fn flat_interior_color(fp: FlatPoint) -> vec3f {
    let mode = i32(u.flat_interior + 0.5);
    if (mode == FLAT_INTERIOR_RADIUS) {
        return flat_gradient(fp.slot, flat_band(fp.orbit.min_r));
    }
    if (mode == FLAT_INTERIOR_DARK) {
        return vec3f(0.0);
    }
    return fp.mat.color;
}

struct FlatShade {
    interior: vec3f,
    exterior: vec3f,
    inside: f32,
    height: f32,
}

fn flat_shade(fp: FlatPoint, px: f32) -> FlatShade {
    let mode = i32(u.flat_coloring + 0.5);
    let trap_t = flat_strip(fp.slot, fp.orbit.trap);
    let solid = flat_solid(fp.de, px);
    var s = FlatShade(flat_interior_color(fp), vec3f(0.0), solid, solid * trap_t);
    if (mode == FLAT_ESCAPE) {
        let escaped = fp.orbit.escape >= 0.0;
        s.inside = select(1.0, 0.0, escaped);
        s.exterior = flat_gradient(fp.slot, flat_band(fp.orbit.escape));
        s.height = select(trap_t, fp.orbit.escape * FLAT_ESCAPE_HEIGHT, escaped);
    } else if (mode == FLAT_DISTANCE) {
        let v = flat_octaves(fp.de, px);
        s.exterior = flat_gradient(fp.slot, flat_band(v));
        s.height = mix(-v * FLAT_DISTANCE_HEIGHT, trap_t, solid);
    } else if (mode == FLAT_ORBIT) {
        s.interior = fp.mat.color;
        s.inside = 1.0;
        s.height = trap_t;
    } else {
        let halo = exp(-max(fp.de, 0.0) / (px * FLAT_HALO_PIXELS));
        s.exterior = fp.mat.color * halo * u.flat_halo;
        s.height = solid * (FLAT_SECTION_RIM + FLAT_SECTION_RIM * trap_t);
    }
    return s;
}

fn flat_jitter() -> vec3f {
    if (u.flat_samples < 1.5) {
        return vec3f(0.0);
    }
    return fract(vec3f(0.5) + u.mc_sample * FLAT_JITTER_R3) - vec3f(0.5);
}

struct FlatComposite {
    color: vec3f,
    height: f32,
}

fn flat_composite(plane_pos: vec3f, front: FlatShade, px: f32, jitter: f32) -> FlatComposite {
    let slices = clamp(i32(u.flat_slab_slices + 0.5), 1, FLAT_MAX_SLICES);
    if (slices == 1) {
        return FlatComposite(mix(front.exterior, front.interior, front.inside), front.height);
    }
    let depth = max(u.flat_slab_depth, 0.0) * u.slice_zoom;
    let spacing = depth / f32(slices - 1);
    let opacity = clamp(u.flat_slab_opacity, 0.0, 1.0);
    var a = front.inside * opacity;
    var acc = front.interior * a;
    var near = a * depth;
    var trans = 1.0 - a;
    for (var k = 1; k < slices; k++) {
        if (trans < FLAT_SLAB_MIN_TRANSMIT) {
            break;
        }
        let z = clamp((f32(k) + jitter) * spacing, 0.0, depth);
        let fp = flat_point(plane_pos + u.camera_forward * z);
        a = flat_solid(fp.de, px) * opacity * trans;
        acc += flat_interior_color(fp) * a * (1.0 - FLAT_SLAB_FADE * z / max(depth, EPSILON_TINY));
        near += a * (depth - z);
        trans *= 1.0 - flat_solid(fp.de, px) * opacity;
    }
    return FlatComposite(acc + front.exterior * trans, near / px);
}

fn flat_relief_shade(height: f32) -> f32 {
    let g = clamp(vec2f(dpdxFine(height), dpdyFine(height)) * u.flat_relief, vec2f(-FLAT_RELIEF_MAX_SLOPE), vec2f(FLAT_RELIEF_MAX_SLOPE));
    let n = normalize(vec3f(-g.x, g.y, 1.0));
    let angle = u.flat_light_angle * FLAT_DEG_TO_RAD;
    let l = vec3f(cos(angle) * FLAT_LIGHT_COS, sin(angle) * FLAT_LIGHT_COS, FLAT_LIGHT_SIN);
    return max(dot(n, l), 0.0) / FLAT_LIGHT_SIN;
}

fn flat_contour_line(de: f32, px: f32) -> f32 {
    let v = flat_octaves(de, px) * u.flat_contour_density;
    let w = max(fwidth(v), EPSILON_FINE) * FLAT_CONTOUR_WIDTH_PX;
    return (1.0 - smoothstep(0.0, w, abs(fract(v + 0.5) - 0.5))) * (1.0 - flat_solid(de, px));
}

@fragment
fn fs_slice(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let pixel_uv = 2.0 / max(u.resolution.y, 1.0);
    let jitter = flat_jitter();
    let uv = vec2f(in.uv.x * aspect, in.uv.y) + jitter.xy * pixel_uv;
    let plane_pos = u.camera_pos + (uv.x * u.camera_right + uv.y * u.camera_up) * u.slice_zoom;
    let px = max(u.slice_zoom * pixel_uv, EPSILON_TINY);

    let front = flat_point(plane_pos);
    let shade = flat_shade(front, px);
    let image = flat_composite(plane_pos, shade, px, jitter.z);
    let relief = flat_relief_shade(image.height);
    let contour = flat_contour_line(front.de, px);
    let color = image.color * relief * (1.0 - clamp(u.flat_contours, 0.0, 1.0) * contour);
    return frag_out(vec4f(undo_tonemap(color), 0.0), 0.0, vec3f(0.0));
}

const SIMPLE_ALBEDO = vec3f(0.72, 0.72, 0.73);
const SIMPLE_AMBIENT = 0.18;
const SIMPLE_BACKGROUND = vec3f(0.10, 0.11, 0.13);
const SIMPLE_DEPTH_CUE = 0.55;
const SIMPLE_KEY_UP = 0.45;
const SIMPLE_KEY_LEFT = 0.35;

fn shade_lite(hit_pos: vec3f, dir: vec3f, normal: vec3f, t: f32) -> vec3f {
    let mat = apply_part_mask(hit_material(hit_pos).mat);
    let spec_power = mix(SPEC_POWER_MIN, SPEC_POWER_MAX, clamp(mat.glossiness, 0.0, 1.0));
    let fresnel = fresnel_schlick(dot(dir, normal), max(mat.ior, 1.0));
    var diffuse = vec3f(AMBIENT_INTENSITY * calc_ao(hit_pos, normal, t));
    var specular = vec3f(0.0);
    let light_count = total_light_count();
    for (var i = 0; i < light_count; i++) {
        let ls = light_sample(u.lights[i], hit_pos);
        let ndotl = max(dot(normal, ls.dir), 0.0);
        if (ndotl <= 0.0) {
            continue;
        }
        diffuse += ls.color * ndotl;
        if (part_on(PART_SPECULAR)) {
            let half_dir = normalize(ls.dir - dir);
            specular += ls.color * pow(max(dot(normal, half_dir), 0.0), spec_power) * mat.glossiness;
        }
    }
    return (1.0 - fresnel) * (mat.color * diffuse + specular);
}

fn render_lite(dir: vec3f) -> FragOut {
    let m = march(u.camera_pos, dir);
    let dots = particle_dots(u.camera_pos, dir, select(min(u.max_dist, max(m.dist, 0.0)), m.dist, m.hit), false);
    if (dots.hit_t >= 0.0) {
        return frag_out(vec4f(dots.emit + dots.hit_color, 0.0), dots.hit_t, -dir);
    }
    if (!m.hit) {
        return frag_out(vec4f(dots.emit + sky_color(dir), 0.0), 0.0, vec3f(0.0));
    }
    let hit_pos = u.camera_pos + dir * m.dist;
    let normal = estimate_normal(hit_pos, m.dist);
    return frag_out(vec4f(dots.emit + shade_lite(hit_pos, dir, normal, m.dist), 0.0), m.dist, normal);
}

const HOTSPOT_COOL = vec3f(0.0, 0.3, 1.0);
const HOTSPOT_WARM = vec3f(1.0, 0.8, 0.0);
const HOTSPOT_HOT = vec3f(1.0, 0.0, 0.0);
const HOTSPOT_WARM_AT = 0.33;
const HOTSPOT_HOT_AT = 0.66;
const HOTSPOT_BLEND = 0.2;
const HOTSPOT_WARM_GLOW = 0.5;
const HOTSPOT_GAIN = 2.0;

// Cost palette from Inigo Quilez, "Robust Binary-Search based intersection for SDFs" (iq/2018-2022).
fn hotspot_palette(h: f32) -> vec3f {
    var col = HOTSPOT_COOL;
    col = mix(col, HOTSPOT_WARM, smoothstep(HOTSPOT_WARM_AT - HOTSPOT_BLEND, HOTSPOT_WARM_AT + HOTSPOT_BLEND, h));
    col = mix(col, HOTSPOT_HOT, smoothstep(HOTSPOT_HOT_AT - HOTSPOT_BLEND, HOTSPOT_HOT_AT + HOTSPOT_BLEND, h));
    col.y += HOTSPOT_WARM_GLOW * (1.0 - smoothstep(0.0, HOTSPOT_BLEND, abs(h - HOTSPOT_WARM_AT)));
    return col * (0.5 + 0.5 * h);
}

fn hotspot_color(amount: f32) -> vec3f {
    return sqrt(clamp(hotspot_palette(clamp(amount, 0.0, 1.0)) * HOTSPOT_GAIN, vec3f(0.0), vec3f(1.0)));
}

fn hotspot_cost_color() -> vec3f {
    return undo_tonemap(hotspot_color(g_hot_evals / max(u.hotspot_scale, 1.0)));
}

fn render_hotspots(dir: vec3f) -> FragOut {
    g_hot_src = HOT_PRIMARY;
    let m = march(u.camera_pos, dir);
    return frag_out(vec4f(hotspot_cost_color(), 0.0), select(0.0, m.dist, m.hit), select(vec3f(0.0), -dir, m.hit));
}

fn simple_geometry(dir: vec3f, m: MarchResult) -> FragOut {
    if (!m.hit) {
        return frag_out(vec4f(undo_tonemap(SIMPLE_BACKGROUND), 0.0), 0.0, vec3f(0.0));
    }

    let hit_pos = u.camera_pos + dir * m.dist;
    let normal = estimate_normal(hit_pos, m.dist);

    let key_dir = normalize(-dir + u.camera_up * SIMPLE_KEY_UP - u.camera_right * SIMPLE_KEY_LEFT);
    let lambert = max(dot(normal, key_dir), 0.0);
    let shade = SIMPLE_AMBIENT + (1.0 - SIMPLE_AMBIENT) * lambert;

    let depth = clamp(m.dist / max(u.max_dist, EPSILON), 0.0, 1.0);
    let color = mix(SIMPLE_ALBEDO * shade, SIMPLE_BACKGROUND, depth * SIMPLE_DEPTH_CUE);

    return frag_out(vec4f(undo_tonemap(color), 0.0), m.dist, normal);
}

fn render_overstep(dir: vec3f) -> FragOut {
    g_overstep_watch = true;
    let m = march(u.camera_pos, dir);
    g_overstep_watch = false;
    var out = simple_geometry(dir, m);
    if (g_overstep_count > 0.0) {
        out.color = vec4f(undo_tonemap(hotspot_color(g_overstep_worst / max(u.overstep_scale, EPSILON))), 0.0);
    }
    return out;
}

@fragment
fn fs_simple(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

    if (!part_on(PART_OVERSTEP)) {
        return render_overstep(dir);
    }
    if (!part_on(PART_HOTSPOTS)) {
        return render_hotspots(dir);
    }
    if (part_on(PART_GEOMETRY_ONLY)) {
        return render_lite(dir);
    }

    return simple_geometry(dir, march(u.camera_pos, dir));
}

const SELECT_ID_NONE = 0;
const SELECT_ID_FRACTAL = 1;
const SELECT_ID_LIGHT = 11;
const SELECT_ID_FOG = 21;
const SELECT_ID_WARP = 31;
const SELECT_ID_PARTICLES = 41;

const SELECT_HANDLE_PX = 10.0;
const SELECT_GLOBAL_LIGHT_REACH = 2.4;
const SELECT_MIN_RAY_COMPONENT = 1e-8;

fn select_handle_radius(depth: f32) -> f32 {
    return max(depth, EPSILON) * SELECT_HANDLE_PX * 2.0 / max(u.resolution.y, 1.0);
}

fn select_handle_hit(origin: vec3f, dir: vec3f, centre: vec3f) -> f32 {
    let rel = centre - origin;
    let along = dot(rel, dir);
    if (along <= 0.0) {
        return -1.0;
    }
    let lateral = length(rel - dir * along);
    if (lateral > select_handle_radius(dot(rel, u.camera_forward))) {
        return -1.0;
    }
    return along;
}

fn select_sphere_entry(origin: vec3f, dir: vec3f, centre: vec3f, radius: f32) -> f32 {
    let oc = origin - centre;
    let b = dot(oc, dir);
    let c = dot(oc, oc) - radius * radius;
    if (c < 0.0) {
        return -1.0;
    }
    let disc = b * b - c;
    if (disc < 0.0) {
        return -1.0;
    }
    let t = -b - sqrt(disc);
    if (t < 0.0) {
        return -1.0;
    }
    return t;
}

fn select_box_entry(origin: vec3f, dir: vec3f, w: Warp) -> f32 {
    let inv_frame = transpose(warp_frame(w));
    let o = inv_frame * (origin - w.center);
    let d = inv_frame * dir;
    let e = max(w.extent, vec3f(WARP_MIN_EXTENT));
    let inv_d = 1.0 / select(d, vec3f(SELECT_MIN_RAY_COMPONENT), abs(d) < vec3f(SELECT_MIN_RAY_COMPONENT));
    let ta = (-e - o) * inv_d;
    let tb = (e - o) * inv_d;
    let t0 = min(ta, tb);
    let t1 = max(ta, tb);
    let enter = max(max(t0.x, t0.y), t0.z);
    let exit = min(min(t1.x, t1.y), t1.z);
    if (enter < 0.0 || exit < enter) {
        return -1.0;
    }
    return enter;
}

@group(5) @binding(0) var select_depth: texture_2d<f32>;

@fragment
fn fs_select(in: VertexOut) -> @location(0) vec4f {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);
    let origin = u.camera_pos;

    var best_t = INFINITE_DISTANCE;
    var best_id = SELECT_ID_NONE;

    let depth_last = vec2i(textureDimensions(select_depth)) - vec2i(1);
    let stored = textureLoad(select_depth, min(vec2i(in.clip_pos.xy), depth_last), 0).r;
    var hit = stored > 0.0;
    var hit_t = stored;
    if (stored < 0.0) {
        let m = march(origin, dir);
        hit = m.hit;
        hit_t = m.dist;
    }
    if (hit) {
        let wp = warp_domain(origin + dir * hit_t);
        var nearest_de = INFINITE_DISTANCE;
        var nearest_i = 0;
        let count = max(i32(u.instance_count), 1);
        for (var i = 0; i < count; i++) {
            if (instance_hidden(i)) {
                continue;
            }
            let di = instance_de_trap_ft(wp.p, i).x;
            if (di < nearest_de) {
                nearest_de = di;
                nearest_i = i;
            }
        }
        best_t = hit_t;
        best_id = SELECT_ID_FRACTAL + nearest_i;
        let lit = particles_nearest_lit(origin + dir * hit_t);
        if (lit.y >= 0.0 && lit.x < nearest_de * wp.de_scale) {
            best_id = SELECT_ID_PARTICLES + i32(lit.y);
        }
    }

    let dots = particle_dots(origin, dir, select(u.max_dist, best_t, hit), true);
    if (dots.hit_t >= 0.0 && dots.hit_t < best_t) {
        best_t = dots.hit_t;
        best_id = SELECT_ID_PARTICLES + i32(dots.hit_sys);
    }
    for (var s = 0; s < MAX_PARTICLE_SYSTEMS; s++) {
        if (u32(u.particle_systems[s].mode + 0.5) == PARTICLE_MODE_OFF) {
            continue;
        }
        let t = select_handle_hit(origin, dir, u.particle_systems[s].center);
        if (t >= 0.0 && t < best_t) {
            best_t = t;
            best_id = SELECT_ID_PARTICLES + s;
        }
    }

    for (var i = 0; i < i32(u.light_count); i++) {
        let light = u.lights[i];
        var centre = light.position_or_direction;
        if (i32(light.light_type + 0.5) == LIGHT_GLOBAL) {
            let aim = light.position_or_direction;
            let len = length(aim);
            centre = select(vec3f(0.0, -1.0, 0.0), aim / len, len > EPSILON_FINE) * SELECT_GLOBAL_LIGHT_REACH;
        }
        let t = select_handle_hit(origin, dir, centre);
        if (t >= 0.0 && t < best_t) {
            best_t = t;
            best_id = SELECT_ID_LIGHT + i;
        }
    }

    if (best_id == SELECT_ID_NONE) {
        for (var i = 0; i < i32(u.fog_count); i++) {
            let fog = u.fog_emitters[i];
            let t = select_sphere_entry(origin, dir, fog.position, max(fog.radius, EPSILON));
            if (t >= 0.0 && t < best_t) {
                best_t = t;
                best_id = SELECT_ID_FOG + i;
            }
        }
        for (var i = 0; i < i32(u.warp_count); i++) {
            let w = u.warps[i];
            let rk = i32(w.region_kind + 0.5);
            var t = -1.0;
            if (rk == WARP_REGION_SPHERE) {
                t = select_sphere_entry(origin, dir, w.center, max(w.extent.x, WARP_MIN_EXTENT));
            } else if (rk == WARP_REGION_BOX) {
                t = select_box_entry(origin, dir, w);
            } else {
                t = select_handle_hit(origin, dir, w.center);
            }
            if (t >= 0.0 && t < best_t) {
                best_t = t;
                best_id = SELECT_ID_WARP + i;
            }
        }
    }

    return vec4f(f32(best_id) / UNORM8_MAX, 0.0, 0.0, 1.0);
}

fn sample_unit_disk(seed: vec2f) -> vec2f {
    let r = sqrt(hash12(seed));
    let theta = hash12w(seed + DISK_ANGLE_SEED_OFFSET) * TAU;
    return vec2f(r * cos(theta), r * sin(theta));
}

const DOF_SAMPLES_FAST = 8;
const DOF_SAMPLES_HQ = 32;
const DOF_FALLOFF_PER_APERTURE = 4.0;
const DOF_MIN_FALLOFF = 0.05;
const DOF_MIN_APERTURE = 0.0001;
const MC_SEED_RATE_X = 91.73;
const MC_SEED_RATE_Y = 57.31;
const DOF_LENS_SEED_STRIDE_X = 91.37;
const DOF_LENS_SEED_STRIDE_Y = 51.91;
const DISK_ANGLE_SEED_OFFSET = vec2f(17.17, 71.71);

fn dof_aperture(hit_t: f32, focus_t: f32) -> f32 {
    let half_range = max(u.focus_range, 0.0) * 0.5;
    let falloff = max(u.aperture * DOF_FALLOFF_PER_APERTURE, DOF_MIN_FALLOFF);
    return u.aperture * smoothstep(half_range, half_range + falloff, abs(hit_t - focus_t));
}

fn dof_coc_px(eff_aperture: f32, hit_t: f32, focus_t: f32) -> f32 {
    let world_radius = eff_aperture * abs(hit_t - focus_t) / max(focus_t, EPSILON);
    let px_per_world_unit = u.resolution.y / (2.0 * length(u.camera_up) * max(hit_t, EPSILON));
    return world_radius * px_per_world_unit;
}

struct PixelState {
    stats: vec4f,
    primary: vec4u,
    second: vec4u,
}

@group(5) @binding(1) var<storage, read_write> adapt_stats: array<PixelState>;

const ADAPT_DARK_FLOOR = 0.05;
const ADAPT_MIN_VARIANCE_SAMPLES = 2.0;

fn adapt_update(stats_in: vec4f, color: vec3f) -> vec4f {
    let l = dot(color / (color + vec3f(1.0)), LUMA_WEIGHTS);
    var stats = stats_in + vec4f(l, l * l, 1.0, 0.0);
    if (stats.z >= max(u.adapt_min_samples, ADAPT_MIN_VARIANCE_SAMPLES)) {
        let mean = stats.x / stats.z;
        let variance = max(stats.y / stats.z - mean * mean, 0.0);
        let err = sqrt(variance / stats.z);
        stats.w = select(0.0, 1.0, err <= u.adapt_threshold * (mean + ADAPT_DARK_FLOOR));
    }
    return stats;
}

@fragment
fn fs_main(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

    let row_width = u32(max(u.adapt_row_width, 0.0));
    let adapt_idx = u32(in.clip_pos.y) * row_width + u32(in.clip_pos.x);
    let pixel_ok = u32(in.clip_pos.x) < row_width && adapt_idx < arrayLength(&adapt_stats);
    let adapt = u.adapt_enabled > 0.5 && u.mc_enabled > 0.5 && pixel_ok;
    var stats = vec4f(0.0);
    if (adapt && u.mc_sample > 0.5) {
        stats = adapt_stats[adapt_idx].stats;
        if (stats.w > 0.5) {
            discard;
        }
    }
    if (pixel_ok && u.primary_cache_key > 0.5) {
        g_primary_slot = i32(adapt_idx);
    }

    detect_scene_transparency();

    var color: vec3f;
    var samples = 1;
    var focus_point = vec3f(0.0);
    var focus_t = 0.0;
    var eff_aperture = 0.0;
    var coc_px = 0.0;
    var post_blur = false;

    if (u.dof_enabled > 0.5 && u.aperture > DOF_MIN_APERTURE && part_on(PART_DEPTH_OF_FIELD)) {
        let hq = u.high_quality > 0.5;
        focus_t = u.focus_distance / max(dot(dir, u.camera_forward), EPSILON);
        focus_point = u.camera_pos + dir * focus_t;

        if (u.mc_enabled < 0.5 && !hq) {
            post_blur = true;
        } else {
            let cached = hit_cache_load();
            var probe_t = select(u.max_dist, cached.dist, cached.hit);
            if (!cached.valid) {
                let hot_prev = hot_enter(HOT_DOF);
                let probe = march(u.camera_pos, dir);
                g_hot_src = hot_prev;
                probe_t = select(u.max_dist, probe.dist, probe.hit);
                hit_cache_store(probe.hit, probe.dist, probe.steps, 0u, false);
            }
            eff_aperture = dof_aperture(probe_t, focus_t);
            if (eff_aperture > DOF_MIN_APERTURE) {
                samples = mc_inner_count(select(DOF_SAMPLES_FAST, DOF_SAMPLES_HQ, hq));
            }
        }
    }

    let base_seed = in.clip_pos.xy + vec2f(u.mc_sample * MC_SEED_RATE_X, u.mc_sample * MC_SEED_RATE_Y);

    var accum = vec3f(0.0);
    for (var s = 0; s < samples; s++) {
        var sample_origin = u.camera_pos;
        var sample_dir = dir;
        var seed = base_seed;
        if (eff_aperture > DOF_MIN_APERTURE && coc_px <= 0.0) {
            g_primary_slot = -1;
            seed = base_seed + vec2f(f32(s) * DOF_LENS_SEED_STRIDE_X, f32(s) * DOF_LENS_SEED_STRIDE_Y);
            let disk = sample_unit_disk(seed) * eff_aperture;
            sample_origin = u.camera_pos + u.camera_right * disk.x + u.camera_up * disk.y;
            sample_dir = normalize(focus_point - sample_origin);
        }
        accum += trace_path(sample_origin, sample_dir, seed);
    }
    color = accum / f32(samples);

    if (!part_on(PART_HOTSPOTS)) {
        return frag_out(vec4f(hotspot_cost_color(), 0.0), g_primary_dist, g_primary_normal);
    }

    if (post_blur) {
        let hit_t = select(u.max_dist, g_primary_dist, g_primary_dist > 0.0);
        let blur_aperture = dof_aperture(hit_t, focus_t);
        if (blur_aperture > DOF_MIN_APERTURE) {
            coc_px = dof_coc_px(blur_aperture, hit_t, focus_t);
        }
    }

    if (adapt) {
        adapt_stats[adapt_idx].stats = adapt_update(stats, color);
    }

    return frag_out(vec4f(color, coc_px), g_primary_dist, g_primary_normal);
}

struct AovOut {
    @location(0) albedo: vec4f,
    @location(1) normal: vec4f,
}

fn aov_albedo(mat: ColorStop) -> vec3f {
    let specular = clamp(max(mat.reflectiveness, mat.transparency), 0.0, 1.0);
    return clamp(mix(mat.color, vec3f(1.0), specular), vec3f(0.0), vec3f(1.0));
}

@fragment
fn fs_aov(in: VertexOut) -> AovOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

    var origin = u.camera_pos;
    var ray = dir;
    let lens_sampled = u.mc_enabled > 0.5 || u.high_quality > 0.5;
    if (lens_sampled && u.dof_enabled > 0.5 && u.aperture > DOF_MIN_APERTURE && part_on(PART_DEPTH_OF_FIELD)) {
        let focus_t = u.focus_distance / max(dot(dir, u.camera_forward), EPSILON);
        let probe = march(u.camera_pos, dir);
        let eff_aperture = dof_aperture(select(u.max_dist, probe.dist, probe.hit), focus_t);
        if (eff_aperture > DOF_MIN_APERTURE) {
            let seed = in.clip_pos.xy + vec2f(u.mc_sample * MC_SEED_RATE_X, u.mc_sample * MC_SEED_RATE_Y);
            let disk = sample_unit_disk(seed) * eff_aperture;
            origin = u.camera_pos + u.camera_right * disk.x + u.camera_up * disk.y;
            ray = normalize(u.camera_pos + dir * focus_t - origin);
        }
    }

    var out: AovOut;
    let m = march(origin, ray);
    if (!m.hit) {
        out.albedo = vec4f(clamp(sky_color(ray), vec3f(0.0), vec3f(1.0)), 1.0);
        out.normal = vec4f(0.0);
        return out;
    }
    let hit_pos = origin + ray * m.dist;
    let mat = apply_part_mask(hit_material(hit_pos).mat);
    out.albedo = vec4f(aov_albedo(mat), 1.0);
    out.normal = vec4f(estimate_normal(hit_pos, m.dist), 1.0);
    return out;
}

const WF_WORKGROUP: u32 = 64u;
const WF_BLOCK_WORDS: u32 = 64u;
const WF_RECT_X: u32 = 0u;
const WF_RECT_Y: u32 = 1u;
const WF_RECT_W: u32 = 2u;
const WF_RECT_H: u32 = 3u;
const WF_TARGET_W: u32 = 4u;
const WF_TARGET_H: u32 = 5u;
const WF_INNER: u32 = 6u;
const WF_QUEUE_STRIDE: u32 = 7u;
const WF_PHASE: u32 = 8u;
const WF_COUNT_PATHS: u32 = 16u;
const WF_COUNT_SHADOW: u32 = 18u;
const WF_COUNT_INDIRECT: u32 = 19u;
const WF_STATS_INDIRECT: u32 = 20u;
const WF_COUNT_BACK: u32 = 21u;
const WF_COUNT_HITS: u32 = 24u;
const WF_COUNT_MISSES: u32 = 25u;
const WF_STATS_PATHS: u32 = 32u;
const WF_STATS_SHADOW: u32 = 48u;
const WF_STATS_DEPTHS: u32 = 16u;
const WF_ARGS_WORDS: u32 = 16u;
const WF_ARGS_PATHS: u32 = 0u;
const WF_ARGS_SHADOW: u32 = 4u;
const WF_ARGS_INDIRECT: u32 = 8u;
const WF_ARGS_HITS: u32 = 12u;
const WF_QUEUE_SHADOW: u32 = 2u;
const WF_QUEUE_INDIRECT: u32 = 3u;
const WF_QUEUE_SHADE: u32 = 4u;

const WF_IN_SOLID: u32 = 1u;
const WF_REFLECTED: u32 = 2u;
const WF_SLAB: u32 = 4u;
const WF_SLAB_SKY: u32 = 8u;
const WF_DISP_VALID: u32 = 16u;
const WF_DISP_INSIDE: u32 = 32u;
const WF_HIT: u32 = 64u;

const WF_OUT_VALID = 1.0;
const WF_OUT_PRIMARY = 3.0;

struct WfPath {
    throughput: Spec,
    shadow_w: Spec,
    indirect_w: Spec,
    pos: vec3f,
    hero: f32,
    dir: vec3f,
    depth: i32,
    seed: vec2f,
    lambda: f32,
    flags: u32,
    disp_in_dir: vec3f,
    disp_ior: f32,
    disp_normal: vec3f,
    disp_abbe: f32,
    slab_dir: vec3f,
    inner_steps: i32,
    slab_color: vec3f,
    adapt_slot: i32,
    shade_pos: vec3f,
    shadow_light: i32,
    shade_normal: vec3f,
    hit_t: f32,
    seg_steps: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
}

struct WfSurface {
    normal: vec3f,
    ao: f32,
    mat: ColorStop,
}

struct WfOut {
    color: vec4f,
    normal: vec4f,
}

@group(6) @binding(0) var<storage, read_write> wf_paths: array<WfPath>;
@group(6) @binding(1) var<storage, read_write> wf_queues: array<u32>;
@group(6) @binding(2) var<storage, read_write> wf_block: array<atomic<u32>, WF_BLOCK_WORDS>;
@group(6) @binding(3) var<storage, read_write> wf_out: array<WfOut>;
@group(6) @binding(4) var<storage, read> wf_block_r: array<u32, WF_BLOCK_WORDS>;
@group(6) @binding(5) var<storage, read> wf_out_r: array<WfOut>;
@group(6) @binding(6) var<storage, read_write> wf_args: array<u32, WF_ARGS_WORDS>;
@group(6) @binding(7) var<storage, read_write> wf_surf: array<WfSurface>;

var<workgroup> wf_wg_count: array<atomic<u32>, 4>;
var<workgroup> wf_wg_base: array<u32, 4>;

fn wf_flag(on: bool, bit: u32) -> u32 {
    return select(0u, bit, on);
}

fn wf_has(flags: u32, bit: u32) -> bool {
    return (flags & bit) != 0u;
}

fn wf_load(slot: u32) -> PathState {
    let p = wf_paths[slot];
    var st: PathState;
    st.throughput = p.throughput;
    st.pos = p.pos;
    st.dir = p.dir;
    st.seed = p.seed;
    st.hero = p.hero;
    st.depth = p.depth;
    st.alive = true;
    st.radiance = spec_splat(0.0);
    st.in_solid = wf_has(p.flags, WF_IN_SOLID);
    st.inner_steps = p.inner_steps;
    st.lambda = p.lambda;
    st.reflected = wf_has(p.flags, WF_REFLECTED);
    st.disp = DispersionRecord(wf_has(p.flags, WF_DISP_VALID), p.disp_in_dir, p.disp_normal, p.disp_ior, p.disp_abbe, wf_has(p.flags, WF_DISP_INSIDE));
    st.slab = wf_has(p.flags, WF_SLAB);
    st.slab_sky = wf_has(p.flags, WF_SLAB_SKY);
    st.slab_dir = p.slab_dir;
    st.slab_color = p.slab_color;
    return st;
}

fn wf_store(slot: u32, st: PathState, adapt_slot: i32) {
    var p: WfPath;
    p.throughput = st.throughput;
    p.shadow_w = g_wf_shadow_w;
    p.indirect_w = g_wf_indirect_w;
    p.pos = st.pos;
    p.hero = st.hero;
    p.dir = st.dir;
    p.depth = st.depth;
    p.seed = st.seed;
    p.lambda = st.lambda;
    p.flags = wf_flag(st.in_solid, WF_IN_SOLID) | wf_flag(st.reflected, WF_REFLECTED) | wf_flag(st.slab, WF_SLAB) |
        wf_flag(st.slab_sky, WF_SLAB_SKY) | wf_flag(st.disp.valid, WF_DISP_VALID) | wf_flag(st.disp.inside, WF_DISP_INSIDE);
    p.disp_in_dir = st.disp.in_dir;
    p.disp_ior = st.disp.ior;
    p.disp_normal = st.disp.normal;
    p.disp_abbe = st.disp.abbe;
    p.slab_dir = st.slab_dir;
    p.inner_steps = st.inner_steps;
    p.slab_color = st.slab_color;
    p.adapt_slot = adapt_slot;
    p.shade_pos = g_wf_shade_pos;
    p.shadow_light = g_wf_shadow_light;
    p.shade_normal = g_wf_shade_normal;
    p.hit_t = 0.0;
    p.seg_steps = 0.0;
    p._pad0 = 0.0;
    p._pad1 = 0.0;
    p._pad2 = 0.0;
    wf_paths[slot] = p;
}

fn wf_word(i: u32) -> u32 {
    return atomicLoad(&wf_block[i]);
}

fn wf_cur() -> u32 {
    return wf_word(WF_PHASE) & 1u;
}

fn wf_queue_at(queue: u32, i: u32) -> u32 {
    return wf_queues[queue * wf_word(WF_QUEUE_STRIDE) + i];
}

fn wf_split_at(queue: u32, front: u32, i: u32) -> u32 {
    let stride = wf_word(WF_QUEUE_STRIDE);
    if (i < front) {
        return wf_queues[queue * stride + i];
    }
    return wf_queues[queue * stride + stride - 1u - (i - front)];
}

fn wf_put_front(queue: u32, i: u32, slot: u32) {
    wf_queues[queue * wf_word(WF_QUEUE_STRIDE) + i] = slot;
}

fn wf_put_back(queue: u32, i: u32, slot: u32) {
    let stride = wf_word(WF_QUEUE_STRIDE);
    wf_queues[queue * stride + stride - 1u - i] = slot;
}

fn wf_reserve(lid: u32, want: vec4u, counters: vec4u) -> vec4u {
    if (lid == 0u) {
        for (var k = 0u; k < 4u; k++) {
            atomicStore(&wf_wg_count[k], 0u);
        }
    }
    workgroupBarrier();
    var local = vec4u(0u);
    for (var k = 0u; k < 4u; k++) {
        if (want[k] > 0u) {
            local[k] = atomicAdd(&wf_wg_count[k], want[k]);
        }
    }
    workgroupBarrier();
    if (lid == 0u) {
        for (var k = 0u; k < 4u; k++) {
            let n = atomicLoad(&wf_wg_count[k]);
            wf_wg_base[k] = select(0u, atomicAdd(&wf_block[counters[k]], n), n > 0u);
        }
    }
    workgroupBarrier();
    return vec4u(wf_wg_base[0], wf_wg_base[1], wf_wg_base[2], wf_wg_base[3]) + local;
}

fn wf_dispatch_size(n: u32) -> u32 {
    return (n + WF_WORKGROUP - 1u) / WF_WORKGROUP;
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_generate(@builtin(global_invocation_id) gid: vec3u, @builtin(local_invocation_index) lid: u32) {
    let rect_w = wf_word(WF_RECT_W);
    let pixels = rect_w * wf_word(WF_RECT_H);
    let inner = max(wf_word(WF_INNER), 1u);
    let live = gid.x < pixels;
    var samples = 0u;
    if (live) {
        let px = wf_word(WF_RECT_X) + gid.x % rect_w;
        let py = wf_word(WF_RECT_Y) + gid.x / rect_w;
        let frag = vec2f(f32(px) + 0.5, f32(py) + 0.5);
        let target_size = vec2f(f32(wf_word(WF_TARGET_W)), f32(wf_word(WF_TARGET_H)));
        let ndc = vec2f(frag.x / target_size.x * 2.0 - 1.0, 1.0 - frag.y / target_size.y * 2.0);
        let p_full = ndc * u.tile_scale + u.tile_bias;
        let aspect = u.resolution.x / u.resolution.y;
        let uv = vec2f(p_full.x * aspect, -p_full.y);
        let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

        let first = gid.x * inner;
        for (var s = 0u; s < inner; s++) {
            wf_out[first + s] = WfOut(vec4f(0.0), vec4f(0.0));
        }

        let row_width = u32(max(u.adapt_row_width, 0.0));
        let adapt_idx = py * row_width + px;
        let pixel_ok = px < row_width && adapt_idx < arrayLength(&adapt_stats);
        let adapt = u.adapt_enabled > 0.5 && u.mc_enabled > 0.5 && pixel_ok;
        var converged = false;
        if (adapt && u.mc_sample > 0.5) {
            converged = adapt_stats[adapt_idx].stats.w > 0.5;
        }
        if (!converged) {
            if (pixel_ok && u.primary_cache_key > 0.5) {
                g_primary_slot = i32(adapt_idx);
            }
            detect_scene_transparency();

            var n = 1;
            var focus_point = vec3f(0.0);
            var eff_aperture = 0.0;
            if (u.dof_enabled > 0.5 && u.aperture > DOF_MIN_APERTURE && part_on(PART_DEPTH_OF_FIELD)) {
                let focus_t = u.focus_distance / max(dot(dir, u.camera_forward), EPSILON);
                focus_point = u.camera_pos + dir * focus_t;
                let cached = hit_cache_load();
                var probe_t = select(u.max_dist, cached.dist, cached.hit);
                if (!cached.valid) {
                    let probe = march(u.camera_pos, dir);
                    probe_t = select(u.max_dist, probe.dist, probe.hit);
                    hit_cache_store(probe.hit, probe.dist, probe.steps, 0u, false);
                }
                eff_aperture = dof_aperture(probe_t, focus_t);
                if (eff_aperture > DOF_MIN_APERTURE) {
                    n = mc_inner_count(DOF_SAMPLES_HQ);
                }
            }
            samples = min(u32(n), inner);

            let base_seed = frag + vec2f(u.mc_sample * MC_SEED_RATE_X, u.mc_sample * MC_SEED_RATE_Y);
            for (var s = 0u; s < samples; s++) {
                var origin = u.camera_pos;
                var sample_dir = dir;
                var seed = base_seed;
                if (eff_aperture > DOF_MIN_APERTURE) {
                    g_primary_slot = -1;
                    seed = base_seed + vec2f(f32(s) * DOF_LENS_SEED_STRIDE_X, f32(s) * DOF_LENS_SEED_STRIDE_Y);
                    let disk = sample_unit_disk(seed) * eff_aperture;
                    origin = u.camera_pos + u.camera_right * disk.x + u.camera_up * disk.y;
                    sample_dir = normalize(focus_point - origin);
                }
                wf_store(first + s, path_begin(origin, sample_dir, seed), g_primary_slot);
                wf_out[first + s].normal.w = WF_OUT_VALID;
            }
        }
    }
    let base = wf_reserve(lid, vec4u(samples, 0u, 0u, 0u), vec4u(WF_COUNT_PATHS, WF_COUNT_PATHS, WF_COUNT_PATHS, WF_COUNT_PATHS));
    for (var s = 0u; s < samples; s++) {
        wf_put_front(0u, base.x + s, gid.x * inner + s);
    }
}

@compute @workgroup_size(1)
fn cs_wf_args_begin() {
    let cur = wf_cur();
    let n = atomicLoad(&wf_block[WF_COUNT_PATHS + cur]) + atomicLoad(&wf_block[WF_COUNT_BACK + cur]);
    atomicStore(&wf_block[WF_STATS_PATHS + min(wf_word(WF_PHASE), WF_STATS_DEPTHS - 1u)], n);
    wf_args[WF_ARGS_PATHS] = wf_dispatch_size(n);
    wf_args[WF_ARGS_PATHS + 1u] = 1u;
    wf_args[WF_ARGS_PATHS + 2u] = 1u;
    atomicStore(&wf_block[WF_COUNT_PATHS + 1u - cur], 0u);
    atomicStore(&wf_block[WF_COUNT_BACK + 1u - cur], 0u);
    atomicStore(&wf_block[WF_COUNT_SHADOW], 0u);
    atomicStore(&wf_block[WF_COUNT_INDIRECT], 0u);
    atomicStore(&wf_block[WF_COUNT_HITS], 0u);
    atomicStore(&wf_block[WF_COUNT_MISSES], 0u);
}

@compute @workgroup_size(1)
fn cs_wf_args_hits() {
    wf_args[WF_ARGS_HITS] = wf_dispatch_size(atomicLoad(&wf_block[WF_COUNT_HITS]));
    wf_args[WF_ARGS_HITS + 1u] = 1u;
    wf_args[WF_ARGS_HITS + 2u] = 1u;
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_surface(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= atomicLoad(&wf_block[WF_COUNT_HITS])) {
        return;
    }
    let slot = wf_queue_at(WF_QUEUE_SHADE, gid.x);
    let p = wf_paths[slot];
    if (wf_has(p.flags, WF_SLAB)) {
        return;
    }
    path_enter(p.depth);
    g_primary_slot = select(-1, p.adapt_slot, p.depth == 0);
    g_second_slot = select(-1, p.adapt_slot, p.depth == 1);
    let hit_pos = p.pos + p.dir * p.hit_t;
    let normal = path_normal(hit_pos, p.hit_t, p.seg_steps, wf_has(p.flags, WF_IN_SOLID));
    let mat = apply_part_mask(hit_material(hit_pos).mat);
    var ao = 1.0;
    if (path_needs_ao(p.depth, wf_has(p.flags, WF_REFLECTED))) {
        ao = calc_ao(hit_pos, normal, p.hit_t);
    }
    wf_surf[slot] = WfSurface(normal, ao, mat);
}

@compute @workgroup_size(1)
fn cs_wf_args_mid() {
    wf_args[WF_ARGS_SHADOW] = wf_dispatch_size(atomicLoad(&wf_block[WF_COUNT_SHADOW]));
    wf_args[WF_ARGS_SHADOW + 1u] = 1u;
    wf_args[WF_ARGS_SHADOW + 2u] = 1u;
    wf_args[WF_ARGS_INDIRECT] = wf_dispatch_size(atomicLoad(&wf_block[WF_COUNT_INDIRECT]));
    wf_args[WF_ARGS_INDIRECT + 1u] = 1u;
    wf_args[WF_ARGS_INDIRECT + 2u] = 1u;
    atomicStore(&wf_block[WF_STATS_SHADOW + min(wf_word(WF_PHASE), WF_STATS_DEPTHS - 1u)], atomicLoad(&wf_block[WF_COUNT_SHADOW]));
    atomicAdd(&wf_block[WF_STATS_INDIRECT], atomicLoad(&wf_block[WF_COUNT_INDIRECT]));
    atomicAdd(&wf_block[WF_PHASE], 1u);
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_extend(@builtin(global_invocation_id) gid: vec3u, @builtin(local_invocation_index) lid: u32) {
    let cur = wf_cur();
    let front = atomicLoad(&wf_block[WF_COUNT_PATHS + cur]);
    let live = gid.x < front + atomicLoad(&wf_block[WF_COUNT_BACK + cur]);
    var slot = 0u;
    var want = vec4u(0u);
    if (live) {
        slot = wf_split_at(cur, front, gid.x);
        var st = wf_load(slot);
        g_primary_slot = select(-1, wf_paths[slot].adapt_slot, st.depth == 0);
        g_second_slot = select(-1, wf_paths[slot].adapt_slot, st.depth == 1);
        let seg = path_extend(st);
        wf_paths[slot].hit_t = seg.hit_t;
        wf_paths[slot].seg_steps = seg.steps;
        wf_paths[slot].flags = (wf_paths[slot].flags & ~WF_HIT) | wf_flag(seg.hit_ok, WF_HIT);
        want = vec4u(select(0u, 1u, seg.hit_ok), select(1u, 0u, seg.hit_ok), 0u, 0u);
    }
    let base = wf_reserve(lid, want, vec4u(WF_COUNT_HITS, WF_COUNT_MISSES, WF_COUNT_HITS, WF_COUNT_HITS));
    if (want.x > 0u) {
        wf_put_front(WF_QUEUE_SHADE, base.x, slot);
    }
    if (want.y > 0u) {
        wf_put_back(WF_QUEUE_SHADE, base.y, slot);
    }
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_shade(@builtin(global_invocation_id) gid: vec3u, @builtin(local_invocation_index) lid: u32) {
    let cur = wf_cur();
    let hits = atomicLoad(&wf_block[WF_COUNT_HITS]);
    let live = gid.x < hits + atomicLoad(&wf_block[WF_COUNT_MISSES]);
    var slot = 0u;
    var want = vec4u(0u);
    if (live) {
        slot = wf_split_at(WF_QUEUE_SHADE, hits, gid.x);
        let p = wf_paths[slot];
        var st = wf_load(slot);
        spectral_setup(st.hero);
        detect_scene_transparency();
        g_primary_slot = select(-1, p.adapt_slot, st.depth == 0);
        g_second_slot = select(-1, p.adapt_slot, st.depth == 1);
        if (gid.x < hits) {
            let surf = wf_surf[slot];
            g_wf_normal = surf.normal;
            g_wf_ao = surf.ao;
            g_wf_mat = surf.mat;
        }
        let depth = st.depth;
        st = path_shade(st, PathSegment(p.hit_t, wf_has(p.flags, WF_HIT), p.seg_steps));
        let radiance = st.radiance;

        var o = wf_out[slot];
        o.color = vec4f(o.color.rgb + spec_to_rgb(radiance), o.color.w);
        if (depth == 0 && g_primary_dist > 0.0) {
            o.color.w = g_primary_dist;
            o.normal = vec4f(g_primary_normal, WF_OUT_PRIMARY);
        }
        wf_out[slot] = o;

        let next = st.alive && st.depth < path_max_depth();
        want = vec4u(select(0u, 1u, next && !st.in_solid), select(0u, 1u, next && st.in_solid), select(0u, 1u, g_wf_shadow_light >= 0), select(0u, 1u, g_wf_indirect));
        if (any(want > vec4u(0u))) {
            wf_store(slot, st, select(-1, g_second_slot, st.depth == 1));
        }
    }
    let next_queue = 1u - cur;
    let base = wf_reserve(lid, want, vec4u(WF_COUNT_PATHS + next_queue, WF_COUNT_BACK + next_queue, WF_COUNT_SHADOW, WF_COUNT_INDIRECT));
    if (want.x > 0u) {
        wf_put_front(next_queue, base.x, slot);
    }
    if (want.y > 0u) {
        wf_put_back(next_queue, base.y, slot);
    }
    if (want.z > 0u) {
        wf_put_front(WF_QUEUE_SHADOW, base.z, slot);
    }
    if (want.w > 0u) {
        wf_put_front(WF_QUEUE_INDIRECT, base.w, slot);
    }
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_shadow(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= atomicLoad(&wf_block[WF_COUNT_SHADOW])) {
        return;
    }
    let slot = wf_queue_at(WF_QUEUE_SHADOW, gid.x);
    let p = wf_paths[slot];
    spectral_setup(p.hero);
    detect_scene_transparency();
    let light = u.lights[p.shadow_light];
    let ls = light_sample(light, p.shade_pos);
    let vis = shadow_factor(p.shade_pos, p.shade_normal, light, ls.dir, ls.dist);
    let add = spec_to_rgb(spec_mul(vis, p.shadow_w));
    wf_out[slot].color = wf_out[slot].color + vec4f(add, 0.0);
}

@compute @workgroup_size(WF_WORKGROUP)
fn cs_wf_indirect(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= atomicLoad(&wf_block[WF_COUNT_INDIRECT])) {
        return;
    }
    let slot = wf_queue_at(WF_QUEUE_INDIRECT, gid.x);
    let p = wf_paths[slot];
    spectral_setup(p.hero);
    detect_scene_transparency();
    let ambient = indirect_light(p.shade_pos, p.shade_normal, path_seed(p.seed, 0) + INDIRECT_SEED_OFFSET);
    let add = spec_to_rgb(spec_mul(ambient, p.indirect_w));
    wf_out[slot].color = wf_out[slot].color + vec4f(add, 0.0);
}

@fragment
fn fs_wf_resolve(in: VertexOut) -> FragOut {
    let px = u32(in.clip_pos.x);
    let py = u32(in.clip_pos.y);
    let rx = wf_block_r[WF_RECT_X];
    let ry = wf_block_r[WF_RECT_Y];
    let rw = wf_block_r[WF_RECT_W];
    let rh = wf_block_r[WF_RECT_H];
    if (px < rx || py < ry || px >= rx + rw || py >= ry + rh) {
        discard;
    }
    let inner = max(wf_block_r[WF_INNER], 1u);
    let first = ((py - ry) * rw + (px - rx)) * inner;
    var sum = vec3f(0.0);
    var n = 0.0;
    var dist = 0.0;
    var normal = vec3f(0.0);
    for (var s = 0u; s < inner; s++) {
        let o = wf_out_r[first + s];
        if (o.normal.w < WF_OUT_VALID - 0.5) {
            continue;
        }
        sum += gamut_fit(o.color.rgb);
        n += 1.0;
        if (o.normal.w > WF_OUT_PRIMARY - 0.5) {
            dist = o.color.w;
            normal = o.normal.xyz;
        }
    }
    if (n < 0.5) {
        discard;
    }
    let color = sum / n;

    let row_width = u32(max(u.adapt_row_width, 0.0));
    let adapt_idx = py * row_width + px;
    let pixel_ok = px < row_width && adapt_idx < arrayLength(&adapt_stats);
    if (u.adapt_enabled > 0.5 && u.mc_enabled > 0.5 && pixel_ok) {
        var stats = vec4f(0.0);
        if (u.mc_sample > 0.5) {
            stats = adapt_stats[adapt_idx].stats;
        }
        adapt_stats[adapt_idx].stats = adapt_update(stats, color);
    }
    return frag_out(vec4f(color, 0.0), dist, normal);
}

@group(1) @binding(1) var accel_out: texture_storage_3d<r32float, write>;

@compute @workgroup_size(VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE)
fn cs_build_accel(@builtin(global_invocation_id) gid: vec3u) {
    let res = u32(u.accel_res);
    let levels = u32(min(u.accel_levels, f32(MAX_CASCADES)));
    let gz = gid.z + u32(u.accel_z_offset);
    if (gid.x >= res || gid.y >= res || gz >= res * levels) {
        return;
    }

    let level = gz / res;
    let cz = gz % res;

    let prm = u.accel_params[level];
    let cell = prm.w;
    let centre = prm.xyz + (vec3f(f32(gid.x), f32(gid.y), f32(cz)) + 0.5) * cell;

    let d = scene_de(centre);
    let safe = max(d - HALF_SQRT3 * cell, 0.0) * u.accel_safety;

    textureStore(accel_out, vec3i(i32(gid.x), i32(gid.y), i32(gz)), vec4f(safe, 0.0, 0.0, 0.0));
}

@group(2) @binding(15) var fog_vis_out: texture_storage_3d<rgba16float, write>;

const FOG_VIS_BUILD_HERO = 0.5;

@compute @workgroup_size(VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE)
fn cs_build_fog_vis(@builtin(global_invocation_id) gid: vec3u) {
    let dims = vec3u(u.fog_vis_dims);
    let layers = u32(u.fog_vis_layers);
    let gz = gid.z + u32(u.fog_vis_z_offset);
    if (gid.x >= dims.x || gid.y >= dims.y || gz >= dims.z * layers) {
        return;
    }

    let layer = gz / dims.z;
    let li = i32(u.fog_vis_layer_light[layer / 4u][layer % 4u]);
    detect_scene_transparency();
    spectral_setup(FOG_VIS_BUILD_HERO);

    let p = u.fog_vis_origin + (vec3f(f32(gid.x), f32(gid.y), f32(gz % dims.z)) + 0.5) * u.fog_vis_cell;
    let ls = light_sample(u.lights[li], p);
    let vis = spec_to_rgb(fog_light_visibility(p, ls.dir, ls.dist, FOG_SHADOW_STEPS_HQ));
    textureStore(fog_vis_out, vec3i(i32(gid.x), i32(gid.y), i32(gz)), vec4f(clamp(vis, vec3f(0.0), vec3f(1.0)), 1.0));
}

@group(1) @binding(0) var<storage, read_write> fft_density: array<f32>;
@group(1) @binding(1) var<storage, read_write> fft_complex_a: array<vec2f>;
@group(1) @binding(2) var<storage, read_write> fft_complex_b: array<vec2f>;
@group(1) @binding(3) var fft_magnitude_out: texture_storage_3d<r32float, write>;
@group(1) @binding(4) var<storage, read_write> fft_peak: array<atomic<u32>>;

const FFT_LOG2N: u32 = 6u;
const FFT_TAU: f32 = 6.283185307179586;

fn fft_idx(x: u32, y: u32, z: u32) -> u32 {
    return x + y * FFT_N + z * FFT_N * FFT_N;
}

fn fft_bit_reverse6(v_in: u32) -> u32 {
    var v = v_in;
    var r: u32 = 0u;
    for (var i: u32 = 0u; i < FFT_LOG2N; i++) {
        r = (r << 1u) | (v & 1u);
        v = v >> 1u;
    }
    return r;
}

fn fft_1d(data: ptr<function, array<vec2f, FFT_N>>) {
    for (var i: u32 = 0u; i < FFT_N; i++) {
        let j = fft_bit_reverse6(i);
        if (j > i) {
            let tmp = (*data)[i];
            (*data)[i] = (*data)[j];
            (*data)[j] = tmp;
        }
    }
    var m: u32 = 2u;
    for (var stage: u32 = 0u; stage < FFT_LOG2N; stage++) {
        let half_m = m >> 1u;
        let theta_base = -FFT_TAU / f32(m);
        for (var k: u32 = 0u; k < FFT_N; k += m) {
            for (var j: u32 = 0u; j < half_m; j++) {
                let angle = theta_base * f32(j);
                let tw = vec2f(cos(angle), sin(angle));
                let even = (*data)[k + j];
                let odd = (*data)[k + j + half_m];
                let odd_tw = vec2f(odd.x * tw.x - odd.y * tw.y, odd.x * tw.y + odd.y * tw.x);
                (*data)[k + j] = even + odd_tw;
                (*data)[k + j + half_m] = even - odd_tw;
            }
        }
        m = m << 1u;
    }
}

@compute @workgroup_size(VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE)
fn cs_fft_voxelize(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N || gid.z >= FFT_N) {
        return;
    }
    let slot = i32(u.fft_target_slot + 0.5);
    let b = max(u.fft_box_radius, FFT_MIN_BOX_RADIUS);
    let cell = (2.0 * b) / f32(FFT_N);
    let local = vec3f(
        -b + (f32(gid.x) + 0.5) * cell,
        -b + (f32(gid.y) + 0.5) * cell,
        -b + (f32(gid.z) + 0.5) * cell,
    );
    let d = instance_local_de(local, slot).x;
    let sigma = max(FFT_VOXEL_SIGMA_CELLS * cell, FFT_MIN_SIGMA);
    let density = exp(-(d * d) / (2.0 * sigma * sigma));
    fft_density[fft_idx(gid.x, gid.y, gid.z)] = density;
    if (all(gid == vec3u(0u))) {
        atomicStore(&fft_peak[0], 0u);
    }
}

@compute @workgroup_size(FFT_LINE_WORKGROUP_SIZE, FFT_LINE_WORKGROUP_SIZE, 1)
fn cs_fft_axis_seed(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N) {
        return;
    }
    let y = gid.x;
    let z = gid.y;
    var line: array<vec2f, FFT_N>;
    for (var x: u32 = 0u; x < FFT_N; x++) {
        line[x] = vec2f(fft_density[fft_idx(x, y, z)], 0.0);
    }
    fft_1d(&line);
    for (var x: u32 = 0u; x < FFT_N; x++) {
        fft_complex_a[fft_idx(x, y, z)] = line[x];
    }
}

@compute @workgroup_size(FFT_LINE_WORKGROUP_SIZE, FFT_LINE_WORKGROUP_SIZE, 1)
fn cs_fft_axis_complex(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N) {
        return;
    }
    var line: array<vec2f, FFT_N>;
    if (i32(u.fft_axis + 0.5) == FFT_AXIS_Y) {
        let x = gid.x;
        let z = gid.y;
        for (var y: u32 = 0u; y < FFT_N; y++) {
            line[y] = fft_complex_a[fft_idx(x, y, z)];
        }
        fft_1d(&line);
        for (var y: u32 = 0u; y < FFT_N; y++) {
            fft_complex_b[fft_idx(x, y, z)] = line[y];
        }
    } else {
        let x = gid.x;
        let y = gid.y;
        for (var z: u32 = 0u; z < FFT_N; z++) {
            line[z] = fft_complex_b[fft_idx(x, y, z)];
        }
        fft_1d(&line);
        for (var z: u32 = 0u; z < FFT_N; z++) {
            fft_complex_a[fft_idx(x, y, z)] = line[z];
        }
    }
}

fn fft_radial_freq(gid: vec3u) -> f32 {
    let n = vec3i(i32(FFT_N));
    let k = vec3i(gid);
    let f = vec3f(select(k, k - n, k >= n / 2));
    return length(f) / (f32(FFT_N / 2u) * SQRT3);
}

@compute @workgroup_size(VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE)
fn cs_fft_magnitude(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N || gid.z >= FFT_N) {
        return;
    }
    let idx = fft_idx(gid.x, gid.y, gid.z);
    let r = fft_radial_freq(gid);
    let pass_band = r <= u.fft_lowpass && r >= u.fft_highpass;
    let mag = select(0.0, log(1.0 + length(fft_complex_a[idx])), pass_band);
    fft_density[idx] = mag;
    atomicMax(&fft_peak[0], bitcast<u32>(mag));
}

@compute @workgroup_size(VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE, VOXEL_WORKGROUP_SIZE)
fn cs_fft_finalize(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N || gid.z >= FFT_N) {
        return;
    }
    var mag = fft_density[fft_idx(gid.x, gid.y, gid.z)];
    let peak = bitcast<f32>(atomicLoad(&fft_peak[0]));
    if (u.fft_normalize > 0.5 && peak > 0.0) {
        mag /= peak;
    }
    textureStore(fft_magnitude_out, vec3i(i32(gid.x), i32(gid.y), i32(gid.z)), vec4f(mag, 0.0, 0.0, 0.0));
}

@group(2) @binding(4) var<storage, read_write> photon_cells_rw: array<vec4f>;
@group(2) @binding(5) var<storage, read_write> photon_counts_rw: array<atomic<u32>>;
@group(2) @binding(6) var<storage, read_write> photon_keys_rw: array<atomic<u32>>;
@group(2) @binding(7) var<storage, read_write> photon_offsets_rw: array<u32>;
@group(2) @binding(8) var<storage, read_write> photon_cursor_rw: array<atomic<u32>>;
@group(2) @binding(9) var<storage, read_write> photon_stats_rw: array<atomic<u32>>;
@group(2) @binding(11) var<storage, read_write> photon_volume_rw: array<atomic<u32>>;
@group(2) @binding(12) var<storage, read_write> photon_staging_rw: array<Photon>;

const PHOTON_STAT_POOL: u32 = 0u;
const PHOTON_STAT_NO_BUCKET: u32 = 1u;
const PHOTON_STAT_NO_POOL: u32 = 2u;
const PHOTON_STAT_CELLS_SURFACE: u32 = 3u;
const PHOTON_STAT_CELLS_VOLUME: u32 = 4u;
const PHOTON_STAT_STAGED: u32 = 5u;

fn photon_staging_overflowed() -> bool {
    return atomicLoad(&photon_stats_rw[PHOTON_STAT_STAGED]) > arrayLength(&photon_staging_rw);
}

var<private> rng_state: u32 = 1u;

fn pcg_next() -> u32 {
    rng_state = rng_state * PCG_MULTIPLIER + PCG_INCREMENT;
    let word = ((rng_state >> ((rng_state >> 28u) + 4u)) ^ rng_state) * PCG_OUTPUT_MULTIPLIER;
    return (word >> 22u) ^ word;
}

fn rand() -> f32 {
    return f32(pcg_next()) * INV_U32_RANGE;
}

fn rand_from(state: ptr<function, u32>) -> f32 {
    *state = *state * PCG_MULTIPLIER + PCG_INCREMENT;
    let word = ((*state >> ((*state >> 28u) + 4u)) ^ *state) * PCG_OUTPUT_MULTIPLIER;
    return f32((word >> 22u) ^ word) * INV_U32_RANGE;
}

const RAND_SEED_RANGE = 512.0;
const MIN_UNIFORM_SAMPLE = 1e-7;
const HG_ISOTROPIC_G = 1e-3;

fn rand_seed() -> vec2f {
    return vec2f(rand() * RAND_SEED_RANGE, rand() * RAND_SEED_RANGE);
}

const R2_ALPHA = vec2u(3242174889u, 2447445414u);
const R4_ALPHA = vec4u(3679390609u, 3152041523u, 2700274806u, 2313257605u);

fn qmc_r2(n: u32, shift: vec2u) -> vec2f {
    return vec2f(vec2u(n) * R2_ALPHA + shift) * INV_U32_RANGE;
}

fn qmc_r4(n: u32, shift: vec4u) -> vec4f {
    return vec4f(vec4u(n) * R4_ALPHA + shift) * INV_U32_RANGE;
}

fn sphere_from(xi: vec2f) -> vec3f {
    let z = 1.0 - 2.0 * xi.x;
    let r = sqrt(max(1.0 - z * z, 0.0));
    let phi = xi.y * TAU;
    return vec3f(r * cos(phi), r * sin(phi), z);
}

fn beam_offset_from(xi: vec2f) -> vec2f {
    let r = sqrt(-log(max(xi.x, MIN_UNIFORM_SAMPLE)));
    let phi = xi.y * TAU;
    return vec2f(r * cos(phi), r * sin(phi));
}

fn photon_basis(n: vec3f) -> mat2x3f {
    let up = select(vec3f(0.0, 0.0, 1.0), vec3f(1.0, 0.0, 0.0), abs(n.z) > BASIS_POLE_COS);
    let tx = normalize(cross(up, n));
    return mat2x3f(tx, cross(n, tx));
}

fn hg_from(dir: vec3f, g: f32, xi: vec2f) -> vec3f {
    var cos_t = 1.0 - 2.0 * xi.x;
    if (abs(g) > HG_ISOTROPIC_G) {
        let sq = (1.0 - g * g) / (1.0 - g + 2.0 * g * xi.x);
        cos_t = (1.0 + g * g - sq * sq) / (2.0 * g);
    }
    cos_t = clamp(cos_t, -1.0, 1.0);
    let sin_t = sqrt(max(1.0 - cos_t * cos_t, 0.0));
    let phi = xi.y * TAU;
    let b = photon_basis(dir);
    return normalize(b[0] * (sin_t * cos(phi)) + b[1] * (sin_t * sin(phi)) + dir * cos_t);
}

const PHOTON_FOG_TRACK_STEPS = 256;
const PHOTON_MIN_MAJORANT = 1e-5;

struct FogCollision {
    hit: bool,
    t: f32,
    albedo: vec3f,
    anisotropy: f32,
}

fn ray_meets_fog(origin: vec3f, dir: vec3f, seg_len: f32, fog: FogEmitter) -> bool {
    let oc = origin - fog.position;
    let b = dot(oc, dir);
    let disc = b * b - (dot(oc, oc) - fog.radius * fog.radius);
    if (disc < 0.0) {
        return false;
    }
    let s = sqrt(disc);
    return -b + s >= 0.0 && -b - s <= seg_len;
}

fn photon_fog_collision(origin: vec3f, dir: vec3f, seg_len: f32) -> FogCollision {
    var c: FogCollision;
    c.hit = false;
    c.t = seg_len;
    c.albedo = vec3f(1.0);
    c.anisotropy = 0.0;

    var majorant = 0.0;
    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    for (var i = 0; i < count; i++) {
        let fog = u.fog_emitters[i];
        if (ray_meets_fog(origin, dir, seg_len, fog)) {
            majorant += max(fog.density, 0.0);
        }
    }
    if (majorant < PHOTON_MIN_MAJORANT) {
        return c;
    }

    var t = 0.0;
    for (var i = 0; i < PHOTON_FOG_TRACK_STEPS; i++) {
        t += -log(max(rand(), MIN_UNIFORM_SAMPLE)) / majorant;
        if (t >= seg_len) {
            return c;
        }
        let fs = sample_fog(origin + dir * t);
        if (rand() * majorant < fs.extinction) {
            c.hit = true;
            c.t = t;
            c.albedo = fs.color;
            c.anisotropy = fs.anisotropy;
            return c;
        }
    }
    return c;
}

fn photon_bucket_claim(c: vec3i, kind: u32) -> u32 {
    let tag = photon_cell_tag(c, kind);
    let mask = u32(u.photon_table) - 1u;
    var b = photon_hash(c, kind);
    for (var i = 0u; i < PHOTON_PROBES; i++) {
        loop {
            let res = atomicCompareExchangeWeak(&photon_keys_rw[b], 0u, tag);
            if (res.exchanged || res.old_value == tag) {
                return b;
            }
            if (res.old_value != 0u) {
                break;
            }
        }
        b = (b + 1u) & mask;
    }
    return PHOTON_NO_BUCKET;
}

fn photon_bucket_lookup_rw(c: vec3i, kind: u32) -> u32 {
    let tag = photon_cell_tag(c, kind);
    let mask = u32(u.photon_table) - 1u;
    var b = photon_hash(c, kind);
    for (var i = 0u; i < PHOTON_PROBES; i++) {
        let k = atomicLoad(&photon_keys_rw[b]);
        if (k == tag) {
            return b;
        }
        if (k == 0u) {
            return PHOTON_NO_BUCKET;
        }
        b = (b + 1u) & mask;
    }
    return PHOTON_NO_BUCKET;
}

fn photon_store(ph: Photon, cell: vec3i, kind: u32) {
    if (u.photon_pass < 0.5) {
        let h = photon_bucket_claim(cell, kind);
        if (h == PHOTON_NO_BUCKET) {
            atomicAdd(&photon_stats_rw[PHOTON_STAT_NO_BUCKET], 1u);
            return;
        }
        atomicAdd(&photon_counts_rw[h], 1u);
        let i = atomicAdd(&photon_stats_rw[PHOTON_STAT_STAGED], 1u);
        if (i < arrayLength(&photon_staging_rw)) {
            var staged = ph;
            staged._pad0 = bitcast<f32>(h);
            photon_staging_rw[i] = staged;
        }
        return;
    }

    let h = photon_bucket_lookup_rw(cell, kind);
    if (h == PHOTON_NO_BUCKET) {
        return;
    }
    photon_place(ph, h);
}

fn photon_bucket_invocation(gid: vec3u, groups: vec3u) -> u32 {
    return gid.x + gid.y * groups.x * u32(LINEAR_WORKGROUP_SIZE);
}

fn photon_power_index_rw(i: u32) -> u32 {
    return arrayLength(&photon_cells_rw) / PHOTON_POOL_SECTIONS + i;
}

fn photon_prefiltered_index_rw(i: u32) -> u32 {
    return arrayLength(&photon_cells_rw) / PHOTON_POOL_SECTIONS * 2u + i;
}

fn photon_write(i: u32, geo: vec4f, power: vec4f) {
    photon_cells_rw[i] = geo;
    photon_cells_rw[photon_power_index_rw(i)] = power;
}

fn photon_place(ph: Photon, h: u32) {
    let stored = atomicLoad(&photon_counts_rw[h]);
    if (stored == 0u) {
        return;
    }
    let room = min(stored, photon_cap_surface());
    let slot = atomicAdd(&photon_cursor_rw[h], 1u);
    if (slot < room) {
        photon_write(photon_offsets_rw[h] + slot, vec4f(ph.pos, bitcast<f32>(oct_encode(ph.normal))), vec4f(ph.power, 0.0));
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_scatter_photons(@builtin(global_invocation_id) gid: vec3u) {
    if (photon_staging_overflowed() || gid.x >= atomicLoad(&photon_stats_rw[PHOTON_STAT_STAGED])) {
        return;
    }
    var ph = photon_staging_rw[gid.x];
    let h = bitcast<u32>(ph._pad0);
    ph._pad0 = 0.0;
    photon_place(ph, h);
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_sort_photons(@builtin(global_invocation_id) gid: vec3u, @builtin(num_workgroups) groups: vec3u) {
    let b = photon_bucket_invocation(gid, groups);
    if (b >= u32(u.photon_table)) {
        return;
    }
    let stored = atomicLoad(&photon_counts_rw[b]);
    if (stored == 0u) {
        return;
    }
    let kind = atomicLoad(&photon_keys_rw[b]) & PHOTON_TAG_KIND_MASK;
    if (!photon_kind_is_surface(kind)) {
        return;
    }
    let kept = min(stored, photon_cap_surface());
    let base = photon_offsets_rw[b];

    for (var s = 0u; s < kept; s++) {
        photon_cells_rw[photon_prefiltered_index_rw(base + s)].w = bitcast<f32>(kind);
    }

    if (kept < PHOTON_OCTANT_HEADER_PHOTONS) {
        return;
    }

    var start: array<u32, 9>;
    for (var s = 0u; s < kept; s++) {
        start[photon_octant(photon_cells_rw[base + s].xyz, kind) + 1u]++;
    }
    for (var o = 1u; o <= PHOTON_OCTANTS; o++) {
        start[o] += start[o - 1u];
    }
    var next = start;
    for (var o = 0u; o < PHOTON_OCTANTS; o++) {
        while (next[o] < start[o + 1u]) {
            let home = base + next[o];
            var geo = photon_cells_rw[home];
            var power = photon_cells_rw[photon_power_index_rw(home)];
            var t = photon_octant(geo.xyz, kind);
            while (t != o) {
                let j = base + next[t];
                next[t]++;
                let geo_j = photon_cells_rw[j];
                let power_j = photon_cells_rw[photon_power_index_rw(j)];
                photon_write(j, geo, power);
                geo = geo_j;
                power = power_j;
                t = photon_octant(geo.xyz, kind);
            }
            photon_write(home, geo, power);
            next[o]++;
        }
    }

    var head = vec3u(0u);
    for (var o = 1u; o < PHOTON_OCTANTS; o++) {
        let i = o - 1u;
        head[i / PHOTON_OCTANTS_PER_WORD] |= start[o] << ((i % PHOTON_OCTANTS_PER_WORD) * PHOTON_OCTANT_BITS);
    }
    for (var w = 0u; w < PHOTON_OCTANT_HEADER_PHOTONS; w++) {
        photon_cells_rw[photon_power_index_rw(base + w)].w = bitcast<f32>(head[w]);
    }
}

fn photon_octant_start_rw(base: u32, o: u32, kept: u32) -> u32 {
    if (o == 0u) {
        return 0u;
    }
    if (o >= PHOTON_OCTANTS) {
        return kept;
    }
    let i = o - 1u;
    let packed = bitcast<u32>(photon_cells_rw[photon_power_index_rw(base + i / PHOTON_OCTANTS_PER_WORD)].w);
    return min((packed >> ((i % PHOTON_OCTANTS_PER_WORD) * PHOTON_OCTANT_BITS)) & PHOTON_OCTANT_MASK, kept);
}

fn photon_scan_rw(base: u32, begin: u32, end: u32, pos: vec3f, normal: vec3f, r: f32) -> vec3f {
    var sum = vec3f(0.0);
    for (var s = base + begin; s < base + end; s++) {
        let geo = photon_cells_rw[s];
        let d = geo.xyz - pos;
        let d2 = dot(d, d);
        if (d2 > r * r || dot(oct_decode(bitcast<u32>(geo.w)), normal) < PHOTON_NORMAL_MIN_COS) {
            continue;
        }
        sum += photon_cells_rw[photon_power_index_rw(s)].xyz * (1.0 - sqrt(d2) / r);
    }
    return sum;
}

fn photon_gather_kind_rw(pos: vec3f, normal: vec3f, kind: u32) -> vec3f {
    let edge = photon_grid_edge(kind);
    let r = PHOTON_GATHER_RADIUS_CELLS * edge;
    let qlo = (pos - vec3f(r)) / edge;
    let qhi = (pos + vec3f(r)) / edge;
    let lo = vec3i(floor(qlo));
    let hi = vec3i(floor(qhi));

    var sum = vec3f(0.0);
    for (var z = lo.z; z <= hi.z; z++) {
        for (var y = lo.y; y <= hi.y; y++) {
            for (var x = lo.x; x <= hi.x; x++) {
                let h = photon_bucket_lookup_rw(vec3i(x, y, z), kind);
                if (h == PHOTON_NO_BUCKET) {
                    continue;
                }
                let stored = atomicLoad(&photon_counts_rw[h]);
                if (stored == 0u) {
                    continue;
                }
                let kept = min(stored, photon_cap_surface());
                let overflow = f32(stored) / f32(kept);
                let base = photon_offsets_rw[h];
                if (kept < PHOTON_OCTANT_HEADER_PHOTONS) {
                    sum += photon_scan_rw(base, 0u, kept, pos, normal, r) * overflow;
                    continue;
                }
                let mid = vec3f(vec3i(x, y, z)) + 0.5;
                let first = select(vec3u(0u), vec3u(1u), qlo >= mid);
                let last = select(vec3u(0u), vec3u(1u), qhi >= mid);
                for (var oz = first.z; oz <= last.z; oz++) {
                    for (var oy = first.y; oy <= last.y; oy++) {
                        let row = (oy << 1u) | (oz << 2u);
                        let begin = photon_octant_start_rw(base, row | first.x, kept);
                        let end = photon_octant_start_rw(base, (row | last.x) + 1u, kept);
                        sum += photon_scan_rw(base, begin, end, pos, normal, r) * overflow;
                    }
                }
            }
        }
    }
    return sum / (r * r);
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_prefilter_photons(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= min(atomicLoad(&photon_stats_rw[PHOTON_STAT_POOL]), u32(u.photon_pool))) {
        return;
    }
    let slot = photon_prefiltered_index_rw(gid.x);
    let mark = photon_cells_rw[slot].w;
    if (bitcast<u32>(mark) != PHOTON_GRID_BOUNCE) {
        return;
    }
    let geo = photon_cells_rw[gid.x];
    photon_cells_rw[slot] = vec4f(photon_gather_kind_rw(geo.xyz, oct_decode(bitcast<u32>(geo.w)), PHOTON_GRID_BOUNCE), mark);
}

const FIXED_POINT_LIMIT = 2147483000.0;
const PHOTON_MIN_FIXED_UNIT = 1e-30;
const PHOTON_MIN_DEPOSIT_WEIGHT = 1e-3;

fn photon_volume_add(word: u32, value: f32, salt: u32) {
    var h = (salt ^ (word * GOLDEN_RATIO_U32)) * PCG_MULTIPLIER + PCG_INCREMENT;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * PCG_OUTPUT_MULTIPLIER;
    let xi = f32((h >> 22u) ^ h) * INV_U32_RANGE;
    let v = i32(clamp(floor(value + xi), -FIXED_POINT_LIMIT, FIXED_POINT_LIMIT));
    let lo = u32(v);
    let hi = select(0u, U32_MAX, v < 0);
    let old = atomicAdd(&photon_volume_rw[word], lo);
    let carry = select(0u, 1u, old > U32_MAX - lo);
    let hi_add = hi + carry;
    if (hi_add != 0u) {
        atomicAdd(&photon_volume_rw[word + 1u], hi_add);
    }
}

fn photon_volume_accumulate(p: vec3f, value: vec3f, dir: vec3f, kind: u32, salt: u32) {
    let inv_unit = 1.0 / max(u.photon_fixed_unit, PHOTON_MIN_FIXED_UNIT);
    let scaled = value * inv_unit;
    let v = dir * dot(scaled, LUMA_WEIGHTS);

    let edge = photon_grid_edge(kind);
    let q = p / edge - photon_lattice_offset() - vec3f(0.5);
    let base = floor(q);
    let f = q - base;
    let cell0 = vec3i(base);
    let own = vec3i(select(vec3i(0), vec3i(1), f >= vec3f(0.5)));

    for (var i = 0; i < CUBE_CORNERS; i++) {
        let corner = vec3i(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        let wv = mix(vec3f(1.0) - f, f, vec3f(corner));
        let w = wv.x * wv.y * wv.z;
        if (w < PHOTON_MIN_DEPOSIT_WEIGHT) {
            continue;
        }
        let h = photon_bucket_claim(cell0 + corner, kind);
        if (h == PHOTON_NO_BUCKET) {
            atomicAdd(&photon_stats_rw[PHOTON_STAT_NO_BUCKET], 1u);
            continue;
        }
        if (all(corner == own)) {
            atomicAdd(&photon_counts_rw[h], 1u);
        }
        let word = h * PHOTON_VOLUME_WORDS;
        photon_volume_add(word + 0u, scaled.r * w, salt);
        photon_volume_add(word + 2u, scaled.g * w, salt);
        photon_volume_add(word + 4u, scaled.b * w, salt);
        photon_volume_add(word + 6u, v.x * w, salt);
        photon_volume_add(word + 8u, v.y * w, salt);
        photon_volume_add(word + 10u, v.z * w, salt);
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_alloc_photons(@builtin(global_invocation_id) gid: vec3u, @builtin(num_workgroups) groups: vec3u) {
    let b = photon_bucket_invocation(gid, groups);
    if (b >= u32(u.photon_table)) {
        return;
    }
    let stored = atomicLoad(&photon_counts_rw[b]);
    if (stored == 0u) {
        return;
    }
    let kind = atomicLoad(&photon_keys_rw[b]) & PHOTON_TAG_KIND_MASK;
    if (!photon_kind_is_surface(kind)) {
        atomicAdd(&photon_stats_rw[PHOTON_STAT_CELLS_VOLUME], 1u);
        return;
    }
    atomicAdd(&photon_stats_rw[PHOTON_STAT_CELLS_SURFACE], 1u);

    let want = min(stored, photon_cap_surface());
    let base = atomicAdd(&photon_stats_rw[PHOTON_STAT_POOL], want);
    if (base + want > u32(u.photon_pool)) {
        atomicStore(&photon_counts_rw[b], 0u);
        atomicAdd(&photon_stats_rw[PHOTON_STAT_NO_POOL], 1u);
        return;
    }
    photon_offsets_rw[b] = base;
}

const PHOTON_MAX_DEPOSITS = 96;
const PHOTON_MAX_WALK = 1024;
const PHOTON_MIN_DIR_COMPONENT = 1e-9;

fn photon_deposit_volume(origin: vec3f, dir: vec3f, seg_len: f32, power: vec3f, kind: u32) {
    if (u.fog_count < 0.5 || seg_len <= 0.0 || u.photon_pass > 0.5) {
        return;
    }
    var walk_rng = rng_state ^ (bitcast<u32>(seg_len) * GOLDEN_RATIO_U32);
    let edge = photon_grid_edge(kind);
    let crossings = 1.0 + seg_len * (abs(dir.x) + abs(dir.y) + abs(dir.z)) / edge;
    let stride = max(i32(ceil(crossings / f32(PHOTON_MAX_DEPOSITS))), 1);
    let phase = min(i32(rand_from(&walk_rng) * f32(stride)), stride - 1);
    let stored_power = power * f32(stride);

    let forward = dir >= vec3f(0.0);
    let moving = abs(dir) > vec3f(PHOTON_MIN_DIR_COMPONENT);
    let origin_l = origin - photon_lattice_offset() * edge;
    var cell = vec3i(floor(origin_l / edge));
    let step = select(vec3i(-1), vec3i(1), forward);
    let safe_dir = select(vec3f(1.0), dir, moving);
    let t_delta = select(vec3f(INFINITE_DISTANCE), edge / abs(safe_dir), moving);
    let next_face = (vec3f(cell) + select(vec3f(0.0), vec3f(1.0), forward)) * edge;
    var t_next = select(vec3f(INFINITE_DISTANCE), (next_face - origin_l) / safe_dir, moving);

    var t = 0.0;
    for (var walk = 0; walk < PHOTON_MAX_WALK; walk++) {
        let t_exit = min(min(min(t_next.x, t_next.y), t_next.z), seg_len);
        let len = t_exit - t;
        if (len > EPSILON_FINE && (walk + phase) % stride == 0) {
            let along = rand_from(&walk_rng);
            let at = origin + dir * (t + along * len);
            if (sample_fog(at).extinction >= VOLUME_MIN_EXTINCTION) {
                photon_volume_accumulate(at, stored_power * len, dir, kind, walk_rng);
            }
        }
        if (t_exit >= seg_len) {
            break;
        }
        t = t_exit;
        if (t_next.x <= t_next.y && t_next.x <= t_next.z) {
            cell.x += step.x;
            t_next.x += t_delta.x;
        } else if (t_next.y <= t_next.z) {
            cell.y += step.y;
            t_next.y += t_delta.y;
        } else {
            cell.z += step.z;
            t_next.z += t_delta.z;
        }
    }
}

struct PhotonEmission {
    origin: vec3f,
    dir: vec3f,
    power: vec3f,
}

const PHOTON_AIM_RES: u32 = 128u;
const PHOTON_AIM_CELLS: u32 = PHOTON_AIM_RES * PHOTON_AIM_RES;
const PHOTON_AIM_SPECULAR_BOOST = 15.0;
const PHOTON_AIM_SUBSAMPLES = 4u;
const PHOTON_MIN_SKY_RADIUS = 1e-3;

struct AimEntry {
    prob: f32,
    other: u32,
    ratio: f32,
    _pad: f32,
}

@group(2) @binding(13) var<storage, read_write> photon_aim_weights_rw: array<f32>;
@group(2) @binding(14) var<storage, read> photon_aim_table: array<AimEntry>;

struct PhotonRay {
    origin: vec3f,
    dir: vec3f,
}

fn photon_light_ray(light: Light, uv: vec2f) -> PhotonRay {
    if (i32(light.light_type + 0.5) == LIGHT_POINT) {
        return PhotonRay(light.position_or_direction, sphere_from(uv));
    }
    let axis = -normalize(light.position_or_direction);
    let b = photon_basis(axis);
    let d = (uv * 2.0 - 1.0) * u.photon_extent;
    return PhotonRay(u.photon_centre - axis * u.photon_extent + b[0] * d.x + b[1] * d.y, axis);
}

fn photon_light_area(light: Light) -> f32 {
    return select(4.0 * u.photon_extent * u.photon_extent, 4.0 * PI, i32(light.light_type + 0.5) == LIGHT_POINT);
}

fn photon_aim_pick(li: u32, x: f32, jitter: vec2f) -> vec3f {
    let fx = x * f32(PHOTON_AIM_CELLS);
    let j = min(u32(fx), PHOTON_AIM_CELLS - 1u);
    let base = li * PHOTON_AIM_CELLS;
    let entry = photon_aim_table[base + j];
    let c = select(entry.other, j, fract(fx) < entry.prob);
    let ratio = photon_aim_table[base + c].ratio;
    let cell = vec2f(f32(c % PHOTON_AIM_RES), f32(c / PHOTON_AIM_RES));
    return vec3f((cell + jitter) / f32(PHOTON_AIM_RES), 1.0 / max(ratio, EPSILON_FINE));
}

fn photon_emit(light: Light, li: u32, paths: f32, xi: vec4f) -> PhotonEmission {
    var e: PhotonEmission;
    let intensity = light.color * light.brightness;
    let inv_paths = 1.0 / max(paths, 1.0);

    if (i32(light.light_type + 0.5) != LIGHT_RAY) {
        var uv = xi.xy;
        var scale = 1.0;
        if (u.photon_aim > 0.5) {
            let pick = photon_aim_pick(li, xi.x, xi.zw);
            uv = pick.xy;
            scale = pick.z;
        }
        let ray = photon_light_ray(light, uv);
        e.origin = ray.origin;
        e.dir = ray.dir;
        e.power = intensity * (photon_light_area(light) * inv_paths * scale);
        return e;
    }

    let axis = light.ray_direction / max(length(light.ray_direction), EPSILON_FINE);
    let b = photon_basis(axis);
    let g = beam_offset_from(xi.xy);
    let perp = b[0] * g.x + b[1] * g.y;
    e.origin = light.position_or_direction + perp * light.waist;
    e.dir = normalize(axis + perp * tan(clamp(light.spread, 0.0, RAY_LIGHT_MAX_SPREAD)));
    e.power = intensity * (PI * inv_paths);
    return e;
}

fn photon_emit_sky(paths: f32, xi: vec4f) -> PhotonEmission {
    var e: PhotonEmission;
    let r = max(u.photon_extent, PHOTON_MIN_SKY_RADIUS);
    let n = sphere_from(xi.xy);
    e.origin = u.photon_centre + n * r;
    e.dir = cosine_hemisphere_from(-n, xi.z, xi.w);
    let area = 4.0 * PI * r * r;
    e.power = sky_color(-e.dir) * (PI * area / max(paths, 1.0));
    return e;
}

fn photon_deposit_rgb(power: Spec, lambda: f32, off: Spec, scale: f32) -> vec3f {
    if (lambda == 0.0 || scale <= 0.0) {
        return spec_to_rgb(power);
    }
    return spec_to_rgb(spec_mul(power, dispersion_weights(spec_mul(off, off), scale)));
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_photon_aim(@builtin(global_invocation_id) gid: vec3u) {
    let light_count = u32(min(u.light_count, f32(MAX_LIGHTS)));
    let li = gid.x / PHOTON_AIM_CELLS;
    if (li >= light_count) {
        return;
    }
    let light = u.lights[li];
    var w = 0.0;
    if (i32(light.light_type + 0.5) != LIGHT_RAY) {
        let c = gid.x % PHOTON_AIM_CELLS;
        let cell = vec2f(f32(c % PHOTON_AIM_RES), f32(c / PHOTON_AIM_RES));
        let reach = u.max_dist + max(u.photon_extent, 0.0);
        let fog_count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
        for (var s = 0u; s < PHOTON_AIM_SUBSAMPLES; s++) {
            let sub = vec2f(f32(s & 1u), f32(s >> 1u)) * 0.5 + 0.25;
            let ray = photon_light_ray(light, (cell + sub) / f32(PHOTON_AIM_RES));
            let m = march_to(ray.origin, ray.dir, reach);
            let span = select(reach, m.dist, m.hit);
            for (var i = 0; i < fog_count; i++) {
                if (ray_meets_fog(ray.origin, ray.dir, span, u.fog_emitters[i])) {
                    w = max(w, 1.0);
                }
            }
            if (m.hit) {
                let mat = hit_material(ray.origin + ray.dir * m.dist).mat;
                let specular = clamp(max(mat.transparency, mat.reflectiveness), 0.0, 1.0);
                w = max(w, 1.0 + PHOTON_AIM_SPECULAR_BOOST * specular);
            }
        }
    }
    photon_aim_weights_rw[gid.x] = w;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_clear_photons(@builtin(global_invocation_id) gid: vec3u, @builtin(num_workgroups) groups: vec3u) {
    let b = photon_bucket_invocation(gid, groups);
    if (b == 0u) {
        atomicStore(&photon_stats_rw[PHOTON_STAT_POOL], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_NO_BUCKET], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_NO_POOL], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_CELLS_SURFACE], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_CELLS_VOLUME], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_STAGED], 0u);
    }
    if (b >= u32(u.photon_table)) {
        return;
    }
    atomicStore(&photon_counts_rw[b], 0u);
    atomicStore(&photon_keys_rw[b], 0u);
    atomicStore(&photon_cursor_rw[b], 0u);
    photon_offsets_rw[b] = 0u;
    let base = b * PHOTON_VOLUME_WORDS;
    for (var w = 0u; w < PHOTON_VOLUME_WORDS; w++) {
        atomicStore(&photon_volume_rw[base + w], 0u);
    }
}

const PHOTON_SHIFT_WORDS = 6u;
const R4_DIMS = 4u;
const PHOTON_MIN_EMIT_POWER = 1e-9;
const PHOTON_MAX_BOUNCES = 16;
const PHOTON_MIN_SURVIVAL = 1e-4;
const PHOTON_MIN_POWER = 1e-6;

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_trace_photons(@builtin(global_invocation_id) gid: vec3u) {
    if (u.photon_pass > 0.5 && !photon_staging_overflowed()) {
        return;
    }
    let index = gid.x + u32(u.photon_path_offset);
    let total = u32(max(u.photon_paths, 0.0));
    if (index >= total) {
        return;
    }
    let light_count = u32(min(u.light_count, f32(MAX_LIGHTS)));
    let sky_emitters = select(0u, 1u, u.sky.photons > 0.5 && u.sky.intensity > 0.0);
    let emitter_count = light_count + sky_emitters;
    if (emitter_count == 0u) {
        return;
    }

    rng_state = pcg_next() ^ index;
    rng_state = pcg_next() ^ (u32(max(u.photon_seed, 0.0)) * KNUTH_MULTIPLIER);
    rng_state = pcg_next();

    let li = index % emitter_count;
    let paths = f32((total - li + emitter_count - 1u) / emitter_count);

    let seq = index / emitter_count;
    var shift_state = (u32(max(u.photon_seed, 0.0)) * KNUTH_MULTIPLIER) ^ (li * GOLDEN_RATIO_U16 + GOLDEN_RATIO_U32);
    var shift = vec4u(0u);
    var shift2 = vec2u(0u);
    for (var d = 0u; d < PHOTON_SHIFT_WORDS; d++) {
        shift_state = shift_state * PCG_MULTIPLIER + PCG_INCREMENT;
        let word = ((shift_state >> ((shift_state >> 28u) + 4u)) ^ shift_state) * PCG_OUTPUT_MULTIPLIER;
        if (d < R4_DIMS) {
            shift[d] = (word >> 22u) ^ word;
        } else {
            shift2[d - R4_DIMS] = (word >> 22u) ^ word;
        }
    }

    var emission: PhotonEmission;
    var xi_spectrum: vec2f;
    if (li < light_count) {
        let r4 = qmc_r4(seq, shift);
        emission = photon_emit(u.lights[li], li, paths, vec4f(qmc_r2(seq, shift2), r4.zw));
        xi_spectrum = r4.xy;
    } else {
        emission = photon_emit_sky(paths, qmc_r4(seq, shift));
        xi_spectrum = qmc_r2(seq, shift2);
    }
    var origin = emission.origin;
    var dir = emission.dir;
    if (max(emission.power.r, max(emission.power.g, emission.power.b)) < PHOTON_MIN_EMIT_POWER) {
        return;
    }
    spectral_setup(xi_spectrum.x);
    let dispersion_pick = min(i32(xi_spectrum.y * SPECTRAL_COUNT), i32(SPECTRAL_COUNT) - 1);
    var power = spec_from_rgb(emission.power);

    let bounces = clamp(i32(u.light_bounces), 0, PHOTON_MAX_BOUNCES);
    var bounces_left = bounces;
    var glass_left = PATH_TRANSPARENCY_FLOOR;

    var in_solid = false;
    var inner_steps = PATH_DEFAULT_INNER_STEPS;
    var diffuse = false;
    var lambda = 0.0;
    var scatters = 0;

    let soft = u.photon_dispersion_soft;
    var disp_ang = spec_splat(0.0);
    var disp_off = spec_splat(0.0);

    let reach = u.max_dist + max(u.photon_extent, 0.0);

    for (var v = 0; v <= bounces + PATH_TRANSPARENCY_FLOOR; v++) {
        var hit_t = 0.0;
        var hit_ok = false;
        if (in_solid) {
            let ins = march_inside(origin, dir, inner_steps, INSIDE_STEP_BASE, u.max_dist);
            hit_t = ins.dist;
            hit_ok = ins.exited;
        } else {
            let m = march_to(origin, dir, reach);
            hit_t = m.dist;
            hit_ok = m.hit;
        }

        var seg_len = select(min(reach, hit_t), hit_t, hit_ok);

        var collision: FogCollision;
        collision.hit = false;
        if (!in_solid) {
            collision = photon_fog_collision(origin, dir, seg_len);
            if (collision.hit) {
                seg_len = collision.t;
            }
        }

        if (scatters >= 1) {
            let kind = select(PHOTON_GRID_VOLUME, PHOTON_GRID_HAZE, diffuse);
            let mid_off = spec_add(disp_off, spec_scale(disp_ang, 0.5 * seg_len));
            photon_deposit_volume(origin, dir, seg_len,
                                  photon_deposit_rgb(power, lambda, mid_off, soft * photon_grid_edge(kind)), kind);
        }
        disp_off = spec_add(disp_off, spec_scale(disp_ang, seg_len));

        if (collision.hit) {
            if (bounces_left == 0) {
                break;
            }
            bounces_left--;
            let albedo = clamp(collision.albedo, vec3f(0.0), vec3f(1.0));
            let survive = max(albedo.r, max(albedo.g, albedo.b));
            if (survive < PHOTON_MIN_SURVIVAL || rand() >= survive) {
                break;
            }
            power = spec_scale(spec_mul(power, spec_from_rgb(albedo)), 1.0 / survive);
            if (spec_max(power) < PHOTON_MIN_POWER) {
                break;
            }
            origin = origin + dir * collision.t;
            dir = hg_from(dir, collision.anisotropy, vec2f(rand(), rand()));
            diffuse = true;
            disp_ang = spec_splat(0.0);
            scatters++;
            continue;
        }

        if (!hit_ok) {
            break;
        }

        let hit_pos = origin + dir * hit_t;
        let normal = estimate_normal(hit_pos, hit_t);
        let mat = hit_material(hit_pos).mat;
        let seed = rand_seed();

        if (lambda == 0.0 && mat.abbe > MIN_ABBE) {
            lambda = spec_lambda_um(dispersion_pick);
            if (soft <= 0.0) {
                power = spec_mul(power, spec_collapse_mask(dispersion_pick));
            }
        }

        if (scatters >= 1 && !in_solid) {
            let kind = select(PHOTON_GRID_SURFACE, PHOTON_GRID_BOUNCE, diffuse);
            let rgb = photon_deposit_rgb(power, lambda, disp_off, soft * PHOTON_GATHER_RADIUS_CELLS * photon_grid_edge(kind));
            photon_store(Photon(hit_pos, 0.0, rgb, 0.0, normal, 0.0), photon_grid_cell(hit_pos, kind), kind);
        }

        let sc = scatter_at(hit_pos, dir, normal, mat, in_solid, lambda, seed, true, soft);
        if (sc.kind == SCATTER_ABSORBED) {
            break;
        }
        if (in_solid || sc.kind == SCATTER_TRANSMIT) {
            if (glass_left == 0) {
                break;
            }
            glass_left--;
        } else {
            if (bounces_left == 0) {
                break;
            }
            bounces_left--;
        }
        power = spec_mul(power, sc.weight);
        if (spec_max(power) < PHOTON_MIN_POWER) {
            break;
        }

        if (sc.kind == SCATTER_TRANSMIT) {
            in_solid = !in_solid;
            if (in_solid) {
                inner_steps = clamp(i32(mat.inner_max_steps), MIN_INNER_STEPS, MAX_INNER_STEPS);
            }
        }
        if (sc.kind == SCATTER_DIFFUSE) {
            diffuse = true;
            disp_ang = spec_splat(0.0);
        } else {
            disp_ang = Spec(sqrt(disp_ang.lo * disp_ang.lo + sc.disp_ang2.lo),
                            sqrt(disp_ang.hi * disp_ang.hi + sc.disp_ang2.hi));
        }

        let bias = max(PHOTON_EXIT_BIAS, EXIT_BIAS_EPS_SCALE * march_epsilon(hit_t));
        origin = hit_pos + sc.dir * bias;
        dir = sc.dir;
        scatters++;
    }
}
