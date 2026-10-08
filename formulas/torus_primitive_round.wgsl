// @param Size min=0.05 max=8 default=1
// @param Thickness min=0.01 max=1 default=0.3
fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let tube = max(p[1], 1e-4);
    let scaled = pos / tube;
    let q = vec2f(length(scaled.xz) - p[0] / tube, scaled.y);
    return IterCarry(vec3f(q, 0.0), 1.0 / tube);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return (length(carry.z.xy) - 1.0) / max(abs(carry.dr), 1e-6);
}
