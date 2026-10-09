// @param Exposure min=0.25 max=4.0 default=1.4
// @param Fade min=0.0 max=0.5 default=0.12
// @param Contrast min=0.3 max=1.5 default=0.8
// @param Pastel min=0.0 max=1.0 default=0.5
// @param Shadow hue min=0.0 max=1.0 default=0.72
// @param Highlight hue min=0.0 max=1.0 default=0.08
// @param Split tone min=0.0 max=1.0 default=0.35
// @param Grain min=0.0 max=0.2 default=0.03

const DR_GAMMA = 2.2;
const DR_CONTRAST_PIVOT = 0.5;
const DR_PASTEL_LIFT = 0.6;
const DR_PASTEL_DESATURATE = 0.55;
const DR_EPS = 1e-5;
const DR_SPLIT_TONE_SCALE = 0.25;
const DR_MAX_LDR = 0.9995;

fn dr_hue(h: f32) -> vec3f {
    return clamp(abs(fract(vec3f(h) + vec3f(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3f(3.0)) - vec3f(1.0), vec3f(0.0), vec3f(1.0));
}

fn dr_chroma(h: f32) -> vec3f {
    let c = dr_hue(h);
    return c - vec3f(luminance(c));
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let hdr = max(color.rgb, vec3f(0.0)) * p[0];
    var d = pow(hdr / (hdr + vec3f(1.0)), vec3f(1.0 / DR_GAMMA));

    d = clamp((d - vec3f(DR_CONTRAST_PIVOT)) * p[2] + vec3f(DR_CONTRAST_PIVOT), vec3f(0.0), vec3f(1.0));

    let l = luminance(d);
    let lifted = mix(l, 1.0 - (1.0 - l) * (1.0 - l), p[3] * DR_PASTEL_LIFT);
    var chroma = (d - vec3f(l)) * (1.0 - p[3] * DR_PASTEL_DESATURATE);
    let hi = max(max(chroma.r, chroma.g), chroma.b);
    let lo = min(min(chroma.r, chroma.g), chroma.b);
    let fit = min(1.0, min((1.0 - lifted) / max(hi, DR_EPS), lifted / max(-lo, DR_EPS)));
    chroma *= max(fit, 0.0);
    d = vec3f(lifted) + chroma;

    let shadow = dr_chroma(p[4]);
    let highlight = dr_chroma(p[5]);
    d += (shadow * (1.0 - lifted) + highlight * lifted) * p[6] * DR_SPLIT_TONE_SCALE;

    let floor_c = max(vec3f(p[1]) + shadow * p[1] * p[6], vec3f(0.0));
    d = floor_c + clamp(d, vec3f(0.0), vec3f(1.0)) * (vec3f(1.0) - floor_c);

    d += vec3f((pixel_noise(uv) - 0.5) * 2.0 * p[7]);

    let lin = pow(clamp(d, vec3f(0.0), vec3f(1.0)), vec3f(DR_GAMMA));
    let y = min(lin, vec3f(DR_MAX_LDR));
    return vec4f(y / (vec3f(1.0) - y), color.a);
}
