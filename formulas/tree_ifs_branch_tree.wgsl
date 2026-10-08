// @param Iterations min=1 max=20 default=12 int
// @param Branches min=2 max=6 default=2 int
// @param Spread min=0 max=90 default=30
// @param Ratio min=0.4 max=0.9 default=0.75
// @param Twist min=0 max=180 default=90
// @param Thickness min=0.01 max=0.3 default=0.07
// @param Trunk min=0.2 max=3 default=1.2
// @param Leaves min=0 max=1 default=0
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn tree_limb(p: vec3f, r1: f32, r2: f32, h: f32) -> f32 {
    let q = vec2f(length(p.xz), p.y);
    let b = (r1 - r2) / h;
    let a = sqrt(1.0 - b * b);
    let k = dot(q, vec2f(-b, a));
    if (k < 0.0) {
        return length(q) - r1;
    }
    if (k > a * h) {
        return length(q - vec2f(0.0, h)) - r2;
    }
    return dot(q, vec2f(a, b)) - r1;
}

fn tree_pack(m: f32, level: u32) -> f32 {
    let safe = select(m, 1e-30, abs(m) < 1e-30);
    return bitcast<f32>((bitcast<u32>(safe) & ~31u) | level);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let level = bitcast<u32>(carry.dr) & 31u;
    let ratio = p[3];
    let thick = p[5];

    var z = carry.z;
    var m = carry.dr;
    var length_here = 1.0;
    if (level == 0u) {
        z = (z + vec3f(0.0, 1.0, 0.0)) / 0.6;
        length_here = p[6];
        m = tree_limb(z, thick, thick * ratio, length_here) * 0.6;
    }

    z.y = z.y - length_here;
    let tw = radians(p[4]);
    z = vec3f(z.x * cos(tw) - z.z * sin(tw), z.y, z.x * sin(tw) + z.z * cos(tw));
    let sector = 6.2831853 / max(round(p[1]), 1.0);
    var ang = atan2(z.z, z.x);
    ang = abs(ang - sector * round(ang / sector));
    let rxz = length(z.xz);
    z = vec3f(rxz * cos(ang), z.y, rxz * sin(ang));

    let th = radians(p[2]);
    z = vec3f(z.x * cos(th) - z.y * sin(th), z.x * sin(th) + z.y * cos(th), z.z) / ratio;

    let next = min(level + 1u, 31u);
    let world_per_local = 0.6 * pow(ratio, f32(next));
    m = min(m, tree_limb(z, thick, thick * ratio, 1.0) * world_per_local);
    if (i32(next) >= i32(p[0]) && p[7] > 0.0) {
        m = min(m, (length(z - vec3f(0.0, 1.0, 0.0)) - p[7]) * world_per_local);
    }
    return IterCarry(z, tree_pack(m, next));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
