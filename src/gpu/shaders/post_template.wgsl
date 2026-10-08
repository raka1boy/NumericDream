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
    params0: vec4f,
    params1: vec4f,
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

fn luminance(c: vec3f) -> f32 {
    return dot(c, vec3f(0.2126, 0.7152, 0.0722));
}

fn hash12(p: vec2f) -> f32 {
    var p3 = fract(vec3f(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn pixel_noise(uv: vec2f) -> f32 {
    return hash12(uv * pp.resolution + vec2f(pp.time * 61.7 + pp.slot * 13.1, pp.frame * 0.618));
}

@@EFFECT@@

@fragment
fn fs_post(in: VertexOut) -> @location(0) vec4f {
    let p = array<f32, 8>(
        pp.params0.x, pp.params0.y, pp.params0.z, pp.params0.w,
        pp.params1.x, pp.params1.y, pp.params1.z, pp.params1.w,
    );
    return effect(in.uv, scene_sample(in.uv), p);
}
