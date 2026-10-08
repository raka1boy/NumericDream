const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const max_systems = 2;

pub const header_words: u32 = 16;
pub const max_particles: u32 = 16384;
pub const record_words: u32 = 8;
pub const max_cells: u32 = 524288;
pub const inserts_per_particle: u32 = 8;
pub const records_base: u32 = header_words * max_systems;
pub const cells_base: u32 = records_base + max_systems * max_particles * record_words;
pub const index_base: u32 = cells_base + max_systems * max_cells * 2;
pub const total_words: u32 = index_base + max_systems * max_particles * inserts_per_particle;
pub const dist_cap: u32 = 10;

pub const hash_buckets: u32 = 16384;
pub const hash_words: u32 = 16;
pub const counter_words: u32 = 16;
const state_stride: u64 = 32;

pub const workgroup: u32 = 64;
pub const steps_per_submit: u32 = 16;

comptime {
    std.debug.assert(records_base == 32);
}

pub const SimParams = extern struct {
    center: [3]f32 = .{ 0, 0, 0 },
    count: f32 = 0,
    axis_u: [3]f32 = .{ 1, 0, 0 },
    spawn_radius: f32 = 0,
    axis_v: [3]f32 = .{ 0, 0, 1 },
    spawn_shape: f32 = 0,
    direction: [3]f32 = .{ 0, 1, 0 },
    velocity_mode: f32 = 0,
    extent: [2]f32 = .{ 1, 1 },
    speed_min: f32 = 0,
    speed_max: f32 = 0,
    spread: f32 = 0,
    size: f32 = 0.02,
    size_var: f32 = 0,
    seed: f32 = 0,
    emit_duration: f32 = 0,
    lifetime: f32 = 0,
    dt: f32 = 1.0 / 60.0,
    t: f32 = 0,
    kill_radius: f32 = 20,
    stop_scene: f32 = 1,
    stick: f32 = 1,
    strip_mode: f32 = 0,
    strip_span: f32 = 1,
    strip_offset: f32 = 0,
    system: f32 = 0,
    sim_cell: f32 = 0.04,
    steps_done: f32 = 0,
    r_insert: f32 = 0.02,
    insert_mult: f32 = 1,
    insert_add: f32 = 0,
};

comptime {
    std.debug.assert(@sizeOf(SimParams) == 160);
    std.debug.assert(@offsetOf(SimParams, "extent") == 64);
}

pub const Job = struct {
    params: SimParams,
    sim_key: u64,
    build_key: u64,
    target_steps: u32,
};

pub const Runtime = struct {
    has_sim: bool = false,
    sim_key: u64 = 0,
    steps: u32 = 0,
    has_build: bool = false,
    build_key: u64 = 0,
    build_steps: u32 = 0,
    generation: u32 = 0,
};

