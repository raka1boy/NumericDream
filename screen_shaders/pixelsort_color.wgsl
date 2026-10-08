// @param Direction min=0 max=3 default=0 int
// @param Threshold low min=0.0 max=1.0 default=0.35
// @param Threshold high min=0.0 max=1.0 default=1.0
// @param Max length min=4 max=512 default=64 int
// @param Sort key min=0 max=3 default=0 int
// @param Chunk jitter min=0.0 max=1.0 default=0.7
// @param Skip chance min=0.0 max=1.0 default=0.0
// @param Amount min=0.0 max=1.0 default=1.0

const PS_KEY_BITS = 12;
const PS_KEY_LEVELS = 4096;
const PS_MAX_SPAN = 512;

fn ps_dims() -> vec2i {
    return vec2i(textureDimensions(scene_tex));
}

fn ps_load(c: vec2i) -> vec3f {
    return textureLoad(scene_tex, clamp(c, vec2i(0), ps_dims() - vec2i(1)), 0).rgb;
}

fn ps_tonal(rgb: vec3f) -> vec3f {
    let c = max(rgb, vec3f(0.0));
    return c / (c + vec3f(1.0));
}

fn ps_luma(rgb: vec3f) -> f32 {
    return luminance(ps_tonal(rgb));
}

fn ps_hue(c: vec3f) -> f32 {
    let mx = max(c.r, max(c.g, c.b));
    let mn = min(c.r, min(c.g, c.b));
    let d = mx - mn;
    if (d < 1e-5) { return 0.0; }
    var h = 0.0;
    if (mx == c.r) {
        h = (c.g - c.b) / d;
    } else if (mx == c.g) {
        h = 2.0 + (c.b - c.r) / d;
    } else {
        h = 4.0 + (c.r - c.g) / d;
    }
    return fract(h / 6.0);
}

fn ps_key(rgb: vec3f, mode: i32) -> f32 {
    let t = ps_tonal(rgb);
    if (mode == 1) {
        return max(t.r, max(t.g, t.b));
    }
    if (mode == 2) {
        let mx = max(t.r, max(t.g, t.b));
        let mn = min(t.r, min(t.g, t.b));
        return select(0.0, (mx - mn) / mx, mx > 1e-5);
    }
    if (mode == 3) {
        return ps_hue(t);
    }
    return luminance(t);
}

fn ps_quant(k: f32) -> i32 {
    return min(i32(clamp(k, 0.0, 1.0) * f32(PS_KEY_LEVELS)), PS_KEY_LEVELS - 1);
}

fn ps_qat(base: vec2i, axis: vec2i, j: i32, mode: i32) -> i32 {
    return ps_quant(ps_key(ps_load(base + axis * j), mode));
}

fn ps_count_below(base: vec2i, axis: vec2i, n: i32, mode: i32, t: i32) -> i32 {
    var c = 0;
    for (var j = 0; j < n; j++) {
        if (ps_qat(base, axis, j, mode) < t) { c += 1; }
    }
    return c;
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let amount = clamp(p[7], 0.0, 1.0);
    if (amount <= 0.0) { return color; }

    let dir = i32(clamp(p[0], 0.0, 3.0));
    let vertical = dir < 2;
    let descending = (dir == 1) || (dir == 3);
    let lo_t = min(p[1], p[2]);
    let hi_t = max(p[1], p[2]);
    let max_len = clamp(i32(p[3]), 2, PS_MAX_SPAN);
    let mode = i32(clamp(p[4], 0.0, 3.0));

    let dims = ps_dims();
    let pix = vec2i(clamp(floor(clamp_uv(uv) * vec2f(dims)), vec2f(0.0), vec2f(dims) - vec2f(1.0)));

    let luma_here = ps_luma(ps_load(pix));
    if (luma_here < lo_t || luma_here > hi_t) { return color; }

    let axis = select(vec2i(1, 0), vec2i(0, 1), vertical);
    let here = select(pix.x, pix.y, vertical);
    let extent = select(dims.x, dims.y, vertical);
    let row = select(pix.y, pix.x, vertical);

    let jitter = clamp(p[5], 0.0, 1.0);
    let off = i32(hash12(vec2f(f32(row) * 0.137 + 11.3, f32(dir) * 3.1 + pp.slot)) * jitter * f32(max_len));
    let chunk = ((here + off) / max_len) * max_len - off;
    let win_start = max(chunk, 0);
    let win_end = min(chunk + max_len, extent);

    let skip = clamp(p[6], 0.0, 1.0);
    if (skip > 0.0 && hash12(vec2f(f32(chunk) * 0.0173 + 7.7, f32(row) * 0.311 + pp.slot * 5.0)) < skip) {
        return color;
    }

    var start = here;
    for (var s = 0; s < PS_MAX_SPAN; s++) {
        if (start <= win_start) { break; }
        let l = ps_luma(ps_load(pix + axis * (start - 1 - here)));
        if (l < lo_t || l > hi_t) { break; }
        start -= 1;
    }
    var last = here;
    for (var s = 0; s < PS_MAX_SPAN; s++) {
        if (last >= win_end - 1) { break; }
        let l = ps_luma(ps_load(pix + axis * (last + 1 - here)));
        if (l < lo_t || l > hi_t) { break; }
        last += 1;
    }
    let n = last - start + 1;
    if (n < 2) { return color; }

    let local = here - start;
    let rank = select(local, n - 1 - local, descending);
    let base = pix + axis * (start - here);

    var lo_q = 0;
    var lo_c = 0;
    var hi_q = PS_KEY_LEVELS;
    for (var b = 0; b < PS_KEY_BITS; b++) {
        let mid = (lo_q + hi_q) / 2;
        let c = ps_count_below(base, axis, n, mode, mid);
        if (c <= rank) {
            lo_q = mid;
            lo_c = c;
        } else {
            hi_q = mid;
        }
    }

    var need = rank - lo_c;
    var pick = local;
    for (var j = 0; j < n; j++) {
        if (ps_qat(base, axis, j, mode) == lo_q) {
            if (need == 0) {
                pick = j;
                break;
            }
            need -= 1;
        }
    }

    return vec4f(mix(color.rgb, ps_load(base + axis * pick), amount), color.a);
}
