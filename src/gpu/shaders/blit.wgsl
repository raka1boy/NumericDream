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

@group(0) @binding(0) var src_sampler: sampler;
@group(0) @binding(1) var src_texture: texture_2d<f32>;

const DOF_BLUR_MIN_PX = 0.4;
const DOF_BLUR_MAX_PX = 24.0;
const DOF_BLUR_TAPS = 16;
const DOF_BLUR_GOLDEN_ANGLE = 2.39996323;

fn dof_blur(uv: vec2f, radius_px: f32) -> vec3f {
    let texel = 1.0 / vec2f(textureDimensions(src_texture));
    var accum = textureSampleLevel(src_texture, src_sampler, uv, 0.0).rgb;
    var total = 1.0;
    for (var i = 0; i < DOF_BLUR_TAPS; i++) {
        let fi = f32(i) + 0.5;
        let angle = fi * DOF_BLUR_GOLDEN_ANGLE;
        let frac = sqrt(fi / f32(DOF_BLUR_TAPS));
        let offset = vec2f(cos(angle), sin(angle)) * frac * radius_px * texel;
        accum += textureSampleLevel(src_texture, src_sampler, uv + offset, 0.0).rgb;
        total += 1.0;
    }
    return accum / total;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    let hdr = textureSampleLevel(src_texture, src_sampler, in.uv, 0.0);
    let radius_px = min(hdr.a, DOF_BLUR_MAX_PX);
    var color = hdr.rgb;
    if (radius_px > DOF_BLUR_MIN_PX) {
        color = dof_blur(in.uv, radius_px);
    }

    let tonemapped = color / (color + vec3f(1.0));
    return vec4f(tonemapped, 1.0);
}
