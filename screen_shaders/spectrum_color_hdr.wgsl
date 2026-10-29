// @param Red gain min=0.0 max=6.0 default=1.0
// @param Orange gain min=0.0 max=6.0 default=1.0
// @param Yellow gain min=0.0 max=6.0 default=1.8
// @param Green gain min=0.0 max=6.0 default=1.0
// @param Cyan gain min=0.0 max=6.0 default=1.6
// @param Blue gain min=0.0 max=6.0 default=1.0
// @param Violet gain min=0.0 max=6.0 default=1.3
// @param Min saturation min=0.0 max=0.5 default=0.12

const SB_EPS = 1e-6;
const SB_TAU = 6.28318530718;
const SB_DEGREES = 360.0;
const SB_SAT_RAMP_START = 0.5;
const SB_BAND_COUNT = 7u;
const SB_RED_HUE = 29.0;
const SB_ORANGE_HUE = 60.0;
const SB_YELLOW_HUE = 105.0;
const SB_GREEN_HUE = 142.0;
const SB_CYAN_HUE = 195.0;
const SB_BLUE_HUE = 264.0;
const SB_VIOLET_HUE = 295.0;

fn sb_cbrt(x: vec3f) -> vec3f {
    return sign(x) * pow(abs(x), vec3f(1.0 / 3.0));
}

fn sb_to_oklab(c: vec3f) -> vec3f {
    let lms = vec3f(
        dot(c, vec3f(0.4122214708, 0.5363325363, 0.0514459929)),
        dot(c, vec3f(0.2119034982, 0.6806995451, 0.1073969566)),
        dot(c, vec3f(0.0883024619, 0.2817188376, 0.6299787005)),
    );
    let r = sb_cbrt(lms);
    return vec3f(
        dot(r, vec3f(0.2104542553, 0.7936177850, -0.0040720468)),
        dot(r, vec3f(1.9779984951, -2.4285922050, 0.4505937099)),
        dot(r, vec3f(0.0259040371, 0.7827717662, -0.8086757660)),
    );
}

fn sb_hue_gain(hue: f32, p: Params) -> f32 {
    var hues = array<f32, 7>(SB_RED_HUE, SB_ORANGE_HUE, SB_YELLOW_HUE, SB_GREEN_HUE, SB_CYAN_HUE, SB_BLUE_HUE, SB_VIOLET_HUE);
    var gains = array<f32, 7>(p[0], p[1], p[2], p[3], p[4], p[5], p[6]);
    for (var i = 0u; i < SB_BAND_COUNT; i = i + 1u) {
        let next = (i + 1u) % SB_BAND_COUNT;
        let start = hues[i] / SB_DEGREES;
        let span = fract(hues[next] / SB_DEGREES - start);
        let t = fract(hue - start);
        if (t < span) {
            return mix(gains[i], gains[next], smoothstep(0.0, span, t));
        }
    }
    return gains[0];
}

fn effect(uv: vec2f, color: vec4f, p: Params) -> vec4f {
    let lab = sb_to_oklab(max(color.rgb, vec3f(0.0)));
    let chroma = length(lab.yz);
    if (lab.x <= SB_EPS || chroma <= SB_EPS) {
        return color;
    }
    let gate = smoothstep(p[7] * SB_SAT_RAMP_START, p[7] + SB_EPS, chroma / lab.x);
    if (gate <= 0.0) {
        return color;
    }

    let hue = fract(atan2(lab.z, lab.y) / SB_TAU + 1.0);
    let gain = sb_hue_gain(hue, p);
    return vec4f(color.rgb * (1.0 + (gain - 1.0) * gate), color.a);
}
