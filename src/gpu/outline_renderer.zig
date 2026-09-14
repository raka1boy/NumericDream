const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

const shader_src = @embedFile("shaders/outline.wgsl");

pub const thickness_px: f32 = 2.5;

const OutlineUniforms = extern struct {
    inv_screen: [2]f32,
    selected_id: f32,
    thickness_px: f32,
};

comptime {
    std.debug.assert(@sizeOf(OutlineUniforms) == 16);
}

pub const OutlineRenderer = struct {
    pipeline: wgpu.WGPURenderPipeline,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    bind_group_layout: wgpu.WGPUBindGroupLayout,
    uniform_buffer: wgpu.WGPUBuffer,
    sampler: wgpu.WGPUSampler,

    bind_group: wgpu.WGPUBindGroup = null,
    bound_generation: u32 = 0,
    has_bind_group: bool = false,

    pub fn init(ctx: *const Context) !OutlineRenderer {
        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("outline uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(OutlineUniforms),
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;
        errdefer wgpu.wgpuBufferRelease(uniform_buffer);

        const texture_entry = wgpu.WGPUTextureBindingLayout{
            .nextInChain = null,
            .sampleType = wgpu.WGPUTextureSampleType_Float,
            .viewDimension = wgpu.WGPUTextureViewDimension_2D,
            .multisampled = 0,
        };
        const bgl_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            .{
                .nextInChain = null,
                .binding = 0,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = .{
                    .nextInChain = null,
                    .type = wgpu.WGPUBufferBindingType_Uniform,
                    .hasDynamicOffset = 0,
                    .minBindingSize = @sizeOf(OutlineUniforms),
                },
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 1,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = texture_entry,
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 2,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = texture_entry,
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 3,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
                .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("outline bind group layout"),
            .entryCount = bgl_entries.len,
            .entries = &bgl_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(bind_group_layout);

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("outline pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{bind_group_layout},
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;
        errdefer wgpu.wgpuPipelineLayoutRelease(pipeline_layout);

        var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(shader_src),
        };
        const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&shader_desc_wgsl),
            .label = sv("outline shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        defer wgpu.wgpuShaderModuleRelease(module);

        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = ctx.surface_format,
            .blend = null,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };
        const pipeline = wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("outline pipeline"),
            .layout = pipeline_layout,
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
                .entryPoint = sv("fs_main"),
                .constantCount = 0,
                .constants = null,
                .targetCount = 1,
                .targets = &[_]wgpu.WGPUColorTargetState{color_target},
            },
        }) orelse return error.RenderPipelineCreationFailed;
        errdefer wgpu.wgpuRenderPipelineRelease(pipeline);

        const sampler = wgpu.wgpuDeviceCreateSampler(ctx.device, &webgpu_context.linearSamplerDesc(sv("outline source sampler"))) orelse
            return error.SamplerCreationFailed;

        return .{
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .bind_group_layout = bind_group_layout,
            .uniform_buffer = uniform_buffer,
            .sampler = sampler,
        };
    }

    pub fn deinit(self: *OutlineRenderer) void {
        if (self.has_bind_group) wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuSamplerRelease(self.sampler);
        wgpu.wgpuRenderPipelineRelease(self.pipeline);
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.bind_group_layout);
        wgpu.wgpuBufferRelease(self.uniform_buffer);
    }

    fn ensureBindGroup(self: *OutlineRenderer, ctx: *const Context, mask_view: wgpu.WGPUTextureView, source_view: wgpu.WGPUTextureView, generation: u32) bool {
        if (self.has_bind_group and self.bound_generation == generation) return true;

        const new_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("outline bind group"),
            .layout = self.bind_group_layout,
            .entryCount = 4,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = self.uniform_buffer, .offset = 0, .size = @sizeOf(OutlineUniforms), .sampler = null, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = mask_view },
                .{ .nextInChain = null, .binding = 2, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = source_view },
                .{ .nextInChain = null, .binding = 3, .buffer = null, .offset = 0, .size = 0, .sampler = self.sampler, .textureView = null },
            },
        }) orelse return false;

        if (self.has_bind_group) wgpu.wgpuBindGroupRelease(self.bind_group);
        self.bind_group = new_group;
        self.bound_generation = generation;
        self.has_bind_group = true;
        return true;
    }

    pub fn render(
        self: *OutlineRenderer,
        ctx: *const Context,
        pass: wgpu.WGPURenderPassEncoder,
        mask_view: wgpu.WGPUTextureView,
        source_view: wgpu.WGPUTextureView,
        generation: u32,
        width: f32,
        height: f32,
        selected_id: u8,
    ) void {
        if (selected_id == 0 or mask_view == null or source_view == null) return;
        if (width < 1 or height < 1) return;
        if (!self.ensureBindGroup(ctx, mask_view, source_view, generation)) return;

        const uniforms = OutlineUniforms{
            .inv_screen = .{ 1.0 / width, 1.0 / height },
            .selected_id = @floatFromInt(selected_id),
            .thickness_px = thickness_px,
        };
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer, 0, &uniforms, @sizeOf(OutlineUniforms));

        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    }
};
