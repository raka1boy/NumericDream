const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const file_dialog = @import("../bindings/file_dialog.zig");
const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const RenderProgress = fractal_gpu.RenderProgress;
const mesher = fractal_gpu.mesher;
const block = mesher.block;
const ProgressOverlay = @import("../gpu/progress_overlay.zig").ProgressOverlay;

const export_image = @import("export_image.zig");
const scene_state = @import("scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const camera_mod = @import("camera.zig");
const Vec3 = camera_mod.Vec3;
const FreeCamera = camera_mod.FreeCamera;
const WarpState = @import("warp.zig").WarpState;
const SliderRange = @import("slider_range.zig").SliderRange;

pub const MeshExportState = struct {
    window_open: bool = false,
    bounds_seeded: bool = false,
    resolution: f32 = 384,
    resolution_range: SliderRange = .{ .min = 64, .max = 1024 },
    center: Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    center_range_x: SliderRange = .{ .min = -8, .max = 8 },
    center_range_y: SliderRange = .{ .min = -8, .max = 8 },
    center_range_z: SliderRange = .{ .min = -8, .max = 8 },
    size: Vec3 = .{ .x = 3, .y = 3, .z = 3 },
    size_range_x: SliderRange = .{ .min = 0.1, .max = 16 },
    size_range_y: SliderRange = .{ .min = 0.1, .max = 16 },
    size_range_z: SliderRange = .{ .min = 0.1, .max = 16 },
    iso_scale: f32 = 0.5,
    iso_scale_range: SliderRange = .{ .min = 0.05, .max = 2 },
    sharpness: f32 = 0.5,
    sharpness_range: SliderRange = .{ .min = 0, .max = 1 },
    min_piece: f32 = 32,
    min_piece_range: SliderRange = .{ .min = 0, .max = 2000 },
    vertex_colors: bool = true,
    info_buf: [160]u8 = undefined,
    info: [:0]const u8 = "",
    status_buf: [200]u8 = undefined,
    status: [:0]const u8 = "",
};

pub const Scene = struct {
    instances: []const FractalInstanceState,
    warps: []const WarpState,
    camera: FreeCamera,
};

const none: u32 = std.math.maxInt(u32);
const side = block + 1;
const block_points = side * side * side;
const cull_margin: f32 = 1.25;
const block_half_diag: f32 = 0.8660254 * @as(f32, block);
const estimate_resolution: u32 = 128;
const fit_resolution: u32 = 512;

pub fn seedBounds(state: *MeshExportState, instances: []const FractalInstanceState) void {
    const box = searchBox(instances);
    state.center = box.center;
    const s = @min(box.half, 8) * 0.75;
    state.size = .{ .x = s, .y = s, .z = s };
    state.bounds_seeded = true;
}

const Grid = struct {
    origin: [3]f32,
    cell: f32,
    blocks: [3]u32,

    fn init(center: Vec3, size: Vec3, resolution: u32) Grid {
        const ext = [3]f32{ @max(size.x, 1e-4), @max(size.y, 1e-4), @max(size.z, 1e-4) };
        const c = [3]f32{ center.x, center.y, center.z };
        const cell = @max(ext[0], @max(ext[1], ext[2])) / @as(f32, @floatFromInt(@max(resolution, block)));
        var g = Grid{ .origin = undefined, .cell = cell, .blocks = undefined };
        for (0..3) |a| {
            g.blocks[a] = @max(1, @as(u32, @intFromFloat(@ceil(ext[a] / cell / @as(f32, block)))));
            g.origin[a] = c[a] - 0.5 * @as(f32, @floatFromInt(g.blocks[a] * block)) * cell;
        }
        return g;
    }

    fn blockCount(g: Grid) usize {
        return @as(usize, g.blocks[0]) * g.blocks[1] * g.blocks[2];
    }

    fn blockIndex(g: Grid, x: usize, y: usize, z: usize) usize {
        return x + g.blocks[0] * (y + g.blocks[1] * z);
    }
};

const Pacer = struct {
    units: u32,
    max_units: u32,
    const target_ms: f64 = 120;

    fn take(self: Pacer, remaining: usize) u32 {
        return @intCast(@min(remaining, self.units));
    }

    fn observe(self: *Pacer, ms: f64, done: u32) void {
        if (done == 0) return;
        const want = target_ms * @as(f64, @floatFromInt(done)) / @max(ms, 0.01);
        const grown = @min(want, @as(f64, @floatFromInt(self.units)) * 2.0);
        self.units = @intFromFloat(std.math.clamp(grown, 1024, @as(f64, @floatFromInt(self.max_units))));
    }
};

fn nowMs() f64 {
    return @as(f64, @floatFromInt(sdl.SDL_GetTicksNS())) / @as(f64, std.time.ns_per_ms);
}

const Job = struct {
    allocator: std.mem.Allocator,
    ctx: *Context,
    fractal: *FractalRenderer,
    gpu: *mesher.MeshGpu,
    progress: RenderProgress,
    point_pacer: Pacer = .{ .units = 1 << 16, .max_units = mesher.max_threads },
    vert_pacer: Pacer = .{ .units = 1 << 11, .max_units = 1 << 20 },

    fn report(self: *Job, frac: f32) !void {
        const p = self.progress;
        p.callback(p.range_start + (p.range_end - p.range_start) * std.math.clamp(frac, 0, 1), p.userdata);
        if (p.cancel_flag) |cf| {
            if (cf.*) return error.RenderCancelled;
        }
    }

    fn evalBlocks(self: *Job, grid: Grid, iso: f32, span: u32, offset: u32, blocks: []const [4]u32, out: []f32, frac_lo: f32, frac_hi: f32) !void {
        const per_item = span * span * span;
        var start: usize = 0;
        while (start < blocks.len) {
            const n = @max(1, self.point_pacer.take((blocks.len - start) * per_item) / per_item);
            const count: u32 = @intCast(@min(n, blocks.len - start));
            const threads = count * per_item;
            const t0 = nowMs();
            try self.gpu.run(self.ctx, self.fractal.bind_group, .points, .{
                .origin = grid.origin,
                .cell = grid.cell,
                .iso = iso,
                .count = count,
                .span = span,
                .local_offset = offset,
            }, std.mem.sliceAsBytes(blocks[start..][0..count]), std.mem.sliceAsBytes(out[start * per_item ..][0..threads]), threads);
            self.point_pacer.observe(nowMs() - t0, threads);
            start += count;
            if (frac_hi > frac_lo) {
                try self.report(frac_lo + (frac_hi - frac_lo) * @as(f32, @floatFromInt(start)) / @as(f32, @floatFromInt(blocks.len)));
            } else if (self.progress.cancel_flag) |cf| {
                if (cf.*) return error.RenderCancelled;
            }
        }
    }

    fn coarsePass(self: *Job, grid: Grid, iso: f32, frac_hi: f32) ![]f32 {
        const a = self.allocator;
        const nb = grid.blockCount();
        const list = try a.alloc([4]u32, nb);
        defer a.free(list);
        for (0..grid.blocks[2]) |z| {
            for (0..grid.blocks[1]) |y| {
                for (0..grid.blocks[0]) |x| {
                    list[grid.blockIndex(x, y, z)] = .{ @intCast(x), @intCast(y), @intCast(z), 0 };
                }
            }
        }
        const coarse = try a.alloc(f32, nb);
        errdefer a.free(coarse);
        try self.evalBlocks(grid, iso, 1, block / 2, list, coarse, 0, frac_hi);
        return coarse;
    }
};

const Mesh = struct {
    positions: std.ArrayList([3]f32) = .empty,
    normals: std.ArrayList([3]f32) = .empty,
    colors: std.ArrayList([3]f32) = .empty,
    quads: std.ArrayList([4]u32) = .empty,
    vert_count: usize = 0,
    quad_count: usize = 0,

    fn deinit(self: *Mesh, a: std.mem.Allocator) void {
        self.positions.deinit(a);
        self.normals.deinit(a);
        self.colors.deinit(a);
        self.quads.deinit(a);
    }
};

const Settings = struct {
    iso_scale: f32,
    sharpness: f32,
    colors: bool,
    count_only: bool,
};

const Layer = struct {
    nx: usize,
    ny: usize,
    vals: []f32,
    ids: []u32,

    fn val(l: Layer, i: usize, j: usize, lz: usize) f32 {
        return l.vals[i + (l.nx + 1) * (j + (l.ny + 1) * lz)];
    }

    fn valPtr(l: Layer, i: usize, j: usize, lz: usize) *f32 {
        return &l.vals[i + (l.nx + 1) * (j + (l.ny + 1) * lz)];
    }

    fn id(l: Layer, i: usize, j: usize, slot: usize) u32 {
        return l.ids[i + l.nx * (j + l.ny * slot)];
    }
};

fn emitQuad(a: std.mem.Allocator, mesh: *Mesh, ids: [4]u32, inside_low: bool, count_only: bool) !void {
    for (ids) |v| {
        if (v == none) return;
    }
    mesh.quad_count += 1;
    if (count_only) return;
    try mesh.quads.append(a, if (inside_low) ids else .{ ids[3], ids[2], ids[1], ids[0] });
}

fn buildMesh(job: *Job, grid: Grid, settings: Settings, mesh: *Mesh) !void {
    const a = job.allocator;
    const iso = settings.iso_scale * grid.cell;
    const nb = grid.blockCount();
    const bxn = grid.blocks[0];
    const byn = grid.blocks[1];
    const bzn = grid.blocks[2];

    const coarse = try job.coarsePass(grid, iso, 0.05);
    defer a.free(coarse);

    const reach = cull_margin * block_half_diag * grid.cell + grid.cell;
    var active = try std.DynamicBitSetUnmanaged.initEmpty(a, nb);
    defer active.deinit(a);
    for (coarse, 0..) |v, i| {
        if (@abs(v) <= reach) active.set(i);
    }
    var near = try std.DynamicBitSetUnmanaged.initEmpty(a, nb);
    defer near.deinit(a);
    for (0..bzn) |z| for (0..byn) |y| for (0..bxn) |x| {
        const hit = blk: {
            for (@max(z, 1) - 1..@min(z + 2, bzn)) |zz| for (@max(y, 1) - 1..@min(y + 2, byn)) |yy| for (@max(x, 1) - 1..@min(x + 2, bxn)) |xx| {
                if (active.isSet(grid.blockIndex(xx, yy, zz))) break :blk true;
            };
            break :blk false;
        };
        if (hit) near.set(grid.blockIndex(x, y, z));
    };

    const nx: usize = bxn * block;
    const ny: usize = byn * block;
    const plane = (nx + 1) * (ny + 1);
    const cell_plane = nx * ny;
    const layer = Layer{
        .nx = nx,
        .ny = ny,
        .vals = try a.alloc(f32, plane * side),
        .ids = try a.alloc(u32, cell_plane * side),
    };
    defer a.free(layer.vals);
    defer a.free(layer.ids);
    const prev_top = try a.alloc(f32, plane);
    defer a.free(prev_top);
    @memset(layer.ids, none);

    var batch: std.ArrayList([4]u32) = .empty;
    defer batch.deinit(a);
    var batch_vals: std.ArrayList(f32) = .empty;
    defer batch_vals.deinit(a);
    var pending: std.ArrayList(mesher.CellIn) = .empty;
    defer pending.deinit(a);

    for (0..bzn) |bz| {
        if (bz > 0) {
            @memcpy(layer.ids[0..cell_plane], layer.ids[block * cell_plane ..][0..cell_plane]);
        } else {
            @memset(layer.ids[0..cell_plane], none);
        }
        @memset(layer.ids[cell_plane..], none);

        batch.clearRetainingCapacity();
        for (0..byn) |by| for (0..bxn) |bx| {
            const bi = grid.blockIndex(bx, by, bz);
            if (!near.isSet(bi)) continue;
            if (active.isSet(bi)) {
                try batch.append(a, .{ @intCast(bx), @intCast(by), @intCast(bz), 0 });
                continue;
            }
            for (0..side) |lz| for (0..side) |ly| for (0..side) |lx| {
                layer.valPtr(bx * block + lx, by * block + ly, lz).* = coarse[bi];
            };
        };

        try batch_vals.resize(a, batch.items.len * block_points);
        try job.evalBlocks(grid, iso, side, 0, batch.items, batch_vals.items, 0, 0);
        for (batch.items, 0..) |b, k| {
            const src = batch_vals.items[k * block_points ..][0..block_points];
            for (0..side) |lz| for (0..side) |ly| for (0..side) |lx| {
                layer.valPtr(b[0] * block + lx, b[1] * block + ly, lz).* = src[lx + side * (ly + side * lz)];
            };
        }

        if (bz > 0) {
            for (0..byn) |by| for (0..bxn) |bx| {
                if (!near.isSet(grid.blockIndex(bx, by, bz - 1))) continue;
                for (0..side) |ly| {
                    const row = (bx * block) + (nx + 1) * (by * block + ly);
                    @memcpy(layer.vals[row..][0..side], prev_top[row..][0..side]);
                }
            };
        }

        pending.clearRetainingCapacity();
        const base: u32 = @intCast(mesh.vert_count);
        for (0..byn) |by| for (0..bxn) |bx| {
            if (!near.isSet(grid.blockIndex(bx, by, bz))) continue;
            for (0..block) |lz| for (by * block..(by + 1) * block) |j| for (bx * block..(bx + 1) * block) |i| {
                var c: [8]f32 = undefined;
                var inside: u32 = 0;
                for (0..8) |corner| {
                    c[corner] = layer.val(i + (corner & 1), j + ((corner >> 1) & 1), lz + (corner >> 2));
                    if (c[corner] < 0) inside += 1;
                }
                if (inside == 0 or inside == 8) continue;
                layer.ids[i + nx * (j + ny * (lz + 1))] = base + @as(u32, @intCast(pending.items.len));
                const k = bz * block + lz;
                try pending.append(a, .{
                    .origin = .{
                        grid.origin[0] + @as(f32, @floatFromInt(i)) * grid.cell,
                        grid.origin[1] + @as(f32, @floatFromInt(j)) * grid.cell,
                        grid.origin[2] + @as(f32, @floatFromInt(k)) * grid.cell,
                        0,
                    },
                    .corners = c,
                });
            };
        };

        for (0..byn) |by| for (0..bxn) |bx| {
            if (!near.isSet(grid.blockIndex(bx, by, bz))) continue;
            for (0..block) |lz| for (by * block..(by + 1) * block) |j| for (bx * block..(bx + 1) * block) |i| {
                const has_below = bz > 0 or lz > 0;
                const v0 = layer.val(i, j, lz);
                const in0 = v0 < 0;
                if (i < nx and has_below and j >= 1 and j < ny and in0 != (layer.val(i + 1, j, lz) < 0)) {
                    try emitQuad(a, mesh, .{
                        layer.id(i, j - 1, lz),
                        layer.id(i, j, lz),
                        layer.id(i, j, lz + 1),
                        layer.id(i, j - 1, lz + 1),
                    }, in0, settings.count_only);
                }
                if (j < ny and has_below and i >= 1 and i < nx and in0 != (layer.val(i, j + 1, lz) < 0)) {
                    try emitQuad(a, mesh, .{
                        layer.id(i - 1, j, lz),
                        layer.id(i - 1, j, lz + 1),
                        layer.id(i, j, lz + 1),
                        layer.id(i, j, lz),
                    }, in0, settings.count_only);
                }
                if (i >= 1 and i < nx and j >= 1 and j < ny and in0 != (layer.val(i, j, lz + 1) < 0)) {
                    try emitQuad(a, mesh, .{
                        layer.id(i - 1, j - 1, lz + 1),
                        layer.id(i, j - 1, lz + 1),
                        layer.id(i, j, lz + 1),
                        layer.id(i - 1, j, lz + 1),
                    }, in0, settings.count_only);
                }
            };
        };

        mesh.vert_count += pending.items.len;
        if (!settings.count_only) try refine(job, grid, iso, settings, pending.items, mesh);

        @memcpy(prev_top, layer.vals[block * plane ..][0..plane]);
        try job.report(0.05 + 0.8 * @as(f32, @floatFromInt(bz + 1)) / @as(f32, @floatFromInt(bzn)));
    }
}

fn refine(job: *Job, grid: Grid, iso: f32, settings: Settings, cells: []const mesher.CellIn, mesh: *Mesh) !void {
    const a = job.allocator;
    var out: std.ArrayList(mesher.VertOut) = .empty;
    defer out.deinit(a);
    try mesh.positions.ensureUnusedCapacity(a, cells.len);
    try mesh.normals.ensureUnusedCapacity(a, cells.len);
    if (settings.colors) try mesh.colors.ensureUnusedCapacity(a, cells.len);

    var start: usize = 0;
    while (start < cells.len) {
        const n = job.vert_pacer.take(cells.len - start);
        try out.resize(a, n);
        const t0 = nowMs();
        try job.gpu.run(job.ctx, job.fractal.bind_group, .verts, .{
            .origin = grid.origin,
            .cell = grid.cell,
            .iso = iso,
            .count = n,
            .sharp = settings.sharpness,
            .color_on = if (settings.colors) 1 else 0,
        }, std.mem.sliceAsBytes(cells[start..][0..n]), std.mem.sliceAsBytes(out.items), n);
        job.vert_pacer.observe(nowMs() - t0, n);
        for (out.items) |v| {
            mesh.positions.appendAssumeCapacity(v.pos[0..3].*);
            mesh.normals.appendAssumeCapacity(v.normal[0..3].*);
            if (settings.colors) mesh.colors.appendAssumeCapacity(v.color[0..3].*);
        }
        start += n;
    }
}

fn findRoot(parent: []u32, v: u32) u32 {
    var x = v;
    while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
    }
    return x;
}

