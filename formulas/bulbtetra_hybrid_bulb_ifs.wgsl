// @param Power min=2 max=16 default=6
// @param Scale min=1.5 max=3 default=2
// @param Iterations min=1 max=20 default=8 int
// @param OffsetX min=0 max=2 default=1
// @param OffsetY min=0 max=2 default=1
// @param OffsetZ min=0 max=2 default=1
// @param ThetaPhaseDeg min=-180 max=180 default=0
// @param PhiPhaseDeg min=-180 max=180 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[2]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let power = p[0];
    let scale = p[1];
    let offset = vec3f(p[3], p[4], p[5]);

    let r0 = length(carry.z);
    var z = carry.z;
    var dr = carry.dr;
    if (r0 <= BULB_BAILOUT) {
        let theta = acos(clamp(z.z / r0, -1.0, 1.0)) * power + radians(p[6]);
        let phi = atan2(z.y, z.x) * power + radians(p[7]);
        let zr = pow(r0, power);
        dr = pow(r0, power - 1.0) * power * dr;
        z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + pos;
    }

    z = tetra_fold(z);
    z = z * scale - offset * (scale - 1.0);
    dr = dr * scale;

    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
