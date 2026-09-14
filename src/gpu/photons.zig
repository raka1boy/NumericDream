const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const pool_per_bucket: u32 = 4;
pub const min_pool_log2: u32 = 19;
pub const max_pool_log2: u32 = 21;

pub const min_cell_cap: u32 = 8;
pub const max_cell_cap: u32 = 512;

pub const volume_words: u32 = 12;

pub const fixed_counts_per_deposit: f32 = 65536;

pub const photon_stride: u32 = 48;

pub const stat_count: u32 = 5;

pub const TraceStats = extern struct {
    pool_used: u32 = 0,
    dropped_no_bucket: u32 = 0,
    dropped_no_pool: u32 = 0,
    cells_surface: u32 = 0,
    cells_volume: u32 = 0,

    pub fn occupiedCells(self: TraceStats) u32 {
        return self.cells_surface +| self.cells_volume;
    }
};

pub const workgroup_dim: u32 = 64;

pub const min_grid_log2: u32 = 12;
pub const max_grid_log2: u32 = 22;
pub const default_grid_log2: u32 = 20;

pub const paths_per_submit: u32 = 1 << 14;

pub fn fixedUnitFor(uniforms: anytype, paths: u32, cell: f32) f32 {
    const light_count: usize = @intFromFloat(@max(uniforms.light_count, 0));
    const sky_emits = uniforms.sky.photons > 0.5 and uniforms.sky.intensity > 0;
    const emitters: u32 = @as(u32, @intCast(@min(light_count, uniforms.lights.len))) + @as(u32, if (sky_emits) 1 else 0);
    if (emitters == 0) return 1;
    const per_emitter: f32 = @floatFromInt(@max(paths / emitters, 1));
    const extent: f32 = @max(uniforms.max_dist, 1e-3);

    var flux_max: f32 = 0;
    for (uniforms.lights[0..@min(light_count, uniforms.lights.len)]) |*light| {
        const intensity = @max(light.color[0], @max(light.color[1], light.color[2])) * light.brightness;
        const flux = if (light.light_type < 0.5)
            4.0 * std.math.pi * intensity
        else if (light.light_type < 1.5)
            std.math.pi * extent * extent * intensity
        else
            std.math.pi * intensity;
        flux_max = @max(flux_max, flux);
    }
    if (sky_emits) {
        flux_max = @max(flux_max, std.math.pi * 4.0 * std.math.pi * extent * extent * uniforms.sky.intensity);
    }
    const per_photon = flux_max / per_emitter;
    const unit = per_photon * cell / fixed_counts_per_deposit;
    return if (unit > 0 and std.math.isFinite(unit)) unit else 1;
}

pub fn clampGridLog2(log2: u32) u32 {
    return std.math.clamp(log2, min_grid_log2, max_grid_log2);
}

pub fn poolFor(log2: u32) u32 {
    const buckets: u64 = @as(u64, 1) << @intCast(clampGridLog2(log2));
    return @intCast(std.math.clamp(
        buckets * pool_per_bucket,
        @as(u64, 1) << @intCast(min_pool_log2),
        @as(u64, 1) << @intCast(max_pool_log2),
    ));
}