fn keepPieces(a: std.mem.Allocator, mesh: *const Mesh, min_quads: u32) !std.DynamicBitSetUnmanaged {
    var keep = try std.DynamicBitSetUnmanaged.initFull(a, mesh.quads.items.len);
    errdefer keep.deinit(a);
    if (min_quads <= 1) return keep;

    const parent = try a.alloc(u32, mesh.positions.items.len);
    defer a.free(parent);
    for (parent, 0..) |*p, i| p.* = @intCast(i);
    for (mesh.quads.items) |q| {
        const r0 = findRoot(parent, q[0]);
        for (q[1..]) |v| {
            const r = findRoot(parent, v);
            if (r != r0) parent[r] = r0;
        }
    }
    const counts = try a.alloc(u32, parent.len);
    defer a.free(counts);
    @memset(counts, 0);
    for (mesh.quads.items) |q| counts[findRoot(parent, q[0])] += 1;
    for (mesh.quads.items, 0..) |q, i| {
        if (counts[findRoot(parent, q[0])] < min_quads) keep.unset(i);
    }
    return keep;
}

fn dist2(a: [3]f32, b: [3]f32) f32 {
    const d = [3]f32{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
    return d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
}

const Written = struct { verts: usize, tris: usize };

fn quadTris(p: []const [3]f32, q: [4]u32) [2][3]u32 {
    return if (dist2(p[q[0]], p[q[2]]) <= dist2(p[q[1]], p[q[3]]))
        .{ .{ q[0], q[1], q[2] }, .{ q[0], q[2], q[3] } }
    else
        .{ .{ q[0], q[1], q[3] }, .{ q[1], q[2], q[3] } };
}

const Output = struct {
    job: *Job,
    mesh: *const Mesh,
    keep: *const std.DynamicBitSetUnmanaged,
    remap: []const u32,
    verts: u32,
    tris: usize,
    colors: bool,
    total: f32,
    done: usize = 0,

    const tick = 1 << 16;

    fn step(self: *Output, n: usize) !void {
        const before = self.done / tick;
        self.done += n;
        if (self.done / tick != before) try self.job.report(@as(f32, @floatFromInt(self.done)) / self.total);
    }
};

fn writeObjBody(w: *std.Io.Writer, o: *Output) !void {
    const m = o.mesh;
    try w.print("# NumericDream mesh export\n# {d} vertices, {d} triangles\n", .{ o.verts, o.tris });
    for (m.positions.items, 0..) |p, i| {
        if (o.remap[i] == none) continue;
        if (o.colors) {
            const c = m.colors.items[i];
            try w.print("v {d:.6} {d:.6} {d:.6} {d:.4} {d:.4} {d:.4}\n", .{ p[0], p[1], p[2], c[0], c[1], c[2] });
        } else {
            try w.print("v {d:.6} {d:.6} {d:.6}\n", .{ p[0], p[1], p[2] });
        }
        try o.step(1);
    }
    for (m.normals.items, 0..) |n, i| {
        if (o.remap[i] == none) continue;
        try w.print("vn {d:.4} {d:.4} {d:.4}\n", .{ n[0], n[1], n[2] });
        try o.step(1);
    }
    var iter = o.keep.iterator(.{});
    while (iter.next()) |qi| {
        for (quadTris(m.positions.items, m.quads.items[qi])) |t| {
            const x = o.remap[t[0]] + 1;
            const y = o.remap[t[1]] + 1;
            const z = o.remap[t[2]] + 1;
            try w.print("f {d}//{d} {d}//{d} {d}//{d}\n", .{ x, x, y, y, z, z });
        }
        try o.step(4);
    }
}

fn putF32(dst: *[4]u8, v: f32) void {
    std.mem.writeInt(u32, dst, @bitCast(v), .little);
}

fn writePlyBody(w: *std.Io.Writer, o: *Output) !void {
    const m = o.mesh;
    try w.print(
        "ply\nformat binary_little_endian 1.0\ncomment NumericDream mesh export\nelement vertex {d}\n" ++
            "property float x\nproperty float y\nproperty float z\n" ++
            "property float nx\nproperty float ny\nproperty float nz\n",
        .{o.verts},
    );
    if (o.colors) try w.writeAll("property uchar red\nproperty uchar green\nproperty uchar blue\n");
    try w.print("element face {d}\nproperty list uchar uint vertex_indices\nend_header\n", .{o.tris});

    var rec: [27]u8 = undefined;
    const rec_len: usize = if (o.colors) 27 else 24;
    for (m.positions.items, 0..) |p, i| {
        if (o.remap[i] == none) continue;
        const n = m.normals.items[i];
        for (0..3) |a| {
            putF32(rec[a * 4 ..][0..4], p[a]);
            putF32(rec[12 + a * 4 ..][0..4], n[a]);
        }
        if (o.colors) {
            for (m.colors.items[i], 0..) |c, a| rec[24 + a] = @intFromFloat(@round(std.math.clamp(c, 0, 1) * 255));
        }
        try w.writeAll(rec[0..rec_len]);
        try o.step(2);
    }

    var face: [13]u8 = undefined;
    face[0] = 3;
    var iter = o.keep.iterator(.{});
    while (iter.next()) |qi| {
        for (quadTris(m.positions.items, m.quads.items[qi])) |t| {
            for (t, 0..) |v, k| std.mem.writeInt(u32, face[1 + k * 4 ..][0..4], o.remap[v], .little);
            try w.writeAll(&face);
        }
        try o.step(4);
    }
}

fn writeMesh(job: *Job, path: []const u8, format: file_dialog.MeshFormat, mesh: *const Mesh, keep: *const std.DynamicBitSetUnmanaged, with_colors: bool) !Written {
    const a = job.allocator;
    const remap = try a.alloc(u32, mesh.positions.items.len);
    defer a.free(remap);
    @memset(remap, none);
    var iter = keep.iterator(.{});
    while (iter.next()) |qi| {
        for (mesh.quads.items[qi]) |v| remap[v] = 0;
    }
    var used: u32 = 0;
    for (remap) |*r| {
        if (r.* == none) continue;
        r.* = used;
        used += 1;
    }
    const tris = keep.count() * 2;

    const io = std.Io.Threaded.global_single_threaded.io();
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [1 << 16]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;

    var out = Output{
        .job = job,
        .mesh = mesh,
        .keep = keep,
        .remap = remap,
        .verts = used,
        .tris = tris,
        .colors = with_colors,
        .total = @floatFromInt(@max(@as(usize, used) * 2 + tris * 2, 1)),
    };
    switch (format) {
        .obj => try writeObjBody(w, &out),
        .ply => try writePlyBody(w, &out),
    }
    try w.flush();
    return .{ .verts = used, .tris = tris };
}

fn searchBox(instances: []const FractalInstanceState) struct { center: Vec3, half: f32 } {
    if (instances.len == 0) return .{ .center = .{ .x = 0, .y = 0, .z = 0 }, .half = 4 };
    var c = Vec3{ .x = 0, .y = 0, .z = 0 };
    for (instances) |inst| {
        c.x += inst.offset.x;
        c.y += inst.offset.y;
        c.z += inst.offset.z;
    }
    const inv = 1.0 / @as(f32, @floatFromInt(instances.len));
    c = .{ .x = c.x * inv, .y = c.y * inv, .z = c.z * inv };
    var half: f32 = 0;
    for (instances) |inst| {
        const spread = @max(@abs(inst.offset.x - c.x), @max(@abs(inst.offset.y - c.y), @abs(inst.offset.z - c.z)));
        const s = inst.scale_uniform * @max(inst.scale.x, @max(inst.scale.y, inst.scale.z));
        half = @max(half, spread + 4 * s);
    }
    return .{ .center = c, .half = half };
}

fn startJob(
    allocator: std.mem.Allocator,
    gpu_ctx: *Context,
    fractal: *FractalRenderer,
    scene: Scene,
    progress: RenderProgress,
) !Job {
    export_image.cancel_requested = false;
    scene_state.drainPendingCompile(fractal, allocator);
    const n = scene.instances.len;
    const gpu = try fractal.meshGpu(gpu_ctx, allocator, scene_state.buildFormulaSources(scene.instances, n), scene_state.buildMixinSources(scene.instances, n));
    const uniforms = export_image.buildUniforms(scene.instances, &.{}, &.{}, scene.warps, &.{}, scene.camera, scene.camera.basis(), 1, 100, 0, .{}, .{}, .{}, 1, 1, 1);
    fractal.updateUniforms(gpu_ctx, uniforms);
    return .{ .allocator = allocator, .ctx = gpu_ctx, .fractal = fractal, .gpu = gpu, .progress = progress };
}

fn failStatus(buf: []u8, what: []const u8, err: anyerror) [:0]const u8 {
    if (err == error.RenderCancelled) return std.fmt.bufPrintSentinel(buf, "{s} canceled.", .{what}, 0) catch "Canceled.";
    if (err == error.ShaderCompileFailed or err == error.PipelineCreationFailed) {
        std.log.err("mesh shader: {s}", .{webgpu_context.g_error_sink.message()});
    }
    return std.fmt.bufPrintSentinel(buf, "{s} failed: {s}", .{ what, @errorName(err) }, 0) catch "Failed.";
}

fn resolutionOf(state: *const MeshExportState) u32 {
    return @intFromFloat(std.math.clamp(state.resolution, 16, 4096));
}

fn settingsOf(state: *const MeshExportState, count_only: bool) Settings {
    return .{ .iso_scale = state.iso_scale, .sharpness = state.sharpness, .colors = state.vertex_colors, .count_only = count_only };
}

fn fmtCount(buf: []u8, n: f64) []const u8 {
    if (n >= 1e6) return std.fmt.bufPrint(buf, "{d:.1}M", .{n / 1e6}) catch "?";
    if (n >= 1e3) return std.fmt.bufPrint(buf, "{d:.0}k", .{n / 1e3}) catch "?";
    return std.fmt.bufPrint(buf, "{d:.0}", .{n}) catch "?";
}

pub fn estimate(state: *MeshExportState, allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, scene: Scene, overlay: *ProgressOverlay) void {
    var pc = export_image.ProgressCtx{ .overlay = overlay, .gpu_ctx = gpu_ctx };
    var job = startJob(allocator, gpu_ctx, fractal, scene, .{ .callback = export_image.onProgress, .userdata = &pc, .cancel_flag = &export_image.cancel_requested }) catch |err| {
        state.info = failStatus(&state.info_buf, "Estimate", err);
        return;
    };
    const res = resolutionOf(state);
    const low = @min(res, estimate_resolution);
    var mesh = Mesh{};
    defer mesh.deinit(allocator);
    buildMesh(&job, Grid.init(state.center, state.size, low), settingsOf(state, true), &mesh) catch |err| {
        state.info = failStatus(&state.info_buf, "Estimate", err);
        return;
    };
    const k = std.math.pow(f64, @as(f64, @floatFromInt(res)) / @as(f64, @floatFromInt(low)), 2);
    const tris = @as(f64, @floatFromInt(mesh.quad_count)) * 2 * k;
    const verts = @as(f64, @floatFromInt(mesh.vert_count)) * k;
    const mib = 1024 * 1024;
    const obj_vert: f64 = if (state.vertex_colors) 58 + 24 else 34 + 24;
    const ply_vert: f64 = if (state.vertex_colors) 27 else 24;
    const obj_mb = (verts * obj_vert + tris * 40) / mib;
    const ply_mb = (verts * ply_vert + tris * 13) / mib;
    var tb: [16]u8 = undefined;
    state.info = std.fmt.bufPrintSentinel(&state.info_buf, "At least ~{s} triangles: ~{d:.0} MB as PLY, ~{d:.0} MB as OBJ", .{ fmtCount(&tb, tris), ply_mb, obj_mb }, 0) catch "";
}

pub fn autoFit(state: *MeshExportState, allocator: std.mem.Allocator, gpu_ctx: *Context, fractal: *FractalRenderer, scene: Scene, overlay: *ProgressOverlay) void {
    var pc = export_image.ProgressCtx{ .overlay = overlay, .gpu_ctx = gpu_ctx };
    var job = startJob(allocator, gpu_ctx, fractal, scene, .{ .callback = export_image.onProgress, .userdata = &pc, .cancel_flag = &export_image.cancel_requested }) catch |err| {
        state.info = failStatus(&state.info_buf, "Auto-fit", err);
        return;
    };
    const box = searchBox(scene.instances);
    const full = Vec3{ .x = 2 * box.half, .y = 2 * box.half, .z = 2 * box.half };
    const grid = Grid.init(box.center, full, fit_resolution);
    const coarse = job.coarsePass(grid, 0, 1) catch |err| {
        state.info = failStatus(&state.info_buf, "Auto-fit", err);
        return;
    };
    defer allocator.free(coarse);

    const reach = block_half_diag * grid.cell;
    var lo = [3]usize{ std.math.maxInt(usize), std.math.maxInt(usize), std.math.maxInt(usize) };
    var hi = [3]usize{ 0, 0, 0 };
    var any = false;
    for (0..grid.blocks[2]) |z| for (0..grid.blocks[1]) |y| for (0..grid.blocks[0]) |x| {
        if (coarse[grid.blockIndex(x, y, z)] > reach) continue;
        any = true;
        const b = [3]usize{ x, y, z };
        for (0..3) |axis| {
            lo[axis] = @min(lo[axis], b[axis]);
            hi[axis] = @max(hi[axis], b[axis]);
        }
    };
    if (!any) {
        state.info = "Auto-fit found no surface near the fractals.";
        return;
    }
    const span = @as(f32, @floatFromInt(block)) * grid.cell;
    var clipped = false;
    var c: [3]f32 = undefined;
    var s: [3]f32 = undefined;
    for (0..3) |axis| {
        if (lo[axis] == 0 or hi[axis] + 1 == grid.blocks[axis]) clipped = true;
        const a0 = grid.origin[axis] + @as(f32, @floatFromInt(lo[axis])) * span;
        const a1 = grid.origin[axis] + @as(f32, @floatFromInt(hi[axis] + 1)) * span;
        c[axis] = 0.5 * (a0 + a1);
        s[axis] = a1 - a0;
    }
    state.center = .{ .x = c[0], .y = c[1], .z = c[2] };
    state.size = .{ .x = s[0], .y = s[1], .z = s[2] };
    state.info = if (clipped)
        std.fmt.bufPrintSentinel(&state.info_buf, "Surface reaches the {d:.1}-unit search box -- probably tiling forever. Set bounds by hand.", .{2 * box.half}, 0) catch ""
    else
        "Bounds fitted to the surface.";
}

pub fn exportMesh(state: *MeshExportState, allocator: std.mem.Allocator, window: *sdl.SDL_Window, gpu_ctx: *Context, fractal: *FractalRenderer, scene: Scene, overlay: *ProgressOverlay) void {
    var path_buf: [export_image.max_path_len]u8 = undefined;
    const saved = file_dialog.pickSaveMeshFile(window, &path_buf) orelse {
        state.status = "Export canceled.";
        return;
    };
    const started = sdl.SDL_GetTicks();

    var pc = export_image.ProgressCtx{ .overlay = overlay, .gpu_ctx = gpu_ctx };
    const cancel = &export_image.cancel_requested;
    var job = startJob(allocator, gpu_ctx, fractal, scene, .{ .callback = export_image.onProgress, .userdata = &pc, .range_end = 0.85, .cancel_flag = cancel }) catch |err| {
        state.status = failStatus(&state.status_buf, "Mesh export", err);
        return;
    };

    var mesh = Mesh{};
    defer mesh.deinit(allocator);
    buildMesh(&job, Grid.init(state.center, state.size, resolutionOf(state)), settingsOf(state, false), &mesh) catch |err| {
        state.status = failStatus(&state.status_buf, "Mesh export", err);
        return;
    };
    if (mesh.quads.items.len == 0) {
        state.status = "No surface inside the bounds -- nothing written.";
        return;
    }

    var keep = keepPieces(allocator, &mesh, @intFromFloat(@max(state.min_piece, 0))) catch |err| {
        state.status = failStatus(&state.status_buf, "Mesh export", err);
        return;
    };
    defer keep.deinit(allocator);
    const dropped = mesh.quads.items.len - keep.count();

    job.progress.range_start = 0.85;
    job.progress.range_end = 1.0;
    const written = writeMesh(&job, path_buf[0..saved.len], saved.format, &mesh, &keep, state.vertex_colors) catch |err| {
        state.status = failStatus(&state.status_buf, "Writing mesh", err);
        return;
    };

    var vb: [16]u8 = undefined;
    var tb: [16]u8 = undefined;
    const secs = @as(f32, @floatFromInt(sdl.SDL_GetTicks() -| started)) / 1000.0;
    state.status = std.fmt.bufPrintSentinel(&state.status_buf, "Saved {s}: {s} vertices, {s} triangles in {d:.1}s ({d} dust quads dropped).", .{
        if (saved.format == .ply) "PLY" else "OBJ",
        fmtCount(&vb, @floatFromInt(written.verts)),
        fmtCount(&tb, @floatFromInt(written.tris)),
        secs,
        dropped,
    }, 0) catch "Saved.";
}
