// @param Distortion k1 min=-0.6 max=0.6 default=0.15
// @param Distortion k2 min=-0.4 max=0.4 default=0.0
// @param Zoom min=0.5 max=1.6 default=1.0
// @param Chromatic min=0.0 max=0.05 default=0.004
// @param Edge mode min=0 max=2 default=0 int
// @param Corner darkening min=0.0 max=1.0 default=0.2

fn lens_to_centred(uv: vec2f) -> vec2f {
    var c = uv * 2.0 - vec2f(1.0);
    c.x *= max(pp.aspect, 1.0);
    return c;
}

fn lens_from_centred(c: vec2f) -> vec2f {
    var o = c;
    o.x /= max(pp.aspect, 1.0);
    return o * 0.5 + vec2f(0.5);
}

fn lens_mirror(v: f32) -> f32 {
    let t = abs(fract(v * 0.5) * 2.0);
    return 1.0 - abs(t - 1.0);
}

fn lens_sample(uv: vec2f, mode: i32) -> vec3f {
    if (mode == 2) {
        return scene_color(vec2f(lens_mirror(uv.x), lens_mirror(uv.y)));
    }
    if (mode == 0 && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
        return vec3f(0.0);
    }
    return scene_color(uv);
}

fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f {
    let c = lens_to_centred(uv);
    let r2 = dot(c, c);
    let warped = c * (1.0 + p[0] * r2 + p[1] * r2 * r2) / max(p[2], 1e-3);

    let mode = i32(round(clamp(p[4], 0.0, 2.0)));
    let ca = p[3];
    let rgb = vec3f(
        lens_sample(lens_from_centred(warped * (1.0 - ca)), mode).r,
        lens_sample(lens_from_centred(warped), mode).g,
        lens_sample(lens_from_centred(warped * (1.0 + ca)), mode).b,
    );

    let falloff = 1.0 / ((1.0 + r2) * (1.0 + r2));
    return vec4f(max(rgb, vec3f(0.0)) * mix(1.0, falloff, p[5]), color.a);
}
