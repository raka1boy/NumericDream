// Mandelbulb Mirror: the Mandelbulb power step with Y mirrored each iteration.

// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let power = p[0];
    var zin = carry.z;
    zin.y = -zin.y; // conjugate mirror before this iteration's power step

    let r = length(zin);
    if (r > 2.0) {
        return carry;
    }
    let theta = acos(clamp(zin.z / r, -1.0, 1.0)) * power;
    let phi = atan2(zin.y, zin.x) * power;
    let zr = pow(r, power);
    let dr = pow(r, power - 1.0) * power * carry.dr + 1.0;
    let z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta)) + pos;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
