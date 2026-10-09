struct ParticleSim {
    center: vec3f,
    count: f32,
    axis_u: vec3f,
    spawn_radius: f32,
    axis_v: vec3f,
    spawn_shape: f32,
    direction: vec3f,
    velocity_mode: f32,
    extent: vec2f,
    speed_min: f32,
    speed_max: f32,
    spread: f32,
    size: f32,
    size_var: f32,
    seed: f32,
    emit_duration: f32,
    lifetime: f32,
    dt: f32,
    t: f32,
    kill_radius: f32,
    stop_scene: f32,
    stick: f32,
    strip_mode: f32,
    strip_span: f32,
    strip_offset: f32,
    system: f32,
    sim_cell: f32,
    steps_done: f32,
    r_insert: f32,
    insert_mult: f32,
    insert_add: f32,
}

struct ParticleState {
    pos: vec3f,
    status: u32,
    vel: vec3f,
    support: i32,
}

const PS_UNBORN: u32 = 0u;
const PS_MOVING: u32 = 1u;
const PS_STOPPED: u32 = 2u;
const PS_DEAD: u32 = 3u;

const PH_BUCKETS: u32 = 16384u;
const PH_WORDS: u32 = 16u;
const PH_SLOTS: u32 = 15u;

const PC_WORDS: u32 = 16u;
const PC_MIN: u32 = 1u;
const PC_MAX: u32 = 4u;
const PC_ALIVE: u32 = 7u;
const PC_ALLOC: u32 = 8u;
const PH_FIRST_SLOT: u32 = 1u;

const SPAWN_SPHERE = 0u;
const SPAWN_DISC = 1u;
const VELOCITY_DIRECTION = 0u;
const VELOCITY_RADIAL = 1u;
const STRIP_DISTANCE = 1u;

const PRAND_SPAWN_A = 0u;
const PRAND_SPAWN_B = 1u;
const PRAND_SPAWN_RADIUS = 2u;
const PRAND_DIR_A = 3u;
const PRAND_DIR_B = 4u;
const PRAND_SPEED = 5u;
const PRAND_SIZE = 6u;
const PRAND_BIRTH = 7u;
const PRAND_STRIP = 8u;
const PRAND_BITS_SHIFT = 8u;
const U24_RANGE = 16777216.0;
const MURMUR3_FMIX_1 = 0x85EBCA6Bu;
const U32_ABS_MASK = 0x7fffffffu;

const SUPPORT_NO_PARTICLE = -1;
const SUPPORT_NOT_STOPPED = -2;
const PARTICLE_MIN_RADIUS = 1e-5;
const PARTICLE_BASIS_POLE = 0.9;
const PHASH_MAX_SPAN = 3;
const PARTICLE_SCENE_EPS_RATIO = 0.02;
const PARTICLE_MIN_SCENE_EPS = 1e-5;
const PARTICLE_SCENE_MARCH_STEPS = 32;
const GRID_PAD_SCALE = 1.001;
const GRID_FIT_ATTEMPTS = 128;
const GRID_GROWTH = 1.05;

@group(1) @binding(30) var<uniform> psim: ParticleSim;
@group(1) @binding(31) var<storage, read> pstate_in: array<ParticleState>;
@group(1) @binding(32) var<storage, read_write> pstate_out: array<ParticleState>;
@group(1) @binding(33) var<storage, read_write> phash: array<atomic<u32>>;
@group(1) @binding(34) var<storage, read_write> particle_rw: array<atomic<u32>>;
@group(1) @binding(35) var<storage, read_write> pcounters: array<atomic<u32>>;

fn psys() -> u32 {
    return u32(psim.system + 0.5);
}

fn phash_u32(x: u32) -> u32 {
    let state = x * PCG_MULTIPLIER + PCG_INCREMENT;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * PCG_OUTPUT_MULTIPLIER;
    return (word >> 22u) ^ word;
}

fn particle_rand(i: u32, k: u32) -> f32 {
    let h = phash_u32(phash_u32(i * GOLDEN_RATIO_U32 + bitcast<u32>(psim.seed)) + k * MURMUR3_FMIX_1);
    return f32(h >> PRAND_BITS_SHIFT) * (1.0 / U24_RANGE);
}

