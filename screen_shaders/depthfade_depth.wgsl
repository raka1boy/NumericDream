// @param Start min=0.0 max=40.0 default=2.0
// @param End min=0.1 max=80.0 default=20.0
// @param Density min=0.0 max=1.0 default=0.8
// @param Fog red min=0.0 max=4.0 default=0.35
// @param Fog green min=0.0 max=4.0 default=0.45
// @param Fog blue min=0.0 max=4.0 default=0.6

const DEPTHFADE_MIN_RANGE = 1e-3;

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let d = scene_depth(uv);
    let dist = select(pp.max_dist, d, d > 0.0);

    let amount = smoothstep(p[0], max(p[1], p[0] + DEPTHFADE_MIN_RANGE), dist) * p[2];
    let fog = vec3f(p[3], p[4], p[5]);

    return vec4f(mix(color.rgb, fog, amount), color.a);
}