pub const ParticleGpu = struct {
    data: wgpu.WGPUBuffer,
    state_a: wgpu.WGPUBuffer,
    state_b: wgpu.WGPUBuffer,
    hash: wgpu.WGPUBuffer,
    counters: wgpu.WGPUBuffer,
    params: wgpu.WGPUBuffer,

    sim_layout: wgpu.WGPUBindGroupLayout,
    build_layout: wgpu.WGPUBindGroupLayout,
    empty_layout: wgpu.WGPUBindGroupLayout,

    sim_ab: wgpu.WGPUBindGroup,
    sim_ba: wgpu.WGPUBindGroup,
    build_a: wgpu.WGPUBindGroup,
    build_b: wgpu.WGPUBindGroup,
    empty_group: wgpu.WGPUBindGroup,

    runtime: [max_systems]Runtime = @splat(.{}),

    pub fn dataSize() u64 {
        return @as(u64, total_words) * 4;
    }

    fn stateSize() u64 {
        return @as(u64, max_systems) * max_particles * state_stride;
    }

    fn hashSize() u64 {
        return @as(u64, hash_buckets) * hash_words * 4;
    }

    fn countersSize() u64 {
        return @as(u64, max_systems) * counter_words * 4;
    }

    pub fn init(ctx: *const Context) !ParticleGpu {
        var self: ParticleGpu = undefined;
        self.runtime = @splat(.{});

        self.data = try makeBuffer(ctx, "particle data", dataSize(), wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst);
        errdefer wgpu.wgpuBufferRelease(self.data);
        self.state_a = try makeBuffer(ctx, "particle state A", stateSize(), wgpu.WGPUBufferUsage_Storage);
        errdefer wgpu.wgpuBufferRelease(self.state_a);
        self.state_b = try makeBuffer(ctx, "particle state B", stateSize(), wgpu.WGPUBufferUsage_Storage);
        errdefer wgpu.wgpuBufferRelease(self.state_b);
        self.hash = try makeBuffer(ctx, "particle contact hash", hashSize(), wgpu.WGPUBufferUsage_Storage);
        errdefer wgpu.wgpuBufferRelease(self.hash);
        self.counters = try makeBuffer(ctx, "particle counters", countersSize(), wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst);
        errdefer wgpu.wgpuBufferRelease(self.counters);
        self.params = try makeBuffer(ctx, "particle sim params", @sizeOf(SimParams), wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst);
        errdefer wgpu.wgpuBufferRelease(self.params);

        const ro = wgpu.WGPUBufferBindingType_ReadOnlyStorage;
        const rw = wgpu.WGPUBufferBindingType_Storage;
        const uni = wgpu.WGPUBufferBindingType_Uniform;
        const sim_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            layoutEntry(30, uni), layoutEntry(31, ro), layoutEntry(32, rw), layoutEntry(33, rw), layoutEntry(35, rw),
        };
        self.sim_layout = try makeLayout(ctx, "particle sim layout", &sim_entries);
        errdefer wgpu.wgpuBindGroupLayoutRelease(self.sim_layout);
        const build_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            layoutEntry(30, uni), layoutEntry(31, ro), layoutEntry(34, rw), layoutEntry(35, rw),
        };
        self.build_layout = try makeLayout(ctx, "particle build layout", &build_entries);
        errdefer wgpu.wgpuBindGroupLayoutRelease(self.build_layout);
        self.empty_layout = try makeLayout(ctx, "particle empty layout", &.{});
        errdefer wgpu.wgpuBindGroupLayoutRelease(self.empty_layout);

        const pb = entry(30, self.params, @sizeOf(SimParams));
        const hb = entry(33, self.hash, hashSize());
        const cb = entry(35, self.counters, countersSize());
        self.sim_ab = try makeGroup(ctx, self.sim_layout, &.{ pb, entry(31, self.state_a, stateSize()), entry(32, self.state_b, stateSize()), hb, cb });
        errdefer wgpu.wgpuBindGroupRelease(self.sim_ab);
        self.sim_ba = try makeGroup(ctx, self.sim_layout, &.{ pb, entry(31, self.state_b, stateSize()), entry(32, self.state_a, stateSize()), hb, cb });
        errdefer wgpu.wgpuBindGroupRelease(self.sim_ba);
        const db = entry(34, self.data, dataSize());
        self.build_a = try makeGroup(ctx, self.build_layout, &.{ pb, entry(31, self.state_a, stateSize()), db, cb });
        errdefer wgpu.wgpuBindGroupRelease(self.build_a);
        self.build_b = try makeGroup(ctx, self.build_layout, &.{ pb, entry(31, self.state_b, stateSize()), db, cb });
        errdefer wgpu.wgpuBindGroupRelease(self.build_b);
        self.empty_group = try makeGroup(ctx, self.empty_layout, &.{});
        return self;
    }

    pub fn deinit(self: *ParticleGpu) void {
        for ([_]wgpu.WGPUBindGroup{ self.sim_ab, self.sim_ba, self.build_a, self.build_b, self.empty_group }) |g| wgpu.wgpuBindGroupRelease(g);
        for ([_]wgpu.WGPUBindGroupLayout{ self.sim_layout, self.build_layout, self.empty_layout }) |l| wgpu.wgpuBindGroupLayoutRelease(l);
        for ([_]wgpu.WGPUBuffer{ self.data, self.state_a, self.state_b, self.hash, self.counters, self.params }) |b| wgpu.wgpuBufferRelease(b);
    }

    pub fn writeParams(self: *const ParticleGpu, ctx: *const Context, params: SimParams) void {
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.params, 0, &params, @sizeOf(SimParams));
    }

    pub fn resetBuildCounters(self: *const ParticleGpu, ctx: *const Context, system: usize) void {
        const words = [8]u32{ 0xffff_ffff, 0xffff_ffff, 0xffff_ffff, 0, 0, 0, 0, 0 };
        const offset: u64 = (@as(u64, system) * counter_words + 1) * 4;
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.counters, offset, &words, @sizeOf(@TypeOf(words)));
    }

    pub fn simGroup(self: *const ParticleGpu, step: u32) wgpu.WGPUBindGroup {
        return if (step % 2 == 0) self.sim_ab else self.sim_ba;
    }

    pub fn buildGroup(self: *const ParticleGpu, steps: u32) wgpu.WGPUBindGroup {
        return if (steps % 2 == 0) self.build_a else self.build_b;
    }

    pub fn stampGenerations(self: *const ParticleGpu, systems: anytype) void {
        for (systems, 0..) |*s, i| s.generation = @floatFromInt(self.runtime[i].generation % (1 << 24));
    }
};

fn makeBuffer(ctx: *const Context, label: []const u8, size: u64, usage: wgpu.WGPUBufferUsage) !wgpu.WGPUBuffer {
    return wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .usage = usage,
        .size = size,
        .mappedAtCreation = 0,
    }) orelse error.BufferCreationFailed;
}

fn layoutEntry(binding: u32, kind: wgpu.WGPUBufferBindingType) wgpu.WGPUBindGroupLayoutEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .visibility = wgpu.WGPUShaderStage_Compute,
        .bindingArraySize = 0,
        .buffer = .{ .nextInChain = null, .type = kind, .hasDynamicOffset = 0, .minBindingSize = 0 },
        .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
        .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
        .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
    };
}

fn makeLayout(ctx: *const Context, label: []const u8, entries: []const wgpu.WGPUBindGroupLayoutEntry) !wgpu.WGPUBindGroupLayout {
    return wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .entryCount = entries.len,
        .entries = entries.ptr,
    }) orelse error.BindGroupLayoutCreationFailed;
}

fn entry(binding: u32, buffer: wgpu.WGPUBuffer, size: u64) wgpu.WGPUBindGroupEntry {
    return .{ .nextInChain = null, .binding = binding, .buffer = buffer, .offset = 0, .size = size, .sampler = null, .textureView = null };
}

fn makeGroup(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, entries: []const wgpu.WGPUBindGroupEntry) !wgpu.WGPUBindGroup {
    return wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
        .nextInChain = null,
        .label = sv("particle bind group"),
        .layout = layout,
        .entryCount = entries.len,
        .entries = entries.ptr,
    }) orelse error.BindGroupCreationFailed;
}
