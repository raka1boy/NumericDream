// @param Font size (px) min=6 max=96 default=16 int
// @param Exposure min=0.1 max=8.0 default=1.0
// @param Edges min=0.0 max=1.0 default=0.5
// @param Colour min=0.0 max=1.0 default=1.0
// @param Tint hue min=0.0 max=1.0 default=0.33
// @param Glyph colour min=0.0 max=1.0 default=1.0
// @param Cell fill min=0.0 max=1.0 default=0.0
// @param Brightness min=0.5 max=16.0 default=4.0
// @text Ramp " .:-=+*#%@"
// @text Edge symbols "|/-\"

const UNI_RAMP_FIELD = 0u;
const UNI_EDGE_FIELD = 1u;
const UNI_PI = 3.14159265359;
const UNI_MIN_CELL_PX = 6.0;
const UNI_MIN_CELL_WIDTH_PX = 3.0;
const UNI_SUBSAMPLES = 4;
const UNI_SUBSAMPLE_STEP = 0.25;
const UNI_SUBSAMPLE_HALF = 2;
const UNI_SAMPLE_COUNT = 16.0;
const UNI_HALF_SAMPLE_COUNT = 8.0;
const UNI_MIN_DEPTH = 1e-4;
const UNI_DEPTH_EDGE_WEIGHT = 0.5;
const UNI_EDGE_THRESHOLD_BASE = 1.05;
const UNI_EDGE_BINS = 4u;
const UNI_EDGE_BIN_FRACTION = 0.25;
const UNI_MIN_PEAK = 1e-4;
const UNI_TINT_SATURATION = 0.75;

fn uni_tone(rgb: vec3f, exposure: f32) -> f32 {
    let l = luminance(max(rgb, vec3f(0.0))) * exposure;
    return sqrt(l / (1.0 + l));
}

fn uni_hue(h: f32, s: f32) -> vec3f {
    let k = abs(fract(vec3f(h) + vec3f(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3f(3.0)) - vec3f(1.0);
    return mix(vec3f(1.0), clamp(k, vec3f(0.0), vec3f(1.0)), s);
}

fn effect(uv: vec2f, color: vec4f, p: Params) -> vec4f {
    let ramp_len = text_length(UNI_RAMP_FIELD);
    if (ramp_len == 0u) {
        return color;
    }

    let cell_h = max(round(p[0]), UNI_MIN_CELL_PX);
    let cell = vec2f(max(round(cell_h * glyph_aspect()), UNI_MIN_CELL_WIDTH_PX), cell_h);
    let px = uv * pp.resolution;
    let origin = floor(px / cell) * cell;

    var avg = vec3f(0.0);
    var tone = 0.0;
    var g_tone = vec2f(0.0);
    var g_depth = vec2f(0.0);
    for (var j = 0; j < UNI_SUBSAMPLES; j++) {
        for (var i = 0; i < UNI_SUBSAMPLES; i++) {
            let suv = (origin + (vec2f(f32(i), f32(j)) + 0.5) * UNI_SUBSAMPLE_STEP * cell) / pp.resolution;
            let d = scene_depth(suv);
            let c = scene_color(suv);
            let t = uni_tone(c, p[1]);
            let ld = log(max(select(pp.max_dist, d, d > 0.0), UNI_MIN_DEPTH));
            let side = vec2f(select(-1.0, 1.0, i >= UNI_SUBSAMPLE_HALF), select(-1.0, 1.0, j >= UNI_SUBSAMPLE_HALF));
            avg += c;
            tone += t;
            g_tone += side * t;
            g_depth += side * ld;
        }
    }
    avg *= 1.0 / UNI_SAMPLE_COUNT;
    tone *= 1.0 / UNI_SAMPLE_COUNT;
    g_tone *= 1.0 / UNI_HALF_SAMPLE_COUNT;
    g_depth *= 1.0 / UNI_HALF_SAMPLE_COUNT;

    var glyph = text_glyph(UNI_RAMP_FIELD, u32(clamp(tone * f32(ramp_len), 0.0, f32(ramp_len - 1u))));

    let depth_strength = length(g_depth) * UNI_DEPTH_EDGE_WEIGHT;
    let tone_strength = length(g_tone);
    let g = select(g_tone, g_depth, depth_strength > tone_strength);
    if (p[2] > 0.0 && text_length(UNI_EDGE_FIELD) > 0u && max(depth_strength, tone_strength) > UNI_EDGE_THRESHOLD_BASE - p[2]) {
        var a = atan2(g.y, g.x);
        if (a < 0.0) { a += UNI_PI; }
        let bin = u32(floor(a / (UNI_PI * UNI_EDGE_BIN_FRACTION) + 0.5)) % UNI_EDGE_BINS;
        glyph = text_glyph(UNI_EDGE_FIELD, bin);
    }

    let local = px - origin;
    let glyph_uv = vec2f((local.x - 0.5 * cell.x) / cell_h + 0.5, local.y / cell_h);
    let s = glyph_sample(glyph, glyph_uv, cell_h);

    let peak = max(max(avg.r, avg.g), max(avg.b, UNI_MIN_PEAK));
    let cell_hue = max(avg, vec3f(0.0)) / peak;
    let ink = mix(uni_hue(p[4], UNI_TINT_SATURATION), cell_hue, clamp(p[3], 0.0, 1.0)) * p[7];
    let paper = max(avg, vec3f(0.0)) * p[6];
    var inked = ink * s.a;
    if (glyph_is_colour(glyph)) {
        inked = mix(inked, s.rgb * p[7], clamp(p[5], 0.0, 1.0));
    }
    return vec4f(paper * (1.0 - s.a) + inked, color.a);
}
