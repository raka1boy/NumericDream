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
    let state = x * 747796405u + 2891336453u;
    let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

fn particle_rand(i: u32, k: u32) -> f32 {
    let h = phash_u32(phash_u32(i * 0x9E3779B9u + bitcast<u32>(psim.seed)) + k * 0x85EBCA6Bu);
    return f32(h >> 8u) * (1.0 / 16777216.0);
}

fn particle_sphere_dir(a: f32, b: f32) -> vec3f {
    let z = 2.0 * a - 1.0;
    let r = sqrt(max(1.0 - z * z, 0.0));
    let phi = 6.28318530718 * b;
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
    return max(psim.size * (1.0 + psim.size_var * (2.0 * particle_rand(i, 6u) - 1.0)), 1e-5);
}

fn particle_static(i: u32) -> ParticleStatic {
    var ps: ParticleStatic;
    let shape = u32(psim.spawn_shape + 0.5);
    if (shape == 0u) {
        let dir = particle_sphere_dir(particle_rand(i, 0u), particle_rand(i, 1u));
        ps.spawn = psim.center + dir * (psim.spawn_radius * pow(particle_rand(i, 2u), 1.0 / 3.0));
    } else if (shape == 1u) {
        let r = psim.spawn_radius * sqrt(particle_rand(i, 0u));
        let a = 6.28318530718 * particle_rand(i, 1u);
        ps.spawn = psim.center + psim.axis_u * (r * cos(a)) + psim.axis_v * (r * sin(a));
    } else {
        ps.spawn = psim.center + psim.axis_u * ((2.0 * particle_rand(i, 0u) - 1.0) * psim.extent.x) +
            psim.axis_v * ((2.0 * particle_rand(i, 1u) - 1.0) * psim.extent.y);
    }

    let mode = u32(psim.velocity_mode + 0.5);
    var dir = particle_sphere_dir(particle_rand(i, 3u), particle_rand(i, 4u));
    if (mode == 0u) {
        let n = psim.direction;
        let cz = 1.0 - particle_rand(i, 3u) * (1.0 - cos(psim.spread));
        let sz = sqrt(max(1.0 - cz * cz, 0.0));
        let phi = 6.28318530718 * particle_rand(i, 4u);
        let t = normalize(cross(n, select(vec3f(1.0, 0.0, 0.0), vec3f(0.0, 1.0, 0.0), abs(n.x) > 0.9)));
        let b = cross(n, t);
        dir = n * cz + (t * cos(phi) + b * sin(phi)) * sz;
    } else if (mode == 1u) {
        let off = ps.spawn - psim.center;
        let len = length(off);
        if (len > 1e-6) {
            dir = off / len;
        }
    }
    ps.vel = dir * mix(psim.speed_min, psim.speed_max, particle_rand(i, 5u));
    ps.radius = particle_radius(i);
    ps.birth = select(0.0, (f32(i) + particle_rand(i, 7u)) / max(psim.count, 1.0) * psim.emit_duration, psim.emit_duration > 0.0);
    ps.strip_rand = particle_rand(i, 8u);
    return ps;
}

fn particle_expired(ps: ParticleStatic, t: f32) -> bool {
    return psim.lifetime > 0.0 && t >= ps.birth + psim.lifetime;
}

@compute @workgroup_size(64)
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
    pstate_out[s * PD_MAX_PARTICLES + i] = ParticleState(ps.spawn, status, ps.vel, -1);
}

fn phash_cell(p: vec3f) -> vec3i {
    return vec3i(floor(p / psim.sim_cell));
}

fn phash_bucket(c: vec3i) -> u32 {
    let h = (u32(c.x) * 73856093u) ^ (u32(c.y) * 19349663u) ^ (u32(c.z) * 83492791u);
    return (h & (PH_BUCKETS - 1u)) * PH_WORDS;
}

@compute @workgroup_size(64)
fn cs_particle_hash_clear(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x < PH_BUCKETS) {
        atomicStore(&phash[gid.x * PH_WORDS], 0u);
    }
}

@compute @workgroup_size(64)
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
        atomicStore(&phash[b + 1u + slot], i);
    }
}

