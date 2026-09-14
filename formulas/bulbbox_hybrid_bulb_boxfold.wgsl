// Bulb Box: Mandelbulb power step alternated with a Mandelbox fold.

// @param Power min=2 max=16 default=6
// @param Scale min=-3 max=3 default=1.5
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param FoldingLimit min=0.1 max=2 default=1
// @param Iterations min=1 max=20 default=8 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[5]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let power = p[0];
    let scale = p[1];
    let min_radius2 = p[2] * p[2];
    let fixed_radius2 = p[3] * p[3];
    let folding_limit = p[4];

    let r0 = length(carry.z);
    var z = carry.z;
    var dr = carry.dr;
    if (r0 <= 2.0) {
        let theta = acos(clamp(z.z / r0, -1.0, 1.0)) * power;
        let phi = atan2(z.y, z.x) * power;
        let zr = pow(r0, power);
        dr = pow(r0, power - 1.0) * power * dr;
        z = zr * vec3f(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    }

    z = box_fold(z, folding_limit);

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    z = z * scale + pos;
    dr = dr * abs(scale) + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
