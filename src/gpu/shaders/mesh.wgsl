struct MeshParams {
    origin: vec3f,
    cell: f32,
    iso: f32,
    count: u32,
    span: u32,
    local_offset: u32,
    sharp: f32,
    color_on: f32,
    _pad0: f32,
    _pad1: f32,
}

struct MeshCellIn {
    origin: vec4f,
    c0: vec4f,
    c1: vec4f,
}

struct MeshVertOut {
    pos: vec4f,
    normal: vec4f,
    color: vec4f,
}

@group(1) @binding(20) var<uniform> mp: MeshParams;
@group(1) @binding(21) var<storage, read> mesh_blocks: array<vec4u>;
@group(1) @binding(22) var<storage, read_write> mesh_values: array<f32>;
@group(1) @binding(21) var<storage, read> mesh_cells: array<MeshCellIn>;
@group(1) @binding(22) var<storage, read_write> mesh_verts: array<MeshVertOut>;
@group(1) @binding(21) var<storage, read> probe_points: array<vec4f>;
@group(1) @binding(22) var<storage, read_write> probe_values: array<vec4f>;

const MESH_BLOCK: u32 = 8u;
const MESH_PROBE_TAPS = 5;
const TETRA_GRAD_DIVISOR = 4.0;
const MESH_MIN_GRADIENT = 1e-8;
const MESH_MIN_DETERMINANT = 1e-20;
const MESH_MIN_SHARPNESS = 0.001;
const CUBE_EDGES = 12u;
const EDGES_PER_AXIS = 4u;
const MESH_FIELD_PROBE_CELLS = 0.25;
const MESH_FINAL_NORMAL_PROBE_CELLS = 0.5;
const MESH_SHARPNESS_FALLOFF = 10.0;
const MESH_PROJECTION_ITERS = 3;
const MESH_DEFAULT_GREY = vec3f(0.8);

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_mesh_points(@builtin(global_invocation_id) gid: vec3u) {
    let per_item = mp.span * mp.span * mp.span;
    let t = gid.x;
    if (t >= mp.count * per_item) {
        return;
    }
    let item = t / per_item;
    let l = t % per_item;
    let local = vec3u(l % mp.span, (l / mp.span) % mp.span, l / (mp.span * mp.span));
    let idx = mesh_blocks[item].xyz * MESH_BLOCK + local + vec3u(mp.local_offset);
    let p = mp.origin + vec3f(idx) * mp.cell;
    mesh_values[t] = scene_de(p) - mp.iso;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_mesh_probe(@builtin(global_invocation_id) gid: vec3u) {
    if (gid.x >= mp.count) {
        return;
    }
    let raw = probe_points[gid.x];
    carves_off = raw.w < 0.0;
    let q = vec4f(raw.xyz, abs(raw.w));
    var g = vec3f(0.0);
    var centre = 0.0;
    for (var i = 0; i < MESH_PROBE_TAPS; i++) {
        var k = vec3f(0.0);
        if (i == 1) {
            k = vec3f(1.0, -1.0, -1.0);
        } else if (i == 2) {
            k = vec3f(-1.0, -1.0, 1.0);
        } else if (i == 3) {
            k = vec3f(-1.0, 1.0, -1.0);
        } else if (i == 4) {
            k = vec3f(1.0, 1.0, 1.0);
        }
        let d = scene_de(q.xyz + k * q.w);
        if (i == 0) {
            centre = d;
        } else {
            g += k * d;
        }
    }
    probe_values[gid.x] = vec4f(centre, g / (TETRA_GRAD_DIVISOR * q.w));
}

fn mesh_field(p: vec3f, h: f32) -> vec4f {
    let a = scene_de(p + vec3f(1.0, -1.0, -1.0) * h) - mp.iso;
    let b = scene_de(p + vec3f(-1.0, -1.0, 1.0) * h) - mp.iso;
    let c = scene_de(p + vec3f(-1.0, 1.0, -1.0) * h) - mp.iso;
    let d = scene_de(p + vec3f(1.0, 1.0, 1.0) * h) - mp.iso;
    let g = (vec3f(1.0, -1.0, -1.0) * a + vec3f(-1.0, -1.0, 1.0) * b + vec3f(-1.0, 1.0, -1.0) * c + vec3f(1.0, 1.0, 1.0) * d) / (TETRA_GRAD_DIVISOR * h);
    return vec4f(g, 0.25 * (a + b + c + d));
}

fn trilinear_grad(c: array<f32, 8>, f: vec3f) -> vec3f {
    let gx = mix(mix(c[1] - c[0], c[3] - c[2], f.y), mix(c[5] - c[4], c[7] - c[6], f.y), f.z);
    let gy = mix(mix(c[2] - c[0], c[3] - c[1], f.x), mix(c[6] - c[4], c[7] - c[5], f.x), f.z);
    let gz = mix(mix(c[4] - c[0], c[5] - c[1], f.x), mix(c[6] - c[2], c[7] - c[3], f.x), f.y);
    return vec3f(gx, gy, gz);
}

fn mesh_normal(g: vec3f, fallback: vec3f) -> vec3f {
    let l = length(g);
    if (l > MESH_MIN_GRADIENT && l == l) {
        return g / l;
    }
    let lf = length(fallback);
    return select(vec3f(0.0, 1.0, 0.0), fallback / lf, lf > EPSILON_TINY);
}

fn solve_sym3(a: mat3x3f, b: vec3f) -> vec3f {
    let det = determinant(a);
    if (abs(det) < MESH_MIN_DETERMINANT) {
        return vec3f(0.0);
    }
    let c0 = cross(a[1], a[2]);
    let c1 = cross(a[2], a[0]);
    let c2 = cross(a[0], a[1]);
    return vec3f(dot(c0, b), dot(c1, b), dot(c2, b)) / det;
}

@compute @workgroup_size(LINEAR_WORKGROUP_SIZE)
fn cs_mesh_verts(@builtin(global_invocation_id) gid: vec3u) {
    let t = gid.x;
    if (t >= mp.count) {
        return;
    }
    let cin = mesh_cells[t];
    let o = cin.origin.xyz;
    let h = mp.cell;
    let c = array<f32, 8>(cin.c0.x, cin.c0.y, cin.c0.z, cin.c0.w, cin.c1.x, cin.c1.y, cin.c1.z, cin.c1.w);

    var mass = vec3f(0.0);
    var n_cross = 0.0;
    var ata = mat3x3f(vec3f(0.0), vec3f(0.0), vec3f(0.0));
    var atb = vec3f(0.0);
    let use_qef = mp.sharp > MESH_MIN_SHARPNESS;

    for (var e = 0u; e < CUBE_EDGES; e++) {
        let axis = e / EDGES_PER_AXIS;
        let k = e % EDGES_PER_AXIS;
        var i0: u32;
        if (axis == 0u) {
            i0 = ((k & 1u) << 1u) | ((k >> 1u) << 2u);
        } else if (axis == 1u) {
            i0 = (k & 1u) | ((k >> 1u) << 2u);
        } else {
            i0 = (k & 1u) | ((k >> 1u) << 1u);
        }
        let i1 = i0 | (1u << axis);
        let v0 = c[i0];
        let v1 = c[i1];
        if ((v0 < 0.0) == (v1 < 0.0)) {
            continue;
        }
        let s = clamp(v0 / (v0 - v1), 0.0, 1.0);
        let f0 = vec3f(f32(i0 & 1u), f32((i0 >> 1u) & 1u), f32(i0 >> 2u));
        let f1 = vec3f(f32(i1 & 1u), f32((i1 >> 1u) & 1u), f32(i1 >> 2u));
        let f = mix(f0, f1, s);
        let p = o + f * h;
        mass += p;
        n_cross += 1.0;
        if (use_qef) {
            let n = mesh_normal(mesh_field(p, MESH_FIELD_PROBE_CELLS * h).xyz, trilinear_grad(c, f));
            ata += mat3x3f(n * n.x, n * n.y, n * n.z);
            atb += n * dot(n, p);
        }
    }
    mass /= max(n_cross, 1.0);

    var x = mass;
    if (use_qef && n_cross > 0.0) {
        let lambda = n_cross * exp2(-MESH_SHARPNESS_FALLOFF * mp.sharp);
        let a = ata + mat3x3f(vec3f(lambda, 0.0, 0.0), vec3f(0.0, lambda, 0.0), vec3f(0.0, 0.0, lambda));
        x = mass + solve_sym3(a, atb - ata * mass);
    }
    let lo = o;
    let hi = o + vec3f(h);
    x = clamp(x, lo, hi);

    for (var it = 0; it < MESH_PROJECTION_ITERS; it++) {
        let fg = mesh_field(x, MESH_FIELD_PROBE_CELLS * h);
        let g2 = dot(fg.xyz, fg.xyz);
        if (g2 < EPSILON_TINY || g2 != g2) {
            break;
        }
        x = clamp(x - fg.w * fg.xyz / g2, lo, hi);
    }

    let n = mesh_normal(mesh_field(x, MESH_FINAL_NORMAL_PROBE_CELLS * h).xyz, trilinear_grad(c, clamp((x - o) / h, vec3f(0.0), vec3f(1.0))));
    var col = MESH_DEFAULT_GREY;
    if (mp.color_on > 0.5) {
        col = clamp(hit_material(x).mat.color, vec3f(0.0), vec3f(1.0));
    }
    mesh_verts[t] = MeshVertOut(vec4f(x, 1.0), vec4f(n, 0.0), vec4f(col, 1.0));
}
