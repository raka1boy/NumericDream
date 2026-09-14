// Buffalo Twist: the Buffalo fold with a per-iteration rotation.

// @param Scale min=-3 max=3 default=-1.6
// @param MinRadius min=0.05 max=1 default=0.5
// @param FixedRadius min=0.5 max=3 default=1
// @param RotationDeg min=-180 max=180 default=15
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[4]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let min_radius2 = p[1] * p[1];
    let fixed_radius2 = p[2] * p[2];
    let angle = radians(p[3]);

    var z = abs(carry.z);
    var dr = carry.dr;

    let sf = sphere_fold(z, dr, min_radius2, fixed_radius2);
    z = sf.xyz;
    dr = sf.w;

    let ca = cos(angle);
    let sa = sin(angle);
    z = vec3f(z.x * ca - z.y * sa, z.x * sa + z.y * ca, z.z);

    z = z * scale + pos;
    dr = dr * abs(scale) + 1.0;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_scaled(carry);
}
