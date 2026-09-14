// Torus primitive lying flat in XZ.

// @param Size min=0.05 max=8 default=1
fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return primitive_de_step(carry, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let tube = 0.3;
    let q = vec2f(length(carry.z.xz) - 1.0, carry.z.y);
    return (length(q) - tube) / max(abs(carry.dr), 1e-6);
}
