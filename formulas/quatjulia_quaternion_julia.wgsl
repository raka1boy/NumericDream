// @param C real min=-1.5 max=1.5 default=-0.2
// @param C i min=-1.5 max=1.5 default=0.6
// @param C j min=-1.5 max=1.5 default=0.2
// @param C k min=-1.5 max=1.5 default=-0.2
// @param Slice W min=-1.5 max=1.5 default=0
// @param Iterations min=2 max=20 default=11 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[5]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let cv = vec3f(p[1], p[2], p[3]);
    let cv_len = length(cv);

    var s = carry.z;
    var dr = -carry.dr;
    if (carry.dr > 0.0) {
        let axis = select(vec3f(1.0, 0.0, 0.0), cv / cv_len, cv_len > 1e-6);
        let v = vec3f(carry.z.y, carry.z.z, p[4]);
        let along = dot(v, axis);
        s = vec3f(carry.z.x, along, length(v - along * axis));
        dr = carry.dr;
    }

    let r2 = dot(s, s);
    if (r2 > 256.0) {
        return IterCarry(s, -dr);
    }
    let q = vec3f(s.x * s.x - s.y * s.y - s.z * s.z + p[0], 2.0 * s.x * s.y + cv_len, 2.0 * s.x * s.z);
    return IterCarry(q, -2.0 * sqrt(r2) * dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let r = length(carry.z);
    return 0.5 * log(max(r, 1e-6)) * r / max(abs(carry.dr), 1e-6);
}
