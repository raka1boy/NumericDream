// @param Scale min=1.5 max=5 default=3
// @param RotationDeg min=-180 max=180 default=0
// @param Iterations min=1 max=16 default=8 int
// @param OffsetX min=0 max=2 default=1
// @param OffsetY min=0 max=2 default=1
// @param OffsetZ min=0 max=2 default=1
// @param RotXDeg min=-180 max=180 default=0
// @param RotYDeg min=-180 max=180 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[2]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let scale = p[0];
    let angle = radians(p[1]);
    let offset = vec3f(p[3], p[4], p[5]);

    var z = sort_desc_abs(carry.z);

    z = z * scale - offset * (scale - 1.0);
    if (z.z < -0.5 * offset.z * (scale - 1.0)) {
        z.z += offset.z * (scale - 1.0);
    }

    let ca = cos(angle);
    let sa = sin(angle);
    z = vec3f(z.x * ca - z.y * sa, z.x * sa + z.y * ca, z.z);
    z = rotate_xyz_deg(z, vec3f(p[6], p[7], 0.0));

    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let q = abs(carry.z) - vec3f(1.0);
    return length(max(q, vec3f(0.0))) / carry.dr;
}
