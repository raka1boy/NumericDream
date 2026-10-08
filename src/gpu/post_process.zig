const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const g_error_sink = &webgpu_context.g_error_sink;
const sv = webgpu_context.sv;

const post_template = @embedFile("shaders/post_template.wgsl");
const effect_marker = "@@EFFECT@@";

pub const max_effects = 8;
pub const max_source_bytes: usize = 1 << 20;

pub const PostUniforms = extern struct {
    resolution: [2]f32 = .{ 1, 1 },
    time: f32 = 0,
    frame: f32 = 0,
    camera_pos: [3]f32 = .{ 0, 0, 0 },
    max_dist: f32 = 1,
    camera_right: [3]f32 = .{ 1, 0, 0 },
    aspect: f32 = 1,
    camera_up: [3]f32 = .{ 0, 1, 0 },
    slot: f32 = 0,
    camera_forward: [3]f32 = .{ 0, 0, -1 },
    _pad1: f32 = 0,
    tile_scale: [2]f32 = .{ 1, 1 },
    tile_bias: [2]f32 = .{ 0, 0 },
    params0: [4]f32 = .{ 0, 0, 0, 0 },
    params1: [4]f32 = .{ 0, 0, 0, 0 },
};

comptime {
    std.debug.assert(@sizeOf(PostUniforms) == 128);
    for (.{ "camera_pos", "camera_right", "camera_up", "camera_forward", "params0", "params1" }) |field| {
        std.debug.assert(@offsetOf(PostUniforms, field) % 16 == 0);
    }
}

pub const Effect = struct {
    pipeline: wgpu.WGPURenderPipeline,
    params0: [4]f32 = .{ 0, 0, 0, 0 },
    params1: [4]f32 = .{ 0, 0, 0, 0 },
};

pub const FrameInfo = struct {
    resolution: [2]f32,
    time: f32 = 0,
    frame: f32 = 0,
    camera_pos: [3]f32,
    max_dist: f32,
    camera_right: [3]f32,
    camera_up: [3]f32,
    camera_forward: [3]f32,
    aspect: f32,
    tile_scale: [2]f32 = .{ 1, 1 },
    tile_bias: [2]f32 = .{ 0, 0 },
};

pub const Targets = struct {
    width: u32 = 0,
    height: u32 = 0,
    texture: [2]wgpu.WGPUTexture = .{ null, null },
    view: [2]wgpu.WGPUTextureView = .{ null, null },
    effect_group: [max_effects][2]wgpu.WGPUBindGroup = @splat(.{ null, null }),
    read_group: [2]wgpu.WGPUBindGroup = .{ null, null },

    pub fn isReady(self: Targets) bool {
        return self.view[0] != null and self.view[1] != null and
            self.read_group[0] != null and self.read_group[1] != null and
            self.effect_group[0][0] != null;
    }

    pub fn deinit(self: *Targets) void {
        for (self.effect_group) |pair| {
            for (pair) |g| if (g != null) wgpu.wgpuBindGroupRelease(g);
        }
        for (self.read_group) |g| if (g != null) wgpu.wgpuBindGroupRelease(g);
        for (self.view) |v| if (v != null) wgpu.wgpuTextureViewRelease(v);
        for (self.texture) |t| if (t != null) wgpu.wgpuTextureRelease(t);
        self.* = .{};
    }
};

