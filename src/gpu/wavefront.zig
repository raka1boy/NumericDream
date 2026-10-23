const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const workgroup: u32 = 64;
pub const group_index: u32 = 6;
pub const min_bind_groups: u32 = group_index + 1;
pub const min_storage_buffers: u32 = 12;
pub const default_slots: u32 = 1 << 18;
pub const max_blocks: u32 = 64;
pub const max_inner: u32 = 32;

const block_words = 64;
const block_bytes: u64 = block_words * 4;
const path_bytes: u64 = 256;
const out_bytes: u64 = 32;
const surface_bytes: u64 = 96;
const queue_count: u64 = 5;

const word_rect_x = 0;
const word_rect_y = 1;
const word_rect_w = 2;
const word_rect_h = 3;
const word_target_w = 4;
const word_target_h = 5;
const word_inner = 6;
const word_queue_stride = 7;

const args_bytes: u64 = 16 * 4;
pub const args_paths_offset: u64 = 0;
pub const args_shadow_offset: u64 = 4 * 4;
pub const args_indirect_offset: u64 = 8 * 4;
pub const args_hits_offset: u64 = 12 * 4;

pub const Band = struct { x: u32, y: u32, w: u32, h: u32 };

pub fn supported(ctx: *const Context) bool {
    return ctx.limits.maxBindGroups >= min_bind_groups and
        ctx.limits.maxStorageBuffersPerShaderStage >= min_storage_buffers and
        ctx.limits.maxStorageBufferBindingSize >= @as(u64, default_slots) * path_bytes;
}

fn bufferEntry(binding: u32, visibility: wgpu.WGPUShaderStage, kind: wgpu.WGPUBufferBindingType, dynamic: bool, min_size: u64) wgpu.WGPUBindGroupLayoutEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .visibility = visibility,
        .bindingArraySize = 0,
        .buffer = .{ .nextInChain = null, .type = kind, .hasDynamicOffset = if (dynamic) 1 else 0, .minBindingSize = min_size },
        .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
        .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
        .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
    };
}

fn groupEntry(binding: u32, buffer: wgpu.WGPUBuffer, size: u64) wgpu.WGPUBindGroupEntry {
    return .{ .nextInChain = null, .binding = binding, .buffer = buffer, .offset = 0, .size = size, .sampler = null, .textureView = null };
}

