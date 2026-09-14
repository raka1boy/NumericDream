const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const g_error_sink = &webgpu_context.g_error_sink;
const sv = webgpu_context.sv;

const shader_src = @embedFile("shaders/progress.wgsl");

const Uniforms = extern struct {
    progress: f32,
    aspect: f32,
    digit0: f32 = 0,
    digit1: f32 = 0,
    digit2: f32 = 0,
    button_hover: f32 = 0,
    _pad1: f32 = 0,
    _pad2: f32 = 0,
};

pub const CancelButtonRect = struct { x0: f32, y0: f32, x1: f32, y1: f32 };

pub fn cancelButtonRect(width: u32, height: u32) CancelButtonRect {
    const h: f32 = @floatFromInt(@max(height, 1));
    const aspect = @as(f32, @floatFromInt(width)) / h;
    const cx = 0.5 * aspect;
    const cy = 0.62;
    const size = 0.09;
    return .{
        .x0 = (cx - size * 0.5) * h,
        .y0 = (cy - size * 0.5) * h,
        .x1 = (cx + size * 0.5) * h,
        .y1 = (cy + size * 0.5) * h,
    };
}

const digit_segments = [10]u8{ 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F };
const blank_segments: u8 = 0x00;

pub const ProgressOverlay = struct {
    pipeline: wgpu.WGPURenderPipeline,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    bind_group_layout: wgpu.WGPUBindGroupLayout,
    bind_group: wgpu.WGPUBindGroup,
    uniform_buffer: wgpu.WGPUBuffer,

    pub fn init(ctx: *const Context) !ProgressOverlay {
        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(Uniforms),
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;

        const bgl_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Fragment,
            .bindingArraySize = 0,
            .buffer = .{
                .nextInChain = null,
                .type = wgpu.WGPUBufferBindingType_Uniform,
                .hasDynamicOffset = 0,
                .minBindingSize = @sizeOf(Uniforms),
            },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{bgl_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        defer wgpu.wgpuBindGroupLayoutRelease(bind_group_layout);

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay bind group"),
            .layout = bind_group_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = 0,
                .buffer = uniform_buffer,
                .offset = 0,
                .size = @sizeOf(Uniforms),
                .sampler = null,
                .textureView = null,
            }},
        }) orelse return error.BindGroupCreationFailed;

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{bind_group_layout},
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        g_error_sink.reset();

        var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(shader_src),
        };
        const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&shader_desc_wgsl),
            .label = sv("progress overlay shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        defer wgpu.wgpuShaderModuleRelease(module);

        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (g_error_sink.has_error) {
            return error.ShaderCompileFailed;
        }

        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = ctx.surface_format,
            .blend = null,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };
        const pipeline = wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay pipeline"),
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
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        wgpu.wgpuInstanceProcessEvents(ctx.instance);
        if (g_error_sink.has_error) {
            wgpu.wgpuRenderPipelineRelease(pipeline);
            return error.PipelineCreationFailed;
        }

        return .{
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .bind_group_layout = bind_group_layout,
            .bind_group = bind_group,
            .uniform_buffer = uniform_buffer,
        };
    }

    pub fn deinit(self: *ProgressOverlay) void {
        wgpu.wgpuRenderPipelineRelease(self.pipeline);
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuBufferRelease(self.uniform_buffer);
    }

    pub fn draw(self: *ProgressOverlay, ctx: *Context, progress: f32, cancel_hover: bool) void {
        const pct = std.math.clamp(@round(progress * 100.0), 0.0, 100.0);
        const percent: u32 = @intFromFloat(pct);
        const hundreds = percent / 100;
        const tens = (percent / 10) % 10;
        const ones = percent % 10;

        const uniforms = Uniforms{
            .progress = std.math.clamp(progress, 0.0, 1.0),
            .aspect = @as(f32, @floatFromInt(ctx.width)) / @as(f32, @floatFromInt(@max(ctx.height, 1))),
            .digit0 = @floatFromInt(if (hundreds > 0) digit_segments[hundreds] else blank_segments),
            .digit1 = @floatFromInt(if (hundreds > 0 or tens > 0) digit_segments[tens] else blank_segments),
            .digit2 = @floatFromInt(digit_segments[ones]),
            .button_hover = if (cancel_hover) 1.0 else 0.0,
        };
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer, 0, &uniforms, @sizeOf(Uniforms));

        const frame = ctx.beginFrame() orelse return;
        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(frame.encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("progress overlay pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = frame.view,
                .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                .resolveTarget = null,
                .loadOp = wgpu.WGPULoadOp_Clear,
                .storeOp = wgpu.WGPUStoreOp_Store,
                .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            }},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }).?;
        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);
        ctx.endFrame(frame);
    }
};
