fn particle_blend_k(s: u32) -> f32 {
    let mode = i32(u.particle_systems[s].combine_mode + 0.5);
    let smin_family = mode == COMBINE_SMOOTH_MIN || mode == COMBINE_SMOOTH_MIN_LIN || mode == COMBINE_SMOOTH_MIN_NLIN || mode == COMBINE_SMOOTH_MIX;
    return select(0.0, max(u.particle_systems[s].blend_k, 0.0), smin_family);
}

fn particle_field(s: u32, p: vec3f) -> vec2f {
    let g = particle_grid(s);
    if (!g.valid) {
        return vec2f(INFINITE_DISTANCE, 0.0);
    }
    let half = g.cell * 0.5;
    let hi = g.origin + vec3f(g.dims) * g.cell;
    let q = abs(p - (g.origin + hi) * 0.5) - (hi - g.origin) * 0.5;
    let box_d = length(max(q, vec3f(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
    if (box_d > half) {
        return vec2f(box_d, 0.0);
    }
    let local = (p - g.origin) / g.cell;
    let c = vec3i(floor(local));
    if (particle_in_grid(g, c)) {
        let k = particle_cell(s, g, c).z;
        if (k >= PD_SKIP_MIN_DIST) {
            return vec2f(f32(k - 1u) * g.cell, 0.0);
        }
    }

    let lo = c + select(vec3i(-1), vec3i(0), local - vec3f(c) >= vec3f(0.5));
    let k_blend = particle_blend_k(s);
    var d = INFINITE_DISTANCE;
    var strip = 0.0;
    for (var n = 0; n < CUBE_CORNERS; n++) {
        let cc = lo + vec3i(n & 1, (n >> 1) & 1, (n >> 2) & 1);
        if (!particle_in_grid(g, cc)) {
            continue;
        }
        let cell = particle_cell(s, g, cc);
        for (var e = 0u; e < cell.y; e++) {
            let i = particle_entry(s, cell.x + e);
            let sph = particle_sphere(s, i);
            if (k_blend > 0.0) {
                let home = clamp(vec3i(floor((sph.xyz - g.origin) / g.cell)), lo, lo + vec3i(1));
                if (any(home != cc)) {
                    continue;
                }
            }
            let di = length(p - sph.xyz) - sph.w;
            let si = particle_strip(s, i);
            if (k_blend > 0.0) {
                let h = clamp(0.5 + 0.5 * (di - d) / k_blend, 0.0, 1.0);
                d = mix(di, d, h) - k_blend * h * (1.0 - h);
                strip = mix(si, strip, h);
            } else if (di < d) {
                d = di;
                strip = si;
            }
        }
    }
    return vec2f(min(d, half), strip);
}

fn particle_lit(s: u32) -> bool {
    return u32(u.particle_systems[s].mode + 0.5) == PARTICLE_MODE_SPHERES;
}

fn particles_scene_de(pos: vec3f, d_in: f32, have_in: bool) -> vec2f {
    var d = d_in;
    var have = have_in;
    if (particles_off) {
        return vec2f(d, select(0.0, 1.0, have));
    }
    for (var s = 0u; s < u32(MAX_PARTICLE_SYSTEMS); s++) {
        if (!particle_lit(s)) {
            continue;
        }
        let f = particle_field(s, pos);
        if (!have) {
            d = f.x;
            have = true;
            continue;
        }
        d = combine_de(i32(u.particle_systems[s].combine_mode + 0.5), d, f.x, u.particle_systems[s].blend_k).x;
    }
    return vec2f(d, select(0.0, 1.0, have));
}

fn particles_hit_material(pos: vec3f, sp_in: SurfacePoint, have_in: bool) -> ParticleSurface {
    var sp = sp_in;
    var have = have_in;
    for (var s = 0u; s < u32(MAX_PARTICLE_SYSTEMS); s++) {
        if (!particle_lit(s)) {
            continue;
        }
        let f = particle_field(s, pos);
        let mat_s = particle_gradient(s, f.y);
        if (!have) {
            sp = SurfacePoint(mat_s, f.x);
            have = true;
            continue;
        }
        let c = combine_de(i32(u.particle_systems[s].combine_mode + 0.5), sp.de, f.x, u.particle_systems[s].blend_k);
        sp = SurfacePoint(mix_material(sp.mat, mat_s, c.y), c.x);
    }
    return ParticleSurface(sp, have);
}

fn particles_nearest_lit(pos: vec3f) -> vec2f {
    var best = vec2f(INFINITE_DISTANCE, -1.0);
    for (var s = 0u; s < u32(MAX_PARTICLE_SYSTEMS); s++) {
        if (!particle_lit(s)) {
            continue;
        }
        let d = particle_field(s, pos).x;
        if (d < best.x) {
            best = vec2f(d, f32(s));
        }
    }
    return best;
}
