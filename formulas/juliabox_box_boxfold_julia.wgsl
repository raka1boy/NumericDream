// Julia Box: the Mandelbox fold with a fixed Julia constant.

// @param Scale min=-3 max=3 default=2
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param FoldingLimit min=0.1 max=2 default=1
// @param JuliaX min=-2 max=2 default=0.6
// @param JuliaY min=-2 max=2 default=0.2
// @param JuliaZ min=-2 max=2 default=0.5
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[7]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let min_radius2 = p[1] * p[1];
    let fixed_radius2 = p[2] * p[2];
    let folding_limit = p[3];
    let c = vec3f(p[4], p[5], p[6]);

    var z = box_fold(carry.z, folding_limit);

    let sf = sphere_fold(z, carry.dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    var dr = sf.w;

    z = z * scale + c;
    dr = dr * abs(scale) + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