@compute @workgroup_size(64)
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
            st.support = -1;
            travel = psim.dt;
        }
    } else if (st.status == PS_MOVING) {
        travel = psim.dt;
    }

    if (st.status == PS_MOVING) {
        let speed = length(st.vel);
        let seg = speed * travel;
        let dir = select(vec3f(0.0, 1.0, 0.0), st.vel / max(speed, 1e-12), speed > 1e-12);
        var stop_s = seg;
        var support = -2;

        if (psim.stick > 0.5) {
            let reach = ps.radius + psim.sim_cell * 0.5;
            let a = st.pos;
            let b = st.pos + dir * seg;
            let lo = phash_cell(min(a, b) - vec3f(reach));
            let hi = min(phash_cell(max(a, b) + vec3f(reach)), lo + vec3i(3));
            for (var z = lo.z; z <= hi.z; z++) {
                for (var y = lo.y; y <= hi.y; y++) {
                    for (var x = lo.x; x <= hi.x; x++) {
                        let bk = phash_bucket(vec3i(x, y, z));
                        let n = min(atomicLoad(&phash[bk]), PH_SLOTS);
                        for (var e = 0u; e < n; e++) {
                            let j = atomicLoad(&phash[bk + 1u + e]);
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
            let eps = max(ps.radius * 0.02, 1e-5);
            var s_t = 0.0;
            for (var k = 0; k < 32; k++) {
                if (s_t > stop_s) {
                    break;
                }
                let dd = scene_de(st.pos + dir * s_t) - ps.radius;
                if (dd < eps) {
                    stop_s = s_t;
                    support = -1;
                    break;
                }
                s_t += dd;
            }
        }

        st.pos = st.pos + dir * stop_s;
        if (support >= -1) {
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
    return select(b | 0x80000000u, ~b, (b & 0x80000000u) != 0u);
}

fn pf_unord(v: u32) -> f32 {
    return bitcast<f32>(select(~v, v & 0x7fffffffu, (v & 0x80000000u) != 0u));
}

fn prw_f32(a: u32) -> f32 {
    return bitcast<f32>(atomicLoad(&particle_rw[a]));
}

@compute @workgroup_size(64)
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
        if (u32(psim.strip_mode + 0.5) == 1u) {
            strip = length(pos - psim.center) / max(psim.strip_span, 1e-4);
        }
        strip = clamp(strip + psim.strip_offset, 0.0, 1.0);
    }

    let a = PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS;
    atomicStore(&particle_rw[a], bitcast<u32>(pos.x));
    atomicStore(&particle_rw[a + 1u], bitcast<u32>(pos.y));
    atomicStore(&particle_rw[a + 2u], bitcast<u32>(pos.z));
    atomicStore(&particle_rw[a + 3u], bitcast<u32>(select(0.0, radius, alive)));
    atomicStore(&particle_rw[a + 4u], bitcast<u32>(strip));
    atomicStore(&particle_rw[a + 5u], select(0u, 1u, alive));
    if (!alive) {
        return;
    }
    let c = s * PC_WORDS;
    atomicMin(&pcounters[c + 1u], pf_ord(pos.x));
    atomicMin(&pcounters[c + 2u], pf_ord(pos.y));
    atomicMin(&pcounters[c + 3u], pf_ord(pos.z));
    atomicMax(&pcounters[c + 4u], pf_ord(pos.x));
    atomicMax(&pcounters[c + 5u], pf_ord(pos.y));
    atomicMax(&pcounters[c + 6u], pf_ord(pos.z));
    atomicAdd(&pcounters[c + 7u], 1u);
}

@compute @workgroup_size(1)
fn cs_particle_grid_setup() {
    let s = psys();
    let c = s * PC_WORDS;
    let h = s * PD_HEADER_WORDS;
    if (atomicLoad(&pcounters[c + 7u]) == 0u) {
        atomicStore(&particle_rw[h + 4u], 0u);
        atomicStore(&particle_rw[h + 5u], 0u);
        atomicStore(&particle_rw[h + 6u], 0u);
        atomicStore(&particle_rw[h + 7u], 0u);
        return;
    }
    let pad = vec3f(psim.r_insert * 1.001 + 1e-6);
    let mn = vec3f(pf_unord(atomicLoad(&pcounters[c + 1u])), pf_unord(atomicLoad(&pcounters[c + 2u])), pf_unord(atomicLoad(&pcounters[c + 3u]))) - pad;
    let mx = vec3f(pf_unord(atomicLoad(&pcounters[c + 4u])), pf_unord(atomicLoad(&pcounters[c + 5u])), pf_unord(atomicLoad(&pcounters[c + 6u]))) + pad;
    let ext = max(mx - mn, vec3f(1e-6));
    var cell = max(2.0 * psim.r_insert * 1.001, max(ext.x, max(ext.y, ext.z)) / f32(PD_MAX_DIM));
    cell = max(cell, pow(ext.x * ext.y * ext.z / f32(PD_MAX_CELLS), 1.0 / 3.0));
    cell = max(cell, 1e-6);
    var dims = vec3u(1u);
    for (var k = 0; k < 128; k++) {
        dims = vec3u(clamp(ceil(ext / cell), vec3f(1.0), vec3f(f32(PD_MAX_DIM))));
        if (dims.x * dims.y * dims.z <= PD_MAX_CELLS && all(vec3f(dims) * cell >= ext)) {
            break;
        }
        cell *= 1.05;
    }
    atomicStore(&particle_rw[h], bitcast<u32>(mn.x));
    atomicStore(&particle_rw[h + 1u], bitcast<u32>(mn.y));
    atomicStore(&particle_rw[h + 2u], bitcast<u32>(mn.z));
    atomicStore(&particle_rw[h + 3u], bitcast<u32>(cell));
    atomicStore(&particle_rw[h + 4u], dims.x);
    atomicStore(&particle_rw[h + 5u], dims.y);
    atomicStore(&particle_rw[h + 6u], dims.z);
    atomicStore(&particle_rw[h + 7u], 1u);
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
    g.cell = prw_f32(h + 3u);
    g.dims = vec3i(i32(atomicLoad(&particle_rw[h + 4u])), i32(atomicLoad(&particle_rw[h + 5u])), i32(atomicLoad(&particle_rw[h + 6u])));
    g.total = u32(g.dims.x * g.dims.y * g.dims.z);
    return g;
}

fn build_cell_addr(s: u32, g: BuildGrid, c: vec3i) -> u32 {
    return PD_CELLS + (s * PD_MAX_CELLS + u32(c.x + g.dims.x * (c.y + g.dims.y * c.z))) * 2u;
}

struct BuildSpan {
    lo: vec3i,
    hi: vec3i,
    ok: bool,
}

fn build_span(s: u32, g: BuildGrid, i: u32) -> BuildSpan {
    var out: BuildSpan;
    let a = PD_RECORDS + (s * PD_MAX_PARTICLES + i) * PD_RECORD_WORDS;
    out.ok = i < u32(psim.count) && atomicLoad(&particle_rw[a + 5u]) != 0u && g.total > 0u;
    if (!out.ok) {
        return out;
    }
    let p = vec3f(prw_f32(a), prw_f32(a + 1u), prw_f32(a + 2u));
    let r = prw_f32(a + 3u) * psim.insert_mult + psim.insert_add;
    out.lo = clamp(vec3i(floor((p - vec3f(r) - g.origin) / g.cell)), vec3i(0), g.dims - 1);
    out.hi = clamp(vec3i(floor((p + vec3f(r) - g.origin) / g.cell)), vec3i(0), g.dims - 1);
    out.hi = min(out.hi, out.lo + vec3i(1));
    return out;
}

@compute @workgroup_size(64)
fn cs_particle_grid_clear(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * 2u;
    atomicStore(&particle_rw[a], 0u);
    atomicStore(&particle_rw[a + 1u], 0u);
}

@compute @workgroup_size(64)
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
                atomicAdd(&particle_rw[build_cell_addr(s, g, vec3i(x, y, z)) + 1u], 1u);
            }
        }
    }
}

