// Mandelbulb Twist: the Mandelbulb power step with a per-iteration rotation.

// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
// @param RotationDeg min=-180 max=180 default=12
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let power = p[0];
    let angle = radians(p[2]);
    let r = length(carry.z);
    if (r > 2.0) {
        return carry;
    }
    let theta = acos(clamp(carry.z.z / r, -1.0, 1.0)) * power;
    let phi = atan2(carry.z.y, carry.z.x) * power;
    let zr = pow(r, power);
    let dr = pow(r, power - 1.0) * power * carry.dr + 1.0;

    var z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    let ca = cos(angle);
    let sa = sin(angle);
    z = vec3f(z.x * ca - z.y * sa, z.x * sa + z.y * ca, z.z);
    z = z + pos;

    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
