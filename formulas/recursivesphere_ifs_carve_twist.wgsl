// Credits: recursive carved-sphere fractal by Otavio Good (Shadertoy, CC0), shadertoy.com/user/otaviogood

// @param Iterations min=1 max=8 default=4 int
// @param Size min=0.1 max=10 default=1.5
// @param Cut min=0.3 max=1.2 default=0.77
// @param Teeth min=0 max=2 default=0
// @param Spin min=-3.1416 max=3.1416 default=0
// @param Inner min=0.2 max=0.5 default=0.333
// @param Fin Width min=0 max=0.3 default=0.1
// @param Blend min=0.01 max=0.5 default=0.25
const RECURSIVESPHERE_REFERENCE_SIZE = 5.2;
const RECURSIVESPHERE_OUTNESS = 1.414;
const RECURSIVESPHERE_FIN_SCALE = 0.7071;
const RECURSIVESPHERE_DIAGONAL = -0.57735027;
const RECURSIVESPHERE_MIN_MAGNITUDE = 1e-30;
const RECURSIVESPHERE_LEVEL_MASK = 31u;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[0]);
}

fn recursivesphere_pack(m: f32, level: u32) -> f32 {
    let safe = select(m, RECURSIVESPHERE_MIN_MAGNITUDE, abs(m) < RECURSIVESPHERE_MIN_MAGNITUDE);
    return bitcast<f32>((bitcast<u32>(safe) & ~RECURSIVESPHERE_LEVEL_MASK) | level);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let level = bitcast<u32>(carry.dr) & RECURSIVESPHERE_LEVEL_MASK;
    let world = p[1] / RECURSIVESPHERE_REFERENCE_SIZE;
    var z = carry.z;
    var best = carry.dr;
    if (level == 0u) {
        z = z / world;
        best = INFINITE_DISTANCE;
    }

    let shrink = pow(p[5], f32(level));
    let radius = RECURSIVESPHERE_REFERENCE_SIZE / RECURSIVESPHERE_OUTNESS * shrink;
    let fin = p[6] * shrink;

    var d = length(z) - radius * RECURSIVESPHERE_OUTNESS;
    var corners = abs(z) + vec3f(RECURSIVESPHERE_DIAGONAL * radius);
    let hole = length(corners) - radius * p[2];
    let ap = abs(z) * RECURSIVESPHERE_FIN_SCALE;
    var cut = max(hole, fin - abs(ap.x - ap.y));
    cut = max(cut, fin - abs(ap.y - ap.z));
    cut = max(cut, fin - abs(ap.z - ap.x));
    cut = min(cut, hole + p[3] * shrink);
    d = -smin(-d, cut, p[7] * shrink);
    best = min(best, d * world);

    let a = p[4] / shrink;
    let c = cos(a);
    let s = sin(a);
    corners = vec3f(c * corners.x - s * corners.z, corners.y, s * corners.x + c * corners.z);
    z = vec3f(corners.x, corners.z, -corners.y);
    if (level + 1u >= u32(max(p[0], 1.0))) {
        best = min(best, (length(z) - radius * p[5] * RECURSIVESPHERE_OUTNESS) * world);
    }
    return IterCarry(z, recursivesphere_pack(best, min(level + 1u, RECURSIVESPHERE_LEVEL_MASK)));
}

fn de_finalize(carry: IterCarry) -> f32 {
    return carry.dr;
}