pub const PostChain = struct {
    format: wgpu.WGPUTextureFormat,
    bind_group_layout: wgpu.WGPUBindGroupLayout,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    uniform_buffer: [max_effects]wgpu.WGPUBuffer,

    pub fn init(ctx: *const Context, format: wgpu.WGPUTextureFormat) !PostChain {
        const entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            uniformEntry(0, @sizeOf(PostUniforms)),
            samplerEntry(1),
            textureEntry(2, wgpu.WGPUTextureSampleType_Float),
            textureEntry(3, wgpu.WGPUTextureSampleType_UnfilterableFloat),
            textureEntry(4, wgpu.WGPUTextureSampleType_Float),
        };
        const bgl = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("post effect bind group layout"),
            .entryCount = entries.len,
            .entries = &entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(bgl);

        const layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("post effect pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{bgl},
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;
        errdefer wgpu.wgpuPipelineLayoutRelease(layout);

        var buffers: [max_effects]wgpu.WGPUBuffer = @splat(null);
        errdefer for (buffers) |b| if (b != null) wgpu.wgpuBufferRelease(b);
        for (&buffers) |*b| {
            b.* = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
                .nextInChain = null,
                .label = sv("post effect uniforms"),
                .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
                .size = @sizeOf(PostUniforms),
                .mappedAtCreation = 0,
            }) orelse return error.BufferCreationFailed;
        }

        return .{
            .format = format,
            .bind_group_layout = bgl,
            .pipeline_layout = layout,
            .uniform_buffer = buffers,
        };
    }

    pub fn deinit(self: *PostChain) void {
        for (self.uniform_buffer) |b| if (b != null) wgpu.wgpuBufferRelease(b);
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.bind_group_layout);
    }

    pub fn compile(self: *const PostChain, ctx: *const Context, allocator: std.mem.Allocator, body: []const u8) !wgpu.WGPURenderPipeline {
        const source = try assembleSource(allocator, body);
        defer allocator.free(source);

        g_error_sink.reset();
        var desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(source),
        };
        const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&desc_wgsl),
            .label = sv("post effect shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        defer wgpu.wgpuShaderModuleRelease(module);

        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (g_error_sink.has_error) return error.ShaderCompileFailed;

        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = self.format,
            .blend = null,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };
        const pipeline = wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("post effect pipeline"),
            .layout = self.pipeline_layout,
            .vertex = .{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv("vs_main"),
                .constantCount = 0,
                .constants = null,
                .bufferCount = 0,
                .buffers = null,
            },
            .primitive = webgpu_context.default_primitive_state,
            .depthStencil = null,
            .multisample = webgpu_context.default_multisample_state,
            .fragment = &wgpu.WGPUFragmentState{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv("fs_post"),
                .constantCount = 0,
                .constants = null,
                .targetCount = 1,
                .targets = &[_]wgpu.WGPUColorTargetState{color_target},
            },
        });
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (pipeline == null or g_error_sink.has_error) {
            if (pipeline != null) wgpu.wgpuRenderPipelineRelease(pipeline);
            return error.PipelineCreationFailed;
        }
        return pipeline;
    }

    pub fn createTargets(
        self: *const PostChain,
        ctx: *const Context,
        read_layout: wgpu.WGPUBindGroupLayout,
        sampler: wgpu.WGPUSampler,
        width: u32,
        height: u32,
        depth_view: wgpu.WGPUTextureView,
        normal_view: wgpu.WGPUTextureView,
    ) Targets {
        var out = Targets{ .width = @max(width, 1), .height = @max(height, 1) };

        for (0..2) |i| {
            out.texture[i] = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
                .nextInChain = null,
                .label = sv("post effect target"),
                .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
                .dimension = wgpu.WGPUTextureDimension_2D,
                .size = .{ .width = out.width, .height = out.height, .depthOrArrayLayers = 1 },
                .format = self.format,
                .mipLevelCount = 1,
                .sampleCount = 1,
                .viewFormatCount = 0,
                .viewFormats = null,
            });
            if (out.texture[i] == null) {
                out.deinit();
                return .{};
            }
            out.view[i] = wgpu.wgpuTextureCreateView(out.texture[i], null);
            if (out.view[i] == null) {
                out.deinit();
                return .{};
            }
        }

        for (0..2) |src| {
            out.read_group[src] = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
                .nextInChain = null,
                .label = sv("post chain readback bind group"),
                .layout = read_layout,
                .entryCount = 2,
                .entries = &[_]wgpu.WGPUBindGroupEntry{
                    bufferless(0, sampler, null),
                    bufferless(1, null, out.view[src]),
                },
            });
            if (out.read_group[src] == null) {
                out.deinit();
                return .{};
            }
        }

        for (0..max_effects) |slot| {
            for (0..2) |src| {
                out.effect_group[slot][src] = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
                    .nextInChain = null,
                    .label = sv("post effect bind group"),
                    .layout = self.bind_group_layout,
                    .entryCount = 5,
                    .entries = &[_]wgpu.WGPUBindGroupEntry{
                        .{
                            .nextInChain = null,
                            .binding = 0,
                            .buffer = self.uniform_buffer[slot],
                            .offset = 0,
                            .size = @sizeOf(PostUniforms),
                            .sampler = null,
                            .textureView = null,
                        },
                        bufferless(1, sampler, null),
                        bufferless(2, null, out.view[src]),
                        bufferless(3, null, depth_view),
                        bufferless(4, null, normal_view),
                    },
                });
                if (out.effect_group[slot][src] == null) {
                    out.deinit();
                    return .{};
                }
            }
        }
        return out;
    }

    pub fn apply(
        self: *const PostChain,
        ctx: *const Context,
        encoder: wgpu.WGPUCommandEncoder,
        targets: *const Targets,
        resolve_pipeline: wgpu.WGPURenderPipeline,
        source_group: wgpu.WGPUBindGroup,
        effects: []const Effect,
        frame: FrameInfo,
    ) ?wgpu.WGPUBindGroup {
        if (!targets.isReady() or resolve_pipeline == null or effects.len == 0) return null;

        fullscreenPass(encoder, "post dof resolve pass", targets.view[0], resolve_pipeline, source_group);

        var src: usize = 0;
        for (effects, 0..) |effect, i| {
            if (i >= max_effects) break;
            var uniforms = PostUniforms{
                .resolution = frame.resolution,
                .time = frame.time,
                .frame = frame.frame,
                .camera_pos = frame.camera_pos,
                .max_dist = frame.max_dist,
                .camera_right = frame.camera_right,
                .aspect = frame.aspect,
                .camera_up = frame.camera_up,
                .slot = @floatFromInt(i),
                .camera_forward = frame.camera_forward,
                .tile_scale = frame.tile_scale,
                .tile_bias = frame.tile_bias,
                .params0 = effect.params0,
                .params1 = effect.params1,
            };
            wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer[i], 0, &uniforms, @sizeOf(PostUniforms));

            const dst = 1 - src;
            fullscreenPass(encoder, "post effect pass", targets.view[dst], effect.pipeline, targets.effect_group[i][src]);
            src = dst;
        }
        return targets.read_group[src];
    }
};

