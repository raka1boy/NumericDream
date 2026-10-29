// Credits: "Seascape" by Alexander Alekseev aka TDM (Shadertoy, CC BY-NC-SA 3.0, 2014), shadertoy.com/view/Ms2SD1

// @param Octaves min=1 max=8 default=5 int
// @param Size min=0.001 max=1 default=0.025
// @param Height min=0 max=3 default=0.6
// @param Choppy min=1 max=10 default=4
// @param Frequency min=0.02 max=1 default=0.16
// @param Time min=0 max=100 default=1
// @param Extent min=1 max=500 default=60
// @param Depth min=0 max=50 default=4
// @param FreqGain min=1.2 max=3 default=1.9
// @param AmpGain min=0.05 max=0.6 default=0.22
// @param ChoppyRelax min=0 max=1 default=0.2
const SEASCAPE_MAX_OCTAVES = 8;
const SEASCAPE_SQUASH_X = 0.75;
const SEASCAPE_OCTAVE_M = mat2x2f(1.6, 1.2, -1.2, 1.6);
const SEASCAPE_OCTAVE_STRETCH = 2.0;
const SEASCAPE_SHARPNESS = 0.65;
const SEASCAPE_SLOPE_BASE = 3.5;
const SEASCAPE_SLOPE_PER_CHOPPY = 1.05;

fn de_iterations(p: Params) -> i32 {
    return primitive_de_iterations();
}

fn seascape_hash(c: vec2i) -> f32 {
    var v = bitcast<vec2u>(c) * LCG_MULTIPLIER + LCG_INCREMENT;
    v.x += v.y * LCG_MULTIPLIER;
    v.y += v.x * LCG_MULTIPLIER;
    v ^= v >> vec2u(16u);
    v.x += v.y * LCG_MULTIPLIER;
    v.y += v.x * LCG_MULTIPLIER;
    v ^= v >> vec2u(16u);
    return f32(v.x ^ v.y) * INV_U32_RANGE;
}

fn seascape_noise(p: vec2f) -> f32 {
    let i = floor(p);
    let f = p - i;
    let c = vec2i(i);
    let u = f * f * (3.0 - 2.0 * f);
    return -1.0 + 2.0 * mix(
        mix(seascape_hash(c), seascape_hash(c + vec2i(1, 0)), u.x),
        mix(seascape_hash(c + vec2i(0, 1)), seascape_hash(c + vec2i(1, 1)), u.x),
        u.y,
    );
}

fn seascape_octave(uv_in: vec2f, choppy: f32) -> f32 {
    let uv = uv_in + seascape_noise(uv_in);
    var wv = 1.0 - abs(sin(uv));
    let swv = abs(cos(uv));
    wv = mix(wv, swv, wv);
    let crest = pow(max(wv.x * wv.y, 0.0), SEASCAPE_SHARPNESS);
    return pow(max(1.0 - crest, 0.0), choppy);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let octaves = clamp(i32(p[0]), 1, SEASCAPE_MAX_OCTAVES);
    let size = max(p[1], EPSILON);
    let q = carry.z / (size * max(abs(carry.dr), EPSILON_FINE));
    let sea_height = max(p[2], 0.0);
    let time = p[5];
    let extent = max(p[6], EPSILON);
    let depth = max(p[7], 0.0);
    let freq_gain = max(p[8], 0.0);
    let amp_gain = clamp(p[9], 0.0, 0.95);
    let choppy_relax = clamp(p[10], 0.0, 1.0);

    let h_max = 2.0 * sea_height * (1.0 - pow(amp_gain, f32(octaves))) / (1.0 - amp_gain);
    var reach = h_max;
    var above = q.y - reach;
    var below = -q.y;

    var uv = vec2f(q.x * SEASCAPE_SQUASH_X, q.z);
    var freq = p[4];
    var amp = sea_height;
    var choppy = max(p[3], 1.0);
    var stretch = 1.0;
    var h = 0.0;
    var slope = 0.0;
    for (var i = 0; i < octaves; i++) {
        let d = seascape_octave((uv + time) * freq, choppy) + seascape_octave((uv - time) * freq, choppy);
        h += d * amp;
        reach -= 2.0 * amp;
        slope += 2.0 * amp * freq * stretch * (SEASCAPE_SLOPE_BASE + SEASCAPE_SLOPE_PER_CHOPPY * choppy);
        let s = sqrt(1.0 + slope * slope);
        above = max(above, (q.y - h - max(reach, 0.0)) / s);
        below = max(below, (h - q.y) / s);
        uv = uv * SEASCAPE_OCTAVE_M;
        freq *= freq_gain;
        amp *= amp_gain;
        stretch *= SEASCAPE_OCTAVE_STRETCH;
        choppy = mix(choppy, 1.0, choppy_relax);
    }
    let wave = select(-below, above, q.y >= h);

    let e = vec3f(abs(q.x) - extent, max(-depth - q.y, q.y - h_max), abs(q.z) - extent);
    let bounds = length(max(e, vec3f(0.0))) + min(max(e.x, max(e.y, e.z)), 0.0);

    let d = max(wave, bounds);
    let elevation = clamp(h / max(h_max, EPSILON), 0.0, 1.0);
    return IterCarry(vec3f(0.0, elevation, 0.0), d * size);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
