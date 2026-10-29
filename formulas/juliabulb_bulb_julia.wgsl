// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=8 int
// @param JuliaX min=-2 max=2 default=-0.65
// @param JuliaY min=-2 max=2 default=0.35
// @param JuliaZ min=-2 max=2 default=0.2
// @param ThetaPhaseDeg min=-180 max=180 default=0
// @param PhiPhaseDeg min=-180 max=180 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let power = p[0];
    let c = vec3f(p[2], p[3], p[4]);
    let r = length(carry.z);
    if (r > BULB_BAILOUT) {
        return carry;
    }
    let theta = acos(clamp(carry.z.z / r, -1.0, 1.0)) * power + radians(p[5]);
    let phi = atan2(carry.z.y, carry.z.x) * power + radians(p[6]);
    let rp = pow(r, power - 1.0);
    let zr = rp * r;
    let dr = rp * power * carry.dr + 1.0;
    let z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + c;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
