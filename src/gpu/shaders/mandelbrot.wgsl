// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=6 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return bulb_power_step(carry, pos, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
