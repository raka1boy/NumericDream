// Kaleidoscopic IFS: abs-fold-sort-scale-translate with a per-iteration rotation.

// @param Scale min=1.5 max=5 default=3
// @param RotationDeg min=-180 max=180 default=0
// @param Iterations min=1 max=16 default=8 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[2]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let angle = radians(p[1]);
    let offset = vec3f(1.0, 1.0, 1.0);

    var z = sort_desc_abs(carry.z);

    z = z * scale - offset * (scale - 1.0);
    if (z.z < -0.5 * offset.z * (scale - 1.0)) {
        z.z += offset.z * (scale - 1.0);
    }

    let ca = cos(angle);
    let sa = sin(angle);
    z = vec3f(z.x * ca - z.y * sa, z.x * sa + z.y * ca, z.z);

    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let q = abs(carry.z) - vec3f(1.0);
    return length(max(q, vec3f(0.0))) / carry.dr;
}