pub const WavefrontGpu = struct {
    compute_layout: wgpu.WGPUBindGroupLayout,
    args_layout: wgpu.WGPUBindGroupLayout,
    resolve_layout: wgpu.WGPUBindGroupLayout,

    paths: wgpu.WGPUBuffer = null,
    queues: wgpu.WGPUBuffer = null,
    blocks: wgpu.WGPUBuffer = null,
    args: wgpu.WGPUBuffer = null,
    out: wgpu.WGPUBuffer = null,
    surfaces: wgpu.WGPUBuffer = null,
    compute_group: wgpu.WGPUBindGroup = null,
    args_group: wgpu.WGPUBindGroup = null,
    resolve_group: wgpu.WGPUBindGroup = null,

    slots: u32 = 0,
    next_block: u32 = 0,

    pub fn init(ctx: *const Context) !WavefrontGpu {
        const storage = wgpu.WGPUBufferBindingType_Storage;
        const compute = wgpu.WGPUShaderStage_Compute;
        const compute_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            bufferEntry(0, compute, storage, false, path_bytes),
            bufferEntry(1, compute, storage, false, 4),
            bufferEntry(2, compute, storage, true, block_bytes),
            bufferEntry(3, compute, storage, false, out_bytes),
            bufferEntry(7, compute, storage, false, surface_bytes),
        };
        const compute_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("wavefront compute bind group layout"),
            .entryCount = compute_entries.len,
            .entries = &compute_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(compute_layout);

        const args_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            bufferEntry(2, compute, storage, true, block_bytes),
            bufferEntry(6, compute, storage, true, args_bytes),
        };
        const args_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("wavefront args bind group layout"),
            .entryCount = args_entries.len,
            .entries = &args_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(args_layout);

        const read = wgpu.WGPUBufferBindingType_ReadOnlyStorage;
        const fragment = wgpu.WGPUShaderStage_Fragment;
        const resolve_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            bufferEntry(4, fragment, read, true, block_bytes),
            bufferEntry(5, fragment, read, false, out_bytes),
        };
        const resolve_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("wavefront resolve bind group layout"),
            .entryCount = resolve_entries.len,
            .entries = &resolve_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;

        return .{ .compute_layout = compute_layout, .args_layout = args_layout, .resolve_layout = resolve_layout };
    }

    pub fn deinit(self: *WavefrontGpu) void {
        self.releaseBuffers();
        wgpu.wgpuBindGroupLayoutRelease(self.compute_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.args_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.resolve_layout);
    }

    fn releaseBuffers(self: *WavefrontGpu) void {
        if (self.compute_group != null) wgpu.wgpuBindGroupRelease(self.compute_group);
        if (self.args_group != null) wgpu.wgpuBindGroupRelease(self.args_group);
        if (self.resolve_group != null) wgpu.wgpuBindGroupRelease(self.resolve_group);
        if (self.paths != null) wgpu.wgpuBufferRelease(self.paths);
        if (self.queues != null) wgpu.wgpuBufferRelease(self.queues);
        if (self.blocks != null) wgpu.wgpuBufferRelease(self.blocks);
        if (self.args != null) wgpu.wgpuBufferRelease(self.args);
        if (self.out != null) wgpu.wgpuBufferRelease(self.out);
        if (self.surfaces != null) wgpu.wgpuBufferRelease(self.surfaces);
        self.surfaces = null;
        self.compute_group = null;
        self.args_group = null;
        self.args = null;
        self.resolve_group = null;
        self.paths = null;
        self.queues = null;
        self.blocks = null;
        self.out = null;
        self.slots = 0;
    }

    fn createBuffer(ctx: *const Context, label: []const u8, usage: wgpu.WGPUBufferUsage, size: u64) ?wgpu.WGPUBuffer {
        return wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .usage = usage,
            .size = size,
            .mappedAtCreation = 0,
        });
    }

    pub fn ensureSlots(self: *WavefrontGpu, ctx: *const Context, slots: u32) bool {
        if (self.slots >= slots and self.compute_group != null) return true;
        self.releaseBuffers();
        const n: u64 = @max(slots, workgroup);
        const storage = wgpu.WGPUBufferUsage_Storage;
        self.paths = createBuffer(ctx, "wavefront paths", storage, n * path_bytes) orelse return false;
        self.queues = createBuffer(ctx, "wavefront queues", storage, n * queue_count * 4) orelse return self.fail();
        self.blocks = createBuffer(ctx, "wavefront blocks", storage | wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_CopySrc, max_blocks * block_bytes) orelse return self.fail();
        self.args = createBuffer(ctx, "wavefront dispatch args", storage | wgpu.WGPUBufferUsage_Indirect, max_blocks * block_bytes) orelse return self.fail();
        self.out = createBuffer(ctx, "wavefront radiance", storage, n * out_bytes) orelse return self.fail();
        self.surfaces = createBuffer(ctx, "wavefront surfaces", storage, n * surface_bytes) orelse return self.fail();

        const compute_entries = [_]wgpu.WGPUBindGroupEntry{
            groupEntry(0, self.paths, n * path_bytes),
            groupEntry(1, self.queues, n * queue_count * 4),
            groupEntry(2, self.blocks, block_bytes),
            groupEntry(3, self.out, n * out_bytes),
            groupEntry(7, self.surfaces, n * surface_bytes),
        };
        self.compute_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("wavefront compute bind group"),
            .layout = self.compute_layout,
            .entryCount = compute_entries.len,
            .entries = &compute_entries,
        }) orelse return self.fail();
        const args_entries = [_]wgpu.WGPUBindGroupEntry{
            groupEntry(2, self.blocks, block_bytes),
            groupEntry(6, self.args, args_bytes),
        };
        self.args_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("wavefront args bind group"),
            .layout = self.args_layout,
            .entryCount = args_entries.len,
            .entries = &args_entries,
        }) orelse return self.fail();
        const resolve_entries = [_]wgpu.WGPUBindGroupEntry{
            groupEntry(4, self.blocks, block_bytes),
            groupEntry(5, self.out, n * out_bytes),
        };
        self.resolve_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("wavefront resolve bind group"),
            .layout = self.resolve_layout,
            .entryCount = resolve_entries.len,
            .entries = &resolve_entries,
        }) orelse return self.fail();
        self.slots = @intCast(n);
        return true;
    }

    fn fail(self: *WavefrontGpu) bool {
        self.releaseBuffers();
        return false;
    }

    pub fn blocksLeft(self: *const WavefrontGpu) bool {
        return self.next_block < max_blocks;
    }

    pub fn resetBlocks(self: *WavefrontGpu) void {
        self.next_block = 0;
    }

    pub fn pixelCapacity(self: *const WavefrontGpu, inner: u32) u64 {
        return self.slots / @max(inner, 1);
    }

    pub fn reserveBlock(self: *WavefrontGpu, ctx: *const Context, band: Band, target_w: u32, target_h: u32, inner: u32) u32 {
        std.debug.assert(self.blocksLeft());
        var words: [block_words]u32 = @splat(0);
        words[word_rect_x] = band.x;
        words[word_rect_y] = band.y;
        words[word_rect_w] = band.w;
        words[word_rect_h] = band.h;
        words[word_target_w] = target_w;
        words[word_target_h] = target_h;
        words[word_inner] = @max(inner, 1);
        words[word_queue_stride] = self.slots;
        const offset: u32 = @intCast(@as(u64, self.next_block) * block_bytes);
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.blocks, offset, &words, block_bytes);
        self.next_block += 1;
        return offset;
    }
};

