// @param Line count min=100 max=1200 default=480 int
// @param Line depth min=0.0 max=1.0 default=0.5
// @param Mask strength min=0.0 max=1.0 default=0.4
// @param Mask pitch (px) min=1.0 max=6.0 default=1.0
// @param Curvature min=0.0 max=0.5 default=0.12
// @param Flicker min=0.0 max=0.5 default=0.04
// @param Brightness min=0.5 max=3.0 default=1.4
// @param Bleed (px) min=0.0 max=4.0 default=1.0

const CRT_TAU = 6.28318530718;
const CRT_HUM_HZ = 50.0;
const CRT_MIN_PITCH = 0.25;
const CRT_TRIAD_SUBPIXELS = 3.0;
const CRT_SUBPIXEL_CENTRES = vec3f(0.5, 1.5, 2.5);
const CRT_MASK_GAIN = 1.5;
const CRT_MIN_BLEED = 0.001;
const CRT_BLEED_SIDE = 0.25;
const CRT_BLEED_CENTRE = 0.5;
const CRT_ROLL_SPEED = 0.35;
const CRT_HUM_WEIGHT = 0.6;
const CRT_BAND_WEIGHT = 0.4;

fn crt_curve(uv: vec2f, amount: f32) -> vec2f {
    var c = uv * 2.0 - vec2f(1.0);
    c.x *= max(pp.aspect, 1.0);
    let r2 = dot(c, c);
    c *= 1.0 + amount * r2;
    c.x /= max(pp.aspect, 1.0);
    return c * 0.5 + vec2f(0.5);
}

fn crt_grille(x_px: f32, pitch: f32, strength: f32) -> vec3f {
    let triad = max(pitch, CRT_MIN_PITCH) * CRT_TRIAD_SUBPIXELS;
    let f = fract(x_px / triad) * CRT_TRIAD_SUBPIXELS;
    var d = abs(vec3f(f) - CRT_SUBPIXEL_CENTRES);
    d = min(d, vec3f(CRT_TRIAD_SUBPIXELS) - d);
    let w = clamp(vec3f(1.0) - d, vec3f(0.0), vec3f(1.0));
    return mix(vec3f(1.0), w * CRT_MASK_GAIN, strength);
}

fn crt_bleed(uv: vec2f, px: f32) -> vec3f {
    if (px <= CRT_MIN_BLEED) {
        return scene_color(uv);
    }
    let o = vec2f(px * texel_size().x, 0.0);
    return scene_color(uv - o) * CRT_BLEED_SIDE + scene_color(uv) * CRT_BLEED_CENTRE + scene_color(uv + o) * CRT_BLEED_SIDE;
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let suv = crt_curve(uv, p[4]);
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        return vec4f(0.0, 0.0, 0.0, color.a);
    }

    var c = max(crt_bleed(suv, p[7]), vec3f(0.0));

    let line = 0.5 + 0.5 * cos(CRT_TAU * suv.y * max(p[0], 1.0));
    c *= mix(1.0, line, p[1]);

    c *= crt_grille(suv.x * pp.resolution.x, p[3], p[2]);

    let hum = sin(pp.time * CRT_TAU * CRT_HUM_HZ);
    let band = sin((suv.y - pp.time * CRT_ROLL_SPEED) * CRT_TAU);
    c *= 1.0 + p[5] * (hum * CRT_HUM_WEIGHT + band * CRT_BAND_WEIGHT);

    return vec4f(max(c * p[6], vec3f(0.0)), color.a);
}
