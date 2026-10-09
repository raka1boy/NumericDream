// @param Iterations min=1 max=8 default=3 int
// @param Angle min=15 max=60 default=36
// @param Spirals min=1 max=5 default=3 int
// @param BudSize min=0.5 max=2.5 default=1.3
// @param Lean min=-30 max=60 default=15
// @param Sink min=0 max=0.8 default=0.2
// @param Tip min=0 max=0.2 default=0.02
const ROMANESCO_MAX_TIP_RATIO = 0.9;
const ROMANESCO_MIN_MAGNITUDE = 1e-30;
const ROMANESCO_SCALE_BIAS = 2.0;
const ROMANESCO_SCALE_STEPS = 32.0;
const ROMANESCO_SCALE_MAX_CODE = 1023.0;
const ROMANESCO_PACK_MASK = 16383u;
const ROMANESCO_LEVEL_BITS = 4u;
const ROMANESCO_LEVEL_MASK = 15u;
const ROMANESCO_BAILOUT_SQ = 100.0;
const ROMANESCO_FIB_START_I = 3.0;
const ROMANESCO_FIB_START_J = 5.0;
const ROMANESCO_GOLDEN_ANGLE_TURNS = 0.381966;
const ROMANESCO_ROOT_SCALE = 1.5;
const ROMANESCO_ROOT_OFFSET = vec3f(0.0, 0.5, 0.0);
const ROMANESCO_MIN_SLANT = 1e-5;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn romanesco_round_cone(p: vec3f, r1: f32, r2: f32, h: f32) -> f32 {
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

fn romanesco_cone(z: vec3f, s: f32, tip: f32) -> f32 {
    let r2 = min(tip, ROMANESCO_MAX_TIP_RATIO * s);
    return romanesco_round_cone(z, s, r2, 1.0 - r2 / s);
}

fn romanesco_pack(m: f32, world_per_local: f32, level: u32) -> f32 {
    let safe = select(m, ROMANESCO_MIN_MAGNITUDE, abs(m) < ROMANESCO_MIN_MAGNITUDE);
    let q = u32(clamp(round((ROMANESCO_SCALE_BIAS - log2(world_per_local)) * ROMANESCO_SCALE_STEPS), 1.0, ROMANESCO_SCALE_MAX_CODE));
    return bitcast<f32>((bitcast<u32>(safe) & ~ROMANESCO_PACK_MASK) | (q << ROMANESCO_LEVEL_BITS) | level);
}

fn romanesco_bud_frame(z: vec3f, c: vec2f, u0: f32, sc: f32, cc: f32, lean: f32, gap: f32, sink: f32) -> vec4f {
    let s_n = exp(u0 + c.x);
    let th = c.y / sc;
    let er = vec3f(cos(th), 0.0, sin(th));
    let et = vec3f(-er.z, 0.0, er.x);
    let normal = er * cc + vec3f(0.0, sc, 0.0);
    let up_slope = vec3f(0.0, cc, 0.0) - er * sc;
    let axis = normal * cos(lean) + up_slope * sin(lean);
    let scale = s_n * gap;
    let base = vec3f(0.0, 1.0, 0.0) + (er * sc - vec3f(0.0, cc, 0.0)) * s_n - axis * (sink * scale);
    let v = z - base;
    return vec4f(vec3f(dot(v, et), dot(v, axis), dot(v, cross(et, axis))) / scale, scale);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let bits = bitcast<u32>(carry.dr) & ROMANESCO_PACK_MASK;
    if (bits != 0u && dot(carry.z, carry.z) > ROMANESCO_BAILOUT_SQ) {
        return carry;
    }
    let level = bits & ROMANESCO_LEVEL_MASK;
    var wpl = exp2(ROMANESCO_SCALE_BIAS - f32(bits >> ROMANESCO_LEVEL_BITS) / ROMANESCO_SCALE_STEPS);
    var z = carry.z;
    var m = carry.dr;

    let alpha = radians(p[1]);
    let sa = sin(alpha);
    let lean = radians(p[4]);
    let sink = p[5];
    let tip = p[6];
    var fi = ROMANESCO_FIB_START_I;
    var fj = ROMANESCO_FIB_START_J;
    for (var k = 1; k < i32(p[2]); k++) {
        let next = fi + fj;
        fi = fj;
        fj = next;
    }
    let g = ROMANESCO_GOLDEN_ANGLE_TURNS;
    let ei = fi * g - round(fi * g);
    let ej = fj * g - round(fj * g);
    let lam = sqrt((ei * ei - ej * ej) / (fj * fj - fi * fi));
    let kappa = sqrt(fi * fi * lam * lam + ei * ei);
    let t = tan(alpha) / cos(lean);
    let ac = atan(t * sa / (PI * kappa * p[3] + t * cos(alpha)));
    let sc = sin(ac);
    let cc = cos(ac);

    if (bits == 0u) {
        wpl = ROMANESCO_ROOT_SCALE;
        z = (z + ROMANESCO_ROOT_OFFSET) / wpl;
        let head = max(romanesco_cone(z, sc, tip), -z.y);
        m = head * wpl;
    }
    let last = i32(level) + 1 >= i32(p[0]);

    let per = TAU * sc;
    let va = vec2f(-fi * lam, ei) * per;
    let vb = vec2f(-fj * lam, ej) * per;
    let spacing = per * kappa;
    let slant = max(length(z.xz) * sc - (z.y - 1.0) * cc, ROMANESCO_MIN_SLANT);
    let u0 = log(1.0 / cc) - 0.5 * spacing;
    let d = vec2f(min(log(slant), u0 + spacing) - u0, atan2(z.z, z.x) * sc);
    let det = va.x * vb.y - va.y * vb.x;
    let x0 = round((d.x * vb.y - d.y * vb.x) / det);
    let y0 = round((va.x * d.y - va.y * d.x) / det);
    let gap = sin(alpha - ac) / ((1.0 - sink) * cos(lean));

    var best = romanesco_bud_frame(z, vec2f(0.0), u0, sc, cc, lean, gap, sink);
    var best_outer = romanesco_cone(best.xyz, sa, tip) * best.w;
    var near = select(romanesco_cone(best.xyz, sc, tip) * best.w, best_outer, last);
    for (var i = -1; i <= 1; i++) {
        for (var j = -1; j <= 1; j++) {
            let cx = x0 + f32(i);
            let cy = y0 + f32(j);
            if (cx * fi + cy * fj < -0.5) {
                continue;
            }
            let f = romanesco_bud_frame(z, cx * va + cy * vb, u0, sc, cc, lean, gap, sink);
            let outer = romanesco_cone(f.xyz, sa, tip) * f.w;
            near = min(near, select(romanesco_cone(f.xyz, sc, tip) * f.w, outer, last));
            if (outer < best_outer) {
                best = f;
                best_outer = outer;
            }
        }
    }

    m = min(m, near * wpl);
    wpl = wpl * best.w;
    return IterCarry(best.xyz, romanesco_pack(m, wpl, min(level + 1u, ROMANESCO_LEVEL_MASK)));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return bitcast<f32>(bitcast<u32>(carry.dr) & ~ROMANESCO_PACK_MASK);
}
