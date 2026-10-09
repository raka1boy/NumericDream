// @param Depth sensitivity min=0.0 max=2.0 default=0.35
// @param Crease sensitivity min=0.0 max=4.0 default=1.2
// @param Thickness (px) min=1.0 max=6.0 default=1.0
// @param Darkness min=0.0 max=1.0 default=0.85
// @param Fill fade min=0.0 max=1.0 default=0.0

const OUTLINE_NEIGHBORS = 4;
const OUTLINE_MIN_DEPTH = 1e-3;
const OUTLINE_DEPTH_GAIN = 8.0;

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let step_uv = texel_size() * max(p[2], 1.0);
    let centre_depth = scene_depth(uv);
    if (centre_depth <= 0.0) {
        return color;
    }
    let centre_normal = scene_normal(uv);

    var depth_edge = 0.0;
    var normal_edge = 0.0;
    let offsets = array<vec2f, OUTLINE_NEIGHBORS>(
        vec2f(step_uv.x, 0.0),
        vec2f(-step_uv.x, 0.0),
        vec2f(0.0, step_uv.y),
        vec2f(0.0, -step_uv.y),
    );
    for (var i = 0; i < OUTLINE_NEIGHBORS; i++) {
        let n_uv = uv + offsets[i];
        let d = scene_depth(n_uv);
        let dd = select(pp.max_dist, d, d > 0.0);
        depth_edge = max(depth_edge, abs(dd - centre_depth) / max(centre_depth, OUTLINE_MIN_DEPTH));
        normal_edge = max(normal_edge, 1.0 - dot(centre_normal, scene_normal(n_uv)));
    }

    let edge = clamp(depth_edge * p[0] * OUTLINE_DEPTH_GAIN + normal_edge * p[1], 0.0, 1.0);
    let faded = mix(color.rgb, vec3f(luminance(color.rgb)), p[4]);
    return vec4f(faded * (1.0 - edge * p[3]), color.a);
}
