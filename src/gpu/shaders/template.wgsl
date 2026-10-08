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
    _pad_film0: f32,
    _pad_film1: f32,
}

const MAX_INSTANCES = 4;
const MAX_MIXINS = 3;
const MAX_COLOR_STOPS = 16;
const MAX_LIGHTS = 8;
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
const PD_CELLS: u32 = PD_RECORDS + 2u * PD_MAX_PARTICLES * PD_RECORD_WORDS;
const PD_INDEX: u32 = PD_CELLS + 2u * PD_MAX_CELLS * 2u;
const PD_DIST_CAP: u32 = 10u;
const PD_CELL_CAP: u32 = 32u;

struct IterCarry {
    z: vec3f,
    dr: f32,
}

struct MixinParams {
    params0: vec4f,
    params1: vec4f,
    iterations: f32,
    _pad0: f32,
    _pad1: f32,
    _pad2: f32,
}

struct FractalInstance {
    offset: vec3f,
    blend_k: f32,
    combine_mode: f32,
    color_count: f32,
    step_safety: f32,
    hidden: f32,
    scale: vec3f,
    _pad_scale: f32,
    rotation: vec3f,
    _pad_rot: f32,
    params0: vec4f,
    params1: vec4f,
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
    _pad_warp1: f32,
    _pad_warp2: f32,
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
    _pad_carve0: f32,
    _pad_carve1: f32,
    _pad_carve2: f32,
    carves: array<vec4f, MAX_CARVES>,
    particle_systems: array<ParticleSystem, MAX_PARTICLE_SYSTEMS>,
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

fn part_on(part: u32) -> bool {
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

@group(2) @binding(0) var<storage, read> photon_cells: array<Photon>;
@group(2) @binding(1) var<storage, read> photon_counts: array<u32>;
@group(2) @binding(2) var<storage, read> photon_keys: array<u32>;
@group(2) @binding(3) var<storage, read> photon_offsets: array<u32>;
@group(2) @binding(10) var<storage, read> photon_volume: array<u32>;

const PHOTON_GRID_SURFACE: u32 = 0u;
const PHOTON_GRID_VOLUME: u32 = 1u;
const PHOTON_GRID_HAZE: u32 = 2u;
const PHOTON_GRID_BOUNCE: u32 = 3u;
const PHOTON_HAZE_SCALE = 4.0;

fn photon_kind_is_surface(kind: u32) -> bool {
    return kind == PHOTON_GRID_SURFACE || kind == PHOTON_GRID_BOUNCE;
}

fn photon_volume_cell() -> f32 {
    return max(u.photon_cell * max(u.photon_volume_scale, 1.0), 1e-6);
}

fn photon_grid_edge(kind: u32) -> f32 {
    if (kind == PHOTON_GRID_SURFACE) {
        return max(u.photon_cell, 1e-6);
    }
    if (kind == PHOTON_GRID_BOUNCE) {
        return max(u.photon_cell * max(u.photon_bounce_scale, 1.0), 1e-6);
    }
    return photon_volume_cell() * select(1.0, PHOTON_HAZE_SCALE, kind == PHOTON_GRID_HAZE);
}

fn photon_lattice_offset() -> vec3f {
    var h = u32(max(u.photon_hash_salt, 0.0)) * 747796405u + 2891336453u;
    var o = vec3f(0.0);
    for (var i = 0; i < 3; i++) {
        h = h * 747796405u + 2891336453u;
        let word = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
        o[i] = f32((word >> 22u) ^ word) * 2.3283064365386963e-10;
    }
    return o;
}

fn photon_grid_cell(p: vec3f, kind: u32) -> vec3i {
    let q = p / photon_grid_edge(kind);
    return vec3i(floor(select(q - photon_lattice_offset(), q, photon_kind_is_surface(kind))));
}

fn photon_hash(c: vec3i, kind: u32) -> u32 {
    let h = (u32(c.x) * 73856093u) ^ (u32(c.y) * 19349663u) ^
            (u32(c.z) * 83492791u) ^ (kind * 2971215073u) ^
            (u32(max(u.photon_hash_salt, 0.0)) * 2654435761u);
    return h & (u32(u.photon_table) - 1u);
}

fn photon_cell_tag(c: vec3i, kind: u32) -> u32 {
    var h = (u32(c.x) * 2654435761u) ^ (u32(c.y) * 2246822519u) ^
            (u32(c.z) * 3266489917u) ^ (kind * 1900403167u);
    h ^= h >> 15u;
    h *= 2246822519u;
    h ^= h >> 13u;
    return ((h | 4u) & 0xfffffffcu) | (kind & 3u);
}

fn photon_cap_surface() -> u32 {
    return max(u32(u.photon_cap_surface), 1u);
}

const PHOTON_PROBES: u32 = 8u;

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

fn photon_gather_surface(pos: vec3f, normal: vec3f) -> vec3f {
    if (!photons_on()) {
        return vec3f(0.0);
    }
    var total = vec3f(0.0);
    for (var g = 0u; g < 2u; g++) {
        let kind = select(PHOTON_GRID_SURFACE, PHOTON_GRID_BOUNCE, g == 1u);
        let r = 0.5 * photon_grid_edge(kind);
        let r2 = r * r;
        let lo = photon_grid_cell(pos - vec3f(r), kind);
        let hi = photon_grid_cell(pos + vec3f(r), kind);

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
                    for (var s = 0u; s < kept; s++) {
                        let ph = photon_cells[base + s];
                        let d = ph.pos - pos;
                        if (dot(d, d) > r2) {
                            continue;
                        }
                        if (dot(ph.normal, normal) < 0.7) {
                            continue;
                        }
                        let w = 1.0 - sqrt(dot(d, d)) / r;
                        sum += ph.power * overflow * w;
                    }
                }
            }
        }
        total += sum / r2;
    }
    return gamut_fit(total) * u.photon_intensity * 3.0 / 3.14159265;
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
    let x = 1.056 * spectral_lobe(l, 599.8, 37.9, 31.0)
          + 0.362 * spectral_lobe(l, 442.0, 16.0, 26.7)
          - 0.065 * spectral_lobe(l, 501.1, 20.4, 26.2);
    let y = 0.821 * spectral_lobe(l, 568.8, 46.9, 40.5)
          + 0.286 * spectral_lobe(l, 530.9, 16.3, 31.1);
    let z = 1.217 * spectral_lobe(l, 437.0, 11.8, 36.0)
          + 0.681 * spectral_lobe(l, 459.0, 26.0, 13.8);
    return Band4(x, y, z);
}

fn spectral_setup(hero: f32) {
    let span = SPECTRAL_BAND_HI - SPECTRAL_BAND_LO;
    let base = fract(hero);
    spec_lambda_lo = SPECTRAL_BAND_LO + span * fract(base + vec4f(0.0, 0.125, 0.25, 0.375));
    spec_lambda_hi = SPECTRAL_BAND_LO + span * fract(base + vec4f(0.5, 0.625, 0.75, 0.875));

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
    var wr = Spec( 3.2404542 * xyz_lo.a - 1.5371385 * xyz_lo.b - 0.4985314 * xyz_lo.c,
                   3.2404542 * xyz_hi.a - 1.5371385 * xyz_hi.b - 0.4985314 * xyz_hi.c);
    var wg = Spec(-0.9692660 * xyz_lo.a + 1.8760108 * xyz_lo.b + 0.0415560 * xyz_lo.c,
                  -0.9692660 * xyz_hi.a + 1.8760108 * xyz_hi.b + 0.0415560 * xyz_hi.c);
    var wb = Spec( 0.0556434 * xyz_lo.a - 0.2040259 * xyz_lo.b + 1.0572252 * xyz_lo.c,
                   0.0556434 * xyz_hi.a - 0.2040259 * xyz_hi.b + 1.0572252 * xyz_hi.c);

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
    let a = spec_lambda_lo[clamp(k, 0, 3)];
    let b = spec_lambda_hi[clamp(k - 4, 0, 3)];
    return select(a, b, k >= 4) * 0.001;
}

fn spec_collapse_mask(k: i32) -> Spec {
    let idx = vec4i(0, 1, 2, 3);
    return Spec(select(vec4f(0.0), vec4f(SPECTRAL_COUNT), idx == vec4i(k)),
                select(vec4f(0.0), vec4f(SPECTRAL_COUNT), idx == vec4i(k - 4)));
}


