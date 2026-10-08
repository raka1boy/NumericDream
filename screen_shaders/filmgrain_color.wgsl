// @param Aberration (px) min=0.0 max=12.0 default=2.0
// @param Grain min=0.0 max=0.5 default=0.06
// @param Grain in shadows min=0.0 max=1.0 default=0.7

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();
    let dir = (uv - vec2f(0.5)) * 2.0;
    let shift = dir * p[0] * texel;

    var c = vec3f(
        scene_color(uv + shift).r,
        color.rgb.g,
        scene_color(uv - shift).b,
    );

    let dark = mix(1.0, 1.0 - clamp(luminance(c), 0.0, 1.0), p[2]);
    c += (pixel_noise(uv) - 0.5) * 2.0 * p[1] * dark;

    return vec4f(max(c, vec3f(0.0)), color.a);
}
