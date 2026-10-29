// @param Scale min=-3 max=3 default=-1.5
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param Iterations min=1 max=30 default=14 int
// @param RotXDeg min=-180 max=180 default=0
// @param RotYDeg min=-180 max=180 default=0
// @param RotZDeg min=-180 max=180 default=0
// @param CScale min=-2 max=2 default=1
// @param JuliaX min=-2 max=2 default=0
// @param JuliaY min=-2 max=2 default=0
// @param JuliaZ min=-2 max=2 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[3]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let scale = p[0];
    let min_radius2 = p[1] * p[1];
    let fixed_radius2 = p[2] * p[2];

    var z = carry.z;
    var dr = carry.dr;

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    z = rotate_xyz_deg(z, vec3f(p[4], p[5], p[6]));
    z = z * scale + pos * p[7] + vec3f(p[8], p[9], p[10]);
    dr = dr * abs(scale) + max(abs(p[7]), 1.0);
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
