// @param Degree min=2 max=16 default=5
// @param Scale min=1.5 max=3 default=2.5
// @param JuliaX min=-2 max=2 default=0.5
// @param JuliaY min=-2 max=2 default=0.5
// @param JuliaZ min=-2 max=2 default=0.5
// @param Iterations min=1 max=30 default=12 int
const WEDGE_MIN_DEGREE = 2.0;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[5]);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let degree = max(floor(p[0]), WEDGE_MIN_DEGREE);
    let scale = p[1];
    let c = vec3f(p[2], p[3], p[4]);

    var z = carry.z;

    let period = TAU / degree;
    var a = wrap_angle(atan2(z.y, z.x), period);
    if (a > period * 0.5) {
        a = period - a;
    }
    let r = length(z.xy);
    z = vec3f(r * cos(a), r * sin(a), z.z);

    z = sort_desc_abs(z);

    z = z * scale - c * (scale - 1.0);
    let dr = carry.dr * scale;
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return de_finalize_plain(carry);
}
