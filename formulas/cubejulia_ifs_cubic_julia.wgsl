// Cube Julia: Menger-style abs-fold-and-sort with a fixed Julia constant.

// @param Scale min=1.5 max=3 default=2.5
// @param JuliaX min=-2 max=2 default=0.5
// @param JuliaY min=-2 max=2 default=0.5
// @param JuliaZ min=-2 max=2 default=0.5
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[4]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let c = vec3f(p[1], p[2], p[3]);

    var z = sort_desc_abs(carry.z);
    z = z * scale - c * (scale - 1.0);
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
