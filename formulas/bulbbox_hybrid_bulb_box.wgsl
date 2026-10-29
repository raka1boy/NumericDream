// @param Power min=2 max=16 default=6
// @param Scale min=-3 max=3 default=1.5
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param FoldingLimit min=0.1 max=2 default=1
// @param Iterations min=1 max=20 default=8 int
// @param ThetaPhaseDeg min=-180 max=180 default=0
// @param PhiPhaseDeg min=-180 max=180 default=0
// @param RotXDeg min=-180 max=180 default=0
// @param RotYDeg min=-180 max=180 default=0
// @param RotZDeg min=-180 max=180 default=0
// @param CScale min=-2 max=2 default=1
// @param JuliaX min=-2 max=2 default=0
// @param JuliaY min=-2 max=2 default=0
// @param JuliaZ min=-2 max=2 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[5]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let power = p[0];
    let scale = p[1];
    let min_radius2 = p[2] * p[2];
    let fixed_radius2 = p[3] * p[3];
    let folding_limit = p[4];

    let r0 = length(carry.z);
    var z = carry.z;
    var dr = carry.dr;
    if (r0 <= BULB_BAILOUT) {
        let theta = acos(clamp(z.z / r0, -1.0, 1.0)) * power + radians(p[6]);
        let phi = atan2(z.y, z.x) * power + radians(p[7]);
        let zr = pow(r0, power);
        dr = pow(r0, power - 1.0) * power * dr;
        z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    }

    z = box_fold(z, folding_limit);

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    z = rotate_xyz_deg(z, vec3f(p[8], p[9], p[10]));
    z = z * scale + pos * p[11] + vec3f(p[12], p[13], p[14]);
    dr = dr * abs(scale) + max(abs(p[11]), 1.0);
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
