// @param FoldingLimit min=0.1 max=2 default=1
// @param CenterX min=-2 max=2 default=1
// @param CenterY min=-2 max=2 default=1
// @param CenterZ min=-2 max=2 default=1
// @param Radius min=0.1 max=3 default=1
// @param CellSize min=0.5 max=4 default=2
// @param Iterations min=1 max=30 default=14 int
// @param CScale min=-2 max=2 default=1
// @param JuliaX min=-2 max=2 default=0
// @param JuliaY min=-2 max=2 default=0
// @param JuliaZ min=-2 max=2 default=0
fn de_iterations(p: Params) -> i32 {
    return i32(p[6]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let folding_limit = p[0];
    let center = vec3f(p[1], p[2], p[3]);
    let radius2 = p[4] * p[4];
    let cell = p[5];

    var z = box_fold(carry.z, folding_limit);
    var dr = carry.dr;

    z = lattice_wrap(z, cell);

    let si = sphere_invert_offset(z, dr, center, radius2);
    z = si.xyz;
    dr = si.w;

    z = z + pos * p[7] + vec3f(p[8], p[9], p[10]);
    dr = dr + max(abs(p[7]), 1.0);
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
