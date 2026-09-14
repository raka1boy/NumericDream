// Diagonal Icosa: icosahedral mirror planes with a diagonal pre-swap.

// @param Scale min=1 max=3 default=2
// @param OffsetX min=0 max=1.2 default=0.850650808
// @param OffsetY min=0 max=1.2 default=0.525731112
// @param Iterations min=1 max=20 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[3]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let offset = vec3f(p[1], p[2], 0.0);
    let phi = 1.6180339887498949;

    let n1 = normalize(vec3f(-phi, phi - 1.0, 1.0));
    let n2 = normalize(vec3f(1.0, -phi, phi + 1.0));
    let n3 = normalize(vec3f(0.0, 0.0, -1.0));

    var z = abs(carry.z);

    if (z.x < z.y) {
        let t = z.x;
        z.x = z.y;
        z.y = t;
    }

    var t2 = dot(z, n1);
    if (t2 > 0.0) {
        z -= 2.0 * t2 * n1;
    }
    t2 = dot(z, n2);
    if (t2 > 0.0) {
        z -= 2.0 * t2 * n2;
    }
    t2 = dot(z, n3);
    if (t2 > 0.0) {
        z -= 2.0 * t2 * n3;
    }

    z = (z - offset) * scale + offset;
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