fn particle_sphere_dir(a: f32, b: f32) -> vec3f {
    let z = 2.0 * a - 1.0;
    let r = sqrt(max(1.0 - z * z, 0.0));
    let phi = TAU * b;
    return vec3f(r * cos(phi), z, r * sin(phi));
}

struct ParticleStatic {
    spawn: vec3f,
    radius: f32,
    vel: vec3f,
    birth: f32,
    strip_rand: f32,
}

fn particle_radius(i: u32) -> f32 {
    return max(psim.size * (1.0 + psim.size_var * (2.0 * particle_rand(i, PRAND_SIZE) - 1.0)), PARTICLE_MIN_RADIUS);
}

fn particle_static(i: u32) -> ParticleStatic {
    var ps: ParticleStatic;
    let shape = u32(psim.spawn_shape + 0.5);
    if (shape == SPAWN_SPHERE) {
        let dir = particle_sphere_dir(particle_rand(i, PRAND_SPAWN_A), particle_rand(i, PRAND_SPAWN_B));
        ps.spawn = psim.center + dir * (psim.spawn_radius * pow(particle_rand(i, PRAND_SPAWN_RADIUS), 1.0 / 3.0));
    } else if (shape == SPAWN_DISC) {
        let r = psim.spawn_radius * sqrt(particle_rand(i, PRAND_SPAWN_A));
        let a = TAU * particle_rand(i, PRAND_SPAWN_B);
        ps.spawn = psim.center + psim.axis_u * (r * cos(a)) + psim.axis_v * (r * sin(a));
    } else {
        ps.spawn = psim.center + psim.axis_u * ((2.0 * particle_rand(i, PRAND_SPAWN_A) - 1.0) * psim.extent.x) +
            psim.axis_v * ((2.0 * particle_rand(i, PRAND_SPAWN_B) - 1.0) * psim.extent.y);
    }

    let mode = u32(psim.velocity_mode + 0.5);
    var dir = particle_sphere_dir(particle_rand(i, PRAND_DIR_A), particle_rand(i, PRAND_DIR_B));
    if (mode == VELOCITY_DIRECTION) {
        let n = psim.direction;
        let cz = 1.0 - particle_rand(i, PRAND_DIR_A) * (1.0 - cos(psim.spread));
        let sz = sqrt(max(1.0 - cz * cz, 0.0));
        let phi = TAU * particle_rand(i, PRAND_DIR_B);
        let t = normalize(cross(n, select(vec3f(1.0, 0.0, 0.0), vec3f(0.0, 1.0, 0.0), abs(n.x) > PARTICLE_BASIS_POLE)));
        let b = cross(n, t);
        dir = n * cz + (t * cos(phi) + b * sin(phi)) * sz;
    } else if (mode == VELOCITY_RADIAL) {
        let off = ps.spawn - psim.center;
        let len = length(off);
        if (len > EPSILON_FINE) {
            dir = off / len;
        }
    }
    ps.vel = dir * mix(psim.speed_min, psim.speed_max, particle_rand(i, PRAND_SPEED));
    ps.radius = particle_radius(i);
    ps.birth = select(0.0, (f32(i) + particle_rand(i, PRAND_BIRTH)) / max(psim.count, 1.0) * psim.emit_duration, psim.emit_duration > 0.0);
    ps.strip_rand = particle_rand(i, PRAND_STRIP);
    return ps;
}