fn gamut_fit(c: vec3f) -> vec3f {
    let y = dot(c, vec3f(0.2126, 0.7152, 0.0722));
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

fn pack_params(p0: vec4f, p1: vec4f) -> array<f32, 8> {
    return array<f32, 8>(
        p0.x, p0.y, p0.z, p0.w,
        p1.x, p1.y, p1.z, p1.w,
    );
}

fn instance_params(slot: i32) -> array<f32, 8> {
    return pack_params(u.instances[slot].params0, u.instances[slot].params1);
}

fn instance_mixin_params(slot: i32, idx: i32) -> array<f32, 8> {
    return pack_params(u.instances[slot].mixins[idx].params0, u.instances[slot].mixins[idx].params1);
}

fn box_fold(z: vec3f, limit: f32) -> vec3f {
    return clamp(z, vec3f(-limit), vec3f(limit)) * 2.0 - z;
}

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

fn sphere_invert_offset(z: vec3f, dr: f32, center: vec3f, radius2: f32) -> vec4f {
    let d = z - center;
    let r2 = max(dot(d, d), 1e-6);
    if (r2 < radius2) {
        let t = radius2 / r2;
        return vec4f(center + d * t, dr * t);
    }
    return vec4f(z, dr);
}

fn lattice_wrap(p: vec3f, cell: f32) -> vec3f {
    return p - cell * round(p / cell);
}

fn de_finalize_scaled(carry: IterCarry) -> f32 {
    return length(carry.z) / abs(carry.dr);
}

fn de_finalize_plain(carry: IterCarry) -> f32 {
    return length(carry.z) / carry.dr;
}

fn bulb_log_escape(carry: IterCarry) -> f32 {
    let r = length(carry.z);
    let log_est = 0.5 * log(max(r, 1e-6)) * r / max(carry.dr, 1e-6);
    return min(log_est, r);
}

fn bulb_power_step(carry: IterCarry, add: vec3f, power: f32) -> IterCarry {
    let r = length(carry.z);
    if (r > 2.0) {
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

fn wrap_angle(a: f32, period: f32) -> f32 {
    return a - period * floor(a / period);
}

fn primitive_de_iterations() -> i32 {
    return 1;
}

fn primitive_de_step(carry: IterCarry, size: f32) -> IterCarry {
    let unit_dr = 1.0 / max(size, 1e-4);
    let f = unit_dr / max(abs(carry.dr), 1e-6);
    return IterCarry(carry.z * f, unit_dr);
}

const TRAP_SPHERE = 1;
const TRAP_BOX = 2;
const TRAP_CROSS = 3;
const TRAP_TORUS = 4;

const TRAP_MAX = 1;
const TRAP_AVERAGE = 2;
const TRAP_LAST = 3;
const TRAP_ITERATION = 4;

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
    return vec4f(select(0.0, 1e6, starts_high), 0.0, 0.0, 1e6);
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

@@FORMULA_0@@

@@FORMULA_1@@

@@FORMULA_2@@

@@FORMULA_3@@

@@MIXINS_0@@

@@MIXINS_1@@

@@MIXINS_2@@

@@MIXINS_3@@

fn eval_formula(slot: i32, pos: vec3f, p: array<f32, 8>) -> vec2f {
    if (slot == 0) {
        return formula_0(pos, p);
    } else if (slot == 1) {
        return formula_1(pos, p);
    } else if (slot == 2) {
        return formula_2(pos, p);
    } else {
        return formula_3(pos, p);
    }
}

@@DISPATCHERS@@

fn eval_mixed(pos: vec3f, base_slot: i32, mixin_slot0: i32) -> vec2f {
    var carry = IterCarry(pos, 1.0);
    let trap_spec = orbit_trap(base_slot);
    var trap = orbit_trap_begin(trap_spec);

    let base_p = instance_params(base_slot);
    let base_n = max(i32(u.instances[base_slot].hybrid_base_iters), 0);
    let mixin_count = min(i32(u.instances[base_slot].mixin_count), MAX_MIXINS);

    var cycle_len = base_n;
    for (var j = 0; j < mixin_count; j++) {
        cycle_len += max(i32(u.instances[base_slot].mixins[j].iterations), 0);
    }
    cycle_len = max(cycle_len, 1);

    let total = max(i32(u.instances[base_slot].hybrid_total_iters), 0);
    for (var it = 0; it < total; it++) {
        var pos_in_cycle = it % cycle_len;

        var slot = base_slot;
        var p = base_p;
        var have_step = true;
        if (pos_in_cycle >= base_n) {
            pos_in_cycle -= base_n;
            have_step = false;
            for (var j = 0; j < mixin_count; j++) {
                let n_j = max(i32(u.instances[base_slot].mixins[j].iterations), 0);
                if (pos_in_cycle < n_j) {
                    slot = mixin_slot0 + j;
                    p = instance_mixin_params(base_slot, j);
                    have_step = true;
                    break;
                }
                pos_in_cycle -= n_j;
            }
        }
        let z_prev = carry.z;
        if (have_step) {
            carry = eval_step(slot, carry, pos, p);
        }

        trap = orbit_trap_update(trap, trap_spec, carry.z, z_prev, it);
    }

    return vec2f(eval_finalize(base_slot, carry), orbit_trap_finish(trap, trap_spec, total));
}

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
    let r = u.instances[slot].rotation;
    return rot_z(r.z) * rot_y(r.y) * rot_x(r.x);
}

fn warp_frame(w: Warp) -> mat3x3f {
    return rot_z(w.rotation.z) * rot_y(w.rotation.y) * rot_x(w.rotation.x);
}

fn warp_region_de(w: Warp, p: vec3f) -> f32 {
    let rk = i32(w.region_kind + 0.5);
    if (rk == 2) {
        return -1e20;
    }
    let q = transpose(warp_frame(w)) * (p - w.center);
    if (rk == 0) {
        return length(q) - max(w.extent.x, 1e-4);
    }
    let e = max(w.extent, vec3f(1e-4));
    let d = abs(q) - e;
    return length(max(d, vec3f(0.0))) + min(max(d.x, max(d.y, d.z)), 0.0);
}

fn warp_influence(w: Warp, p: vec3f) -> f32 {
    let rk = i32(w.region_kind + 0.5);
    if (rk == 2) {
        return w.strength;
    }
    let de = warp_region_de(w, p);
    if (w.falloff <= 1e-4) {
        return select(0.0, w.strength, de <= 0.0);
    }
    return w.strength * (1.0 - smoothstep(-w.falloff, 0.0, de));
}

fn coord_warp_raw(w: Warp, p: vec3f) -> vec3f {
    let frame = warp_frame(w);
    var q = transpose(frame) * (p - w.center);
    let sk = i32(w.sub_kind + 0.5);
    if (sk == 0) {
        let a = w.params0.x * q.y;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.z, q.y, s * q.x + c * q.z);
    } else if (sk == 1) {
        let a = w.params0.x * q.x;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.y, s * q.x + c * q.y, q.z);
    } else if (sk == 2) {
        let a = w.params0.x;
        let c = cos(a);
        let s = sin(a);
        q = vec3f(c * q.x - s * q.z, q.y, s * q.x + c * q.z);
    } else if (sk == 3) {
        q = q / max(abs(w.params0.xyz), vec3f(1e-3));
    } else if (sk == 4) {
        let r_min = max(w.params0.y, 1e-3);
        let r2 = max(dot(q, q), r_min * r_min);
        q = q * (w.params0.x * w.params0.x / r2);
    } else if (sk == 5) {
        let c = w.params0.xyz;
        var f = q;
        if (c.x > 1e-4) { f.x = q.x - c.x * round(q.x / c.x); }
        if (c.y > 1e-4) { f.y = q.y - c.y * round(q.y / c.y); }
        if (c.z > 1e-4) { f.z = q.z - c.z * round(q.z / c.z); }
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
    g.cell = bitcast<f32>(particle_data[h + 3u]);
    g.dims = vec3i(i32(particle_data[h + 4u]), i32(particle_data[h + 5u]), i32(particle_data[h + 6u]));
    g.valid = particle_data[h + 7u] != 0u && u32(u.particle_systems[s].mode + 0.5) != 0u;
    return g;
}

fn particle_in_grid(g: ParticleGrid, c: vec3i) -> bool {
    return all(c >= vec3i(0)) && all(c < g.dims);
}

fn particle_cell(s: u32, g: ParticleGrid, c: vec3i) -> vec3u {
    let a = PD_CELLS + (s * PD_MAX_CELLS + u32(c.x + g.dims.x * (c.y + g.dims.y * c.z))) * 2u;
    let w1 = particle_data[a + 1u];
    return vec3u(particle_data[a], w1 & 0xffffu, w1 >> 16u);
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
        bitcast<f32>(particle_data[a + 3u]),
    );
}

fn particle_strip(s: u32, i: u32) -> f32 {
    return bitcast<f32>(particle_data[PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS + 4u]);
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
            let f = (t - a.position) / max(b.position - a.position, 0.0001);
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


fn instance_local_de(local: vec3f, slot: i32) -> vec2f {
    if (u.instances[slot].mixin_count > 0.5) {
        return eval_mixed(local, slot, MAX_INSTANCES + slot * MAX_MIXINS);
    }
    return eval_formula(slot, local, instance_params(slot));
}

fn instance_de_trap(pos: vec3f, slot: i32) -> vec2f {
    let s = max(u.instances[slot].scale, vec3f(0.001));
    let rot = instance_rotation(slot);
    let unrotated = transpose(rot) * (pos - u.instances[slot].offset);
    let local = unrotated / s;
    let result = instance_local_de(local, slot);
    let scale_factor = min(s.x, min(s.y, s.z));
    let safety = clamp(u.instances[slot].step_safety, 0.001, 1.0);
    return vec2f(result.x * scale_factor * safety, result.y);
}

fn instance_de_trap_ft(pos: vec3f, slot: i32) -> vec2f {
    if (u.fft_active > 0.5 && slot == i32(u.fft_target_slot + 0.5)) {
        return vec2f(1e6, 0.0);
    }
    return instance_de_trap(pos, slot);
}

fn smin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return min(a, b);
    }
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

fn smax(a: f32, b: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return max(a, b);
    }
    let h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

fn ssub(cut: f32, base: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return max(-cut, base);
    }
    let h = clamp(0.5 - 0.5 * (base + cut) / k, 0.0, 1.0);
    return mix(base, -cut, h) + k * h * (1.0 - h);
}

fn smin_lin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return min(a, b);
    }
    return min(b - max(k - a, 0.0), a - max(k - b, 0.0));
}

fn smin_nlin(a: f32, b: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return min(a, b);
    }
    let ra = max(k - a, 0.0);
    let rb = max(k - b, 0.0);
    return min(b - ra * (k - rb) / k, a - rb * (k - ra) / k);
}

