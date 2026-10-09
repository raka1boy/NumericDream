// @param Glow min=0.0 max=1.0 default=0.35
// @param Glow radius (px) min=2.0 max=96.0 default=28.0
// @param Halation min=0.0 max=3.0 default=0.8
// @param Halation threshold min=0.0 max=4.0 default=0.6
// @param Halation hue min=0.0 max=1.0 default=0.95
// @param Soft focus (px) min=0.0 max=6.0 default=1.5
// @param Drift min=0.0 max=1.0 default=0.3
// @param Taps min=12 max=64 default=32 int

const DG_GOLDEN_ANGLE = 2.39996323;
const DG_TAU = 6.28318531;
const DG_SOFT_MIX = 0.6;
const DG_KNEE_RATIO = 0.5;
const DG_MIN_KNEE = 1e-3;
const DG_EPS = 1e-4;
const DG_MIN_TAPS = 4.0;
const DG_MAX_TAPS = 64.0;
const DG_SOFT_TAPS = 8;
const DG_SOFT_ANGLE_OFFSET = 0.39;
const DG_BREATHE_AMOUNT = 0.15;
const DG_BREATHE_RATE = 0.47;
const DG_EDGE_WEIGHT_FALLOFF = 0.9;
const DG_DRIFT_SCALE = 2.5;
const DG_DRIFT_VELOCITY_X = 0.07;
const DG_DRIFT_VELOCITY_Y = -0.05;
const DG_DRIFT_AMOUNT = 0.6;
const DG_TINT_SATURATION = 0.5;

fn dg_hue(h: f32) -> vec3f {
    return clamp(abs(fract(vec3f(h) + vec3f(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3f(3.0)) - vec3f(1.0), vec3f(0.0), vec3f(1.0));
}

fn dg_bright(c: vec3f, threshold: f32) -> vec3f {
    let l = luminance(c);
    let knee = max(threshold * DG_KNEE_RATIO, DG_MIN_KNEE);
    let s = clamp(l - threshold + knee, 0.0, 2.0 * knee);
    let contrib = max(s * s / (4.0 * knee), l - threshold);
    return c * (contrib / max(l, DG_EPS));
}

fn dg_vnoise(x: vec2f) -> f32 {
    let i = floor(x);
    let f = fract(x);
    let u = f * f * (vec2f(3.0) - 2.0 * f);
    let a = hash12(i);
    let b = hash12(i + vec2f(1.0, 0.0));
    let c = hash12(i + vec2f(0.0, 1.0));
    let d = hash12(i + vec2f(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();
    let taps = i32(clamp(p[7], DG_MIN_TAPS, DG_MAX_TAPS));

    var base = max(color.rgb, vec3f(0.0));
    if (p[5] > 0.0) {
        var ring = vec3f(0.0);
        for (var k = 0; k < DG_SOFT_TAPS; k++) {
            let a = f32(k) * (DG_TAU / f32(DG_SOFT_TAPS)) + DG_SOFT_ANGLE_OFFSET;
            ring += max(scene_color(uv + vec2f(cos(a), sin(a)) * p[5] * texel), vec3f(0.0));
        }
        base = mix(base, ring / f32(DG_SOFT_TAPS), DG_SOFT_MIX);
    }

    let radius = p[1] * (1.0 + DG_BREATHE_AMOUNT * p[6] * sin(pp.time * DG_BREATHE_RATE));
    var soft = vec3f(0.0);
    var halo = vec3f(0.0);
    var wsum = 0.0;
    for (var i = 0; i < taps; i++) {
        let fi = f32(i) + 0.5;
        let frac = sqrt(fi / f32(taps));
        let angle = fi * DG_GOLDEN_ANGLE;
        let s = max(scene_color(uv + vec2f(cos(angle), sin(angle)) * frac * radius * texel), vec3f(0.0));
        let w = 1.0 - frac * DG_EDGE_WEIGHT_FALLOFF;
        soft += s * w;
        wsum += w;
        halo += dg_bright(s, p[3]);
    }
    soft /= max(wsum, DG_EPS);
    halo /= f32(taps);

    let aspect = pp.resolution.x / max(pp.resolution.y, 1.0);
    let field = dg_vnoise(uv * vec2f(aspect, 1.0) * DG_DRIFT_SCALE + vec2f(pp.time * DG_DRIFT_VELOCITY_X, pp.time * DG_DRIFT_VELOCITY_Y));
    let drift = 1.0 + p[6] * DG_DRIFT_AMOUNT * (field * 2.0 - 1.0);

    let tint_raw = mix(vec3f(1.0), dg_hue(p[4]), DG_TINT_SATURATION);
    let tint = tint_raw / max(luminance(tint_raw), DG_EPS);

    let orton = soft * p[0] * drift;
    var out_c = base + orton + base * orton;
    out_c += halo * tint * p[2] * drift;

    return vec4f(out_c, color.a);
}
