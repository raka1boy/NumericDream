// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
// @param RotationDeg min=-180 max=180 default=12
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
    let angle = radians(p[2]);
    let r = length(carry.z);
    if (r > BULB_BAILOUT) {
        return carry;
    }
    let theta = acos(clamp(carry.z.z / r, -1.0, 1.0)) * power + radians(p[3]);
    let phi = atan2(carry.z.y, carry.z.x) * power + radians(p[4]);
    let zr = pow(r, power);
    let dr = pow(r, power - 1.0) * power * carry.dr + max(abs(p[5]), 1.0);

    var z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    let ca = cos(angle);
    let sa = sin(angle);
    z = vec3f(z.x * ca - z.y * sa, z.x * sa + z.y * ca, z.z);
    z = z + pos * p[5] + vec3f(p[6], p[7], p[8]);

    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