fn smix(a: f32, b: f32, k: f32) -> f32 {
    if (k <= 0.0001) {
        return min(a, b);
    }
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h);
}

fn combine_de(mode: i32, d: f32, di: f32, k: f32) -> vec2f {
    let hard = k <= 0.0001;
    let closer = select(1.0, 0.0, di < d);
    if (mode == 0) {
        return vec2f(min(d, di), closer);
    }
    if (mode == 1 || mode == 6) {
        let h = select(clamp(0.5 + 0.5 * (di - d) / k, 0.0, 1.0), closer, hard);
        return vec2f(select(smin(d, di, k), smix(d, di, k), mode == 6), h);
    }
    if (mode == 2) {
        let h = select(clamp(0.5 - 0.5 * (di - d) / k, 0.0, 1.0), select(1.0, 0.0, di > d), hard);
        return vec2f(smax(d, di, k), h);
    }
    if (mode == 3) {
        let h = select(1.0 - clamp(0.5 - 0.5 * (d + di) / k, 0.0, 1.0), select(1.0, 0.0, -di > d), hard);
        return vec2f(ssub(di, d, k), h);
    }
    if (mode == 4) {
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

fn estimate_normal(pos: vec3f, t: f32) -> vec3f {
    let e = march_epsilon(t);
    var grad = vec3f(0.0);
    for (var i = 0; i < 4; i++) {
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
    return normalize(grad);
}

struct MarchResult {
    hit: bool,
    dist: f32,
    steps: f32,
}

fn march_epsilon(t: f32) -> f32 {
    return u.epsilon_coefficient * t + u.epsilon_floor;
}

fn calc_ao(pos: vec3f, normal: vec3f, t: f32) -> f32 {
    if (!part_on(PART_AMBIENT_OCCLUSION)) {
        return 1.0;
    }
    let radius = clamp(t * 0.04, 0.003, 0.25);
    var occlusion = 0.0;
    var weight = 1.0;
    for (var i = 0; i < 5; i++) {
        let step_dist = radius * (0.2 + 0.2 * f32(i));
        let d = scene_de(pos + normal * step_dist);
        occlusion += max(step_dist - d, 0.0) * weight;
        weight *= 0.6;
    }
    return clamp(1.0 - 2.0 * occlusion / radius, 0.0, 1.0);
}

fn march(origin: vec3f, dir: vec3f) -> MarchResult {
    return march_to(origin, dir, u.max_dist);
}

fn march_to(origin: vec3f, dir: vec3f, max_t: f32) -> MarchResult {
    let max_steps = i32(u.max_steps);
    let hq = u.high_quality > 0.5;
    let refine_budget = max(select(i32(u.refine_fast), i32(u.refine_hq), hq), 0);
    let footprint_per_unit_t = u.hq_footprint_budget_px * 2.0 / max(u.resolution.y, 1.0);

    var t = 0.0;
    var i = 0; 
    var probing = true; 
    var lo = 0.0;
    var hi = 0.0;
    var refines = 0;
    var resolved = false;

    let max_samples = max_steps * (1 + refine_budget);
    for (var n = 0; n < max_samples; n++) {
        let sample_t = select(0.5 * (lo + hi), t, probing);
        let eps = march_epsilon(sample_t);

        var step_lim = 1e30;
        if (probing) {
            step_lim = warp_step_limit(origin + dir * sample_t);
        }

        if (probing) {
            let skip = min(accel_skip(origin + dir * sample_t), step_lim);
            if (skip > eps) {
                t = sample_t + skip;
                i++;
                if (t > max_t || i >= max_steps) {
                    break;
                }
                continue;
            }
        }

        let d = scene_de(origin + dir * sample_t);
        if (d < eps) {
            return MarchResult(true, sample_t, f32(i));
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
            if (hq && !resolved) {
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
    return MarchResult(false, t, f32(max_steps));
}

fn default_material() -> ColorStop {
    return ColorStop(vec3f(0.8, 0.8, 0.85), 0.0, 0.3, 0.0, 0.0, 1.5, 0.0, 0.0, 64.0, 0.0, 400.0, 1.8, 0.0, 1.0, 0.0, 0.2, 0.0, 0.0);
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
    result._pad_film0 = 0.0;
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
            let f = (t - a.position) / max(b.position - a.position, 0.0001);
            return mix_material(a, b, 1.0 - f);
        }
    }
    return u.instances[slot].colors[count - 1];
}

fn orbit_trap_to_strip(slot: i32, v: f32) -> f32 {
    let x = v / max(u.instances[slot].trap_span, 1e-4) + u.instances[slot].trap_offset;
    let rep = i32(u.instances[slot].trap_repeat + 0.5);
    if (rep == 1) {
        return fract(x);
    }
    if (rep == 2) {
        return 1.0 - abs(fract(x * 0.5) * 2.0 - 1.0);
    }
    return clamp(x, 0.0, 1.0);
}

@group(3) @binding(0) var sky_samp: sampler;
@group(3) @binding(1) var sky_tex: texture_2d<f32>;

@group(4) @binding(0) var fft_magnitude_tex: texture_3d<f32>;

const SKY_INV_TWO_PI = 0.15915494309189535;
const SKY_INV_PI = 0.3183098861837907;

fn sky_rotate(dir: vec3f) -> vec3f {
    let c = cos(u.sky.yaw);
    let s = sin(u.sky.yaw);
    return vec3f(c * dir.x - s * dir.z, dir.y, s * dir.x + c * dir.z);
}

fn sky_procedural(dir: vec3f) -> vec3f {
    var base: vec3f;
    if (dir.y >= 0.0) {
        let t = pow(clamp(dir.y, 0.0, 1.0), 1.0 / max(u.sky.falloff, 0.01));
        base = mix(u.sky.horizon, u.sky.zenith, t);
    } else {
        base = mix(u.sky.horizon, u.sky.ground, clamp(-dir.y, 0.0, 1.0));
    }

    if (u.sky.sun_cos > -1.0) {
        let d = dot(dir, normalize(u.sky.sun_dir));
        let inner = mix(u.sky.sun_cos, 1.0, 0.15);
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
    if (u.sky.mode > 0.5) {
        c = sky_image(d);
    } else {
        c = sky_procedural(d);
    }
    return max(c * u.sky.intensity, vec3f(0.0));
}

struct SurfacePoint {
    mat: ColorStop,
    de: f32,
}

fn hit_material(hit_pos: vec3f) -> SurfacePoint {
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

fn erf_approx(x: f32) -> f32 {
    let a = 0.147;
    let x2 = x * x;
    let inner = x2 * (4.0 / 3.14159265 + a * x2) / (1.0 + a * x2);
    return sign(x) * sqrt(max(1.0 - exp(-inner), 0.0));
}

fn light_sample_ex(light: Light, surf_pos: vec3f, seg_dir: vec3f, seg_len: f32) -> LightSample {
    var s: LightSample;
    if (light.light_type < 0.5) {
        let to_light = light.position_or_direction - surf_pos;
        let dist = length(to_light);
        s.dir = to_light / max(dist, 1e-4);
        s.color = light.color * light.brightness / max(dist * dist, 0.01);
        s.dist = dist;
    } else if (light.light_type < 1.5) {
        s.dir = normalize(light.position_or_direction);
        s.color = light.color * light.brightness;
        s.dist = u.max_dist * 2.0;
    } else {
        let axis = light.ray_direction / max(length(light.ray_direction), 1e-6);
        let to_light = light.position_or_direction - surf_pos;
        let dist = length(to_light);
        s.dir = to_light / max(dist, 1e-4);
        s.dist = dist;

        let u0 = -to_light;
        let t0 = dot(u0, axis);
        let perp0 = u0 - axis * t0;

        let d_perp = seg_dir - axis * dot(seg_dir, axis);
        let a_quad = dot(d_perp, d_perp);
        let crossing = seg_len > 1e-6 && a_quad > 1e-12;

        let s_star = select(0.0, -dot(perp0, d_perp) / max(a_quad, 1e-12), crossing);
        let s_eval = clamp(s_star, -0.5 * seg_len, 0.5 * seg_len);
        let t_eval = t0 + dot(seg_dir, axis) * s_eval;
        let w = light.waist + max(t_eval, 0.0) * tan(clamp(light.spread, 0.0, 1.5));
        let perp_star = perp0 + d_perp * s_star;

        var profile: f32;
        if (crossing) {
            let k = sqrt(a_quad) / w;
            let hi = erf_approx(k * (0.5 * seg_len - s_star));
            let lo = erf_approx(k * (-0.5 * seg_len - s_star));
            let integral = (w / sqrt(a_quad)) * 0.5 * sqrt(3.14159265) * (hi - lo);
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
}
fn visibility_march(origin: vec3f, light_dir: vec3f, light_dist: f32, vp: VisParams) -> Spec {
    let opaque_only = !scene_has_transparency || photons_on();
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
            if (a < 0.01) {
                return spec_splat(0.0);
            }
            tint = spec_mul(tint, spec_scale(spec_from_rgb(mix(vec3f(1.0), mat.color, a)), a));
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

fn shadow_factor(surf_pos: vec3f, normal: vec3f, light: Light, light_dir: vec3f, light_dist: f32) -> Spec {
    if (light.cast_shadows < 0.5) {
        return spec_splat(1.0);
    }
    let bias = 0.004;
    let vp = VisParams(mix(light.shadow_softness, 512.0, light.hard_shadows), bias, 0.0005, 0.001, 0.0005, 0.004, 1.15, 0.001, 0.004, min(i32(u.max_steps), 40));
    return visibility_march(surf_pos + normal * bias, light_dir, light_dist, vp);
}

fn fog_light_visibility(pos: vec3f, light_dir: vec3f, light_dist: f32, steps: i32) -> Spec {
    let vp = VisParams(12.0, 0.03, 0.001, 0.002, 0.001, 0.02, 1.3, 0.08, 0.01, steps);
    return visibility_march(pos, light_dir, light_dist, vp);
}


fn hash12(p: vec2f) -> f32 {
    return fract(52.9829189 * fract(dot(p, vec2f(0.06711056, 0.00583715))));
}

fn hash12w(p: vec2f) -> f32 {
    var v = vec2u(bitcast<u32>(p.x), bitcast<u32>(p.y));
    v = v * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v ^= v >> vec2u(16u);
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v ^= v >> vec2u(16u);
    return f32(v.x ^ v.y) * 2.3283064365386963e-10;
}

fn phase_hg(cos_theta: f32, g: f32) -> f32 {
    let g2 = g * g;
    let denom = 1.0 + g2 - 2.0 * g * cos_theta;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(max(denom, 1e-4), 1.5));
}

const PHOTON_VOLUME_WORDS: u32 = 12u;

fn fixed64_to_f32(lo: u32, hi: u32) -> f32 {
    if ((hi & 0x80000000u) == 0u) {
        return f32(hi) * 4294967296.0 + f32(lo);
    }
    let mag_lo = ~lo + 1u;
    let mag_hi = ~hi + select(0u, 1u, mag_lo == 0u);
    return -(f32(mag_hi) * 4294967296.0 + f32(mag_lo));
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

fn photon_volume_sample(pos: vec3f, kind: u32) -> mat2x3f {
    let edge = photon_grid_edge(kind);
    let q = pos / edge - photon_lattice_offset() - vec3f(0.5);
    let base = floor(q);
    let f = q - base;
    let cell0 = vec3i(base);

    var flux = vec3f(0.0);
    var vector = vec3f(0.0);
    for (var i = 0; i < 8; i++) {
        let corner = vec3i(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        let wv = mix(vec3f(1.0) - f, f, vec3f(corner));
        let w = wv.x * wv.y * wv.z;
        if (w < 1e-4) {
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

    let beam_lum = dot(beam[0], vec3f(0.2126, 0.7152, 0.0722));
    let beam_vlen = length(beam[1]);
    if (beam_lum > 0.0 && beam_vlen > 0.5 * beam_lum) {
        let along = beam[1] / beam_vlen * photon_grid_edge(PHOTON_GRID_VOLUME);
        let fwd = photon_volume_sample(pos + along, PHOTON_GRID_VOLUME);
        let back = photon_volume_sample(pos - along, PHOTON_GRID_VOLUME);
        beam = mat2x3f((beam[0] + fwd[0] + back[0]) / 3.0, (beam[1] + fwd[1] + back[1]) / 3.0);
    }

    let flux = beam[0] + haze[0];
    let vector = beam[1] + haze[1];

    let lum = dot(flux, vec3f(0.2126, 0.7152, 0.0722));
    if (lum <= 0.0) {
        return vec3f(0.0);
    }
    let vlen = length(vector);
    let align = clamp(vlen / lum, 0.0, 1.0);
    let mean_dir = select(view_dir, vector / max(vlen, 1e-12), vlen > 1e-12);
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
        let edge = clamp(fog.softness, 0.001, 1.0);
        let inner = fog.radius * (1.0 - edge);
        let falloff = 1.0 - smoothstep(inner, fog.radius, dist);
        let d = falloff * max(fog.density, 0.0);
        total += d;
        color_accum += fog.color * d;
        g_accum += fog.anisotropy * d;
    }
    var result: FogSample;
    result.extinction = total;
    result.color = select(vec3f(1.0), color_accum / total, total > 0.0001);
    result.anisotropy = select(0.0, g_accum / total, total > 0.0001);
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

fn march_fog_once(origin: vec3f, dir: vec3f, max_t: f32, jitter: f32, steps: i32, shadow_steps: i32) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;

    let step_size = max_t / f32(steps);
    var t = step_size * jitter;

    let light_count = total_light_count();
    for (var i = 0; i < steps; i++) {
        if (t >= max_t || result.transmittance < 0.003) {
            break;
        }
        let pos = origin + dir * t;
        let fog = sample_fog(pos);
        if (fog.extinction > 0.0005) {
            let sigma_t = fog.extinction;
            let step_transmittance = exp(-sigma_t * step_size);

            var inscatter = spec_from_rgb(photon_gather_volume(pos, dir, fog.anisotropy, step_size, jitter));
            for (var li = 0; li < light_count; li++) {
                let light = u.lights[li];
                let ls = light_sample_ex(light, pos, dir, step_size);
                if (max(ls.color.r, max(ls.color.g, ls.color.b)) < 1e-6) {
                    continue;
                }
                var vis = spec_splat(1.0);
                if (light.cast_shadows > 0.5 && part_on(PART_SHADOWS)) {
                    vis = fog_light_visibility(pos, ls.dir, ls.dist, shadow_steps);
                }
                let cos_theta = dot(dir, ls.dir);
                let phase = phase_hg(cos_theta, fog.anisotropy);
                inscatter = spec_add(inscatter, spec_scale(spec_mul(spec_from_rgb(ls.color), vis), phase));
            }

            let integ = (1.0 - step_transmittance) / max(sigma_t, 1e-5);
            result.color = spec_add(result.color,
                spec_scale(spec_mul(spec_from_rgb(fog.color), inscatter),
                           result.transmittance * sigma_t * integ));
            result.transmittance *= step_transmittance;
        }
        t += step_size;
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

fn march_fog(origin: vec3f, dir: vec3f, max_t: f32, screen_pos: vec2f) -> VolumeResult {
    var result: VolumeResult;
    result.color = spec_splat(0.0);
    result.transmittance = 1.0;

    let count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
    if (count == 0 || max_t <= 0.0 || !part_on(PART_FOG)) {
        return result;
    }

    let hq = u.high_quality > 0.5;
    let steps = select(FOG_STEPS_FAST, FOG_STEPS_HQ, hq);
    let shadow_steps = select(FOG_SHADOW_STEPS_FAST, FOG_SHADOW_STEPS_HQ, hq);
    let span = fog_ray_span(origin, dir, min(max_t, u.max_dist));
    if (span.y <= span.x) {
        return result;
    }
    let span_origin = origin + dir * span.x;
    let samples = clamp(i32(u.fog_samples), 1, FOG_MAX_SAMPLES);

    var accum_color = spec_splat(0.0);
    var accum_transmittance = 0.0;
    for (var s = 0; s < samples; s++) {
        let seed = screen_pos + vec2f(f32(s) * 13.37, f32(s) * 71.13);
        let one = march_fog_once(span_origin, dir, span.y - span.x, hash12(seed), steps, shadow_steps);
        accum_color = spec_add(accum_color, one.color);
        accum_transmittance += one.transmittance;
    }
    result.color = spec_scale(accum_color, 1.0 / f32(samples));
    result.transmittance = accum_transmittance / f32(samples);
    return result;
}

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
    let b = max(box_radius, 0.05);
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
    let box_radius = max(u.fft_box_radius, 0.05);
    let s = max(u.instances[slot].scale, vec3f(0.001));
    let sphere_r = box_radius * max(s.x, max(s.y, s.z)) * 1.7320508;

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
    let jitter = hash12(screen_pos + vec2f(83.71, 21.19));
    var t = t0 + step_size * jitter;

    for (var i = 0; i < FFT_CLOUD_STEPS; i++) {
        if (t >= t1 || result.transmittance < 0.003) {
            break;
        }
        let pos = origin + dir * t;
        let local = (transpose(rot) * (pos - offset)) / s;
        if (all(abs(local) <= vec3f(box_radius))) {
            let mag = sample_fft_magnitude(local, box_radius);
            let sigma_t = mag * density_scale;
            if (sigma_t > 0.0005) {
                let step_transmittance = exp(-sigma_t * step_size);
                let integ = (1.0 - step_transmittance) / max(sigma_t, 1e-5);
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

fn march_inside(origin: vec3f, dir: vec3f, max_inner_steps: i32, step_base: f32) -> InsideMarch {
    var t = 0.0;
    let steps = max(max_inner_steps, 1);
    let growth = 1.0 + INSIDE_STEP_GROWTH / f32(steps);
    var step_floor = max(step_base, 0.0005);
    for (var i = 0; i < steps; i++) {
        let pos = origin + dir * t;
        let d = scene_de(pos);
        if (i > 1 && d > 0.0005 * t + 0.00005) {
            return InsideMarch(true, t);
        }
        t += max(abs(d), step_floor);
        step_floor *= growth;
        if (t > u.max_dist) {
            break;
        }
    }
    return InsideMarch(false, t);
}

const SSS_DISTORTION = 0.35;
const SSS_POWER = 4.0;
const SSS_WRAP = 0.6;
const SSS_ABSORB_THIN = 14.0;
const SSS_ABSORB_THICK = 2.0;

fn shade_local(pos: vec3f, dir: vec3f, normal: vec3f, mat: ColorStop, ambient_light: Spec, use_shadows: bool) -> Spec {
    let view_dir = -dir;
    let spec_power = mix(4.0, 128.0, clamp(mat.glossiness, 0.0, 1.0));
    var albedo = spec_from_rgb(mat.color);

    var film = spec_splat(1.0);
    if (mat.film_strength > 0.001) {
        film = thin_film_tint(dot(view_dir, film_normal(normal, pos, mat)), mat);
        albedo = spec_mul(albedo, film);
    }

    let sss = clamp(mat.subsurface, 0.0, 1.0);
    var translucency = 0.0;
    if (sss > 0.001) {
        let inside = march_inside(pos - normal * 0.003, -normal, min(i32(u.max_steps), 64), 0.003);
        if (inside.exited) {
            translucency = sss * exp(-inside.dist * mix(SSS_ABSORB_THIN, SSS_ABSORB_THICK, sss));
        }
    }

    var diffuse_accum = spec_from_rgb(photon_gather_surface(pos, normal));
    var specular_accum = spec_splat(0.0);
    var sss_accum = spec_splat(0.0);
    let light_count = total_light_count();
    for (var i = 0; i < light_count; i++) {
        let light = u.lights[i];
        let ls = light_sample(light, pos);
        if (max(ls.color.r, max(ls.color.g, ls.color.b)) < 1e-5) {
            continue;
        }
        let light_spec = spec_from_rgb(ls.color);

        if (translucency > 0.0) {
            let back_dir = normalize(ls.dir + normal * SSS_DISTORTION);
            let back = pow(max(dot(view_dir, -back_dir), 0.0), SSS_POWER);
            sss_accum = spec_add(sss_accum, spec_scale(light_spec, back * translucency));
        }

        let wrap = SSS_WRAP * translucency;
        let ndotl = max((dot(normal, ls.dir) + wrap) / (1.0 + wrap), 0.0);
        if (ndotl <= 0.0) {
            continue;
        }
        var shadow = spec_splat(1.0);
        if (use_shadows && part_on(PART_SHADOWS)) {
            shadow = shadow_factor(pos, normal, light, ls.dir, ls.dist);
            if (spec_max(shadow) <= 0.0) {
                continue;
            }
        }
        let half_dir = normalize(ls.dir + view_dir);
        let specular = select(0.0, pow(max(dot(normal, half_dir), 0.0), spec_power) * mat.glossiness, part_on(PART_SPECULAR));
        let reaching = spec_mul(light_spec, shadow);
        diffuse_accum = spec_add(diffuse_accum, spec_scale(reaching, ndotl));
        specular_accum = spec_add(specular_accum, spec_scale(reaching, specular));
    }

    return spec_add(spec_mul(albedo, spec_add(ambient_light, spec_add(diffuse_accum, sss_accum))),
                    spec_mul(specular_accum, film));
}

fn cosine_hemisphere_sample(normal: vec3f, seed: vec2f) -> vec3f {
    return cosine_hemisphere_from(normal, hash12w(seed), hash12w(seed + vec2f(91.73, 31.13)));
}

fn cosine_hemisphere_from(normal: vec3f, u1: f32, u2: f32) -> vec3f {
    let r = sqrt(u1);
    let phi = u2 * 6.28318530718;
    let local = vec3f(r * cos(phi), r * sin(phi), sqrt(max(1.0 - u1, 0.0)));

    let up = select(vec3f(0.0, 0.0, 1.0), vec3f(1.0, 0.0, 0.0), abs(normal.z) > 0.99);
    let tangent = normalize(cross(up, normal));
    let bitangent = cross(normal, tangent);
    return normalize(tangent * local.x + bitangent * local.y + normal * local.z);
}

fn indirect_light(pos: vec3f, normal: vec3f, seed: vec2f) -> Spec {
    let dir = cosine_hemisphere_sample(normal, seed);
    let origin = pos + normal * 0.004;
    let bounce = march(origin, dir);
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
    return shade_local(hit_pos, dir, hit_normal, hit_mat, spec_splat(AMBIENT_INTENSITY), false);
}

struct Refraction {
    dir: vec3f,
    tir: bool,
}

fn refract_safe(dir: vec3f, raw_normal: vec3f, eta: f32) -> Refraction {
    let n = select(raw_normal, -raw_normal, dot(dir, raw_normal) > 0.0);
    let r = refract(dir, n, eta);
    if (dot(r, r) > 0.0001) {
        return Refraction(r, false);
    }
    return Refraction(reflect(dir, n), true);
}

fn perturb_normal(n: vec3f, alpha: f32, seed: vec2f) -> vec3f {
    if (alpha <= 0.0001) {
        return n;
    }
    return normalize(mix(n, cosine_hemisphere_sample(n, seed), alpha));
}

const DISPERSION_INV_LAMBDA_D2 = 2.89626;

fn cauchy_ior(ior_d: f32, abbe: f32, lambda: f32) -> f32 {
    let b = (ior_d - 1.0) / (max(abbe, 1.0) * 1.9099);
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

fn hash33(p: vec3f) -> vec3f {
    var v = bitcast<vec3u>(vec3i(p));
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v ^= v >> vec3u(16u);
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return vec3f(v) * 2.3283064365386963e-10;
}

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
    if (amount <= 0.001) {
        return n;
    }
    let bend = film_noise(pos / max(mat.film_perturb_scale, 1e-4));
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
    let c1 = cos(min(theta, 1.5607));
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
    if (peak < 1e-5) {
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
        if (k < 4) {
            a_lo[k] = a;
        } else {
            a_hi[k - 4] = a;
        }
    }
    return Spec(a_lo, a_hi);
}

fn dispersion_weights(dist2: Spec, sigma: f32) -> Spec {
    let k = -0.5 / max(sigma * sigma, 1e-12);
    let g_lo = exp(dist2.lo * k);
    let g_hi = exp(dist2.hi * k);
    let total = dot(g_lo, vec4f(1.0)) + dot(g_hi, vec4f(1.0));
    let scale = SPECTRAL_COUNT / max(total, 1e-6);
    return Spec(g_lo * scale, g_hi * scale);
}

fn scatter_at(pos: vec3f, in_dir: vec3f, raw_normal: vec3f, mat: ColorStop, inside: bool, lambda: f32, seed: vec2f, allow_diffuse: bool, dispersion_soft: f32) -> Scatter {
    let n = select(raw_normal, -raw_normal, dot(in_dir, raw_normal) > 0.0);

    var ior = max(mat.ior, 1.0);
    if (lambda > 0.0 && mat.abbe > 0.5) {
        ior = max(cauchy_ior(ior, mat.abbe, lambda), 1.0);
    }
    let eta = select(1.0 / ior, ior, inside);

    let rough = clamp(mat.roughness, 0.0, 1.0);
    let n_rough = perturb_normal(n, rough * rough, seed + vec2f(5.19, 12.73));

    let f = fresnel_schlick(dot(in_dir, n_rough), ior);

    var film = spec_splat(1.0);
    if (!inside && mat.film_strength > 0.001) {
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
        if (dispersion_soft > 0.0 && lambda > 0.0 && mat.abbe > 0.5) {
            s.disp_ang2 = dispersion_angles2(in_dir, n_rough, mat, inside, s.dir);
        }
        s.weight = spec_scale(spec_from_rgb(mat.color), scale);
        s.kind = select(SCATTER_TRANSMIT, SCATTER_REFLECT, refr.tir);
        return s;
    }

    if (allow_diffuse && p_diffuse > 0.001) {
        s.dir = cosine_hemisphere_sample(n, seed + vec2f(61.7, 17.3));
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

const PATH_MAX_VERTICES = 16;
const PATH_TRANSPARENCY_FLOOR = 8;
const PATH_RR_START = 4;

var<private> g_primary_dist: f32 = 0.0;
var<private> g_primary_normal: vec3f = vec3f(0.0);

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

fn trace_path(ray_origin: vec3f, ray_dir: vec3f, screen_pos: vec2f) -> vec3f {
    spectral_setup(hash12w(screen_pos + vec2f(19.31, 47.11)) + u.mc_sample * 0.61803399);

    var radiance = spec_splat(0.0);
    var throughput = spec_splat(1.0);
    var pos = ray_origin;
    var dir = ray_dir;

    var in_solid = false; 
    var inner_steps = 64;
    var lambda = 0.0;
    var reflected = false;

    let base_seed = screen_pos + vec2f(u.mc_sample * 27.31, u.mc_sample * 45.17);
    let max_depth = clamp(i32(u.max_reflection_bounces) + PATH_TRANSPARENCY_FLOOR, 1, PATH_MAX_VERTICES);

    for (var depth = 0; depth < max_depth; depth++) {
        let seed = base_seed + vec2f(f32(depth) * 17.77 + 3.1, f32(depth) * 41.13 + 7.7);

        var hit_t = 0.0;
        var hit_ok = false;
        if (in_solid) {
            let ins = march_inside(pos, dir, inner_steps, 0.004);
            hit_t = ins.dist;
            hit_ok = ins.exited;
        } else {
            let m = march(pos, dir);
            hit_t = m.dist;
            hit_ok = m.hit;
        }
        var seg_len = select(min(u.max_dist, max(hit_t, 0.0)), hit_t, hit_ok);

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

        if (dots.hit_t >= 0.0) {
            radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(dots.hit_color)));
            if (depth == 0) {
                g_primary_dist = dots.hit_t;
                g_primary_normal = -dir;
            }
            break;
        }

        if (!hit_ok) {
            radiance = spec_add(radiance, spec_mul(throughput, spec_from_rgb(sky_color(dir))));
            break;
        }
        if (spec_max(throughput) < 0.002) {
            break;
        }

        let hit_pos = pos + dir * hit_t;
        let normal = estimate_normal(hit_pos, hit_t);
        if (depth == 0) {
            g_primary_dist = hit_t;
            g_primary_normal = normal;
        }
        let mat = apply_part_mask(hit_material(hit_pos).mat);

        let soft = radians(0.5 * u.photon_dispersion_soft);
        var disp_weight = spec_splat(1.0);
        if (lambda == 0.0 && mat.abbe > 0.5) {
            let pick = min(i32(hash12w(seed + vec2f(3.71, 8.13)) * SPECTRAL_COUNT), i32(SPECTRAL_COUNT) - 1);
            lambda = spec_lambda_um(pick);
            if (soft <= 0.0) {
                disp_weight = spec_collapse_mask(pick);
            }
        }

        let sc = scatter_at(hit_pos, dir, normal, mat, in_solid, lambda, seed, false, soft);

        if (sc.local_share > 0.001) {
            var ambient_light = spec_splat(AMBIENT_INTENSITY);
            if (depth == 0 && u.mc_enabled > 0.5 && part_on(PART_MC_INDIRECT)) {
                ambient_light = indirect_light(hit_pos, normal, seed + vec2f(13.13, 71.71));
            } else if (!reflected) {
                ambient_light = spec_scale(ambient_light, calc_ao(hit_pos, normal, hit_t));
            }
            radiance = spec_add(radiance, spec_scale(
                spec_mul(throughput, shade_local(hit_pos, dir, normal, mat, ambient_light, !reflected)),
                sc.local_share));
        }

        if (sc.kind == SCATTER_ABSORBED) {
            break;
        }
        if (sc.kind == SCATTER_REFLECT && !in_solid && !part_on(PART_REFLECTIONS)) {
            break;
        }
        if (spec_max(sc.disp_ang2) > 0.0) {
            disp_weight = dispersion_weights(sc.disp_ang2, soft);
        }
        throughput = spec_mul(throughput, spec_mul(disp_weight, sc.weight));
        reflected = reflected || sc.kind == SCATTER_REFLECT;

        if (sc.kind == SCATTER_TRANSMIT) {
            in_solid = !in_solid;
            if (in_solid) {
                inner_steps = clamp(i32(mat.inner_max_steps), 4, 512);
            }
        }

        let bias = max(0.003, 2.0 * march_epsilon(hit_t));
        pos = hit_pos + sc.dir * bias;
        dir = sc.dir;

        if (depth >= PATH_RR_START) {
            let survive = clamp(spec_max(throughput), 0.05, 1.0);
            if (hash12w(seed + vec2f(59.3, 23.9)) > survive) {
                break;
            }
            throughput = spec_scale(throughput, 1.0 / survive);
        }
    }

    return gamut_fit(spec_to_rgb(radiance));
}

const SLICE_HALO_PIXELS = 24.0;
const SLICE_HALO_STRENGTH = 0.35;

fn undo_tonemap(color: vec3f) -> vec3f {
    let c = clamp(color, vec3f(0.0), vec3f(1.0));
    return c / max(vec3f(1.0) - c, vec3f(1.0 / 255.0));
}

fn slice_color(plane_pos: vec3f, pixel_world: f32) -> vec3f {
    let px = max(pixel_world, 1e-12);
    let sp = hit_material(plane_pos);
    let inside = 1.0 - smoothstep(0.0, px, sp.de);
    let halo = exp(-max(sp.de, 0.0) / (px * SLICE_HALO_PIXELS));
    let amount = clamp(max(inside, halo * SLICE_HALO_STRENGTH), 0.0, 1.0);
    return undo_tonemap(sp.mat.color * amount);
}

@fragment
fn fs_slice(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let plane_pos = u.camera_pos + (uv.x * u.camera_right + uv.y * u.camera_up) * u.slice_zoom;
    let pixel_world = 2.0 * u.slice_zoom / max(u.resolution.y, 1.0);
    return frag_out(vec4f(slice_color(plane_pos, pixel_world), 0.0), 0.0, vec3f(0.0));
}

const SIMPLE_ALBEDO = vec3f(0.72, 0.72, 0.73);
const SIMPLE_AMBIENT = 0.18;
const SIMPLE_BACKGROUND = vec3f(0.10, 0.11, 0.13);
const SIMPLE_DEPTH_CUE = 0.55;

@fragment
fn fs_simple(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

    let m = march(u.camera_pos, dir);
    if (!m.hit) {
        return frag_out(vec4f(undo_tonemap(SIMPLE_BACKGROUND), 0.0), 0.0, vec3f(0.0));
    }

    let hit_pos = u.camera_pos + dir * m.dist;
    let normal = estimate_normal(hit_pos, m.dist);

    let key_dir = normalize(-dir + u.camera_up * 0.45 - u.camera_right * 0.35);
    let lambert = max(dot(normal, key_dir), 0.0);
    let shade = SIMPLE_AMBIENT + (1.0 - SIMPLE_AMBIENT) * lambert;

    let depth = clamp(m.dist / max(u.max_dist, 1e-4), 0.0, 1.0);
    let color = mix(SIMPLE_ALBEDO * shade, SIMPLE_BACKGROUND, depth * SIMPLE_DEPTH_CUE);

    return frag_out(vec4f(undo_tonemap(color), 0.0), m.dist, normal);
}

const SELECT_ID_NONE = 0;
const SELECT_ID_FRACTAL = 1;
const SELECT_ID_LIGHT = 11;
const SELECT_ID_FOG = 21;
const SELECT_ID_WARP = 31;
const SELECT_ID_PARTICLES = 41;

const SELECT_HANDLE_PX = 10.0;
const SELECT_GLOBAL_LIGHT_REACH = 2.4;

fn select_handle_radius(depth: f32) -> f32 {
    return max(depth, 1e-4) * SELECT_HANDLE_PX * 2.0 / max(u.resolution.y, 1.0);
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
    let e = max(w.extent, vec3f(1e-4));
    let inv_d = 1.0 / select(d, vec3f(1e-8), abs(d) < vec3f(1e-8));
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

    var best_t = 1e30;
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
        var nearest_de = 1e30;
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
        if (u32(u.particle_systems[s].mode + 0.5) == 0u) {
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
        if (i32(light.light_type + 0.5) == 1) {
            let aim = light.position_or_direction;
            let len = length(aim);
            centre = select(vec3f(0.0, -1.0, 0.0), aim / len, len > 1e-6) * SELECT_GLOBAL_LIGHT_REACH;
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
            let t = select_sphere_entry(origin, dir, fog.position, max(fog.radius, 1e-4));
            if (t >= 0.0 && t < best_t) {
                best_t = t;
                best_id = SELECT_ID_FOG + i;
            }
        }
        for (var i = 0; i < i32(u.warp_count); i++) {
            let w = u.warps[i];
            let rk = i32(w.region_kind + 0.5);
            var t = -1.0;
            if (rk == 0) {
                t = select_sphere_entry(origin, dir, w.center, max(w.extent.x, 1e-4));
            } else if (rk == 1) {
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

    return vec4f(f32(best_id) / 255.0, 0.0, 0.0, 1.0);
}

fn sample_unit_disk(seed: vec2f) -> vec2f {
    let r = sqrt(hash12(seed));
    let theta = hash12w(seed + vec2f(17.17, 71.71)) * 6.28318530718;
    return vec2f(r * cos(theta), r * sin(theta));
}

const DOF_SAMPLES_FAST = 8;
const DOF_SAMPLES_HQ = 32;

fn dof_aperture(hit_t: f32, focus_t: f32) -> f32 {
    let half_range = max(u.focus_range, 0.0) * 0.5;
    let falloff = max(u.aperture * 4.0, 0.05);
    return u.aperture * smoothstep(half_range, half_range + falloff, abs(hit_t - focus_t));
}

fn dof_coc_px(eff_aperture: f32, hit_t: f32, focus_t: f32) -> f32 {
    let world_radius = eff_aperture * abs(hit_t - focus_t) / max(focus_t, 0.0001);
    let px_per_world_unit = u.resolution.y / (2.0 * length(u.camera_up) * max(hit_t, 0.0001));
    return world_radius * px_per_world_unit;
}

@fragment
fn fs_main(in: VertexOut) -> FragOut {
    let aspect = u.resolution.x / u.resolution.y;
    let uv = vec2f(in.uv.x * aspect, in.uv.y);
    let dir = normalize(u.camera_forward + uv.x * u.camera_right + uv.y * u.camera_up);

    detect_scene_transparency();

    var color: vec3f;
    var samples = 1;
    var focus_point = vec3f(0.0);
    var focus_t = 0.0;
    var eff_aperture = 0.0;
    var coc_px = 0.0;
    var post_blur = false;

    if (u.dof_enabled > 0.5 && u.aperture > 0.0001 && part_on(PART_DEPTH_OF_FIELD)) {
        let hq = u.high_quality > 0.5;
        focus_t = u.focus_distance / max(dot(dir, u.camera_forward), 0.0001);
        focus_point = u.camera_pos + dir * focus_t;

        if (u.mc_enabled < 0.5 && !hq) {
            post_blur = true;
        } else {
            let probe = march(u.camera_pos, dir);
            eff_aperture = dof_aperture(select(u.max_dist, probe.dist, probe.hit), focus_t);
            if (eff_aperture > 0.0001) {
                samples = select(DOF_SAMPLES_FAST, DOF_SAMPLES_HQ, hq);
            }
        }
    }

    let base_seed = in.clip_pos.xy + vec2f(u.mc_sample * 91.73, u.mc_sample * 57.31);

    var accum = vec3f(0.0);
    for (var s = 0; s < samples; s++) {
        var sample_origin = u.camera_pos;
        var sample_dir = dir;
        var seed = base_seed;
        if (eff_aperture > 0.0001 && coc_px <= 0.0) {
            seed = base_seed + vec2f(f32(s) * 91.37, f32(s) * 51.91);
            let disk = sample_unit_disk(seed) * eff_aperture;
            sample_origin = u.camera_pos + u.camera_right * disk.x + u.camera_up * disk.y;
            sample_dir = normalize(focus_point - sample_origin);
        }
        accum += trace_path(sample_origin, sample_dir, seed);
    }
    color = accum / f32(samples);

    if (post_blur) {
        let hit_t = select(u.max_dist, g_primary_dist, g_primary_dist > 0.0);
        let blur_aperture = dof_aperture(hit_t, focus_t);
        if (blur_aperture > 0.0001) {
            coc_px = dof_coc_px(blur_aperture, hit_t, focus_t);
        }
    }

    return frag_out(vec4f(color, coc_px), g_primary_dist, g_primary_normal);
}

@group(1) @binding(1) var accel_out: texture_storage_3d<r32float, write>;

@compute @workgroup_size(4, 4, 4)
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
    let safe = max(d - 0.8660254 * cell, 0.0) * u.accel_safety;

    textureStore(accel_out, vec3i(i32(gid.x), i32(gid.y), i32(gz)), vec4f(safe, 0.0, 0.0, 0.0));
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

fn fft_1d(data: ptr<function, array<vec2f, 64>>) {
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

@compute @workgroup_size(4, 4, 4)
fn cs_fft_voxelize(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N || gid.z >= FFT_N) {
        return;
    }
    let slot = i32(u.fft_target_slot + 0.5);
    let b = max(u.fft_box_radius, 0.05);
    let cell = (2.0 * b) / f32(FFT_N);
    let local = vec3f(
        -b + (f32(gid.x) + 0.5) * cell,
        -b + (f32(gid.y) + 0.5) * cell,
        -b + (f32(gid.z) + 0.5) * cell,
    );
    let d = instance_local_de(local, slot).x;
    let sigma = max(1.5 * cell, 1e-5);
    let density = exp(-(d * d) / (2.0 * sigma * sigma));
    fft_density[fft_idx(gid.x, gid.y, gid.z)] = density;
    if (all(gid == vec3u(0u))) {
        atomicStore(&fft_peak[0], 0u);
    }
}

@compute @workgroup_size(8, 8, 1)
fn cs_fft_axis_seed(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N) {
        return;
    }
    let y = gid.x;
    let z = gid.y;
    var line: array<vec2f, 64>;
    for (var x: u32 = 0u; x < FFT_N; x++) {
        line[x] = vec2f(fft_density[fft_idx(x, y, z)], 0.0);
    }
    fft_1d(&line);
    for (var x: u32 = 0u; x < FFT_N; x++) {
        fft_complex_a[fft_idx(x, y, z)] = line[x];
    }
}

@compute @workgroup_size(8, 8, 1)
fn cs_fft_axis_complex(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= FFT_N || gid.y >= FFT_N) {
        return;
    }
    var line: array<vec2f, 64>;
    if (u.fft_axis < 1.5) {
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
    return length(f) / (f32(FFT_N / 2u) * 1.7320508);
}

@compute @workgroup_size(4, 4, 4)
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

@compute @workgroup_size(4, 4, 4)
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

@group(2) @binding(4) var<storage, read_write> photon_cells_rw: array<Photon>;
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
    rng_state = rng_state * 747796405u + 2891336453u;
    let word = ((rng_state >> ((rng_state >> 28u) + 4u)) ^ rng_state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn rand() -> f32 {
    return f32(pcg_next()) * 2.3283064365386963e-10;
}

fn rand_from(state: ptr<function, u32>) -> f32 {
    *state = *state * 747796405u + 2891336453u;
    let word = ((*state >> ((*state >> 28u) + 4u)) ^ *state) * 277803737u;
    return f32((word >> 22u) ^ word) * 2.3283064365386963e-10;
}

fn rand_seed() -> vec2f {
    return vec2f(rand() * 512.0, rand() * 512.0);
}

const R2_ALPHA = vec2u(3242174889u, 2447445414u);
const R4_ALPHA = vec4u(3679390609u, 3152041523u, 2700274806u, 2313257605u);

fn qmc_r2(n: u32, shift: vec2u) -> vec2f {
    return vec2f(vec2u(n) * R2_ALPHA + shift) * 2.3283064365386963e-10;
}

fn qmc_r4(n: u32, shift: vec4u) -> vec4f {
    return vec4f(vec4u(n) * R4_ALPHA + shift) * 2.3283064365386963e-10;
}

fn sphere_from(xi: vec2f) -> vec3f {
    let z = 1.0 - 2.0 * xi.x;
    let r = sqrt(max(1.0 - z * z, 0.0));
    let phi = xi.y * 6.28318530718;
    return vec3f(r * cos(phi), r * sin(phi), z);
}

fn beam_offset_from(xi: vec2f) -> vec2f {
    let r = sqrt(-log(max(xi.x, 1e-7)));
    let phi = xi.y * 6.28318530718;
    return vec2f(r * cos(phi), r * sin(phi));
}

fn photon_basis(n: vec3f) -> mat2x3f {
    let up = select(vec3f(0.0, 0.0, 1.0), vec3f(1.0, 0.0, 0.0), abs(n.z) > 0.99);
    let tx = normalize(cross(up, n));
    return mat2x3f(tx, cross(n, tx));
}

fn hg_from(dir: vec3f, g: f32, xi: vec2f) -> vec3f {
    var cos_t = 1.0 - 2.0 * xi.x;
    if (abs(g) > 1e-3) {
        let sq = (1.0 - g * g) / (1.0 - g + 2.0 * g * xi.x);
        cos_t = (1.0 + g * g - sq * sq) / (2.0 * g);
    }
    cos_t = clamp(cos_t, -1.0, 1.0);
    let sin_t = sqrt(max(1.0 - cos_t * cos_t, 0.0));
    let phi = xi.y * 6.28318530718;
    let b = photon_basis(dir);
    return normalize(b[0] * (sin_t * cos(phi)) + b[1] * (sin_t * sin(phi)) + dir * cos_t);
}

const PHOTON_FOG_TRACK_STEPS = 256;

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
    if (majorant < 1e-5) {
        return c;
    }

    var t = 0.0;
    for (var i = 0; i < PHOTON_FOG_TRACK_STEPS; i++) {
        t += -log(max(rand(), 1e-7)) / majorant;
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

fn photon_place(ph: Photon, h: u32) {
    let stored = atomicLoad(&photon_counts_rw[h]);
    if (stored == 0u) {
        return;
    }
    let room = min(stored, photon_cap_surface());
    let slot = atomicAdd(&photon_cursor_rw[h], 1u);
    if (slot < room) {
        photon_cells_rw[photon_offsets_rw[h] + slot] = ph;
    }
}

@compute @workgroup_size(64)
fn cs_scatter_photons(@builtin(global_invocation_id) gid: vec3u) {
    if (photon_staging_overflowed() || gid.x >= atomicLoad(&photon_stats_rw[PHOTON_STAT_STAGED])) {
        return;
    }
    var ph = photon_staging_rw[gid.x];
    let h = bitcast<u32>(ph._pad0);
    ph._pad0 = 0.0;
    photon_place(ph, h);
}

fn photon_volume_add(word: u32, value: f32, salt: u32) {
    var h = (salt ^ (word * 0x9e3779b9u)) * 747796405u + 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    let xi = f32((h >> 22u) ^ h) * 2.3283064365386963e-10;
    let v = i32(clamp(floor(value + xi), -2147483000.0, 2147483000.0));
    let lo = u32(v);
    let hi = select(0u, 0xffffffffu, v < 0);
    let old = atomicAdd(&photon_volume_rw[word], lo);
    let carry = select(0u, 1u, old > 0xffffffffu - lo);
    let hi_add = hi + carry;
    if (hi_add != 0u) {
        atomicAdd(&photon_volume_rw[word + 1u], hi_add);
    }
}

fn photon_volume_accumulate(p: vec3f, value: vec3f, dir: vec3f, kind: u32, salt: u32) {
    let inv_unit = 1.0 / max(u.photon_fixed_unit, 1e-30);
    let scaled = value * inv_unit;
    let v = dir * dot(scaled, vec3f(0.2126, 0.7152, 0.0722));

    let edge = photon_grid_edge(kind);
    let q = p / edge - photon_lattice_offset() - vec3f(0.5);
    let base = floor(q);
    let f = q - base;
    let cell0 = vec3i(base);
    let own = vec3i(select(vec3i(0), vec3i(1), f >= vec3f(0.5)));

    for (var i = 0; i < 8; i++) {
        let corner = vec3i(i & 1, (i >> 1) & 1, (i >> 2) & 1);
        let wv = mix(vec3f(1.0) - f, f, vec3f(corner));
        let w = wv.x * wv.y * wv.z;
        if (w < 1e-3) {
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

@compute @workgroup_size(64)
fn cs_alloc_photons(@builtin(global_invocation_id) gid: vec3u) {
    let b = gid.x;
    if (b >= u32(u.photon_table)) {
        return;
    }
    let stored = atomicLoad(&photon_counts_rw[b]);
    if (stored == 0u) {
        return;
    }
    let kind = atomicLoad(&photon_keys_rw[b]) & 3u;
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

fn photon_deposit_volume(origin: vec3f, dir: vec3f, seg_len: f32, power: vec3f, kind: u32) {
    if (u.fog_count < 0.5 || seg_len <= 0.0 || u.photon_pass > 0.5) {
        return;
    }
    var walk_rng = rng_state ^ (bitcast<u32>(seg_len) * 0x9e3779b9u);
    let edge = photon_grid_edge(kind);
    let crossings = 1.0 + seg_len * (abs(dir.x) + abs(dir.y) + abs(dir.z)) / edge;
    let stride = max(i32(ceil(crossings / f32(PHOTON_MAX_DEPOSITS))), 1);
    let phase = min(i32(rand_from(&walk_rng) * f32(stride)), stride - 1);
    let stored_power = power * f32(stride);

    let forward = dir >= vec3f(0.0);
    let moving = abs(dir) > vec3f(1e-9);
    let origin_l = origin - photon_lattice_offset() * edge;
    var cell = vec3i(floor(origin_l / edge));
    let step = select(vec3i(-1), vec3i(1), forward);
    let safe_dir = select(vec3f(1.0), dir, moving);
    let t_delta = select(vec3f(1e30), edge / abs(safe_dir), moving);
    let next_face = (vec3f(cell) + select(vec3f(0.0), vec3f(1.0), forward)) * edge;
    var t_next = select(vec3f(1e30), (next_face - origin_l) / safe_dir, moving);

    var t = 0.0;
    for (var walk = 0; walk < PHOTON_MAX_WALK; walk++) {
        let t_exit = min(min(min(t_next.x, t_next.y), t_next.z), seg_len);
        let len = t_exit - t;
        if (len > 1e-6 && (walk + phase) % stride == 0) {
            let along = rand_from(&walk_rng);
            let at = origin + dir * (t + along * len);
            if (sample_fog(at).extinction >= 0.0005) {
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
    if (light.light_type < 0.5) {
        return PhotonRay(light.position_or_direction, sphere_from(uv));
    }
    let axis = -normalize(light.position_or_direction);
    let b = photon_basis(axis);
    let d = (uv * 2.0 - 1.0) * u.photon_extent;
    return PhotonRay(u.photon_centre - axis * u.photon_extent + b[0] * d.x + b[1] * d.y, axis);
}

fn photon_light_area(light: Light) -> f32 {
    return select(4.0 * u.photon_extent * u.photon_extent, 4.0 * 3.14159265, light.light_type < 0.5);
}

fn photon_aim_pick(li: u32, x: f32, jitter: vec2f) -> vec3f {
    let fx = x * f32(PHOTON_AIM_CELLS);
    let j = min(u32(fx), PHOTON_AIM_CELLS - 1u);
    let base = li * PHOTON_AIM_CELLS;
    let entry = photon_aim_table[base + j];
    let c = select(entry.other, j, fract(fx) < entry.prob);
    let ratio = photon_aim_table[base + c].ratio;
    let cell = vec2f(f32(c % PHOTON_AIM_RES), f32(c / PHOTON_AIM_RES));
    return vec3f((cell + jitter) / f32(PHOTON_AIM_RES), 1.0 / max(ratio, 1e-6));
}

fn photon_emit(light: Light, li: u32, paths: f32, xi: vec4f) -> PhotonEmission {
    var e: PhotonEmission;
    let intensity = light.color * light.brightness;
    let inv_paths = 1.0 / max(paths, 1.0);

    if (light.light_type < 1.5) {
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

    let axis = light.ray_direction / max(length(light.ray_direction), 1e-6);
    let b = photon_basis(axis);
    let g = beam_offset_from(xi.xy);
    let perp = b[0] * g.x + b[1] * g.y;
    e.origin = light.position_or_direction + perp * light.waist;
    e.dir = normalize(axis + perp * tan(clamp(light.spread, 0.0, 1.5)));
    e.power = intensity * (3.14159265 * inv_paths);
    return e;
}

fn photon_emit_sky(paths: f32, xi: vec4f) -> PhotonEmission {
    var e: PhotonEmission;
    let r = max(u.photon_extent, 1e-3);
    let n = sphere_from(xi.xy);
    e.origin = u.photon_centre + n * r;
    e.dir = cosine_hemisphere_from(-n, xi.z, xi.w);
    let area = 4.0 * 3.14159265 * r * r;
    e.power = sky_color(-e.dir) * (3.14159265 * area / max(paths, 1.0));
    return e;
}

fn photon_deposit_rgb(power: Spec, lambda: f32, off: Spec, scale: f32) -> vec3f {
    if (lambda == 0.0 || scale <= 0.0) {
        return spec_to_rgb(power);
    }
    return spec_to_rgb(spec_mul(power, dispersion_weights(spec_mul(off, off), scale)));
}

@compute @workgroup_size(64)
fn cs_photon_aim(@builtin(global_invocation_id) gid: vec3u) {
    let light_count = u32(min(u.light_count, f32(MAX_LIGHTS)));
    let li = gid.x / PHOTON_AIM_CELLS;
    if (li >= light_count) {
        return;
    }
    let light = u.lights[li];
    var w = 0.0;
    if (light.light_type < 1.5) {
        let c = gid.x % PHOTON_AIM_CELLS;
        let cell = vec2f(f32(c % PHOTON_AIM_RES), f32(c / PHOTON_AIM_RES));
        let reach = u.max_dist + max(u.photon_extent, 0.0);
        let fog_count = min(i32(u.fog_count), MAX_FOG_EMITTERS);
        for (var s = 0u; s < 4u; s++) {
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

@compute @workgroup_size(64)
fn cs_clear_photons(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x == 0u) {
        atomicStore(&photon_stats_rw[PHOTON_STAT_POOL], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_NO_BUCKET], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_NO_POOL], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_CELLS_SURFACE], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_CELLS_VOLUME], 0u);
        atomicStore(&photon_stats_rw[PHOTON_STAT_STAGED], 0u);
    }
    if (gid.x >= u32(u.photon_table)) {
        return;
    }
    atomicStore(&photon_counts_rw[gid.x], 0u);
    atomicStore(&photon_keys_rw[gid.x], 0u);
    atomicStore(&photon_cursor_rw[gid.x], 0u);
    photon_offsets_rw[gid.x] = 0u;
    let base = gid.x * PHOTON_VOLUME_WORDS;
    for (var w = 0u; w < PHOTON_VOLUME_WORDS; w++) {
        atomicStore(&photon_volume_rw[base + w], 0u);
    }
}

@compute @workgroup_size(64)
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
    rng_state = pcg_next() ^ (u32(max(u.photon_seed, 0.0)) * 2654435761u);
    rng_state = pcg_next();

    let li = index % emitter_count;
    let paths = f32((total - li + emitter_count - 1u) / emitter_count);

    let seq = index / emitter_count;
    var shift_state = (u32(max(u.photon_seed, 0.0)) * 2654435761u) ^ (li * 40503u + 0x9e3779b9u);
    var shift = vec4u(0u);
    var shift2 = vec2u(0u);
    for (var d = 0u; d < 6u; d++) {
        shift_state = shift_state * 747796405u + 2891336453u;
        let word = ((shift_state >> ((shift_state >> 28u) + 4u)) ^ shift_state) * 277803737u;
        if (d < 4u) {
            shift[d] = (word >> 22u) ^ word;
        } else {
            shift2[d - 4u] = (word >> 22u) ^ word;
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
    if (max(emission.power.r, max(emission.power.g, emission.power.b)) < 1e-9) {
        return;
    }
    spectral_setup(xi_spectrum.x);
    let dispersion_pick = min(i32(xi_spectrum.y * SPECTRAL_COUNT), i32(SPECTRAL_COUNT) - 1);
    var power = spec_from_rgb(emission.power);

    let bounces = clamp(i32(u.light_bounces), 0, 16);
    var bounces_left = bounces;
    var glass_left = PATH_TRANSPARENCY_FLOOR;

    var in_solid = false;
    var inner_steps = 64;
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
            let ins = march_inside(origin, dir, inner_steps, 0.004);
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
            if (survive < 1e-4 || rand() >= survive) {
                break;
            }
            power = spec_scale(spec_mul(power, spec_from_rgb(albedo)), 1.0 / survive);
            if (spec_max(power) < 1e-6) {
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

        if (lambda == 0.0 && mat.abbe > 0.5) {
            lambda = spec_lambda_um(dispersion_pick);
            if (soft <= 0.0) {
                power = spec_mul(power, spec_collapse_mask(dispersion_pick));
            }
        }

        if (scatters >= 1 && !in_solid) {
            let kind = select(PHOTON_GRID_SURFACE, PHOTON_GRID_BOUNCE, diffuse);
            let rgb = photon_deposit_rgb(power, lambda, disp_off, soft * 0.5 * photon_grid_edge(kind));
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
        if (spec_max(power) < 1e-6) {
            break;
        }

        if (sc.kind == SCATTER_TRANSMIT) {
            in_solid = !in_solid;
            if (in_solid) {
                inner_steps = clamp(i32(mat.inner_max_steps), 4, 512);
            }
        }
        if (sc.kind == SCATTER_DIFFUSE) {
            diffuse = true;
            disp_ang = spec_splat(0.0);
        } else {
            disp_ang = Spec(sqrt(disp_ang.lo * disp_ang.lo + sc.disp_ang2.lo),
                            sqrt(disp_ang.hi * disp_ang.hi + sc.disp_ang2.hi));
        }

        let bias = max(0.004, 2.0 * march_epsilon(hit_t));
        origin = hit_pos + sc.dir * bias;
        dir = sc.dir;
        scatters++;
    }
}
