// Bulb Tetra: Mandelbulb power step alternated with a Sierpinski tetra fold.

// @param Power min=2 max=16 default=6
// @param Scale min=1.5 max=3 default=2
// @param Iterations min=1 max=20 default=8 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[2]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let power = p[0];
    let scale = p[1];
    let offset = vec3f(1.0, 1.0, 1.0);

    let r0 = length(carry.z);
    var z = carry.z;
    var dr = carry.dr;
    if (r0 <= 2.0) {
        let theta = acos(clamp(z.z / r0, -1.0, 1.0)) * power;
        let phi = atan2(z.y, z.x) * power;
        let zr = pow(r0, power);
        dr = pow(r0, power - 1.0) * power * dr;
        z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + pos;
    }

    z = tetra_fold(z);
    z = z * scale - offset * (scale - 1.0);
    dr = dr * scale;

    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
