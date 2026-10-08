// After Jos Leys and knighty's escape-time Kleinian DE.

// @param KleinR min=1.8 max=2.1 default=1.958591
// @param KleinI min=-0.15 max=0.15 default=0.011279
// @param BoxX min=0.5 max=2 default=1
// @param BoxZ min=0.5 max=2 default=1
// @param Ceiling min=0.3 max=1 default=0.6
// @param Iterations min=5 max=80 default=30 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[5]);
}

fn klein_pack(v: f32, tag: u32) -> f32 {
    let safe = select(v, 1e-30, abs(v) < 1e-30);
    return bitcast<f32>((bitcast<u32>(safe) & ~127u) | tag);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let step = bitcast<u32>(carry.dr) & 127u;
    if (step == 127u) {
        return carry;
    }
    let a = p[0];
    let b = p[1];
    let bx = p[2];
    let bz = p[3];

    var z = carry.z;
    var df = carry.dr;
    if (step == 0u) {
        z.y = z.y + 1.0;
        df = 1.0;
    }

    z.x = z.x + b / a * z.y;
    z.x = z.x - 2.0 * bx * floor((z.x + bx) / (2.0 * bx));
    z.z = z.z - 2.0 * bz * floor((z.z + bz) / (2.0 * bz));
    z.x = z.x - b / a * z.y;

    let xs = z.x + b * 0.5;
    let sep = a * 0.5 + sign(b) * (2.0 * a - 1.95) / 4.0 * sign(xs)
        * (1.0 - exp(-(7.2 - (1.95 - a) * 15.0) * abs(xs)));
    if (z.y >= sep) {
        z = vec3f(-b, a, 0.0) - z;
    }

    let ir = 1.0 / max(dot(z, z), 1e-20);
    z = z * -ir;
    z.x = -b - z.x;
    z.y = a + z.y;
    df = df * ir;

    if (i32(step) + 1 >= i32(p[5])) {
        let y = min(z.y, a - z.y);
        let de = min(y, 0.3) / max(df, 2.0);
        let cut = pos.y + 1.0 - p[4] * a;
        return IterCarry(z, klein_pack(max(de, cut), 127u));
    }
    return IterCarry(z, klein_pack(df, step + 1u));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
