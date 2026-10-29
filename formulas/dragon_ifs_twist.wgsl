// @param Iterations min=1 max=20 default=12 int
// @param Fold min=15 max=55 default=45
// @param Twist A min=-180 max=180 default=90
// @param Twist B min=-180 max=180 default=90
// @param Levy min=0 max=1 default=0 int
// @param Thickness min=0.02 max=0.5 default=0.25
const DRAGON_MAX_DEPTH = 20;
const DRAGON_STACK = 21;
const DRAGON_MAX_VISITS = 2048;
const DRAGON_ROOT_SCALE = 2.0;
const DRAGON_IDENTITY = mat3x3f(vec3f(1.0, 0.0, 0.0), vec3f(0.0, 1.0, 0.0), vec3f(0.0, 0.0, 1.0));

fn de_iterations(p: Params) -> i32 {
    return 1;
}

fn dragon_rz(a: f32) -> mat3x3f {
    let c = cos(a);
    let s = sin(a);
    return mat3x3f(vec3f(c, s, 0.0), vec3f(-s, c, 0.0), vec3f(0.0, 0.0, 1.0));
}

fn dragon_rx(a: f32) -> mat3x3f {
    let c = cos(a);
    let s = sin(a);
    return mat3x3f(vec3f(1.0, 0.0, 0.0), vec3f(0.0, c, s), vec3f(0.0, -s, c));
}

fn dragon_inverse(m: mat3x3f) -> mat3x3f {
    let a = cross(m[1], m[2]);
    let b = cross(m[2], m[0]);
    let c = cross(m[0], m[1]);
    return transpose(mat3x3f(a, b, c)) * (1.0 / dot(m[0], a));
}

fn dragon_radius(c: vec3f, ob: vec3f, qa: mat3x3f, qb: mat3x3f, s: f32) -> f32 {
    return max(length(s * (qa * c) - c), length(ob + s * (qb * c) - c)) / (1.0 - s);
}

fn dragon_curve_t(path: u32, n: i32, levy: bool, x: f32) -> f32 {
    var t0 = 0.0;
    var span = 1.0;
    for (var k = 0; k < n; k++) {
        if (((path >> u32(k)) & 1u) == 1u) {
            t0 += select(span, 0.5 * span, levy);
            span *= select(-0.5, 0.5, levy);
        } else {
            span *= 0.5;
        }
    }
    return t0 + span * x;
}

fn de_step(carry: IterCarry, pos: vec3f, p: Params) -> IterCarry {
    let n = clamp(i32(p[0]), 1, DRAGON_MAX_DEPTH);
    let th = radians(p[1]);
    let s = 0.5 / cos(th);
    let levy = p[4] > 0.5;
    let thick = p[5];
    let qa = dragon_rz(th) * dragon_rx(radians(p[2]));
    let qb = dragon_rz(select(PI - th, -th, levy)) * dragon_rx(radians(p[3]));
    let ob = select(vec3f(1.0, 0.0, 0.0), vec3f(0.5, 0.5 * tan(th), 0.0), levy);

    let centroid = dragon_inverse(DRAGON_IDENTITY - (qa + qb) * (0.5 * s)) * (0.5 * ob);
    let mid = 0.5 * (dragon_inverse(DRAGON_IDENTITY - qb * s) * ob);
    let r_centroid = dragon_radius(centroid, ob, qa, qb, s);
    let r_mid = dragon_radius(mid, ob, qa, qb, s);
    let c = select(centroid, mid, r_mid < r_centroid);
    let radius = min(r_centroid, r_mid);

    var zs: array<vec3f, DRAGON_STACK>;
    zs[0] = carry.z / DRAGON_ROOT_SCALE + c;
    var depth = 0;
    var fresh = true;
    var path = 0u;
    var second = 0u;
    var best = INFINITE_DISTANCE;
    var best_t = 0.0;
    for (var visit = 0; visit < DRAGON_MAX_VISITS && depth >= 0; visit++) {
        let z = zs[depth];
        let bit = 1u << u32(depth);
        if (fresh) {
            let scale_here = pow(s, f32(depth));
            let bound = (length(z - c) - radius - thick * pow(s, f32(n - depth))) * scale_here;
            if (bound >= best) {
                depth--;
                fresh = false;
                continue;
            }
            if (depth == n) {
                let x = clamp(z.x, 0.0, 1.0);
                let d = (length(z - vec3f(x, 0.0, 0.0)) - thick) * scale_here;
                if (d < best) {
                    best = d;
                    best_t = dragon_curve_t(path, n, levy, x);
                }
                depth--;
                fresh = false;
                continue;
            }
        } else if ((second & bit) != 0u) {
            depth--;
            continue;
        }
        let za = (z * qa) / s;
        let zb = ((z - ob) * qb) / s;
        let a_first = dot(za - c, za - c) <= dot(zb - c, zb - c);
        let pick_b = a_first != fresh;
        second = select(second & ~bit, second | bit, !fresh);
        path = select(path & ~bit, path | bit, pick_b);
        zs[depth + 1] = select(za, zb, pick_b);
        depth++;
        fresh = true;
    }
    for (var k = 0; k <= depth; k++) {
        best = min(best, (length(zs[k] - c) - radius - thick * pow(s, f32(n - k))) * pow(s, f32(k)));
    }
    return IterCarry(vec3f(best_t, 0.0, 0.0), best * DRAGON_ROOT_SCALE / max(abs(carry.dr), EPSILON_FINE));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
