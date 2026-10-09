// Credits: fractal by macbooktall (Shadertoy), whose defaults these are.

// @param Scale min=1.05 max=2 default=1.25
// @param Iterations min=1 max=40 default=28 int
// @param OffsetX min=-5 max=5 default=-3
// @param OffsetY min=-5 max=5 default=-1.15
// @param OffsetZ min=-5 max=5 default=-0.5
// @param TwistXZ min=0 max=1 default=0.45
// @param TwistYZ min=0 max=1 default=0.15
// @param Time min=0 max=1.570795 default=0
const WOBBLE_TIME_SCALE = 4.0;
const WOBBLE_INITIAL_ANGLE = 0.5;
const WOBBLE_INITIAL_PHASE = 0.25;
const WOBBLE_INITIAL_SWAY = 0.1;
const WOBBLE_X_RIPPLE_FREQ = 0.4;
const WOBBLE_X_RIPPLE_AMOUNT = 0.025;
const WOBBLE_Y_PHASE = 0.2;
const WOBBLE_Y_RIPPLE_FREQ = 0.2;
const WOBBLE_Y_RIPPLE_AMOUNT = 0.05;
const WOBBLE_TWIST_RANGE = 3.14;
const WOBBLE_XZ_JITTER = 0.04;
const WOBBLE_YZ_JITTER = 0.05;
const WOBBLE_MIN_EXTENT = 1e-20;
const WOBBLE_NORM_POWER = 6.0;
const WOBBLE_SHELL_OFFSET = 0.25;

fn de_iterations(p: array<f32, 8>) -> i32 {
    return i32(p[1]);
}

fn wobblekifs_rot(v: vec2f, a: f32) -> vec2f {
    return cos(a) * v + sin(a) * vec2f(v.y, -v.x);
}

fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry {
    let scale = p[0];
    let t = p[7] * WOBBLE_TIME_SCALE;
    let len = length(pos);
    var z = carry.z;

    if (carry.dr == 1.0) {
        z = z.yxz;
        z = vec3f(wobblekifs_rot(z.xy, WOBBLE_INITIAL_ANGLE + sin(t - WOBBLE_INITIAL_PHASE) * WOBBLE_INITIAL_SWAY), z.z);
    }

    let phase_x = p[5] + sin(t + len * WOBBLE_X_RIPPLE_FREQ) * WOBBLE_X_RIPPLE_AMOUNT;
    let phase_y = p[6] + cos(t - WOBBLE_Y_PHASE + len * WOBBLE_Y_RIPPLE_FREQ) * WOBBLE_Y_RIPPLE_AMOUNT;

    z = abs(z) * scale + vec3f(p[2], p[3], p[4]);
    let xz = wobblekifs_rot(z.xz, phase_x * WOBBLE_TWIST_RANGE + cos(t + len) * WOBBLE_XZ_JITTER);
    z = vec3f(xz.x, z.y, xz.y);
    let yz = wobblekifs_rot(z.yz, phase_y * WOBBLE_TWIST_RANGE + sin(t + len) * WOBBLE_YZ_JITTER);
    z = vec3f(z.x, yz.x, yz.y);

    return IterCarry(z, carry.dr * scale);
}

fn de_finalize(carry: IterCarry) -> f32 {
    let a = abs(carry.z);
    let m = max(max(a.x, a.y), max(a.z, WOBBLE_MIN_EXTENT));
    let q = a / m;
    let q3 = q * q * q;
    let q6 = q3 * q3;
    return m * pow(q6.x + q6.y + q6.z, 1.0 / WOBBLE_NORM_POWER) / carry.dr - WOBBLE_SHELL_OFFSET;
}
