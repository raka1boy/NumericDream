// @param Threshold min=0.0 max=8.0 default=1.0
// @param Intensity min=0.0 max=3.0 default=0.6
// @param Radius (px) min=1.0 max=64.0 default=18.0
// @param Taps min=8 max=48 default=24 int
fn bright_pass(c: vec3f, threshold: f32) -> vec3f {
    return max(c - vec3f(threshold), vec3f(0.0));
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    return vec4f(sin(color.rgb * p[1]), color.a);
}
