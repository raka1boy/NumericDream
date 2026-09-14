struct Uniforms {
    progress: f32,
    aspect: f32,
    digit0: f32, // hundreds place; blank (0) segment mask when not shown
    digit1: f32, // tens place; blank unless digit0 is also shown
    digit2: f32, // ones place -- always shown
    button_hover: f32, // 1.0 while the mouse is over the Cancel button
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

fn segment_lit(mask: u32, local: vec2f) -> bool {
    let st = 0.16;
    let x = local.x;
    let y = local.y;
    if ((mask & 1u) != 0u && y < st && x > st && x < 1.0 - st) { return true; }
    if ((mask & 2u) != 0u && x > 1.0 - st && y > st * 0.5 && y < 0.5 + st * 0.5) { return true; }
    if ((mask & 4u) != 0u && x > 1.0 - st && y > 0.5 - st * 0.5 && y < 1.0 - st * 0.5) { return true; }
    if ((mask & 8u) != 0u && y > 1.0 - st && x > st && x < 1.0 - st) { return true; }
    if ((mask & 16u) != 0u && x < st && y > 0.5 - st * 0.5 && y < 1.0 - st * 0.5) { return true; }
    if ((mask & 32u) != 0u && x < st && y > st * 0.5 && y < 0.5 + st * 0.5) { return true; }
    if ((mask & 64u) != 0u && y > 0.5 - st * 0.5 && y < 0.5 + st * 0.5 && x > st && x < 1.0 - st) { return true; }
    return false;
}

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4f {
    let uv = vec2f(in.uv.x * u.aspect, in.uv.y);
    let center = vec2f(0.5 * u.aspect, 0.5);

    let bg = vec3f(0.03, 0.03, 0.05);
    let track_col = vec3f(0.16, 0.16, 0.2);
    let fill_col = vec3f(0.95, 0.55, 0.15);
    let digit_col = vec3f(0.92, 0.92, 0.95);

    var color = bg;

    let bar_w = 0.4 * u.aspect;
    let bar_h = 0.028;
    let bar_x0 = center.x - bar_w * 0.5;
    let bar_y0 = center.y - bar_h * 0.5;
    if (uv.x >= bar_x0 && uv.x <= bar_x0 + bar_w && uv.y >= bar_y0 && uv.y <= bar_y0 + bar_h) {
        color = track_col;
        if (uv.x <= bar_x0 + bar_w * clamp(u.progress, 0.0, 1.0)) {
            color = fill_col;
        }
    }

    let digit_h = 0.09;
    let digit_w = digit_h * 0.55;
    let digit_gap = digit_h * 0.22;
    let digits_w = digit_w * 3.0 + digit_gap * 2.0;
    let digits_x0 = center.x - digits_w * 0.5;
    let digits_y0 = bar_y0 - digit_gap - digit_h;

    let masks = array<u32, 3>(u32(u.digit0), u32(u.digit1), u32(u.digit2));
    for (var i = 0; i < 3; i++) {
        let cell_x0 = digits_x0 + f32(i) * (digit_w + digit_gap);
        if (uv.x >= cell_x0 && uv.x <= cell_x0 + digit_w && uv.y >= digits_y0 && uv.y <= digits_y0 + digit_h) {
            let local = vec2f((uv.x - cell_x0) / digit_w, (uv.y - digits_y0) / digit_h);
            if (segment_lit(masks[i], local)) {
                color = digit_col;
            }
        }
    }

    let btn_size = 0.09;
    let btn_x0 = center.x - btn_size * 0.5;
    let btn_y0 = 0.62 - btn_size * 0.5;
    if (uv.x >= btn_x0 && uv.x <= btn_x0 + btn_size && uv.y >= btn_y0 && uv.y <= btn_y0 + btn_size) {
        let local = vec2f((uv.x - btn_x0) / btn_size, (uv.y - btn_y0) / btn_size);
        let base_col = vec3f(0.45, 0.12, 0.12);
        let hover_col = vec3f(0.75, 0.18, 0.18);
        color = mix(base_col, hover_col, u.button_hover);
        let inset = 0.14;
        if (local.x > inset && local.x < 1.0 - inset && local.y > inset && local.y < 1.0 - inset) {
            let d1 = abs(local.y - local.x);
            let d2 = abs(local.y - (1.0 - local.x));
            if (d1 < 0.09 || d2 < 0.09) {
                color = vec3f(0.95, 0.93, 0.93);
            }
        }
    }

    return vec4f(color, 1.0);
}
