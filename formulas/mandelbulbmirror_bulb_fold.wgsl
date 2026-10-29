// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
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
    let power = p[0];
    var zin = carry.z;
    zin.y = -zin.y;

    let r = length(zin);
    if (r > BULB_BAILOUT) {
        return carry;
    }
    let theta = acos(clamp(zin.z / r, -1.0, 1.0)) * power + radians(p[2]);
    let phi = atan2(zin.y, zin.x) * power + radians(p[3]);
    let zr = pow(r, power);
    let dr = pow(r, power - 1.0) * power * carry.dr + max(abs(p[4]), 1.0);
    let z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + pos * p[4] + vec3f(p[5], p[6], p[7]);
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
