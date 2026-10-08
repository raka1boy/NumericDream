// Credits: Mandalay fold by DarkBeam (fractalforums.com); Aurullia by Tom Beddard (subblue.com);
// ported from the Shadertoy shader at https://www.shadertoy.com/view/MsK3DR, whose defaults these are.

// @param Scale min=1.5 max=4.5 default=3.22996
// @param MinRadius min=0.05 max=1 default=0.335537
// @param FoldX min=0 max=2 default=0.0961
// @param FoldY min=0 max=2 default=1.28528
// @param FoldZ min=0 max=2 default=0.74286
// @param Gap min=0 max=2 default=1
// @param SquashZ min=0.5 max=1.2 default=0.92
// @param Iterations min=1 max=30 default=12 int
fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[7]);
}

fn mandalay_fold(p: vec3f, fo: f32, g: f32) -> f32 {
    var q = p;
    if (q.z > q.y) {
        q = vec3f(q.x, q.z, q.y);
    }
    let vx = q.x - 2.0 * fo;
    let vy = q.y - 4.0 * fo;
    let v = max(abs(vx + fo) - fo, vy);
    let v1 = max(vx - g, q.y);
    return min(min(v, v1), q.x);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let c = pos * 4.0;
    var z = carry.z;
    var dr = carry.dr;
    if (dr == 1.0) {
        z = c;
        dr = 4.0;
    }
    if (dot(z, z) > 1e20) {
        return IterCarry(z, dr);
    }

    z = z - clamp(z, vec3f(-1.0), vec3f(1.0)) * 2.0;

    let signs = sign(z);
    let a = abs(z);
    let gap = vec3f(0.4273, 0.62314, 0.5638) * p[5];
    z = vec3f(
        mandalay_fold(a, p[2], gap.x),
        mandalay_fold(a.yzx, p[3], gap.y),
        mandalay_fold(a.zxy, p[4], gap.z),
    ) * signs;

    let t = clamp(1.0 / max(dot(z, z), 1e-12), 1.0, 1.0 / (p[1] * p[1]));
    z = z * t;
    dr = dr * t;

    z = z * p[0] + c;
    dr = dr * abs(p[0]) + 4.0;
    z.z = z.z * p[6];
    return IterCarry(z, dr);
}

fn de_finalize(carry: IterCarry) -> f32 {
    return (length(carry.z) - 30.0) / abs(carry.dr);
}
