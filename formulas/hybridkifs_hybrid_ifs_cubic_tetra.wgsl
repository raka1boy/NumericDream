// Hybrid KIFS: Sierpinski tetra fold alternated with a Menger cube fold.

// @param Scale min=1.5 max=3 default=2.5
// @param Iterations min=1 max=20 default=10 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let offset = vec3f(1.0, 1.0, 1.0);

    var z = carry.z;

    z = tetra_fold(z);

    z = sort_desc_abs(z);

    z = z * scale - offset * (scale - 1.0);
    if (z.z < -0.5 * offset.z * (scale - 1.0)) {
        z.z += offset.z * (scale - 1.0);
    }

    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let q = abs(carry.z) - vec3f(1.0);
    return length(max(q, vec3f(0.0))) / carry.dr;
}
