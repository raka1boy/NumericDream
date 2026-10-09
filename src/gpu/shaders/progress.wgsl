struct Uniforms {
    progress: f32,
    aspect: f32,
    digit0: f32,
    digit1: f32,
    digit2: f32,
    button_hover: f32,
    _pad1: f32,
    _pad2: f32,
}

@group(0) @binding(0) var<uniform> u: Uniforms;

struct VertexOut {
    @builtin(position) clip_pos: vec4f,
    @location(0) uv: vec2f,
}

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOut {
    var positions = array<vec2f, 3>(
        vec2f(-1.0, -1.0),
        vec2f(3.0, -1.0),
        vec2f(-1.0, 3.0),
    );
    let p = positions[idx];
    var out: VertexOut;
    out.clip_pos = vec4f(p, 0.0, 1.0);
    out.uv = vec2f(p.x * 0.5 + 0.5, 1.0 - (p.y * 0.5 + 0.5));
    return out;
}

const SEGMENT_THICKNESS = 0.16;
const SEG_TOP = 1u;
const SEG_TOP_RIGHT = 2u;
const SEG_BOTTOM_RIGHT = 4u;
const SEG_BOTTOM = 8u;
const SEG_BOTTOM_LEFT = 16u;
const SEG_TOP_LEFT = 32u;
const SEG_MIDDLE = 64u;

const PROGRESS_BG = vec3f(0.03, 0.03, 0.05);
const PROGRESS_TRACK = vec3f(0.16, 0.16, 0.2);
const PROGRESS_FILL = vec3f(0.95, 0.55, 0.15);
const PROGRESS_DIGIT = vec3f(0.92, 0.92, 0.95);
const BAR_WIDTH = 0.4;
const BAR_HEIGHT = 0.028;
const DIGIT_COUNT = 3;
const DIGIT_HEIGHT = 0.09;
const DIGIT_ASPECT = 0.55;
const DIGIT_GAP_RATIO = 0.22;
const BUTTON_SIZE = 0.09;
const BUTTON_CENTER_Y = 0.62;
const BUTTON_COLOR = vec3f(0.45, 0.12, 0.12);
const BUTTON_HOVER_COLOR = vec3f(0.75, 0.18, 0.18);
const BUTTON_ICON_INSET = 0.14;
const BUTTON_CROSS_HALF_WIDTH = 0.09;
const BUTTON_CROSS_COLOR = vec3f(0.95, 0.93, 0.93);

fn segment_lit(mask: u32, local: vec2f) -> bool {
    let st = SEGMENT_THICKNESS;
    let x = local.x;
    let y = local.y;
    if ((mask & SEG_TOP) != 0u && y < st && x > st && x < 1.0 - st) { return true; }
    if ((mask & SEG_TOP_RIGHT) != 0u && x > 1.0 - st && y > st * 0.5 && y < 0.5 + st * 0.5) { return true; }
    if ((mask & SEG_BOTTOM_RIGHT) != 0u && x > 1.0 - st && y > 0.5 - st * 0.5 && y < 1.0 - st * 0.5) { return true; }
    if ((mask & SEG_BOTTOM) != 0u && y > 1.0 - st && x > st && x < 1.0 - st) { return true; }
    if ((mask & SEG_BOTTOM_LEFT) != 0u && x < st && y > 0.5 - st * 0.5 && y < 1.0 - st * 0.5) { return true; }
    if ((mask & SEG_TOP_LEFT) != 0u && x < st && y > st * 0.5 && y < 0.5 + st * 0.5) { return true; }
    if ((mask & SEG_MIDDLE) != 0u && y > 0.5 - st * 0.5 && y < 0.5 + st * 0.5 && x > st && x < 1.0 - st) { return true; }
    return false;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    let uv = vec2f(in.uv.x * u.aspect, in.uv.y);
    let center = vec2f(0.5 * u.aspect, 0.5);

    let bg = PROGRESS_BG;
    let track_col = PROGRESS_TRACK;
    let fill_col = PROGRESS_FILL;
    let digit_col = PROGRESS_DIGIT;

    var color = bg;

    let bar_w = BAR_WIDTH * u.aspect;
    let bar_h = BAR_HEIGHT;
    let bar_x0 = center.x - bar_w * 0.5;
    let bar_y0 = center.y - bar_h * 0.5;
    if (uv.x >= bar_x0 && uv.x <= bar_x0 + bar_w && uv.y >= bar_y0 && uv.y <= bar_y0 + bar_h) {
        color = track_col;
        if (uv.x <= bar_x0 + bar_w * clamp(u.progress, 0.0, 1.0)) {
            color = fill_col;
        }
    }

    let digit_h = DIGIT_HEIGHT;
    let digit_w = digit_h * DIGIT_ASPECT;
    let digit_gap = digit_h * DIGIT_GAP_RATIO;
    let digits_w = digit_w * f32(DIGIT_COUNT) + digit_gap * f32(DIGIT_COUNT - 1);
    let digits_x0 = center.x - digits_w * 0.5;
    let digits_y0 = bar_y0 - digit_gap - digit_h;

    let masks = array<u32, DIGIT_COUNT>(u32(u.digit0), u32(u.digit1), u32(u.digit2));
    for (var i = 0; i < DIGIT_COUNT; i++) {
        let cell_x0 = digits_x0 + f32(i) * (digit_w + digit_gap);
        if (uv.x >= cell_x0 && uv.x <= cell_x0 + digit_w && uv.y >= digits_y0 && uv.y <= digits_y0 + digit_h) {
            let local = vec2f((uv.x - cell_x0) / digit_w, (uv.y - digits_y0) / digit_h);
            if (segment_lit(masks[i], local)) {
                color = digit_col;
            }
        }
    }

    let btn_size = BUTTON_SIZE;
    let btn_x0 = center.x - btn_size * 0.5;
    let btn_y0 = BUTTON_CENTER_Y - btn_size * 0.5;
    if (uv.x >= btn_x0 && uv.x <= btn_x0 + btn_size && uv.y >= btn_y0 && uv.y <= btn_y0 + btn_size) {
        let local = vec2f((uv.x - btn_x0) / btn_size, (uv.y - btn_y0) / btn_size);
        let base_col = BUTTON_COLOR;
        let hover_col = BUTTON_HOVER_COLOR;
        color = mix(base_col, hover_col, u.button_hover);
        let inset = BUTTON_ICON_INSET;
        if (local.x > inset && local.x < 1.0 - inset && local.y > inset && local.y < 1.0 - inset) {
            let d1 = abs(local.y - local.x);
            let d2 = abs(local.y - (1.0 - local.x));
            if (d1 < BUTTON_CROSS_HALF_WIDTH || d2 < BUTTON_CROSS_HALF_WIDTH) {
                color = BUTTON_CROSS_COLOR;
            }
        }
    }

    return vec4f(color, 1.0);
}
