// Credits: "Fractal SDF fBM" by Inigo Quilez (Shadertoy, MIT License, 2019), iquilezles.org/articles/fbmsdf

// @param Iterations min=1 max=10 default=7 int
// @param Size min=0.1 max=4 default=1
// @param Radius min=0.1 max=1.5 default=0.7
// @param Blend min=0.01 max=0.5 default=0.15
// @param Gain min=0.3 max=0.7 default=0.55
// @param Lacunarity min=1.5 max=3 default=2
// @param Simplex min=0 max=1 default=0 int
// @param Seed min=0 max=20 default=0
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn fbmsdf_hash(c: vec3f) -> f32 {
    let q = 17.0 * fract(c * 0.3183099 + vec3f(0.11, 0.17, 0.13));
    return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

fn fbmsdf_lattice(p: vec3f, radius: f32) -> f32 {
    let i = floor(p);
    let f = p - i;
    var d = 1e10;
    for (var k = 0u; k < 8u; k++) {
        let c = vec3f(f32(k & 1u), f32((k >> 1u) & 1u), f32((k >> 2u) & 1u));
        let r = fbmsdf_hash(i + c);
        d = min(d, length(f - c) - r * r * radius);
    }
    return d;
}

fn fbmsdf_simplex(p: vec3f, radius: f32) -> f32 {
    let k1 = 0.333333333;
    let k2 = 0.166666667;
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
    let rs = radius * (0.55 / 0.7);
    return min(min(length(d0) - r0 * r0 * rs, length(d1) - r1 * r1 * rs),
               min(length(d2) - r2 * r2 * rs, length(d3) - r3 * r3 * rs));
}

fn fbmsdf_pack(m: f32, level: u32) -> f32 {
    let safe = select(m, 1e-30, abs(m) < 1e-30);
    return bitcast<f32>((bitcast<u32>(safe) & ~31u) | level);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let level = bitcast<u32>(carry.dr) & 31u;
    var z = carry.z;
    var d = carry.dr;
    if (level == 0u) {
        let q = abs(z) - vec3f(p[1]);
        d = min(max(q.x, max(q.y, q.z)), 0.0) + length(max(q, vec3f(0.0)));
        z = z + vec3f(0.5 + p[7]);
    }

    let s = pow(p[4], f32(level));
    var base = 0.0;
    if (p[6] > 0.5) {
        base = fbmsdf_simplex(z, p[2]);
    } else {
        base = fbmsdf_lattice(z, p[2]);
    }
    let n = s * base;
    let k = max(p[3] * s, 1e-6);
    let h = max(k - abs(d + n), 0.0);
    d = max(d, -n) + h * h * 0.25 / k;

    z = p[5] * vec3f(
        -0.80 * z.y - 0.60 * z.z,
        0.80 * z.x + 0.36 * z.y - 0.48 * z.z,
        0.60 * z.x - 0.48 * z.y + 0.64 * z.z,
    );
    return IterCarry(z, fbmsdf_pack(d, min(level + 1u, 31u)));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
