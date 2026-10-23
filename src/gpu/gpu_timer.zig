const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;
const MapState = @import("fractal_renderer.zig").MapState;
const onBufferMapped = @import("fractal_renderer.zig").onBufferMapped;

pub const Lane = enum {
    march,
    select_mask,
    post_chain,
    present,
    particles,
    accel,
    fog_vis,
    photons,
    fft,
    denoise_aov,

    pub const count = @typeInfo(Lane).@"enum".field_names.len;

    pub fn label(self: Lane) [:0]const u8 {
        return switch (self) {
            .march => "Fractal render",
            .select_mask => "Selection mask",
            .post_chain => "Post chain",
            .present => "Display + UI",
            .particles => "Particle sim",
            .accel => "Accelerator build",
            .fog_vis => "Fog shadow grid",
            .photons => "Photon trace",
            .fft => "FT View volume",
            .denoise_aov => "Denoise guides",
        };
    }

    pub fn everyFrame(self: Lane) bool {
        return switch (self) {
            .march, .select_mask, .post_chain, .present, .particles => true,
            else => false,
        };
    }
};

pub const LaneStat = struct {
    ms: f32 = 0,
    seen: bool = false,
    fresh: bool = false,
};

const max_pairs: u32 = 64;
const bytes_per_pair: u64 = 2 * @sizeOf(u64);
const smoothing: f32 = 0.2;

pub const GpuTimer = struct {
    supported: bool = false,
    wanted: bool = false,
    query_set: wgpu.WGPUQuerySet = null,
    resolve_buffer: wgpu.WGPUBuffer = null,
    read_buffer: wgpu.WGPUBuffer = null,
    period_ns: f32 = 1,

    writes: [max_pairs]wgpu.WGPUPassTimestampWrites = undefined,
    pair_lane: [max_pairs]Lane = undefined,
    used: u32 = 0,

    inflight_lane: [max_pairs]Lane = undefined,
    inflight: u32 = 0,
    map_state: MapState = .{},
    mapping: bool = false,

    stats: [Lane.count]LaneStat = @splat(.{}),
    frame_ms: f32 = 0,

    pub fn init(self: *GpuTimer, ctx: *const Context) void {
        if (!ctx.timestamps) return;
        self.query_set = wgpu.wgpuDeviceCreateQuerySet(ctx.device, &wgpu.WGPUQuerySetDescriptor{
            .nextInChain = null,
            .label = sv("gpu timer queries"),
            .type = wgpu.WGPUQueryType_Timestamp,
            .count = 2 * max_pairs,
        });
        self.resolve_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("gpu timer resolve"),
            .usage = wgpu.WGPUBufferUsage_QueryResolve | wgpu.WGPUBufferUsage_CopySrc,
            .size = max_pairs * bytes_per_pair,
            .mappedAtCreation = 0,
        });
        self.read_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("gpu timer readback"),
            .usage = wgpu.WGPUBufferUsage_MapRead | wgpu.WGPUBufferUsage_CopyDst,
            .size = max_pairs * bytes_per_pair,
            .mappedAtCreation = 0,
        });
        if (self.query_set == null or self.resolve_buffer == null or self.read_buffer == null) {
            self.deinit();
            return;
        }
        const period = wgpu.wgpuQueueGetTimestampPeriod(ctx.queue);
        self.period_ns = if (period > 0) period else 1;
        self.supported = true;
    }

    pub fn deinit(self: *GpuTimer) void {
        if (self.query_set != null) wgpu.wgpuQuerySetRelease(self.query_set);
        if (self.resolve_buffer != null) wgpu.wgpuBufferRelease(self.resolve_buffer);
        if (self.read_buffer != null) wgpu.wgpuBufferRelease(self.read_buffer);
        self.query_set = null;
        self.resolve_buffer = null;
        self.read_buffer = null;
        self.supported = false;
    }

    pub fn pass(self: *GpuTimer, lane: Lane) ?*const wgpu.WGPUPassTimestampWrites {
        if (!self.supported or !self.wanted or self.mapping or self.used >= max_pairs) return null;
        const i = self.used;
        self.used += 1;
        self.pair_lane[i] = lane;
        self.writes[i] = .{
            .nextInChain = null,
            .querySet = self.query_set,
            .beginningOfPassWriteIndex = 2 * i,
            .endOfPassWriteIndex = 2 * i + 1,
        };
        return &self.writes[i];
    }

    pub fn endFrame(self: *GpuTimer, ctx: *const Context, rendered: bool) void {
        if (self.used == 0 or self.mapping) return;
        const n = self.used;
        self.used = 0;
        var keep = rendered;
        for (self.pair_lane[0..n]) |lane| {
            if (!lane.everyFrame()) keep = true;
        }
        if (!keep) return;
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return;
        wgpu.wgpuCommandEncoderResolveQuerySet(encoder, self.query_set, 0, 2 * n, self.resolve_buffer, 0);
        wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, self.resolve_buffer, 0, self.read_buffer, 0, n * bytes_per_pair);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        @memcpy(self.inflight_lane[0..n], self.pair_lane[0..n]);
        self.inflight = n;
        self.map_state = .{};
        self.mapping = true;
        _ = wgpu.wgpuBufferMapAsync(self.read_buffer, wgpu.WGPUMapMode_Read, 0, n * bytes_per_pair, wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onBufferMapped,
            .userdata1 = &self.map_state,
            .userdata2 = null,
        });
    }

    pub fn collect(self: *GpuTimer, ctx: *const Context) void {
        if (!self.mapping) return;
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (!self.map_state.done) return;
        self.mapping = false;
        if (self.map_state.status != wgpu.WGPUMapAsyncStatus_Success) return;
        defer wgpu.wgpuBufferUnmap(self.read_buffer);

        const size: usize = @intCast(self.inflight * bytes_per_pair);
        const ptr = wgpu.wgpuBufferGetConstMappedRange(self.read_buffer, 0, size) orelse return;
        const ticks: [*]const u64 = @ptrCast(@alignCast(ptr));

        var sums: [Lane.count]f64 = @splat(0);
        var present: [Lane.count]bool = @splat(false);
        for (0..self.inflight) |i| {
            const begin = ticks[2 * i];
            const end = ticks[2 * i + 1];
            if (end < begin) continue;
            const lane = @intFromEnum(self.inflight_lane[i]);
            sums[lane] += @as(f64, @floatFromInt(end - begin)) * self.period_ns / std.time.ns_per_ms;
            present[lane] = true;
        }

        var frame: f32 = 0;
        for (&self.stats, 0..) |*s, lane| {
            s.fresh = present[lane];
            if (!present[lane]) continue;
            const ms: f32 = @floatCast(sums[lane]);
            const smooth = s.seen and @as(Lane, @enumFromInt(lane)).everyFrame();
            s.ms = if (smooth) s.ms + (ms - s.ms) * smoothing else ms;
            s.seen = true;
            frame += ms;
        }
        self.frame_ms = if (self.frame_ms > 0) self.frame_ms + (frame - self.frame_ms) * smoothing else frame;
    }

    pub fn busy(self: *const GpuTimer) bool {
        return self.mapping;
    }
};

pub var global: GpuTimer = .{};

pub fn pass(lane: Lane) ?*const wgpu.WGPUPassTimestampWrites {
    return global.pass(lane);
}
