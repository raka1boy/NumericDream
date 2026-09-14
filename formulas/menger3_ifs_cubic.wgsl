// Menger3: the classic Menger sponge as an abs-fold-and-sort IFS.

// @param Iterations min=1 max=8 default=4 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = 3.0;
    let offset = vec3f(1.0, 1.0, 1.0);

    var z = sort_desc_abs(carry.z);
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
