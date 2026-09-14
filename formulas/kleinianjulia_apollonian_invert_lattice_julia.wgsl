// Kleinian Julia: lattice-wrapped off-centre sphere inversion with a Julia constant.

// @param CenterX min=-2 max=2 default=1
// @param CenterY min=-2 max=2 default=1
// @param CenterZ min=-2 max=2 default=1
// @param Radius min=0.1 max=3 default=1
// @param JuliaX min=-1 max=1 default=0.2
// @param JuliaY min=-1 max=1 default=0.1
// @param JuliaZ min=-1 max=1 default=0.0
// @param Iterations min=1 max=30 default=14 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[7]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let center = vec3f(p[0], p[1], p[2]);
    let radius2 = p[3] * p[3];
    let cell = 2.0;
    let c = vec3f(p[4], p[5], p[6]);

    var z = lattice_wrap(carry.z, cell);
    var dr = carry.dr;

    let si = sphere_invert_offset(z, dr, center, radius2);
    z = si.xyz;
    dr = si.w;

    z = z + c;
    dr = dr + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
