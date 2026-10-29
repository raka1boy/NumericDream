// @param Power1 min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
// @param Power2 min=2 max=16 default=3
// @param ThetaPhaseDeg min=-180 max=180 default=0
// @param PhiPhaseDeg min=-180 max=180 default=0
// @param CScale min=-2 max=2 default=1
// @param JuliaX min=-2 max=2 default=0
// @param JuliaY min=-2 max=2 default=0
// @param JuliaZ min=-2 max=2 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let power1 = p[0];
    let power2 = p[2];
    let r0 = length(carry.z);
    if (r0 > BULB_BAILOUT) {
        return carry;
    }

    var z = carry.z;
    var dr = carry.dr;

    let r1 = length(z);
    let theta1 = acos(clamp(z.z / r1, -1.0, 1.0)) * power1 + radians(p[3]);
    let phi1 = atan2(z.y, z.x) * power1 + radians(p[4]);
    let zr1 = pow(r1, power1);
    dr = pow(r1, power1 - 1.0) * power1 * dr;
    z = zr1 * vec3f(sin(theta1) * cos(phi1), sin(theta1) * sin(phi1), cos(theta1));

    let r2 = length(z);
    let theta2 = acos(clamp(z.z / r2, -1.0, 1.0)) * power2 + radians(p[3]);
    let phi2 = atan2(z.y, z.x) * power2 + radians(p[4]);
    let zr2 = pow(r2, power2);
    dr = pow(r2, power2 - 1.0) * power2 * dr;
    z = zr2 * vec3f(sin(theta2) * cos(phi2), sin(theta2) * sin(phi2), cos(theta2)) + pos * p[5] + vec3f(p[6], p[7], p[8]);
    dr = dr + max(abs(p[5]), 1.0);

    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
