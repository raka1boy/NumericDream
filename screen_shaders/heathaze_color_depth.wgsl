// @param Strength (px) min=0.0 max=24.0 default=6.0
// @param Scale min=1.0 max=40.0 default=10.0
// @param Rise speed min=0.0 max=4.0 default=1.0
// @param Turbulence min=1 max=5 default=3 int
// @param Vertical stretch min=1.0 max=8.0 default=3.0
// @param Distance start min=0.0 max=40.0 default=0.0
// @param Distance full min=0.1 max=80.0 default=12.0
// @param Sky shimmer min=0.0 max=1.0 default=1.0

const HH_MAX_OCTAVES = 5;
const HH_LACUNARITY = 2.07;
const HH_HASH_SCALE = 0.1031;
const HH_HASH_OFFSET = 31.32;
const HH_GAIN = 0.5;
const HH_EPS = 1e-5;
const HH_MIN_RANGE = 1e-3;
const HH_MIN_OFFSET = 1e-4;
const HH_RISE_STRETCH = 2.0;
const HH_Y_NOISE_OFFSET = vec3f(17.31, 5.77, 41.13);
const HH_VERTICAL_SCALE = 0.6;

fn hh_hash13(p: vec3f) -> f32 {
    var p3 = fract(p * HH_HASH_SCALE);
    p3 += dot(p3, p3.zyx + vec3f(HH_HASH_OFFSET));
    return fract((p3.x + p3.y) * p3.z);
}

fn hh_noise3(p: vec3f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);

    let n000 = hh_hash13(i);
    let n100 = hh_hash13(i + vec3f(1.0, 0.0, 0.0));
    let n010 = hh_hash13(i + vec3f(0.0, 1.0, 0.0));
    let n110 = hh_hash13(i + vec3f(1.0, 1.0, 0.0));
    let n001 = hh_hash13(i + vec3f(0.0, 0.0, 1.0));
    let n101 = hh_hash13(i + vec3f(1.0, 0.0, 1.0));
    let n011 = hh_hash13(i + vec3f(0.0, 1.0, 1.0));
    let n111 = hh_hash13(i + vec3f(1.0, 1.0, 1.0));

    let x00 = mix(n000, n100, u.x);
    let x10 = mix(n010, n110, u.x);
    let x01 = mix(n001, n101, u.x);
    let x11 = mix(n011, n111, u.x);
    return mix(mix(x00, x10, u.y), mix(x01, x11, u.y), u.z);
}

fn hh_fbm(p: vec3f, octaves: i32) -> f32 {
    var sum = 0.0;
    var norm = 0.0;
    var amp = HH_GAIN;
    var freq = 1.0;
    for (var i = 0; i < octaves; i++) {
        sum += amp * hh_noise3(p * freq);
        norm += amp;
        amp *= HH_GAIN;
        freq *= HH_LACUNARITY;
    }
    return sum / max(norm, HH_EPS);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let d = scene_depth(uv);
    let dist = select(pp.max_dist, d, d > 0.0);

    var ramp = smoothstep(p[5], max(p[6], p[5] + HH_MIN_RANGE), dist);
    if (d <= 0.0) {
        ramp *= p[7];
    }
    if (ramp * p[0] <= HH_MIN_OFFSET) {
        return color;
    }

    let rise = pp.time * p[2];
    let q = vec3f(
        uv.x * p[1] * max(pp.aspect, 1.0),
        uv.y * p[1] / max(p[4], 1.0) - rise * HH_RISE_STRETCH,
        rise,
    );
    let octaves = i32(clamp(p[3], 1.0, f32(HH_MAX_OCTAVES)));
    let nx = hh_fbm(q, octaves) * 2.0 - 1.0;
    let ny = hh_fbm(q + HH_Y_NOISE_OFFSET, octaves) * 2.0 - 1.0;

    let offset = vec2f(nx, ny * HH_VERTICAL_SCALE) * p[0] * ramp * texel_size();
    return vec4f(scene_sample(uv + offset).rgb, color.a);
}
