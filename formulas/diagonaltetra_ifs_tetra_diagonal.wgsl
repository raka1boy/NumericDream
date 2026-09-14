// Diagonal Tetra: Sierpinski tetra fold with a diagonal pre-swap.

// @param Scale min=1.5 max=3 default=2
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let offset = vec3f(1.0, 1.0, 1.0);

    var z = carry.z;

    if (z.x < z.y) {
        let t = z.x;
        z.x = z.y;
        z.y = t;
    }

    z = tetra_fold(z);
    z = z * scale - offset * (scale - 1.0);
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
