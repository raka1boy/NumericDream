// @param Line jitter (px) min=0.0 max=24.0 default=4.0
// @param Chroma bleed (px) min=0.0 max=32.0 default=8.0
// @param Chroma shift (px) min=-12.0 max=12.0 default=2.0
// @param Tape noise min=0.0 max=1.0 default=0.2
// @param Dropouts min=0.0 max=1.0 default=0.15
// @param Tracking band min=0.0 max=1.0 default=0.4
// @param Roll speed min=-1.0 max=1.0 default=0.0
// @param Saturation min=0.0 max=2.0 default=1.2

const VHS_LINES = 240.0;
const VHS_CHROMA_TAPS = 8;
const VHS_HEAD_HZ = 24.0;
const VHS_DROPOUT_LEVEL = 6.0;
const VHS_YIQ_Y = vec3f(0.299, 0.587, 0.114);
const VHS_YIQ_I = vec3f(0.596, -0.274, -0.322);
const VHS_YIQ_Q = vec3f(0.211, -0.523, 0.312);
const VHS_YIQ_TO_R_I = 0.956;
const VHS_YIQ_TO_R_Q = 0.621;
const VHS_YIQ_TO_G_I = -0.272;
const VHS_YIQ_TO_G_Q = -0.647;
const VHS_YIQ_TO_B_I = -1.106;
const VHS_YIQ_TO_B_Q = 1.703;
const VHS_BAND_SPEED = 0.13;
const VHS_BAND_MIN_WIDTH = 0.02;
const VHS_BAND_WIDTH_GAIN = 0.10;
const VHS_WOBBLE_FREQ = 180.0;
const VHS_WOBBLE_SPEED = 9.0;
const VHS_WOBBLE_AMOUNT = 0.35;
const VHS_TRACKING_JITTER_GAIN = 6.0;
const VHS_EPS = 1e-4;
const VHS_TRACKING_CHROMA_LOSS = 0.8;
const VHS_TRACKING_NOISE_GAIN = 2.0;
const VHS_SNOW_SCALE = 0.25;
const VHS_SNOW_FLOOR = 0.3;
const VHS_DROP_SEED_RATE = 1.7;
const VHS_DROP_SEED_OFFSET = 3.1;
const VHS_DROP_RATE_HZ = 12.0;
const VHS_DROP_CHANCE = 0.06;
const VHS_DROP_SEGMENTS = 24.0;
const VHS_DROP_SEGMENT_CUTOFF = 0.55;
const VHS_DROP_OPACITY = 0.85;

fn vhs_rgb_to_yiq(c: vec3f) -> vec3f {
    return vec3f(
        dot(c, VHS_YIQ_Y),
        dot(c, VHS_YIQ_I),
        dot(c, VHS_YIQ_Q),
    );
}

fn vhs_yiq_to_rgb(v: vec3f) -> vec3f {
    return vec3f(
        v.x + VHS_YIQ_TO_R_I * v.y + VHS_YIQ_TO_R_Q * v.z,
        v.x + VHS_YIQ_TO_G_I * v.y + VHS_YIQ_TO_G_Q * v.z,
        v.x + VHS_YIQ_TO_B_I * v.y + VHS_YIQ_TO_B_Q * v.z,
    );
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();

    var suv = uv;
    suv.y = fract(suv.y + pp.time * p[6]);

    let band = floor(suv.y * VHS_LINES);

    let band_centre = fract(pp.time * VHS_BAND_SPEED);
    let band_dy = abs(fract(suv.y - band_centre + 0.5) - 0.5);
    let tracking = (1.0 - smoothstep(0.0, VHS_BAND_MIN_WIDTH + VHS_BAND_WIDTH_GAIN * p[5], band_dy)) * p[5];

    let head = hash12(vec2f(band, floor(pp.time * VHS_HEAD_HZ))) - 0.5;
    let wobble = sin(suv.y * VHS_WOBBLE_FREQ + pp.time * VHS_WOBBLE_SPEED) * VHS_WOBBLE_AMOUNT;
    suv.x += (head * 2.0 + wobble) * p[0] * (1.0 + tracking * VHS_TRACKING_JITTER_GAIN) * texel.x;

    let centre = max(scene_sample(suv).rgb, vec3f(0.0));
    let y = vhs_rgb_to_yiq(centre).x;

    var iq = vec2f(0.0);
    var wsum = 0.0;
    for (var k = 0; k < VHS_CHROMA_TAPS; k++) {
        let t = f32(k) / f32(VHS_CHROMA_TAPS);
        let lag = (p[2] + t * p[1]) * texel.x;
        let c = max(scene_color(suv - vec2f(lag, 0.0)), vec3f(0.0));
        let w = 1.0 - t;
        iq += vhs_rgb_to_yiq(c).yz * w;
        wsum += w;
    }
    iq = iq / max(wsum, VHS_EPS) * p[7];
    iq *= 1.0 - tracking * VHS_TRACKING_CHROMA_LOSS;

    var out_c = max(vhs_yiq_to_rgb(vec3f(y, iq)), vec3f(0.0));

    let snow_amount = p[3] * (1.0 + tracking * VHS_TRACKING_NOISE_GAIN);
    let dark = 1.0 - clamp(luminance(out_c), 0.0, 1.0);
    out_c += vec3f((pixel_noise(uv) - 0.5) * 2.0 * snow_amount * VHS_SNOW_SCALE * (VHS_SNOW_FLOOR + dark));

    let drop_line = hash12(vec2f(band * VHS_DROP_SEED_RATE + VHS_DROP_SEED_OFFSET, floor(pp.time * VHS_DROP_RATE_HZ)));
    if (drop_line < p[4] * VHS_DROP_CHANCE) {
        let seg = floor(suv.x * VHS_DROP_SEGMENTS);
        if (hash12(vec2f(seg, band)) > VHS_DROP_SEGMENT_CUTOFF) {
            out_c = mix(out_c, vec3f(VHS_DROPOUT_LEVEL), VHS_DROP_OPACITY);
        }
    }

    return vec4f(max(out_c, vec3f(0.0)), color.a);
}