fn fullscreenPass(
    encoder: wgpu.WGPUCommandEncoder,
    label: []const u8,
    target: wgpu.WGPUTextureView,
    pipeline: wgpu.WGPURenderPipeline,
    group: wgpu.WGPUBindGroup,
) void {
    const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .colorAttachmentCount = 1,
        .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
            .nextInChain = null,
            .view = target,
            .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
            .resolveTarget = null,
            .loadOp = wgpu.WGPULoadOp_Clear,
            .storeOp = wgpu.WGPUStoreOp_Store,
            .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        }},
        .depthStencilAttachment = null,
        .occlusionQuerySet = null,
        .timestampWrites = null,
    }) orelse return;
    wgpu.wgpuRenderPassEncoderSetPipeline(pass, pipeline);
    wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, group, 0, null);
    wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    wgpu.wgpuRenderPassEncoderEnd(pass);
    wgpu.wgpuRenderPassEncoderRelease(pass);
}

fn assembleSource(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    const idx = std.mem.indexOf(u8, post_template, effect_marker) orelse return error.MissingEffectMarker;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, post_template[0..idx]);
    try out.appendSlice(allocator, body);
    try out.appendSlice(allocator, post_template[idx + effect_marker.len ..]);
    return out.toOwnedSlice(allocator);
}

fn uniformEntry(binding: u32, size: u64) wgpu.WGPUBindGroupLayoutEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Vertex,
        .bindingArraySize = 0,
        .buffer = .{
            .nextInChain = null,
            .type = wgpu.WGPUBufferBindingType_Uniform,
            .hasDynamicOffset = 0,
            .minBindingSize = size,
        },
        .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
        .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
        .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
    };
}

fn samplerEntry(binding: u32) wgpu.WGPUBindGroupLayoutEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .visibility = wgpu.WGPUShaderStage_Fragment,
        .bindingArraySize = 0,
        .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
        .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
        .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
        .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
    };
}

fn textureEntry(binding: u32, sample_type: wgpu.WGPUTextureSampleType) wgpu.WGPUBindGroupLayoutEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .visibility = wgpu.WGPUShaderStage_Fragment,
        .bindingArraySize = 0,
        .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
        .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
        .texture = .{
            .nextInChain = null,
            .sampleType = sample_type,
            .viewDimension = wgpu.WGPUTextureViewDimension_2D,
            .multisampled = 0,
        },
        .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
    };
}

fn bufferless(binding: u32, sampler: wgpu.WGPUSampler, view: wgpu.WGPUTextureView) wgpu.WGPUBindGroupEntry {
    return .{
        .nextInChain = null,
        .binding = binding,
        .buffer = null,
        .offset = 0,
        .size = 0,
        .sampler = sampler,
        .textureView = view,
    };
}

pub fn missingContractFn(content: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, content, "fn effect(") == null) {
        return "fn effect(uv: vec2f, color: vec4f, p: array<f32, 8>) -> vec4f";
    }
    return null;
}
