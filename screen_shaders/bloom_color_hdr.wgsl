// @param Threshold min=0.0 max=8.0 default=1.0
// @param Intensity min=0.0 max=3.0 default=0.6
// @param Radius (px) min=1.0 max=64.0 default=18.0
// @param Taps min=8 max=48 default=24 int

const GOLDEN_ANGLE = 2.39996323;
const BLOOM_MIN_TAPS = 4.0;
const BLOOM_MAX_TAPS = 48.0;
const BLOOM_MIN_WEIGHT = 1e-4;

fn bright_pass(c: vec3f, threshold: f32) -> vec3f {
    return max(c - vec3f(threshold), vec3f(0.0));
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();
    let taps = i32(clamp(p[3], BLOOM_MIN_TAPS, BLOOM_MAX_TAPS));

    var glow = vec3f(0.0);
    var weight_sum = 0.0;
    for (var i = 0; i < taps; i++) {
        let fi = f32(i) + 0.5;
        let angle = fi * GOLDEN_ANGLE;
        let frac = sqrt(fi / f32(taps));
        let offset = vec2f(cos(angle), sin(angle)) * frac * p[2] * texel;
        let w = 1.0 - frac;
        glow += bright_pass(scene_color(uv + offset), p[0]) * w;
        weight_sum += w;
    }
    glow /= max(weight_sum, BLOOM_MIN_WEIGHT);

    return vec4f(color.rgb + glow * p[1], color.a);
}
