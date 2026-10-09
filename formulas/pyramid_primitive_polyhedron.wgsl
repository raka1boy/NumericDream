// @param Size min=0.02 max=8 default=1
const PYRAMID_SLOPE = 2.0;
const PYRAMID_NORMAL_LEN_SQ = 5.0;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return primitive_de_iterations();
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    return primitive_de_step(carry, p[0]);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let z = carry.z;
    let m = max(abs(z.x), abs(z.z));

    let side = (PYRAMID_SLOPE * m + z.y - 1.0) * inverseSqrt(PYRAMID_NORMAL_LEN_SQ);
    let base = -(z.y + 1.0);

    return max(side, base) / max(abs(carry.dr), EPSILON_FINE);
}
