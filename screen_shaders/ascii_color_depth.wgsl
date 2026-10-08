// @param Font size (px) min=6 max=64 default=16 int
// @param Exposure min=0.1 max=8.0 default=1.0
// @param ASCII background min=0 max=1 default=1 int
// @param Edges min=0.0 max=1.0 default=0.5
// @param Colour min=0.0 max=1.0 default=1.0
// @param Tint hue min=0.0 max=1.0 default=0.33
// @param Cell fill min=0.0 max=1.0 default=0.0
// @param Brightness min=0.5 max=16.0 default=4.0

const ASCII_RAMP_LEN = 13u;
const ASCII_PI = 3.14159265359;

fn ascii_glyph(index: u32) -> vec2u {
    var glyphs = array<vec2u, 17>(
        vec2u(0x00000u, 0x0000u),
        vec2u(0x00000u, 0x18c0u),
        vec2u(0x018c0u, 0x00c6u),
        vec2u(0xf9080u, 0x0084u),
        vec2u(0x07c00u, 0x001fu),
        vec2u(0x75480u, 0x0095u),
        vec2u(0x8b800u, 0x3a31u),
        vec2u(0x22263u, 0x6322u),
        vec2u(0x11526u, 0x5935u),
        vec2u(0x717c4u, 0x11f4u),
        vec2u(0x7462eu, 0x3a31u),
        vec2u(0x57d4au, 0x295fu),
        vec2u(0xaf62eu, 0x783du),
        vec2u(0x21084u, 0x1084u),
        vec2u(0xf8000u, 0x0000u),
        vec2u(0x22210u, 0x0422u),
        vec2u(0x20821u, 0x4208u),
    );
    return glyphs[min(index, 16u)];
}

fn ascii_ink(glyph: vec2u, col: u32, row: u32) -> bool {
    if (col > 4u || row > 6u) {
        return false;
    }
    let bits = select(glyph.x, glyph.y, row >= 4u);
    return ((bits >> ((row % 4u) * 5u + col)) & 1u) != 0u;
}

fn ascii_tone(rgb: vec3f, exposure: f32) -> f32 {
    let l = luminance(max(rgb, vec3f(0.0))) * exposure;
    return sqrt(l / (1.0 + l));
}

fn ascii_hue(h: f32, s: f32) -> vec3f {
    let k = abs(fract(vec3f(h) + vec3f(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - vec3f(3.0)) - vec3f(1.0);
    return mix(vec3f(1.0), clamp(k, vec3f(0.0), vec3f(1.0)), s);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let cell_h = max(round(p[0]), 6.0);
    let cell = vec2f(max(round(cell_h * 0.75), 4.0), cell_h);
    let px = uv * pp.resolution;
    let cell_id = floor(px / cell);
    let origin = cell_id * cell;
    let sky_ascii = p[2] > 0.5;

    var avg = vec3f(0.0);
    var tone = 0.0;
    var g_tone = vec2f(0.0);
    var g_depth = vec2f(0.0);
    for (var j = 0; j < 4; j++) {
        for (var i = 0; i < 4; i++) {
            let suv = (origin + (vec2f(f32(i), f32(j)) + 0.5) * 0.25 * cell) / pp.resolution;
            let d = scene_depth(suv);
            let c = select(vec3f(0.0), scene_color(suv), d > 0.0 || sky_ascii);
            let t = ascii_tone(c, p[1]);
            let ld = log(max(select(pp.max_dist, d, d > 0.0), 1e-4));
            let side = vec2f(select(-1.0, 1.0, i >= 2), select(-1.0, 1.0, j >= 2));
            avg += c;
            tone += t;
            g_tone += side * t;
            g_depth += side * ld;
        }
    }
    avg *= 1.0 / 16.0;
    tone *= 1.0 / 16.0;
    g_tone *= 1.0 / 8.0;
    g_depth *= 1.0 / 8.0;

    var glyph_index = u32(clamp(tone * f32(ASCII_RAMP_LEN), 0.0, f32(ASCII_RAMP_LEN - 1u)));

    let depth_strength = length(g_depth) * 0.5;
    let tone_strength = length(g_tone);
    let g = select(g_tone, g_depth, depth_strength > tone_strength);
    if (p[3] > 0.0 && max(depth_strength, tone_strength) > 1.05 - p[3]) {
        var a = atan2(g.y, g.x);
        if (a < 0.0) { a += ASCII_PI; }
        let bin = u32(floor(a / (ASCII_PI * 0.25) + 0.5)) % 4u;
        let edge_glyphs = vec4u(13u, 15u, 14u, 16u);
        glyph_index = edge_glyphs[bin];
    }

    let unit = vec2u(clamp(floor((px - origin) / cell * vec2f(6.0, 8.0)), vec2f(0.0), vec2f(5.0, 7.0)));
    let on = ascii_ink(ascii_glyph(glyph_index), unit.x, unit.y);

    let peak = max(max(avg.r, avg.g), max(avg.b, 1e-4));
    let cell_hue = max(avg, vec3f(0.0)) / peak;
    let ink = mix(ascii_hue(p[5], 0.75), cell_hue, clamp(p[4], 0.0, 1.0)) * p[7];
    let paper = max(avg, vec3f(0.0)) * p[6];
    return vec4f(select(paper, ink, on), color.a);
}
