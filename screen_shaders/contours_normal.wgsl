// @param Source min=0 max=3 default=0 int
// @param Bands min=2 max=64 default=18
// @param Offset min=0.0 max=1.0 default=0.0
// @param Line width min=0.0 max=0.5 default=0.08
// @param Min width (px) min=0.5 max=4.0 default=1.0
// @param Line brightness min=0.0 max=10.0 default=3.0
// @param Fill brightness min=0.0 max=1.0 default=0.01
// @param Scene mix min=0.0 max=1.0 default=0.0

fn contour_value(uv: vec2f, n: vec3f, source: i32) -> f32 {
    switch source {
        case 1: { return n.x * 0.5 + 0.5; }
        case 2: { return n.y * 0.5 + 0.5; }
        case 3: { return n.z * 0.5 + 0.5; }
        default: { return clamp(dot(n, -view_ray(uv)), 0.0, 1.0); }
    }
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let centre_depth = scene_depth(uv);
    if (centre_depth <= 0.0) {
        return color;
    }
    let source = i32(round(p[0]));
    let bands = max(p[1], 1.0);
    let t = contour_value(uv, scene_normal(uv), source) * bands + p[2];

    let ts = texel_size();
    let offsets = array<vec2f, 4>(
        vec2f(ts.x, 0.0),
        vec2f(-ts.x, 0.0),
        vec2f(0.0, ts.y),
        vec2f(0.0, -ts.y),
    );
    var grad = 0.0;
    for (var i = 0; i < 4; i++) {
        let n_uv = uv + offsets[i];
        let d = scene_depth(n_uv);
        if (d <= 0.0 || abs(d - centre_depth) > centre_depth * 0.05) {
            continue;
        }
        let tn = contour_value(n_uv, scene_normal(n_uv), source) * bands + p[2];
        grad = max(grad, abs(tn - t));
    }
    grad = max(grad, 1e-5);

    let dist = abs(fract(t + 0.5) - 0.5);
    let half_w = max(p[3] * 0.5, grad * p[4] * 0.5);
    let sharp = clamp((half_w - dist) / grad + 0.5, 0.0, 1.0);
    let average = min(half_w * 2.0, 1.0);
    let coverage = mix(average, sharp, 1.0 - smoothstep(0.25, 0.5, grad));

    let base = mix(vec3f(p[6]), color.rgb, p[7]);
    return vec4f(mix(base, vec3f(p[5]), coverage), color.a);
}
