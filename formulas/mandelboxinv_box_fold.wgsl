// @param InvRadius min=0.1 max=2 default=0.7
// @param Scale min=-3 max=3 default=2
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param FoldingLimit min=0.1 max=2 default=1
// @param Iterations min=1 max=30 default=12 int
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
    let inv_radius2 = p[0] * p[0];
    let scale = p[1];
    let min_radius2 = p[2] * p[2];
    let fixed_radius2 = p[3] * p[3];
    let folding_limit = p[4];

    var z = carry.z;
    var dr = carry.dr;
    let r2in = max(dot(z, z), EPSILON_FINE);
    let tin = inv_radius2 / r2in;
    z *= tin;
    dr *= tin;

    z = box_fold(z, folding_limit);

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    z = rotate_xyz_deg(z, vec3f(p[6], p[7], p[8]));
    z = z * scale + pos * p[9] + vec3f(p[10], p[11], p[12]);
    dr = dr * abs(scale) + max(abs(p[9]), 1.0);
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
