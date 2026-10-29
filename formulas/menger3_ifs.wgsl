// @param Iterations min=1 max=8 default=4 int
// @param Scalex min=1 max=12 default=1
// @param Scaley min=1 max=12 default=1
// @param Scalez min=1 max=12 default=1
// @param Scale min=1.5 max=4.5 default=3
// @param RotXDeg min=-180 max=180 default=0
// @param RotYDeg min=-180 max=180 default=0
// @param RotZDeg min=-180 max=180 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[0]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let scale = p[4];
    let offset = vec3f(1.0 * p[1], 1.0 * p[2], 1.0 * p[3]);

    var z = rotate_xyz_deg(sort_desc_abs(carry.z), vec3f(p[5], p[6], p[7]));
    z = z * scale - offset * (scale - 1.0);
    if (z.z < -0.5 * offset.z * (scale - 1.0)) {
        z.z += offset.z * (scale - 1.0);
    }
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let q = abs(carry.z) - vec3f(1.0);
    return length(max(q, vec3f(0.0))) / carry.dr;
}
