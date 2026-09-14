struct Uniforms {
    projection: mat4x4f,
}

@group(0) @binding(0) var<uniform> u: Uniforms;
@group(0) @binding(1) var font_sampler: sampler;
@group(0) @binding(2) var font_texture: texture_2d<f32>;

struct VertexIn {
    @location(0) position: vec2f,
    @location(1) uv: vec2f,
    @location(2) color: vec4f,
}

struct VertexOut {
    @builtin(position) clip_pos: vec4f,
    @location(0) uv: vec2f,
    @location(1) color: vec4f,
}

@vertex
fn vs_main(in: VertexIn) -> VertexOut {
    var out: VertexOut;
    out.clip_pos = u.projection * vec4f(in.position, 0.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    let tex_alpha = textureSample(font_texture, font_sampler, in.uv).r;
    return vec4f(in.color.rgb, in.color.a * tex_alpha);
}
