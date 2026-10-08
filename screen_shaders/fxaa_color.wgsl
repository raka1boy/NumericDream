// @param Edge threshold min=0.02 max=0.5 default=0.125
// @param Min threshold min=0.0 max=0.1 default=0.0312
// @param Subpixel amount min=0.0 max=1.0 default=0.75
// @param Search steps min=2 max=12 default=8 int
// @param Blend amount min=0.0 max=1.0 default=1.0

const FXAA_MAX_STEPS = 12;

fn fxaa_luma_of(rgb: vec3f) -> f32 {
    let c = max(rgb, vec3f(0.0));
    return sqrt(luminance(c / (c + vec3f(1.0))));
}

fn fxaa_luma(uv: vec2f) -> f32 {
    return fxaa_luma_of(scene_color(uv));
}

fn fxaa_step_scale(i: i32) -> f32 {
    if (i < 5) { return 1.0; }
    if (i < 6) { return 1.5; }
    if (i < 10) { return 2.0; }
    if (i < 11) { return 4.0; }
    return 8.0;
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let texel = texel_size();
    let steps = i32(clamp(p[3], 2.0, f32(FXAA_MAX_STEPS)));

    let luma_c = fxaa_luma_of(color.rgb);
    let luma_d = fxaa_luma(uv + vec2f(0.0, texel.y));
    let luma_u = fxaa_luma(uv - vec2f(0.0, texel.y));
    let luma_l = fxaa_luma(uv - vec2f(texel.x, 0.0));
    let luma_r = fxaa_luma(uv + vec2f(texel.x, 0.0));

    let luma_min = min(luma_c, min(min(luma_d, luma_u), min(luma_l, luma_r)));
    let luma_max = max(luma_c, max(max(luma_d, luma_u), max(luma_l, luma_r)));
    let range = luma_max - luma_min;

    if (range < max(p[1], luma_max * p[0])) {
        return color;
    }

    let luma_dl = fxaa_luma(uv + vec2f(-texel.x, texel.y));
    let luma_ur = fxaa_luma(uv + vec2f(texel.x, -texel.y));
    let luma_dr = fxaa_luma(uv + vec2f(texel.x, texel.y));
    let luma_ul = fxaa_luma(uv + vec2f(-texel.x, -texel.y));

    let luma_du = luma_d + luma_u;
    let luma_lr = luma_l + luma_r;
    let corners_l = luma_dl + luma_ul;
    let corners_d = luma_dl + luma_dr;
    let corners_r = luma_dr + luma_ur;
    let corners_u = luma_ur + luma_ul;

    let edge_h = abs(-2.0 * luma_l + corners_l) + abs(-2.0 * luma_c + luma_du) * 2.0 + abs(-2.0 * luma_r + corners_r);
    let edge_v = abs(-2.0 * luma_u + corners_u) + abs(-2.0 * luma_c + luma_lr) * 2.0 + abs(-2.0 * luma_d + corners_d);
    let horizontal = edge_h >= edge_v;

    let luma1 = select(luma_l, luma_d, horizontal);
    let luma2 = select(luma_r, luma_u, horizontal);
    let grad1 = luma1 - luma_c;
    let grad2 = luma2 - luma_c;
    let steepest_is_1 = abs(grad1) >= abs(grad2);
    let grad_scaled = 0.25 * max(abs(grad1), abs(grad2));

    var step_length = select(texel.x, texel.y, horizontal);
    var luma_local_avg = 0.0;
    if (steepest_is_1) {
        step_length = -step_length;
        luma_local_avg = 0.5 * (luma1 + luma_c);
    } else {
        luma_local_avg = 0.5 * (luma2 + luma_c);
    }

    var mid = uv;
    if (horizontal) {
        mid.y += step_length * 0.5;
    } else {
        mid.x += step_length * 0.5;
    }

    let along = select(vec2f(0.0, texel.y), vec2f(texel.x, 0.0), horizontal);
    var uv1 = mid - along;
    var uv2 = mid + along;
    var luma_end1 = fxaa_luma(uv1) - luma_local_avg;
    var luma_end2 = fxaa_luma(uv2) - luma_local_avg;
    var reached1 = abs(luma_end1) >= grad_scaled;
    var reached2 = abs(luma_end2) >= grad_scaled;
    if (!reached1) { uv1 -= along; }
    if (!reached2) { uv2 += along; }

    if (!(reached1 && reached2)) {
        for (var i = 2; i < steps; i++) {
            if (!reached1) {
                luma_end1 = fxaa_luma(uv1) - luma_local_avg;
                reached1 = abs(luma_end1) >= grad_scaled;
            }
            if (!reached2) {
                luma_end2 = fxaa_luma(uv2) - luma_local_avg;
                reached2 = abs(luma_end2) >= grad_scaled;
            }
            if (!reached1) { uv1 -= along * fxaa_step_scale(i); }
            if (!reached2) { uv2 += along * fxaa_step_scale(i); }
            if (reached1 && reached2) { break; }
        }
    }

    let dist1 = select(uv.y - uv1.y, uv.x - uv1.x, horizontal);
    let dist2 = select(uv2.y - uv.y, uv2.x - uv.x, horizontal);
    let nearest_is_1 = dist1 < dist2;
    let thickness = dist1 + dist2;
    var final_offset = -min(dist1, dist2) / max(thickness, 1e-6) + 0.5;

    let centre_is_darker = luma_c < luma_local_avg;
    let end_luma = select(luma_end2, luma_end1, nearest_is_1);
    if ((end_luma < 0.0) == centre_is_darker) {
        final_offset = 0.0;
    }

    let luma_avg = (1.0 / 12.0) * (2.0 * (luma_du + luma_lr) + corners_l + corners_r);
    let sub1 = clamp(abs(luma_avg - luma_c) / max(range, 1e-6), 0.0, 1.0);
    let sub2 = (-2.0 * sub1 + 3.0) * sub1 * sub1;
    final_offset = max(final_offset, sub2 * sub2 * p[2]);

    var final_uv = uv;
    if (horizontal) {
        final_uv.y += final_offset * step_length;
    } else {
        final_uv.x += final_offset * step_length;
    }

    return vec4f(mix(color.rgb, scene_color(final_uv), clamp(p[4], 0.0, 1.0)), color.a);
}
