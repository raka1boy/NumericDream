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

fn vhs_rgb_to_yiq(c: vec3f) -> vec3f {
    return vec3f(
        dot(c, vec3f(0.299, 0.587, 0.114)),
        dot(c, vec3f(0.596, -0.274, -0.322)),
        dot(c, vec3f(0.211, -0.523, 0.312)),
    );
}

fn vhs_yiq_to_rgb(v: vec3f) -> vec3f {
    return vec3f(
        v.x + 0.956 * v.y + 0.621 * v.z,
        v.x - 0.272 * v.y - 0.647 * v.z,
        v.x - 1.106 * v.y + 1.703 * v.z,
    );
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();

    var suv = uv;
    suv.y = fract(suv.y + pp.time * p[6]);

    let band = floor(suv.y * VHS_LINES);

    let band_centre = fract(pp.time * 0.13);
    let band_dy = abs(fract(suv.y - band_centre + 0.5) - 0.5);
    let tracking = (1.0 - smoothstep(0.0, 0.02 + 0.10 * p[5], band_dy)) * p[5];

    let head = hash12(vec2f(band, floor(pp.time * VHS_HEAD_HZ))) - 0.5;
    let wobble = sin(suv.y * 180.0 + pp.time * 9.0) * 0.35;
    suv.x += (head * 2.0 + wobble) * p[0] * (1.0 + tracking * 6.0) * texel.x;

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
    iq = iq / max(wsum, 1e-4) * p[7];
    iq *= 1.0 - tracking * 0.8;

    var out_c = max(vhs_yiq_to_rgb(vec3f(y, iq)), vec3f(0.0));

    let snow_amount = p[3] * (1.0 + tracking * 2.0);
    let dark = 1.0 - clamp(luminance(out_c), 0.0, 1.0);
    out_c += vec3f((pixel_noise(uv) - 0.5) * 2.0 * snow_amount * 0.25 * (0.3 + dark));

    let drop_line = hash12(vec2f(band * 1.7 + 3.1, floor(pp.time * 12.0)));
    if (drop_line < p[4] * 0.06) {
        let seg = floor(suv.x * 24.0);
        if (hash12(vec2f(seg, band)) > 0.55) {
            out_c = mix(out_c, vec3f(VHS_DROPOUT_LEVEL), 0.85);
        }
    }

    return vec4f(max(out_c, vec3f(0.0)), color.a);
}
