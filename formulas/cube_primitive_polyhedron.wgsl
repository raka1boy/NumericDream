// Cube primitive (exact signed distance), mixable like the other primitives.

// @param Size min=0.02 max=8 default=1
fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return primitive_de_step(carry, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let q = abs(carry.z) - vec3f(1.0);
    let outside = length(max(q, vec3f(0.0)));
    let inside = min(max(q.x, max(q.y, q.z)), 0.0);
    return (outside + inside) / max(abs(carry.dr), 1e-6);
}
