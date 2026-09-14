// Juliabulb: the Mandelbulb power step with a fixed Julia constant.

// @param Power min=2 max=16 default=8
// @param Iterations min=2 max=16 default=8 int
// @param JuliaX min=-2 max=2 default=-0.65
// @param JuliaY min=-2 max=2 default=0.35
// @param JuliaZ min=-2 max=2 default=0.2
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let power = p[0];
    let c = vec3f(p[2], p[3], p[4]);
    return bulb_power_step(carry, c, power);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bulb_log_escape(carry);
}
