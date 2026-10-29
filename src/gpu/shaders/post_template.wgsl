const MAX_PARAMS = 16;
const PARAM_VEC4S = 4;

alias Params = array<f32, MAX_PARAMS>;

struct PostUniforms {
    resolution: vec2f,
    time: f32,
    frame: f32,
    camera_pos: vec3f,
    max_dist: f32,
    camera_right: vec3f,
    aspect: f32,
    camera_up: vec3f,
    slot: f32,
    camera_forward: vec3f,
    _pad1: f32,
    tile_scale: vec2f,
    tile_bias: vec2f,
    params: array<vec4f, PARAM_VEC4S>,
}

@group(0) @binding(0) var<uniform> pp: PostUniforms;
@group(0) @binding(1) var scene_samp: sampler;
@group(0) @binding(2) var scene_tex: texture_2d<f32>;
@group(0) @binding(3) var depth_tex: texture_2d<f32>;
@group(0) @binding(4) var normal_tex: texture_2d<f32>;

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
    out.uv = vec2f(p.x * 0.5 + 0.5, 1.0 - (p.y * 0.5 + 0.5));
    return out;
}

fn texel_size() -> vec2f {
    return 1.0 / max(pp.resolution, vec2f(1.0));
}

fn clamp_uv(uv: vec2f) -> vec2f {
    return clamp(uv, vec2f(0.0), vec2f(1.0));
}

fn scene_sample(uv: vec2f) -> vec4f {
    return textureSampleLevel(scene_tex, scene_samp, clamp_uv(uv), 0.0);
}

fn scene_color(uv: vec2f) -> vec3f {
    return scene_sample(uv).rgb;
}

fn gbuffer_coord(uv: vec2f) -> vec2i {
    let dims = vec2f(textureDimensions(depth_tex));
    return vec2i(clamp(floor(clamp_uv(uv) * dims), vec2f(0.0), dims - vec2f(1.0)));
}

fn scene_depth(uv: vec2f) -> f32 {
    return textureLoad(depth_tex, gbuffer_coord(uv), 0).r;
}

fn scene_hit(uv: vec2f) -> bool {
    return scene_depth(uv) > 0.0;
}

fn scene_normal(uv: vec2f) -> vec3f {
    return textureLoad(normal_tex, gbuffer_coord(uv), 0).xyz;
}

fn view_ray(uv: vec2f) -> vec3f {
    let ndc = vec2f(clamp_uv(uv).x * 2.0 - 1.0, 1.0 - clamp_uv(uv).y * 2.0);
    let full = ndc * pp.tile_scale + pp.tile_bias;
    return normalize(pp.camera_forward + full.x * pp.aspect * pp.camera_right - full.y * pp.camera_up);
}

fn world_pos(uv: vec2f) -> vec3f {
    return pp.camera_pos + view_ray(uv) * scene_depth(uv);
}

const POST_LUMA_WEIGHTS = vec3f(0.2126, 0.7152, 0.0722);
const POST_HASH_SCALE = 0.1031;
const POST_HASH_OFFSET = 33.33;
const POST_NOISE_TIME_RATE = 61.7;
const POST_NOISE_SLOT_RATE = 13.1;
const POST_NOISE_FRAME_RATE = 0.618;

fn luminance(c: vec3f) -> f32 {
    return dot(c, POST_LUMA_WEIGHTS);
}

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * POST_HASH_SCALE);
    p3 += dot(p3, p3.yzx + POST_HASH_OFFSET);
    return fract((p3.x + p3.y) * p3.z);
}

fn pixel_noise(uv: vec2f) -> f32 {
    return hash12(uv * pp.resolution + vec2f(pp.time * POST_NOISE_TIME_RATE + pp.slot * POST_NOISE_SLOT_RATE, pp.frame * POST_NOISE_FRAME_RATE));
}

struct GlyphInfo {
    field_start: vec4u,
    field_len: vec4u,
    aspect: f32,
    count: u32,
    cols: u32,
    mips: u32,
    ink: array<vec4f, 16>,
    colour: array<vec4u, 16>,
}

@group(1) @binding(0) var<uniform> glyph_info: GlyphInfo;
@group(1) @binding(1) var glyph_atlas: texture_2d<f32>;
@group(1) @binding(2) var glyph_samp: sampler;

const GLYPH_CELL_PX = 64.0;
const GLYPH_FIELDS = 4u;
const GLYPH_NONE = 0xffffffffu;

fn text_length(field: u32) -> u32 {
    if (field >= GLYPH_FIELDS) { return 0u; }
    return glyph_info.field_len[field];
}

fn text_glyph(field: u32, i: u32) -> u32 {
    let n = text_length(field);
    if (n == 0u) { return GLYPH_NONE; }
    return glyph_info.field_start[field] + min(i, n - 1u);
}

fn glyph_count() -> u32 {
    return glyph_info.count;
}

fn glyph_aspect() -> f32 {
    return glyph_info.aspect;
}

fn glyph_ink(g: u32) -> f32 {
    if (g >= glyph_info.count) { return 0.0; }
    return glyph_info.ink[g / 4u][g % 4u];
}

fn glyph_is_colour(g: u32) -> bool {
    if (g >= glyph_info.count) { return false; }
    return glyph_info.colour[g / 4u][g % 4u] != 0u;
}

fn glyph_sample(g: u32, uv: vec2f, size_px: f32) -> vec4f {
    if (g >= glyph_info.count || any(uv < vec2f(0.0)) || any(uv > vec2f(1.0))) {
        return vec4f(0.0);
    }
    let lod = clamp(log2(GLYPH_CELL_PX / max(size_px, 1.0)), 0.0, f32(glyph_info.mips - 1u));
    let atlas_px = vec2f(textureDimensions(glyph_atlas));
    let cell = vec2f(f32(g % glyph_info.cols), f32(g / glyph_info.cols));
    let half_texel = 0.5 * exp2(ceil(lod)) / GLYPH_CELL_PX;
    let inner = clamp(uv, vec2f(half_texel), vec2f(1.0 - half_texel));
    return textureSampleLevel(glyph_atlas, glyph_samp, (cell + inner) * GLYPH_CELL_PX / atlas_px, lod);
}

@@EFFECT@@

@fragment
fn fs_post(in: VertexOut) -> @location(0) vec4f {
    let v = pp.params;
    let p = Params(
        v[0].x, v[0].y, v[0].z, v[0].w,
        v[1].x, v[1].y, v[1].z, v[1].w,
        v[2].x, v[2].y, v[2].z, v[2].w,
        v[3].x, v[3].y, v[3].z, v[3].w,
    );
    return effect(in.uv, scene_sample(in.uv), p);
}
