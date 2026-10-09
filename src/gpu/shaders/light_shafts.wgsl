const SHAFT_SAMPLES = 48;
const SHAFT_DECAY = 0.965;
const SHAFT_FALLOFF = 2.5;
const SHAFT_MIN_AHEAD = 1e-4;
const SHAFT_MIN_AXIS_LEN_SQ = 1e-8;
const SHAFT_MIN_ASPECT = 1e-4;
const SHAFT_MIN_LIGHT_DIST = 1e-6;
const SHAFT_INFINITE_DISTANCE = 1e30;
const SHAFT_FADE_START = 0.02;
const SHAFT_FADE_END = 0.2;

fn shaft_light_uv(world_dir: vec3f) -> vec3f {
    let ahead = dot(world_dir, pp.camera_forward);
    let v = world_dir / max(ahead, SHAFT_MIN_AHEAD);
    let a = dot(v, pp.camera_right) / max(dot(pp.camera_right, pp.camera_right), SHAFT_MIN_AXIS_LEN_SQ);
    let b = dot(v, pp.camera_up) / max(dot(pp.camera_up, pp.camera_up), SHAFT_MIN_AXIS_LEN_SQ);
    let full = vec2f(a / max(pp.aspect, SHAFT_MIN_ASPECT), -b);
    let ndc = (full - pp.tile_bias) / pp.tile_scale;
    return vec3f(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5, ahead);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let strength = p[3];
    let directional = p[7] > 0.5;
    let light_ref = vec3f(p[0], p[1], p[2]);
    let to_light = select(light_ref - pp.camera_pos, light_ref, directional);
    let len = length(to_light);
    if (strength <= 0.0 || len < SHAFT_MIN_LIGHT_DIST) {
        return color;
    }
    let ldir = to_light / len;
    let light_dist = select(len, SHAFT_INFINITE_DISTANCE, directional);
    let lp = shaft_light_uv(ldir);
    if (lp.z <= SHAFT_FADE_START) {
        return color;
    }

    let delta = lp.xy - uv;
    let jitter = pixel_noise(uv);
    var illum = 0.0;
    var total = 0.0;
    var weight = 1.0;
    for (var i = 0; i < SHAFT_SAMPLES; i++) {
        let s_uv = uv + delta * ((f32(i) + jitter) / f32(SHAFT_SAMPLES));
        var lit = 1.0;
        if (all(s_uv >= vec2f(0.0)) && all(s_uv <= vec2f(1.0))) {
            let d = scene_depth(s_uv);
            lit = select(1.0, 0.0, d > 0.0 && d < light_dist);
        }
        illum += lit * weight;
        total += weight;
        weight *= SHAFT_DECAY;
    }

    let screen_dist = length(delta * vec2f(pp.aspect, 1.0));
    let falloff = exp(-screen_dist * SHAFT_FALLOFF) * smoothstep(SHAFT_FADE_START, SHAFT_FADE_END, lp.z);
    let shaft = vec3f(p[4], p[5], p[6]) * (strength * falloff * illum / total);
    return vec4f(color.rgb + shaft, color.a);
}
