const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const sdl = @import("../bindings/sdl3.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;
const g_error_sink = &webgpu_context.g_error_sink;
const fractal_gpu = @import("fractal_renderer.zig");

pub const shader_source = @embedFile("shaders/mesh.wgsl");

pub const block: u32 = 8;
pub const workgroup: u32 = 64;
pub const max_threads: u32 = 65535 * workgroup;

pub const Params = extern struct {
    origin: [3]f32,
    cell: f32,
    iso: f32,
    count: u32,
    span: u32 = 1,
    local_offset: u32 = 0,
    sharp: f32 = 0,
    color_on: f32 = 0,
    _pad0: f32 = 0,
    _pad1: f32 = 0,
};

pub const CellIn = extern struct {
    origin: [4]f32,
    corners: [8]f32,
};

pub const VertOut = extern struct {
    pos: [4]f32,
    normal: [4]f32,
    color: [4]f32,
};

comptime {
    std.debug.assert(@sizeOf(Params) == 48);
    std.debug.assert(@sizeOf(CellIn) == 48);
    std.debug.assert(@sizeOf(VertOut) == 48);
}

pub const Pass = enum { points, verts, probe };
const pass_count = 3;
const entry_points = [pass_count][]const u8{ "cs_mesh_points", "cs_mesh_verts", "cs_mesh_probe" };

pub const MeshGpu = struct {
    layout: wgpu.WGPUBindGroupLayout,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    params_buffer: wgpu.WGPUBuffer,

    in_buffer: wgpu.WGPUBuffer = null,
    in_cap: u64 = 0,
    out_buffer: wgpu.WGPUBuffer = null,
    read_buffer: wgpu.WGPUBuffer = null,
    out_cap: u64 = 0,
    bind_group: wgpu.WGPUBindGroup = null,

    module: wgpu.WGPUShaderModule = null,
    pipelines: [pass_count]wgpu.WGPUComputePipeline = @splat(null),
    hash: u64 = 0,

    pub fn init(ctx: *const Context, uniform_layout: wgpu.WGPUBindGroupLayout) !MeshGpu {
        const entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            bufferEntry(20, wgpu.WGPUBufferBindingType_Uniform),
            bufferEntry(21, wgpu.WGPUBufferBindingType_ReadOnlyStorage),
            bufferEntry(22, wgpu.WGPUBufferBindingType_Storage),
        };
        const layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("mesh bind group layout"),
            .entryCount = entries.len,
            .entries = &entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(layout);

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("mesh pipeline layout"),
            .bindGroupLayoutCount = 2,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{ uniform_layout, layout },
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;
        errdefer wgpu.wgpuPipelineLayoutRelease(pipeline_layout);

        const params_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("mesh params"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(Params),
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;

        return .{ .layout = layout, .pipeline_layout = pipeline_layout, .params_buffer = params_buffer };
    }

    fn bufferEntry(binding: u32, kind: wgpu.WGPUBufferBindingType) wgpu.WGPUBindGroupLayoutEntry {
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

    pub fn deinit(self: *MeshGpu) void {
        self.releasePipelines();
        self.releaseBuffers();
        wgpu.wgpuBufferRelease(self.params_buffer);
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.layout);
    }

    fn releasePipelines(self: *MeshGpu) void {
        for (&self.pipelines) |*p| {
            if (p.* != null) wgpu.wgpuComputePipelineRelease(p.*);
            p.* = null;
        }
        if (self.module != null) wgpu.wgpuShaderModuleRelease(self.module);
        self.module = null;
        self.hash = 0;
    }

    fn releaseBuffers(self: *MeshGpu) void {
        if (self.bind_group != null) wgpu.wgpuBindGroupRelease(self.bind_group);
        if (self.in_buffer != null) wgpu.wgpuBufferRelease(self.in_buffer);
        if (self.out_buffer != null) wgpu.wgpuBufferRelease(self.out_buffer);
        if (self.read_buffer != null) wgpu.wgpuBufferRelease(self.read_buffer);
        self.bind_group = null;
        self.in_buffer = null;
        self.out_buffer = null;
        self.read_buffer = null;
        self.in_cap = 0;
        self.out_cap = 0;
    }

    pub fn hasModule(self: *const MeshGpu, hash: u64) bool {
        return self.module != null and self.hash == hash;
    }

    pub fn buildModule(self: *MeshGpu, ctx: *const Context, source: []const u8, hash: u64) !void {
        self.releasePipelines();
        g_error_sink.reset();
        var wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(source),
        };
        const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&wgsl),
            .label = sv("mesh shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (g_error_sink.has_error) {
            wgpu.wgpuShaderModuleRelease(module);
            return error.ShaderCompileFailed;
        }
        self.module = module;
        self.hash = hash;
    }

    fn pipeline(self: *MeshGpu, ctx: *const Context, pass: Pass) !wgpu.WGPUComputePipeline {
        const slot = &self.pipelines[@intFromEnum(pass)];
        if (slot.* != null) return slot.*;
        if (self.module == null) return error.PipelineCreationFailed;
        const started = sdl.SDL_GetTicks();
        g_error_sink.reset();
        const p = wgpu.wgpuDeviceCreateComputePipeline(ctx.device, &wgpu.WGPUComputePipelineDescriptor{
            .nextInChain = null,
            .label = sv(entry_points[@intFromEnum(pass)]),
            .layout = self.pipeline_layout,
            .compute = .{ .nextInChain = null, .module = self.module, .entryPoint = sv(entry_points[@intFromEnum(pass)]), .constantCount = 0, .constants = null },
        });
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (p == null or g_error_sink.has_error) {
            if (p != null) wgpu.wgpuComputePipelineRelease(p);
            return error.PipelineCreationFailed;
        }
        std.debug.print("[mesh] built {s} pipeline in {d}ms\n", .{ entry_points[@intFromEnum(pass)], sdl.SDL_GetTicks() -| started });
        slot.* = p;
        return p;
    }

    fn ensureBuffers(self: *MeshGpu, ctx: *const Context, in_size: u64, out_size: u64) !void {
        if (self.bind_group != null and in_size <= self.in_cap and out_size <= self.out_cap) return;
        const round = 1 << 20;
        const in_cap = std.mem.alignForward(u64, @max(in_size, self.in_cap), round);
        const out_cap = std.mem.alignForward(u64, @max(out_size, self.out_cap), round);
        self.releaseBuffers();

        self.in_buffer = createBuffer(ctx, "mesh input", wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst, in_cap) orelse return error.BufferCreationFailed;
        self.out_buffer = createBuffer(ctx, "mesh output", wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopySrc, out_cap) orelse return error.BufferCreationFailed;
        self.read_buffer = createBuffer(ctx, "mesh readback", wgpu.WGPUBufferUsage_MapRead | wgpu.WGPUBufferUsage_CopyDst, out_cap) orelse return error.BufferCreationFailed;
        self.in_cap = in_cap;
        self.out_cap = out_cap;

        const entries = [_]wgpu.WGPUBindGroupEntry{
            .{ .nextInChain = null, .binding = 20, .buffer = self.params_buffer, .offset = 0, .size = @sizeOf(Params), .sampler = null, .textureView = null },
            .{ .nextInChain = null, .binding = 21, .buffer = self.in_buffer, .offset = 0, .size = in_cap, .sampler = null, .textureView = null },
            .{ .nextInChain = null, .binding = 22, .buffer = self.out_buffer, .offset = 0, .size = out_cap, .sampler = null, .textureView = null },
        };
        self.bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("mesh bind group"),
            .layout = self.layout,
            .entryCount = entries.len,
            .entries = &entries,
        }) orelse return error.BindGroupCreationFailed;
    }

    fn createBuffer(ctx: *const Context, label: []const u8, usage: wgpu.WGPUBufferUsage, size: u64) wgpu.WGPUBuffer {
        return wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .usage = usage,
            .size = size,
            .mappedAtCreation = 0,
        });
    }

    pub fn run(
        self: *MeshGpu,
        ctx: *const Context,
        uniforms_group: wgpu.WGPUBindGroup,
        pass: Pass,
        params: Params,
        input: []const u8,
        output: []u8,
        threads: u32,
    ) !void {
        if (threads == 0) return;
        if (threads > max_threads) return error.MeshBatchTooLarge;
        const pipe = try self.pipeline(ctx, pass);
        try self.ensureBuffers(ctx, @max(input.len, 16), @max(output.len, 16));

        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.params_buffer, 0, &params, @sizeOf(Params));
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.in_buffer, 0, input.ptr, input.len);

        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        const cpass = wgpu.wgpuCommandEncoderBeginComputePass(encoder, &wgpu.WGPUComputePassDescriptor{
            .nextInChain = null,
            .label = sv("mesh pass"),
            .timestampWrites = null,
        }).?;
        wgpu.wgpuComputePassEncoderSetPipeline(cpass, pipe);
        const slot0: u32 = 0;
        wgpu.wgpuComputePassEncoderSetBindGroup(cpass, 0, uniforms_group, 1, &slot0);
        wgpu.wgpuComputePassEncoderSetBindGroup(cpass, 1, self.bind_group, 0, null);
        wgpu.wgpuComputePassEncoderDispatchWorkgroups(cpass, (threads + workgroup - 1) / workgroup, 1, 1);
        wgpu.wgpuComputePassEncoderEnd(cpass);
        wgpu.wgpuComputePassEncoderRelease(cpass);
        wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, self.out_buffer, 0, self.read_buffer, 0, output.len);
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        var map_state = fractal_gpu.MapState{};
        _ = wgpu.wgpuBufferMapAsync(self.read_buffer, wgpu.WGPUMapMode_Read, 0, output.len, wgpu.WGPUBufferMapCallbackInfo{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = fractal_gpu.onBufferMapped,
            .userdata1 = &map_state,
            .userdata2 = null,
        });
        _ = webgpu_context.pollUntil(ctx.instance, &map_state.done, fractal_gpu.gpu_work_timeout_ms);
        if (!map_state.done or map_state.status != wgpu.WGPUMapAsyncStatus_Success) return error.BufferMapFailed;
        defer wgpu.wgpuBufferUnmap(self.read_buffer);
        const ptr = wgpu.wgpuBufferGetConstMappedRange(self.read_buffer, 0, output.len) orelse return error.MappedRangeFailed;
        @memcpy(output, @as([*]const u8, @ptrCast(ptr))[0..output.len]);
    }
};
