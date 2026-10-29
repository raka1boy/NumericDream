// @image Height map
// @param Size min=0.05 max=8 default=1
// @param Height min=-1 max=1 default=0.2
// @param Base min=0 max=0.5 default=0.02
// @param Red scale min=-1 max=1 default=0.2126
// @param Green scale min=-1 max=1 default=0.7152
// @param Blue scale min=-1 max=1 default=0.0722
// @param Alpha scale min=-1 max=1 default=0
// @param Invert min=0 max=1 default=0 int
fn de_iterations(p: Params) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let size = max(p[0], EPSILON);
    let q = carry.z / (size * max(abs(carry.dr), EPSILON_FINE));
    let lift = p[1];
    let base = max(p[2], 0.0);
    let up = lift >= 0.0;
    let w = vec4f(p[3], p[4], p[5], p[6]);
    let k = select(w, vec4f(-w.xyz, dot(w, vec4f(1.0))), p[7] > 0.5);
    let info = image_info();

    var half = vec2f(1.0);
    var texel = 0.0;
    var s = ImageSample(vec4f(0.0), vec4f(0.0), vec4f(0.0));
    var h_lo = 0.0;
    var h_hi = 0.0;
    if (info.size.x > 0u) {
        let dims = vec2f(info.size);
        half = dims / max(dims.x, dims.y);
        texel = 2.0 / max(dims.x, dims.y);
        s = image_sample(info, q.xz / half * 0.5 + 0.5);
        let rgb = vec3f(1.0);
        h_lo = min(0.0, k.w + dot(min(k.xyz, vec3f(0.0)), rgb));
        h_hi = max(0.0, k.w + dot(max(k.xyz, vec3f(0.0)), rgb));
    }

    let top = lift * dot(k, s.value);
    let dy = select(top - q.y, q.y - top, up);
    let flat_side = select(q.y - base, -base - q.y, up);

    let ak = abs(k);
    let per_texel = abs(lift) / max(texel, EPSILON_FINE);
    let g = per_texel * vec3f(dot(ak, info.slope), dot(ak, s.near), dot(ak, s.far));
    let c = dy / sqrt(1.0 + g * g);
    let near = IMAGE_SLOPE_RADIUS_NEAR * texel;
    let far = IMAGE_SLOPE_RADIUS_FAR * texel;
    let c_near = clamp(c.y, -near, near);
    let c_far = clamp(c.z, -far, far);
    let curved = select(min(c.x, min(c_near, c_far)), max(c.x, max(c_near, c_far)), dy >= 0.0);

    let t_min = min(lift * h_lo, lift * h_hi);
    let t_max = max(lift * h_lo, lift * h_hi);
    let lo = select(min(t_min, base), -base, up);
    let hi = select(base, max(t_max, -base), up);
    let e = vec3f(abs(q.x) - half.x, max(lo - q.y, q.y - hi), abs(q.z) - half.y);
    let bounds = length(max(e, vec3f(0.0))) + min(max(e.x, max(e.y, e.z)), 0.0);

    let d = max(max(curved, flat_side), bounds);
    let elevation = clamp((q.y - lo) / max(hi - lo, EPSILON), 0.0, 1.0);
    return IterCarry(vec3f(0.0, elevation, 0.0), d * size);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
