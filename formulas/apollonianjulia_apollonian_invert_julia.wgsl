// Apollonian Julia: the Apollonian fold with a fixed Julia constant.

// @param Scale min=-3 max=3 default=-1.5
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param JuliaX min=-2 max=2 default=0.5
// @param JuliaY min=-2 max=2 default=0.5
// @param JuliaZ min=-2 max=2 default=0.0
// @param Iterations min=1 max=30 default=14 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[6]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let min_radius2 = p[1] * p[1];
    let fixed_radius2 = p[2] * p[2];
    let c = vec3f(p[3], p[4], p[5]);

    var z = carry.z;
    var dr = carry.dr;

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    z = z * scale + c;
    dr = dr * abs(scale) + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
