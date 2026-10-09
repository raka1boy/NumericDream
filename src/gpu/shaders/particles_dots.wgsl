const PARTICLE_DDA_MAX_STEPS = 512;

fn particle_dots_system(s: u32, o: vec3f, d: vec3f, t_max: f32, pick: bool, out: ptr<function, DotsHit>) {
    let g = particle_grid(s);
    if (!g.valid || u32(u.particle_systems[s].mode + 0.5) != PARTICLE_MODE_DOTS) {
        return;
    }
    let hard = pick || u.particle_systems[s].dot_style > 0.5;
    let reach = select(max(u.particle_systems[s].glow_extent, 1.0), 1.0, hard);
    let glow = max(u.particle_systems[s].glow, 0.0);

    let inv = 1.0 / select(d, vec3f(EPSILON_TINY), abs(d) < vec3f(EPSILON_TINY));
    let hi = g.origin + vec3f(g.dims) * g.cell;
    let ta = (g.origin - o) * inv;
    let tb = (hi - o) * inv;
    let t0 = max(max(max(min(ta.x, tb.x), min(ta.y, tb.y)), min(ta.z, tb.z)), 0.0);
    var t1 = min(min(max(ta.x, tb.x), max(ta.y, tb.y)), max(ta.z, tb.z));
    t1 = min(t1, t_max);
    if ((*out).hit_t >= 0.0) {
        t1 = min(t1, (*out).hit_t);
    }
    if (t0 >= t1) {
        return;
    }

    let dstep = select(vec3i(-1), vec3i(1), d >= vec3f(0.0));
    var c = clamp(vec3i(floor((o + d * t0 - g.origin) / g.cell)), vec3i(0), g.dims - 1);
    var t = t0;
    for (var it = 0; it < PARTICLE_DDA_MAX_STEPS; it++) {
        let cmin = g.origin + vec3f(c) * g.cell;
        let ea = (cmin - o) * inv;
        let eb = (cmin + vec3f(g.cell) - o) * inv;
        let exit_v = max(ea, eb);
        let t_exit = min(exit_v.x, min(exit_v.y, exit_v.z));
        let t_in = max(max(min(ea.x, eb.x), min(ea.y, eb.y)), min(ea.z, eb.z));
        let cell = particle_cell(s, g, c);

        if (cell.z >= PD_SKIP_MIN_DIST) {
            t = max(t, t_in) + f32(cell.z - 1u) * g.cell;
            if (t >= t1) {
                break;
            }
            c = clamp(vec3i(floor((o + d * t - g.origin) / g.cell)), vec3i(0), g.dims - 1);
            continue;
        }

        for (var e = 0u; e < cell.y; e++) {
            let i = particle_entry(s, cell.x + e);
            let sph = particle_sphere(s, i);
            let oc = sph.xyz - o;
            let along = dot(oc, d);
            let perp2 = max(dot(oc, oc) - along * along, 0.0);
            if (hard) {
                let r2 = sph.w * sph.w;
                if (perp2 >= r2) {
                    continue;
                }
                let th = along - sqrt(r2 - perp2);
                if (th >= 0.0 && th < t1) {
                    t1 = th;
                    let col = particle_gradient(s, particle_strip(s, i)).color;
                    (*out).hit_t = th;
                    (*out).hit_color = col * glow;
                    (*out).hit_sys = f32(s);
                }
            } else {
                let rg = sph.w * reach;
                if (perp2 >= rg * rg || along < max(t_in, 0.0) || along >= t_exit || along >= t1) {
                    continue;
                }
                let x = 1.0 - perp2 / (rg * rg);
                (*out).emit += particle_gradient(s, particle_strip(s, i)).color * (glow * x * x);
            }
        }

        if (t_exit >= t1) {
            break;
        }
        t = t_exit;
        if (exit_v.x <= exit_v.y && exit_v.x <= exit_v.z) {
            c.x += dstep.x;
        } else if (exit_v.y <= exit_v.z) {
            c.y += dstep.y;
        } else {
            c.z += dstep.z;
        }
        if (!particle_in_grid(g, c)) {
            break;
        }
    }
}

fn particle_dots(origin: vec3f, dir: vec3f, t_max: f32, pick: bool) -> DotsHit {
    var out = DotsHit(vec3f(0.0), -1.0, vec3f(0.0), -1.0);
    for (var s = 0u; s < u32(MAX_PARTICLE_SYSTEMS); s++) {
        particle_dots_system(s, origin, dir, t_max, pick, &out);
    }
    return out;
}
