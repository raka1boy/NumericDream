// Credits: "Radioactive" by @XorDev (Shadertoy)

// @param Iterations min=1 max=20 default=13 int
// @param Size min=0.1 max=20 default=7
// @param Twist min=-3.1416 max=3.1416 default=0.8
// @param Cube min=0.05 max=1 default=0.8
// @param Ratio min=0.3 max=0.8 default=0.5
// @param Floor min=-10 max=10 default=0
const RADIOACTIVE_MIN_MAGNITUDE = 1e-30;
const RADIOACTIVE_LEVEL_MASK = 31u;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn radioactive_pack(m: f32, level: u32) -> f32 {
    let safe = select(m, RADIOACTIVE_MIN_MAGNITUDE, abs(m) < RADIOACTIVE_MIN_MAGNITUDE);
    return bitcast<f32>((bitcast<u32>(safe) & ~RADIOACTIVE_LEVEL_MASK) | level);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let level = bitcast<u32>(carry.dr) & RADIOACTIVE_LEVEL_MASK;
    var v = carry.z;
    var s = carry.dr;
    if (level == 0u) {
        s = v.y - p[5];
    }

    let i = p[1] * pow(p[4], f32(level));
    let c = cos(p[2]);
    let sn = sin(p[2]);
    v = vec3f(v.x * c + v.z * sn, v.y, v.z * c - v.x * sn);
    let w = 2.0 * i;
    v = vec3f(i * p[3]) - abs(v - w * floor(v / w) - vec3f(i));
    s = max(s, min(min(v.x, v.y), v.z));

    return IterCarry(v, radioactive_pack(s, min(level + 1u, RADIOACTIVE_LEVEL_MASK)));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
