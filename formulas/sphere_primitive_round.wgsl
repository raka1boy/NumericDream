// Sphere primitive: the reference for how a primitive is made mixable (size travels in dr).

// @param Radius min=0.05 max=8 default=1
fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return primitive_de_step(carry, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return (length(carry.z) - 1.0) / max(abs(carry.dr), 1e-6);
}
