// @param Scale min=1.5 max=3 default=2.5
// @param Iterations min=1 max=20 default=10 int
// @param OffsetX min=0 max=2 default=1
// @param OffsetY min=0 max=2 default=1
// @param OffsetZ min=0 max=2 default=1
// @param RotXDeg min=-180 max=180 default=0
// @param RotYDeg min=-180 max=180 default=0
// @param RotZDeg min=-180 max=180 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let scale = p[0];
    let offset = vec3f(p[2], p[3], p[4]);

    var z = carry.z;

    z = tetra_fold(z);

    z = rotate_xyz_deg(sort_desc_abs(z), vec3f(p[5], p[6], p[7]));

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
