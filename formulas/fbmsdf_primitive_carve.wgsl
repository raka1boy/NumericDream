// Credits: "Fractal SDF fBM" by Inigo Quilez (Shadertoy, MIT License, 2019), iquilezles.org/articles/fbmsdf

// @param Iterations min=1 max=10 default=7 int
// @param Size min=0.1 max=4 default=1
// @param Radius min=0.1 max=1.5 default=0.7
// @param Blend min=0.01 max=0.5 default=0.15
// @param Gain min=0.3 max=0.7 default=0.55
// @param Lacunarity min=1.5 max=3 default=2
// @param Simplex min=0 max=1 default=0 int
// @param Seed min=0 max=20 default=0
const FBMSDF_HASH_GAIN = 17.0;
const FBMSDF_HASH_SCALE = 0.3183099;
const FBMSDF_HASH_OFFSET = vec3f(0.11, 0.17, 0.13);
const FBMSDF_FAR = 1e10;
const FBMSDF_CORNERS = 8u;
const FBMSDF_SIMPLEX_SKEW = 0.333333333;
const FBMSDF_SIMPLEX_UNSKEW = 0.166666667;
const FBMSDF_SIMPLEX_RADIUS = 0.55;
const FBMSDF_LATTICE_RADIUS = 0.7;
const FBMSDF_MIN_MAGNITUDE = 1e-30;
const FBMSDF_LEVEL_MASK = 31u;
const FBMSDF_LATTICE_OFFSET = 0.5;
const FBMSDF_ROT_COS = 0.80;
const FBMSDF_ROT_SIN = 0.60;
const FBMSDF_ROT_SIN_SQ = 0.36;
const FBMSDF_ROT_SIN_COS = 0.48;
const FBMSDF_ROT_COS_SQ = 0.64;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn fbmsdf_hash(c: vec3f) -> f32 {
    let q = FBMSDF_HASH_GAIN * fract(c * FBMSDF_HASH_SCALE + FBMSDF_HASH_OFFSET);
    return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

fn fbmsdf_lattice(p: vec3f, radius: f32) -> f32 {
    let i = floor(p);
    let f = p - i;
    var d = FBMSDF_FAR;
    for (var k = 0u; k < FBMSDF_CORNERS; k++) {
        let c = vec3f(f32(k & 1u), f32((k >> 1u) & 1u), f32((k >> 2u) & 1u));
        let r = fbmsdf_hash(i + c);
        d = min(d, length(f - c) - r * r * radius);
    }
    return d;
}

fn fbmsdf_simplex(p: vec3f, radius: f32) -> f32 {
    let k1 = FBMSDF_SIMPLEX_SKEW;
    let k2 = FBMSDF_SIMPLEX_UNSKEW;
    let i = floor(p + (p.x + p.y + p.z) * k1);
    let d0 = p - (i - (i.x + i.y + i.z) * k2);
    let e = step(d0.yzx, d0);
    let i1 = e * (1.0 - e.zxy);
    let i2 = 1.0 - e.zxy * (1.0 - e);
    let d1 = d0 - (i1 - k2);
    let d2 = d0 - (i2 - 2.0 * k2);
    let d3 = d0 - (1.0 - 3.0 * k2);
    let r0 = fbmsdf_hash(i);
    let r1 = fbmsdf_hash(i + i1);
    let r2 = fbmsdf_hash(i + i2);
    let r3 = fbmsdf_hash(i + 1.0);
    let rs = radius * (FBMSDF_SIMPLEX_RADIUS / FBMSDF_LATTICE_RADIUS);
    return min(min(length(d0) - r0 * r0 * rs, length(d1) - r1 * r1 * rs),
               min(length(d2) - r2 * r2 * rs, length(d3) - r3 * r3 * rs));
}

fn fbmsdf_pack(m: f32, level: u32) -> f32 {
    let safe = select(m, FBMSDF_MIN_MAGNITUDE, abs(m) < FBMSDF_MIN_MAGNITUDE);
    return bitcast<f32>((bitcast<u32>(safe) & ~FBMSDF_LEVEL_MASK) | level);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let level = bitcast<u32>(carry.dr) & FBMSDF_LEVEL_MASK;
    var z = carry.z;
    var d = carry.dr;
    if (level == 0u) {
        let q = abs(z) - vec3f(p[1]);
        d = min(max(q.x, max(q.y, q.z)), 0.0) + length(max(q, vec3f(0.0)));
        z = z + vec3f(FBMSDF_LATTICE_OFFSET + p[7]);
    }

    let s = pow(p[4], f32(level));
    var base = 0.0;
    if (p[6] > 0.5) {
        base = fbmsdf_simplex(z, p[2]);
    } else {
        base = fbmsdf_lattice(z, p[2]);
    }
    let n = s * base;
    let k = max(p[3] * s, EPSILON_FINE);
    let h = max(k - abs(d + n), 0.0);
    d = max(d, -n) + h * h * 0.25 / k;

    z = p[5] * vec3f(
        -FBMSDF_ROT_COS * z.y - FBMSDF_ROT_SIN * z.z,
        FBMSDF_ROT_COS * z.x + FBMSDF_ROT_SIN_SQ * z.y - FBMSDF_ROT_SIN_COS * z.z,
        FBMSDF_ROT_SIN * z.x - FBMSDF_ROT_SIN_COS * z.y + FBMSDF_ROT_COS_SQ * z.z,
    );
    return IterCarry(z, fbmsdf_pack(d, min(level + 1u, FBMSDF_LEVEL_MASK)));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