@compute @workgroup_size(64)
fn cs_particle_grid_alloc(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * 2u;
    let n = atomicLoad(&particle_rw[a + 1u]);
    if (n > 0u) {
        atomicStore(&particle_rw[a], atomicAdd(&pcounters[s * PC_WORDS + 8u], min(n, PD_CELL_CAP)));
    }
    atomicStore(&particle_rw[a + 1u], 0u);
}

@compute @workgroup_size(64)
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
                let k = atomicAdd(&particle_rw[a + 1u], 1u);
                if (k < PD_CELL_CAP) {
                    let slot = atomicLoad(&particle_rw[a]) + k;
                    atomicStore(&particle_rw[PD_INDEX + s * PD_MAX_PARTICLES * PD_INSERTS_PER_PARTICLE + slot], gid.x);
                }
            }
        }
    }
}

@compute @workgroup_size(64)
fn cs_particle_grid_dist_init(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * 2u;
    let n = min(atomicLoad(&particle_rw[a + 1u]), PD_CELL_CAP);
    atomicStore(&particle_rw[a + 1u], n | (select(PD_DIST_CAP, 0u, n > 0u) << 16u));
}

@compute @workgroup_size(64)
fn cs_particle_grid_dilate(@builtin(global_invocation_id) gid: vec3u) {
    let s = psys();
    let g = build_grid(s);
    if (gid.x >= g.total) {
        return;
    }
    let a = PD_CELLS + (s * PD_MAX_CELLS + gid.x) * 2u;
    let w1 = atomicLoad(&particle_rw[a + 1u]);
    let d = w1 >> 16u;
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
                m = min(m, (atomicLoad(&particle_rw[build_cell_addr(s, g, n) + 1u]) >> 16u) + 1u);
            }
        }
    }
    if (m < d) {
        atomicStore(&particle_rw[a + 1u], (w1 & 0xffffu) | (m << 16u));
    }
}
