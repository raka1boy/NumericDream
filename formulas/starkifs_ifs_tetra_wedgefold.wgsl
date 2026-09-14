// Star KIFS: polar wedge fold ahead of the Sierpinski tetra fold.

// @param Degree min=2 max=16 default=6
// @param Scale min=1.5 max=3 default=2
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[2]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let degree = max(floor(p[0]), 2.0);
    let scale = p[1];
    let offset = vec3f(1.0, 1.0, 1.0);

    var z = carry.z;

    let period = 6.28318530717959 / degree;
    var a = wrap_angle(atan2(z.y, z.x), period);
    if (a > period * 0.5) {
        a = period - a;
    }
    let r = length(z.xy);
    z = vec3f(r * cos(a), r * sin(a), z.z);

    z = tetra_fold(z);

    z = z * scale - offset * (scale - 1.0);
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
