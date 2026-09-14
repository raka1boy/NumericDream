// Pseudo Kleinian: lattice-wrapped off-centre sphere inversion.

// @param CenterX min=-2 max=2 default=1
// @param CenterY min=-2 max=2 default=1
// @param CenterZ min=-2 max=2 default=1
// @param Radius min=0.1 max=3 default=1
// @param CellSize min=0.5 max=4 default=2
// @param Iterations min=1 max=30 default=14 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[5]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let center = vec3f(p[0], p[1], p[2]);
    let radius2 = p[3] * p[3];
    let cell = p[4];

    var z = lattice_wrap(carry.z, cell);
    var dr = carry.dr;

    let si = sphere_invert_offset(z, dr, center, radius2);
    z = si.xyz;
    dr = si.w;

    z = z + pos;
    dr = dr + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