fn particle_expired(ps: ParticleStatic, t: f32) -> bool {
    return psim.lifetime > 0.0 && t >= ps.birth + psim.lifetime;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_reset(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    if (gid.x == 0u) {
        atomicStore(&pcounters[s * PC_WORDS], 0u);
    }
    let i = gid.x;
    if (i >= PD_MAX_PARTICLES) {
        return;
    }
    let ps = particle_static(i);
    let status = select(PS_UNBORN, PS_DEAD, i >= u32(psim.count));
    pstate_out[s * PD_MAX_PARTICLES + i] = ParticleState(ps.spawn, status, ps.vel, SUPPORT_NO_PARTICLE);
}

fn phash_cell(p: vec3f) -> vec3i {
    return vec3i(floor(p / psim.sim_cell));
}

fn phash_bucket(c: vec3i) -> u32 {
    let h = (u32(c.x) * SPATIAL_PRIME_X) ^ (u32(c.y) * SPATIAL_PRIME_Y) ^ (u32(c.z) * SPATIAL_PRIME_Z);
    return (h & (PH_BUCKETS - 1u)) * PH_WORDS;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_hash_clear(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x < PH_BUCKETS) {
        atomicStore(&phash[gid.x * PH_WORDS], 0u);
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_hash_insert(@builtin(global_invocation_id) gid: vec3u) {
    let i = gid.x;
    if (i >= u32(psim.count)) {
        return;
    }
    let st = pstate_in[psys() * PD_MAX_PARTICLES + i];
    if (st.status != PS_STOPPED) {
        return;
    }
    let b = phash_bucket(phash_cell(st.pos));
    let slot = atomicAdd(&phash[b], 1u);
    if (slot < PH_SLOTS) {
        atomicStore(&phash[b + PH_FIRST_SLOT + slot], i);
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_step(@builtin(global_invocation_id) gid: vec3u) {
    particles_off = true;
    let i = gid.x;
    if (i >= u32(psim.count)) {
        return;
    }
    let s = psys();
    let base = s * PD_MAX_PARTICLES;
    var st = pstate_in[base + i];
    let step_i = atomicLoad(&pcounters[s * PC_WORDS]);
    let t0 = f32(step_i) * psim.dt;
    let t1 = t0 + psim.dt;
    let ps = particle_static(i);

    if (st.status != PS_DEAD && particle_expired(ps, t1)) {
        st.status = PS_DEAD;
    }

    var travel = 0.0;
    if (st.status == PS_UNBORN) {
        if (ps.birth < t1) {
            st.status = PS_MOVING;
            st.pos = ps.spawn;
            travel = t1 - max(ps.birth, t0);
        }
    } else if (st.status == PS_STOPPED) {
        if (st.support >= 0 && pstate_in[base + u32(st.support)].status != PS_STOPPED) {
            st.status = PS_MOVING;
            st.support = SUPPORT_NO_PARTICLE;
            travel = psim.dt;
        }
    } else if (st.status == PS_MOVING) {
        travel = psim.dt;
    }

    if (st.status == PS_MOVING) {
        let speed = length(st.vel);
        let seg = speed * travel;
        let dir = select(vec3f(0.0, 1.0, 0.0), st.vel / max(speed, EPSILON_TINY), speed > EPSILON_TINY);
        var stop_s = seg;
        var support = SUPPORT_NOT_STOPPED;

        if (psim.stick > 0.5) {
            let reach = ps.radius + psim.sim_cell * 0.5;
            let a = st.pos;
            let b = st.pos + dir * seg;
            let lo = phash_cell(min(a, b) - vec3f(reach));
            let hi = min(phash_cell(max(a, b) + vec3f(reach)), lo + vec3i(PHASH_MAX_SPAN));
            for (var z = lo.z; z <= hi.z; z++) {
                for (var y = lo.y; y <= hi.y; y++) {
                    for (var x = lo.x; x <= hi.x; x++) {
                        let bk = phash_bucket(vec3i(x, y, z));
                        let n = min(atomicLoad(&phash[bk]), PH_SLOTS);
                        for (var e = 0u; e < n; e++) {
                            let j = atomicLoad(&phash[bk + PH_FIRST_SLOT + e]);
                            if (j == i) {
                                continue;
                            }
                            let other = pstate_in[base + j];
                            let rr = ps.radius + particle_radius(j);
                            let oc = st.pos - other.pos;
                            let bq = dot(oc, dir);
                            let cq = dot(oc, oc) - rr * rr;
                            var hit_s = 0.0;
                            if (cq > 0.0) {
                                let disc = bq * bq - cq;
                                if (disc < 0.0 || bq > 0.0) {
                                    continue;
                                }
                                hit_s = -bq - sqrt(disc);
                            }
                            if (hit_s < stop_s || (hit_s == stop_s && support >= 0 && i32(j) < support)) {
                                stop_s = hit_s;
                                support = i32(j);
                            }
                        }
                    }
                }
            }
        }

        if (psim.stop_scene > 0.5) {
            let eps = max(ps.radius * PARTICLE_SCENE_EPS_RATIO, PARTICLE_MIN_SCENE_EPS);
            var s_t = 0.0;
            for (var k = 0; k < PARTICLE_SCENE_MARCH_STEPS; k++) {
                if (s_t > stop_s) {
                    break;
                }
                let dd = scene_de(st.pos + dir * s_t) - ps.radius;
                if (dd < eps) {
                    stop_s = s_t;
                    support = SUPPORT_NO_PARTICLE;
                    break;
                }
                s_t += dd;
            }
        }

        st.pos = st.pos + dir * stop_s;
        if (support >= SUPPORT_NO_PARTICLE) {
            st.status = PS_STOPPED;
            st.support = support;
        }
        if (length(st.pos - psim.center) > psim.kill_radius) {
            st.status = PS_DEAD;
        }
    }
    pstate_out[base + i] = st;
}

@compute @workgroup_size(1)
fn cs_particle_step_end() {
    atomicAdd(&pcounters[psys() * PC_WORDS], 1u);
}

fn pf_ord(f: f32) -> u32 {
    let b = bitcast<u32>(f);
    return select(b | U32_SIGN_BIT, ~b, (b & U32_SIGN_BIT) != 0u);
}

fn pf_unord(v: u32) -> f32 {
    return bitcast<f32>(select(~v, v & U32_ABS_MASK, (v & U32_SIGN_BIT) != 0u));
}

fn prw_f32(a: u32) -> f32 {
    return bitcast<f32>(atomicLoad(&particle_rw[a]));
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_emit(@builtin(global_invocation_id) gid: vec3u) {
    let i = gid.x;
    if (i >= PD_MAX_PARTICLES) {
        return;
    }
    let s = psys();
    var alive = false;
    var pos = vec3f(0.0);
    var radius = 0.0;
    var strip = 0.0;
    if (i < u32(psim.count)) {
        let st = pstate_in[s * PD_MAX_PARTICLES + i];
        let ps = particle_static(i);
        let t = psim.t;
        let frac = max(t - psim.steps_done * psim.dt, 0.0);
        if (!particle_expired(ps, t)) {
            if (st.status == PS_UNBORN && ps.birth <= t) {
                alive = true;
                pos = ps.spawn + ps.vel * (t - ps.birth);
            } else if (st.status == PS_MOVING) {
                alive = true;
                pos = st.pos + st.vel * frac;
            } else if (st.status == PS_STOPPED) {
                alive = true;
                pos = st.pos;
            }
        }
        alive = alive && length(pos - psim.center) <= psim.kill_radius;
        radius = ps.radius;
        strip = ps.strip_rand;
        if (u32(psim.strip_mode + 0.5) == STRIP_DISTANCE) {
            strip = length(pos - psim.center) / max(psim.strip_span, EPSILON);
        }
        strip = clamp(strip + psim.strip_offset, 0.0, 1.0);
    }

    let a = PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS;
    atomicStore(&particle_rw[a], bitcast<u32>(pos.x));
    atomicStore(&particle_rw[a + 1u], bitcast<u32>(pos.y));
    atomicStore(&particle_rw[a + 2u], bitcast<u32>(pos.z));
    atomicStore(&particle_rw[a + PD_RECORD_RADIUS], bitcast<u32>(select(0.0, radius, alive)));
    atomicStore(&particle_rw[a + PD_RECORD_STRIP], bitcast<u32>(strip));
    atomicStore(&particle_rw[a + PD_RECORD_ALIVE], select(0u, 1u, alive));
    if (!alive) {
        return;
    }
    let c = s * PC_WORDS;
    atomicMin(&pcounters[c + PC_MIN], pf_ord(pos.x));
    atomicMin(&pcounters[c + PC_MIN + 1u], pf_ord(pos.y));
    atomicMin(&pcounters[c + PC_MIN + 2u], pf_ord(pos.z));
    atomicMax(&pcounters[c + PC_MAX], pf_ord(pos.x));
    atomicMax(&pcounters[c + PC_MAX + 1u], pf_ord(pos.y));
    atomicMax(&pcounters[c + PC_MAX + 2u], pf_ord(pos.z));
    atomicAdd(&pcounters[c + PC_ALIVE], 1u);
}

@compute @workgroup_size(1)
fn cs_particle_grid_setup() {
    let s = psys();
    let c = s * PC_WORDS;
    let h = s * PD_HEADER_WORDS;
    if (atomicLoad(&pcounters[c + PC_ALIVE]) == 0u) {
        atomicStore(&particle_rw[h + PD_HEADER_DIMS], 0u);
        atomicStore(&particle_rw[h + PD_HEADER_DIMS + 1u], 0u);
        atomicStore(&particle_rw[h + PD_HEADER_DIMS + 2u], 0u);
        atomicStore(&particle_rw[h + PD_HEADER_VALID], 0u);
        return;
    }
    let pad = vec3f(psim.r_insert * GRID_PAD_SCALE + EPSILON_FINE);
    let mn = vec3f(pf_unord(atomicLoad(&pcounters[c + PC_MIN])), pf_unord(atomicLoad(&pcounters[c + PC_MIN + 1u])), pf_unord(atomicLoad(&pcounters[c + PC_MIN + 2u]))) - pad;
    let mx = vec3f(pf_unord(atomicLoad(&pcounters[c + PC_MAX])), pf_unord(atomicLoad(&pcounters[c + PC_MAX + 1u])), pf_unord(atomicLoad(&pcounters[c + PC_MAX + 2u]))) + pad;
    let ext = max(mx - mn, vec3f(EPSILON_FINE));
    var cell = max(2.0 * psim.r_insert * GRID_PAD_SCALE, max(ext.x, max(ext.y, ext.z)) / f32(PD_MAX_DIM));
    cell = max(cell, pow(ext.x * ext.y * ext.z / f32(PD_MAX_CELLS), 1.0 / 3.0));
    cell = max(cell, EPSILON_FINE);
    var dims = vec3u(1u);
    for (var k = 0; k < GRID_FIT_ATTEMPTS; k++) {
        dims = vec3u(clamp(ceil(ext / cell), vec3f(1.0), vec3f(f32(PD_MAX_DIM))));
        if (dims.x * dims.y * dims.z <= PD_MAX_CELLS && all(vec3f(dims) * cell >= ext)) {
            break;
        }
        cell *= GRID_GROWTH;
    }
    atomicStore(&particle_rw[h], bitcast<u32>(mn.x));
    atomicStore(&particle_rw[h + 1u], bitcast<u32>(mn.y));
    atomicStore(&particle_rw[h + 2u], bitcast<u32>(mn.z));
    atomicStore(&particle_rw[h + PD_HEADER_CELL], bitcast<u32>(cell));
    atomicStore(&particle_rw[h + PD_HEADER_DIMS], dims.x);
    atomicStore(&particle_rw[h + PD_HEADER_DIMS + 1u], dims.y);
    atomicStore(&particle_rw[h + PD_HEADER_DIMS + 2u], dims.z);
    atomicStore(&particle_rw[h + PD_HEADER_VALID], 1u);
}

struct BuildGrid {
    origin: vec3f,
    cell: f32,
    dims: vec3i,
    total: u32,
}

fn build_grid(s: u32) -> BuildGrid {
    let h = s * PD_HEADER_WORDS;
    var g: BuildGrid;
    g.origin = vec3f(prw_f32(h), prw_f32(h + 1u), prw_f32(h + 2u));
    g.cell = prw_f32(h + PD_HEADER_CELL);
    g.dims = vec3i(i32(atomicLoad(&particle_rw[h + PD_HEADER_DIMS])), i32(atomicLoad(&particle_rw[h + PD_HEADER_DIMS + 1u])), i32(atomicLoad(&particle_rw[h + PD_HEADER_DIMS + 2u])));
    g.total = u32(g.dims.x * g.dims.y * g.dims.z);
    return g;
}

fn build_cell_addr(s: u32, g: BuildGrid, c: vec3i) -> u32 {
    return PD_CELLS + (s * PD_MAX_CELLS + u32(c.x + g.dims.x * (c.y + g.dims.y * c.z))) * PD_CELL_WORDS;
}

struct BuildSpan {
    lo: vec3i,
    hi: vec3i,
    ok: bool,
}

fn build_span(s: u32, g: BuildGrid, i: u32) -> BuildSpan {
    var out: BuildSpan;
    let a = PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS;
    out.ok = i < u32(psim.count) && atomicLoad(&particle_rw[a + PD_RECORD_ALIVE]) != 0u && g.total > 0u;
    if (!out.ok) {
        return out;
    }
    let p = vec3f(prw_f32(a), prw_f32(a + 1u), prw_f32(a + 2u));
    let r = prw_f32(a + PD_RECORD_RADIUS) * psim.insert_mult + psim.insert_add;
    out.lo = clamp(vec3i(floor((p - vec3f(r) - g.origin) / g.cell)), vec3i(0), g.dims - 1);
    out.hi = clamp(vec3i(floor((p + vec3f(r) - g.origin) / g.cell)), vec3i(0), g.dims - 1);
    out.hi = min(out.hi, out.lo + vec3i(1));
    return out;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_clear(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * PD_CELL_WORDS;
    atomicStore(&particle_rw[a], 0u);
    atomicStore(&particle_rw[a + PD_CELL_COUNT_WORD], 0u);
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_count(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    let sp = build_span(s, g, gid.x);
    if (!sp.ok) {
        return;
    }
    for (var z = sp.lo.z; z <= sp.hi.z; z++) {
        for (var y = sp.lo.y; y <= sp.hi.y; y++) {
            for (var x = sp.lo.x; x <= sp.hi.x; x++) {
                atomicAdd(&particle_rw[build_cell_addr(s, g, vec3i(x, y, z)) + PD_CELL_COUNT_WORD], 1u);
            }
        }
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_alloc(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * PD_CELL_WORDS;
    let n = atomicLoad(&particle_rw[a + PD_CELL_COUNT_WORD]);
    if (n > 0u) {
        atomicStore(&particle_rw[a], atomicAdd(&pcounters[s * PC_WORDS + PC_ALLOC], min(n, PD_CELL_CAP)));
    }
    atomicStore(&particle_rw[a + PD_CELL_COUNT_WORD], 0u);
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_scatter(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    let sp = build_span(s, g, gid.x);
    if (!sp.ok) {
        return;
    }
    for (var z = sp.lo.z; z <= sp.hi.z; z++) {
        for (var y = sp.lo.y; y <= sp.hi.y; y++) {
            for (var x = sp.lo.x; x <= sp.hi.x; x++) {
                let a = build_cell_addr(s, g, vec3i(x, y, z));
                let k = atomicAdd(&particle_rw[a + PD_CELL_COUNT_WORD], 1u);
                if (k < PD_CELL_CAP) {
                    let slot = atomicLoad(&particle_rw[a]) + k;
                    atomicStore(&particle_rw[PD_INDEX + s * PD_MAX_PARTICLES * PD_INSERTS_PER_PARTICLE + slot], gid.x);
                }
            }
        }
    }
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_dist_init(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * PD_CELL_WORDS;
    let n = min(atomicLoad(&particle_rw[a + PD_CELL_COUNT_WORD]), PD_CELL_CAP);
    atomicStore(&particle_rw[a + PD_CELL_COUNT_WORD], n | (select(PD_DIST_CAP, 0u, n > 0u) << PD_CELL_SKIP_SHIFT));
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_particle_grid_dilate(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * PD_CELL_WORDS;
    let w1 = atomicLoad(&particle_rw[a + PD_CELL_COUNT_WORD]);
    let d = w1 >> PD_CELL_SKIP_SHIFT;
    if (d <= 1u) {
        return;
    }
    let plane = u32(g.dims.x * g.dims.y);
    let c = vec3i(i32(gid.x % u32(g.dims.x)), i32((gid.x / u32(g.dims.x)) % u32(g.dims.y)), i32(gid.x / plane));
    var m = d;
    for (var z = -1; z <= 1; z++) {
        for (var y = -1; y <= 1; y++) {
            for (var x = -1; x <= 1; x++) {
                let n = c + vec3i(x, y, z);
                if (any(n < vec3i(0)) || any(n >= g.dims)) {
                    continue;
                }
                m = min(m, (atomicLoad(&particle_rw[build_cell_addr(s, g, n) + PD_CELL_COUNT_WORD]) >> PD_CELL_SKIP_SHIFT) + 1u);
            }
        }
    }
    if (m < d) {
        atomicStore(&particle_rw[a + PD_CELL_COUNT_WORD], (w1 & PD_CELL_COUNT_MASK) | (m << PD_CELL_SKIP_SHIFT));
    }
}
