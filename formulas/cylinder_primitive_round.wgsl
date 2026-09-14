// Capped cylinder primitive on +Y.

// @param Size min=0.02 max=8 default=1
fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return primitive_de_step(carry, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let e = vec2f(length(carry.z.xz) - 1.0, abs(carry.z.y) - 1.0);
    let outside = length(max(e, vec2f(0.0)));
    let inside = min(max(e.x, e.y), 0.0);
    return (outside + inside) / max(abs(carry.dr), 1e-6);
}
