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

fn dg_hue(h: f32) -> vec3f {
    return clamp(abs(fract(vec3f(h) + vec3f(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3f(3.0)) - vec3f(1.0), vec3f(0.0), vec3f(1.0));
}

fn dg_bright(c: vec3f, threshold: f32) -> vec3f {
    let l = luminance(c);
    let knee = max(threshold * 0.5, 1e-3);
    let s = clamp(l - threshold + knee, 0.0, 2.0 * knee);
    let contrib = max(s * s / (4.0 * knee), l - threshold);
    return c * (contrib / max(l, 1e-4));
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
    let taps = i32(clamp(p[7], 4.0, 64.0));

    var base = max(color.rgb, vec3f(0.0));
    if (p[5] > 0.0) {
        var ring = vec3f(0.0);
        for (var k = 0; k < 8; k++) {
            let a = f32(k) * (DG_TAU / 8.0) + 0.39;
            ring += max(scene_color(uv + vec2f(cos(a), sin(a)) * p[5] * texel), vec3f(0.0));
        }
        base = mix(base, ring / 8.0, DG_SOFT_MIX);
    }

    let radius = p[1] * (1.0 + 0.15 * p[6] * sin(pp.time * 0.47));
    var soft = vec3f(0.0);
    var halo = vec3f(0.0);
    var wsum = 0.0;
    for (var i = 0; i < taps; i++) {
        let fi = f32(i) + 0.5;
        let frac = sqrt(fi / f32(taps));
        let angle = fi * DG_GOLDEN_ANGLE;
        let s = max(scene_color(uv + vec2f(cos(angle), sin(angle)) * frac * radius * texel), vec3f(0.0));
        let w = 1.0 - frac * 0.9;
        soft += s * w;
        wsum += w;
        halo += dg_bright(s, p[3]);
    }
    soft /= max(wsum, 1e-4);
    halo /= f32(taps);

    let aspect = pp.resolution.x / max(pp.resolution.y, 1.0);
    let field = dg_vnoise(uv * vec2f(aspect, 1.0) * 2.5 + vec2f(pp.time * 0.07, pp.time * -0.05));
    let drift = 1.0 + p[6] * 0.6 * (field * 2.0 - 1.0);

    let tint_raw = mix(vec3f(1.0), dg_hue(p[4]), 0.5);
    let tint = tint_raw / max(luminance(tint_raw), 1e-4);

    let orton = soft * p[0] * drift;
    var out_c = base + orton + base * orton;
    out_c += halo * tint * p[2] * drift;

    return vec4f(out_c, color.a);
}
