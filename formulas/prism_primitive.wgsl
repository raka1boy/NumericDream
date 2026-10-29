// @param Size min=0.02 max=8 default=1
// @param Height min=0.02 max=8 default=1
// @param Sides min=3 max=12 default=6 int
fn de_iterations(p: Params) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let c = primitive_de_step(carry, p[0]);
    let half_height = p[1] / max(p[0], EPSILON);
    let wedge = PI / max(round(p[2]), 3.0);
    let cs = vec2f(cos(wedge), sin(wedge));

    let a = wrap_angle(atan2(c.z.x, c.z.z), 2.0 * wedge) - wedge;
    var q = length(c.z.xz) * vec2f(cos(a), abs(sin(a))) - cs;
    q.y += clamp(-q.y, 0.0, cs.y);
    let edge = length(q) * select(-1.0, 1.0, q.x > 0.0);

    return IterCarry(vec3f(edge, abs(c.z.y) - half_height, 0.0), c.dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let e = carry.z.xy;
    let outside = length(max(e, vec2f(0.0)));
    let inside = min(max(e.x, e.y), 0.0);
    return (outside + inside) / max(abs(carry.dr), EPSILON_FINE);
}
