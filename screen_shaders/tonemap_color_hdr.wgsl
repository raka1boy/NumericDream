// @param Exposure min=0.05 max=8.0 default=1.0
// @param Operator min=0 max=3 default=2 int
// @param White point min=1.0 max=20.0 default=4.0
// @param Contrast min=0.4 max=2.0 default=1.0
// @param Saturation min=0.0 max=2.0 default=1.0
// @param Black point min=0.0 max=0.2 default=0.0

const TM_EPS = 1e-4;
const TM_MID_GREY = 0.18;

fn tm_reinhard(c: vec3f) -> vec3f {
    return c / (c + vec3f(1.0));
}

fn tm_reinhard_white(c: vec3f, white: f32) -> vec3f {
    let w2 = max(white * white, TM_EPS);
    return c * (vec3f(1.0) + c / vec3f(w2)) / (c + vec3f(1.0));
}

fn tm_aces(c: vec3f) -> vec3f {
    let num = c * (2.51 * c + vec3f(0.03));
    let den = c * (2.43 * c + vec3f(0.59)) + vec3f(0.14);
    return num / den;
}

fn tm_hable_curve(x: vec3f) -> vec3f {
    let a = 0.15;
    let b = 0.50;
    let c = 0.10;
    let d = 0.20;
    let e = 0.02;
    let f = 0.30;
    return ((x * (a * x + vec3f(c * b)) + vec3f(d * e)) / (x * (a * x + vec3f(b)) + vec3f(d * f))) - vec3f(e / f);
}

fn tm_uncharted(c: vec3f, white: f32) -> vec3f {
    let scale = tm_hable_curve(vec3f(max(white, TM_EPS)));
    return tm_hable_curve(c * 2.0) / max(scale, vec3f(TM_EPS));
}

fn tm_to_engine(ldr: vec3f) -> vec3f {
    let y = clamp(ldr, vec3f(0.0), vec3f(0.9995));
    return y / (vec3f(1.0) - y);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    var c = max(color.rgb, vec3f(0.0)) * p[0];

    let grey = luminance(c);
    c = max(mix(vec3f(grey), c, p[4]), vec3f(0.0));

    c = TM_MID_GREY * pow(max(c / TM_MID_GREY, vec3f(1e-5)), vec3f(p[3]));

    let op = i32(round(clamp(p[1], 0.0, 3.0)));
    var ldr: vec3f;
    if (op == 0) {
        ldr = tm_reinhard(c);
    } else if (op == 1) {
        ldr = tm_reinhard_white(c, p[2]);
    } else if (op == 2) {
        ldr = tm_aces(c);
    } else {
        ldr = tm_uncharted(c, p[2]);
    }
    ldr = clamp(ldr, vec3f(0.0), vec3f(1.0));

    ldr = clamp((ldr - vec3f(p[5])) / max(1.0 - p[5], 1e-3), vec3f(0.0), vec3f(1.0));

    return vec4f(tm_to_engine(ldr), color.a);
}