pub const Kernel = enum {
    generate,
    extend,
    surface,
    shade,
    shadow,
    indirect,
    args,
    resolve,
    megakernel,

    pub const count = @typeInfo(Kernel).@"enum".field_names.len;
};

const stats_paths_word = 32;
const stats_shadow_word = 48;
const stats_indirect_word = 20;
pub const stats_depths = 16;
const profile_pairs: u32 = 2048;

pub const Profile = struct {
    query_set: wgpu.WGPUQuerySet = null,
    resolve_buffer: wgpu.WGPUBuffer = null,
    read_buffer: wgpu.WGPUBuffer = null,
    block_read: wgpu.WGPUBuffer = null,
    period_ns: f64 = 1,
    kernel_of: [profile_pairs]Kernel = undefined,
    writes: [profile_pairs]wgpu.WGPUPassTimestampWrites = undefined,
    used: u32 = 0,

    ms: [Kernel.count]f64 = @splat(0),
    paths: [stats_depths]u64 = @splat(0),
    shadows: [stats_depths]u64 = @splat(0),
    indirect: u64 = 0,

    pub fn init(ctx: *const Context) ?Profile {
        if (!ctx.timestamps) return null;
        var p = Profile{};
        p.query_set = wgpu.wgpuDeviceCreateQuerySet(ctx.device, &wgpu.WGPUQuerySetDescriptor{
            .nextInChain = null,
            .label = sv("wavefront profile queries"),
            .type = wgpu.WGPUQueryType_Timestamp,
            .count = 2 * profile_pairs,
        });
        const bytes: u64 = 2 * 8 * profile_pairs;
        p.resolve_buffer = WavefrontGpu.createBuffer(ctx, "wavefront profile resolve", wgpu.WGPUBufferUsage_QueryResolve | wgpu.WGPUBufferUsage_CopySrc, bytes) orelse null;
        p.read_buffer = WavefrontGpu.createBuffer(ctx, "wavefront profile read", wgpu.WGPUBufferUsage_MapRead | wgpu.WGPUBufferUsage_CopyDst, bytes) orelse null;
        p.block_read = WavefrontGpu.createBuffer(ctx, "wavefront block read", wgpu.WGPUBufferUsage_MapRead | wgpu.WGPUBufferUsage_CopyDst, max_blocks * block_bytes) orelse null;
        if (p.query_set == null or p.resolve_buffer == null or p.read_buffer == null or p.block_read == null) {
            p.deinit();
            return null;
        }
        const period = wgpu.wgpuQueueGetTimestampPeriod(ctx.queue);
        p.period_ns = if (period > 0) period else 1;
        return p;
    }

    pub fn deinit(self: *Profile) void {
        if (self.query_set != null) wgpu.wgpuQuerySetRelease(self.query_set);
        if (self.resolve_buffer != null) wgpu.wgpuBufferRelease(self.resolve_buffer);
        if (self.read_buffer != null) wgpu.wgpuBufferRelease(self.read_buffer);
        if (self.block_read != null) wgpu.wgpuBufferRelease(self.block_read);
        self.* = .{};
    }

    pub fn full(self: *const Profile) bool {
        return self.used + 128 >= profile_pairs;
    }

    pub fn pass(self: *Profile, kernel: Kernel) ?*const wgpu.WGPUPassTimestampWrites {
        if (self.used >= profile_pairs) return null;
        const i = self.used;
        self.used += 1;
        self.kernel_of[i] = kernel;
        self.writes[i] = .{ .nextInChain = null, .querySet = self.query_set, .beginningOfPassWriteIndex = 2 * i, .endOfPassWriteIndex = 2 * i + 1 };
        return &self.writes[i];
    }

    fn mapRead(ctx: *const Context, buffer: wgpu.WGPUBuffer, size: u64) ?[*]const u8 {
        const State = struct {
            done: bool = false,
            ok: bool = false,
            fn cb(status: wgpu.WGPUMapAsyncStatus, _: wgpu.WGPUStringView, ud1: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
                const st: *@This() = @ptrCast(@alignCast(ud1.?));
                st.ok = status == wgpu.WGPUMapAsyncStatus_Success;
                st.done = true;
            }
        };
        var state = State{};
        _ = wgpu.wgpuBufferMapAsync(buffer, wgpu.WGPUMapMode_Read, 0, size, .{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = State.cb,
            .userdata1 = &state,
            .userdata2 = null,
        });
        _ = webgpu_context.pollUntil(ctx.instance, &state.done, 60_000);
        if (!state.ok) return null;
        const ptr = wgpu.wgpuBufferGetConstMappedRange(buffer, 0, size) orelse return null;
        return @ptrCast(ptr);
    }

    pub fn collect(self: *Profile, ctx: *const Context, gpu: *const WavefrontGpu, blocks_used: u32) void {
        const pairs = self.used;
        self.used = 0;
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return;
        if (pairs > 0) {
            wgpu.wgpuCommandEncoderResolveQuerySet(encoder, self.query_set, 0, 2 * pairs, self.resolve_buffer, 0);
            wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, self.resolve_buffer, 0, self.read_buffer, 0, @as(u64, pairs) * 16);
        }
        if (blocks_used > 0) wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, gpu.blocks, 0, self.block_read, 0, @as(u64, blocks_used) * block_bytes);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        if (pairs > 0) {
            if (mapRead(ctx, self.read_buffer, @as(u64, pairs) * 16)) |bytes| {
                const ticks: [*]const u64 = @ptrCast(@alignCast(bytes));
                for (0..pairs) |i| {
                    if (ticks[2 * i + 1] < ticks[2 * i]) continue;
                    self.ms[@intFromEnum(self.kernel_of[i])] += @as(f64, @floatFromInt(ticks[2 * i + 1] - ticks[2 * i])) * self.period_ns / std.time.ns_per_ms;
                }
                wgpu.wgpuBufferUnmap(self.read_buffer);
            }
        }
        if (blocks_used > 0) {
            if (mapRead(ctx, self.block_read, @as(u64, blocks_used) * block_bytes)) |bytes| {
                const words: [*]const u32 = @ptrCast(@alignCast(bytes));
                for (0..blocks_used) |b| {
                    const w = words[b * block_words ..];
                    for (0..stats_depths) |d| {
                        self.paths[d] += w[stats_paths_word + d];
                        self.shadows[d] += w[stats_shadow_word + d];
                    }
                    self.indirect += w[stats_indirect_word];
                }
                wgpu.wgpuBufferUnmap(self.block_read);
            }
        }
    }

    pub fn report(self: *const Profile) void {
        var total: f64 = 0;
        for (self.ms) |m| total += m;
        std.debug.print("[wavefront] GPU time by kernel ({d:.0}ms total):", .{total});
        for (self.ms, 0..) |m, k| {
            std.debug.print(" {s}={d:.0}ms({d:.0}%)", .{ @tagName(@as(Kernel, @enumFromInt(k))), m, 100 * m / @max(total, 1e-9) });
        }
        std.debug.print("\n[wavefront] live paths per depth:", .{});
        for (self.paths, 0..) |n, d| {
            if (n == 0) continue;
            std.debug.print(" d{d}={d}", .{ d, n });
        }
        std.debug.print("\n[wavefront] shadow rays per depth:", .{});
        for (self.shadows, 0..) |n, d| {
            if (n == 0) continue;
            std.debug.print(" d{d}={d}", .{ d, n });
        }
        std.debug.print("\n[wavefront] indirect probes: {d}\n", .{self.indirect});
    }
};