pub const PhotonMap = struct {
    render_layout: wgpu.WGPUBindGroupLayout,
    compute_layout: wgpu.WGPUBindGroupLayout,

    cells: wgpu.WGPUBuffer = null,
    counts: wgpu.WGPUBuffer = null,
    keys: wgpu.WGPUBuffer = null,
    offsets: wgpu.WGPUBuffer = null,
    cursor: wgpu.WGPUBuffer = null,
    stats: wgpu.WGPUBuffer = null,
    stats_read: wgpu.WGPUBuffer = null,
    volume: wgpu.WGPUBuffer = null,
    render_bind_group: wgpu.WGPUBindGroup = null,
    compute_bind_group: wgpu.WGPUBindGroup = null,

    buckets: u32 = 0,
    grid_log2: u32 = 0,

    valid: bool = false,

    centre: [3]f32 = .{ 0, 0, 0 },

    last_trace_ms: u64 = 0,
    last_paths: u32 = 0,

    last_stats: TraceStats = .{},
    cell_cap_surface: u32 = min_cell_cap,

    stored_cap_surface: u32 = min_cell_cap,

    stored_volume_scale: f32 = 1,

    stored_fixed_unit: f32 = 1,

    stored_hash_salt: f32 = 0,

    pub fn init(ctx: *const Context) !PhotonMap {
        const render_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            storageEntry(0, wgpu.WGPUShaderStage_Fragment, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
            storageEntry(1, wgpu.WGPUShaderStage_Fragment, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
            storageEntry(2, wgpu.WGPUShaderStage_Fragment, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
            storageEntry(3, wgpu.WGPUShaderStage_Fragment, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
            storageEntry(10, wgpu.WGPUShaderStage_Fragment, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
        };
        const render_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("photon read bind group layout"),
            .entryCount = render_entries.len,
            .entries = &render_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(render_layout);

        const compute_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            storageEntry(4, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(5, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(6, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(7, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(8, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(9, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
            storageEntry(11, wgpu.WGPUShaderStage_Compute, wgpu.WGPUBufferBindingType_Storage),
        };
        const compute_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("photon write bind group layout"),
            .entryCount = compute_entries.len,
            .entries = &compute_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;

        return .{ .render_layout = render_layout, .compute_layout = compute_layout };
    }

    fn storageEntry(binding: u32, visibility: wgpu.WGPUShaderStage, kind: wgpu.WGPUBufferBindingType) wgpu.WGPUBindGroupLayoutEntry {
        return .{
            .nextInChain = null,
            .binding = binding,
            .visibility = visibility,
            .bindingArraySize = 0,
            .buffer = .{
                .nextInChain = null,
                .type = kind,
                .hasDynamicOffset = 0,
                .minBindingSize = 0,
            },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
    }

    pub fn deinit(self: *PhotonMap) void {
        self.releaseBuffers();
        wgpu.wgpuBindGroupLayoutRelease(self.render_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.compute_layout);
    }

    fn releaseBuffers(self: *PhotonMap) void {
        if (self.render_bind_group != null) wgpu.wgpuBindGroupRelease(self.render_bind_group);
        if (self.compute_bind_group != null) wgpu.wgpuBindGroupRelease(self.compute_bind_group);
        if (self.cells != null) wgpu.wgpuBufferRelease(self.cells);
        if (self.counts != null) wgpu.wgpuBufferRelease(self.counts);
        if (self.keys != null) wgpu.wgpuBufferRelease(self.keys);
        if (self.offsets != null) wgpu.wgpuBufferRelease(self.offsets);
        if (self.cursor != null) wgpu.wgpuBufferRelease(self.cursor);
        if (self.stats != null) wgpu.wgpuBufferRelease(self.stats);
        if (self.stats_read != null) wgpu.wgpuBufferRelease(self.stats_read);
        if (self.volume != null) wgpu.wgpuBufferRelease(self.volume);
        self.render_bind_group = null;
        self.compute_bind_group = null;
        self.cells = null;
        self.counts = null;
        self.keys = null;
        self.offsets = null;
        self.cursor = null;
        self.stats = null;
        self.stats_read = null;
        self.volume = null;
        self.buckets = 0;
        self.grid_log2 = 0;
        self.valid = false;
    }

    pub fn isAllocated(self: *const PhotonMap) bool {
        return self.cells != null;
    }

    pub fn bytes(self: *const PhotonMap) u64 {
        if (!self.isAllocated()) return 0;
        const b: u64 = self.buckets;
        return @as(u64, self.poolPhotons()) * photon_stride + b * (16 + volume_words * 4);
    }

    pub fn ensureSize(self: *PhotonMap, ctx: *const Context, grid_log2: u32) bool {
        const log2 = clampGridLog2(grid_log2);
        if (self.cells != null and self.grid_log2 == log2) return true;

        const buckets: u32 = @as(u32, 1) << @intCast(log2);
        const cells_size: u64 = @as(u64, poolFor(log2)) * photon_stride;
        const counts_size: u64 = @as(u64, buckets) * 4;
        const stats_size: u64 = stat_count * 4;
        const volume_size: u64 = @as(u64, buckets) * volume_words * 4;
        const largest = @max(cells_size, volume_size);
        if (largest > ctx.limits.maxStorageBufferBindingSize or largest > ctx.limits.maxBufferSize) {
            return self.cells != null;
        }

        const Slot = struct { label: [:0]const u8, size: u64, usage: wgpu.WGPUBufferUsage };
        const slots = [_]Slot{
            .{ .label = "photon pool", .size = cells_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon bucket counts", .size = counts_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon bucket keys", .size = counts_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon bucket offsets", .size = counts_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon bucket cursor", .size = counts_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon trace stats", .size = stats_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_CopySrc },
            .{ .label = "photon trace stats readback", .size = stats_size, .usage = wgpu.WGPUBufferUsage_MapRead | wgpu.WGPUBufferUsage_CopyDst },
            .{ .label = "photon fog sums", .size = volume_size, .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst },
        };

        var made: [slots.len]wgpu.WGPUBuffer = @splat(null);
        var ok = true;
        for (slots, 0..) |slot, i| {
            made[i] = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
                .nextInChain = null,
                .label = sv(slot.label),
                .usage = slot.usage,
                .size = slot.size,
                .mappedAtCreation = 0,
            });
            if (made[i] == null) {
                ok = false;
                break;
            }
        }

        const cells = made[0];
        const counts = made[1];
        const keys = made[2];
        const offsets = made[3];
        const cursor = made[4];
        const stats = made[5];
        const stats_read = made[6];
        const volume = made[7];

        var render_bind_group: wgpu.WGPUBindGroup = null;
        var compute_bind_group: wgpu.WGPUBindGroup = null;
        if (ok) {
            render_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
                .nextInChain = null,
                .label = sv("photon read bind group"),
                .layout = self.render_layout,
                .entryCount = 5,
                .entries = &[_]wgpu.WGPUBindGroupEntry{
                    bufferEntry(0, cells, cells_size),
                    bufferEntry(1, counts, counts_size),
                    bufferEntry(2, keys, counts_size),
                    bufferEntry(3, offsets, counts_size),
                    bufferEntry(10, volume, volume_size),
                },
            });
            compute_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
                .nextInChain = null,
                .label = sv("photon write bind group"),
                .layout = self.compute_layout,
                .entryCount = 7,
                .entries = &[_]wgpu.WGPUBindGroupEntry{
                    bufferEntry(4, cells, cells_size),
                    bufferEntry(5, counts, counts_size),
                    bufferEntry(6, keys, counts_size),
                    bufferEntry(7, offsets, counts_size),
                    bufferEntry(8, cursor, counts_size),
                    bufferEntry(9, stats, stats_size),
                    bufferEntry(11, volume, volume_size),
                },
            });
            ok = render_bind_group != null and compute_bind_group != null;
        }

        if (!ok) {
            if (render_bind_group != null) wgpu.wgpuBindGroupRelease(render_bind_group);
            if (compute_bind_group != null) wgpu.wgpuBindGroupRelease(compute_bind_group);
            for (made) |b| {
                if (b != null) wgpu.wgpuBufferRelease(b);
            }
            return self.cells != null;
        }

        self.releaseBuffers();
        self.cells = cells;
        self.counts = counts;
        self.keys = keys;
        self.offsets = offsets;
        self.cursor = cursor;
        self.stats = stats;
        self.stats_read = stats_read;
        self.volume = volume;
        self.render_bind_group = render_bind_group;
        self.compute_bind_group = compute_bind_group;
        self.buckets = buckets;
        self.grid_log2 = log2;
        self.valid = false;
        self.last_stats = .{};
        self.cell_cap_surface = min_cell_cap;
        self.stored_cap_surface = min_cell_cap;
        return true;
    }

    pub fn poolPhotons(self: *const PhotonMap) u32 {
        if (!self.isAllocated()) return 0;
        return poolFor(self.grid_log2);
    }

    fn capFor(pool_share: u64, occupied: u32) u32 {
        if (occupied == 0) return max_cell_cap;
        const share = (pool_share * 7 / 8) / occupied;
        return @intCast(std.math.clamp(share, min_cell_cap, max_cell_cap));
    }

    pub fn noteStats(self: *PhotonMap, s: TraceStats) void {
        self.last_stats = s;
        self.cell_cap_surface = capFor(self.poolPhotons(), s.cells_surface);
    }

    pub fn wantsRecap(self: *const PhotonMap) bool {
        if (!self.valid) return false;
        return movedFar(self.cell_cap_surface, self.stored_cap_surface);
    }

    fn movedFar(now: u32, ran_at_raw: u32) bool {
        const ran_at = @max(ran_at_raw, 1);
        return now * 4 > ran_at * 5 or now * 5 < ran_at * 4;
    }

    fn bufferEntry(binding: u32, buffer: wgpu.WGPUBuffer, size: u64) wgpu.WGPUBindGroupEntry {
        return .{
            .nextInChain = null,
            .binding = binding,
            .buffer = buffer,
            .offset = 0,
            .size = size,
            .sampler = null,
            .textureView = null,
        };
    }

    pub fn invalidate(self: *PhotonMap) void {
        self.valid = false;
    }

    pub fn drift(self: *const PhotonMap, camera_pos: [3]f32) f32 {
        return webgpu_context.dist3(camera_pos, self.centre);
    }
};
