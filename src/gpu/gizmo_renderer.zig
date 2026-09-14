const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

const shader_src = @embedFile("shaders/gizmo.wgsl");

pub const GizmoVertex = extern struct {
    position: [3]f32,
    color: [3]f32,
};

pub const max_vertices = 256;

const GizmoUniforms = extern struct {
    camera_pos: [3]f32,
    aspect: f32,
    camera_right: [3]f32,
    _pad0: f32 = 0,
    camera_up: [3]f32,
    _pad1: f32 = 0,
    camera_forward: [3]f32,
    slice_zoom: f32 = 0,
};

pub const GizmoRenderer = struct {
    pipeline: wgpu.WGPURenderPipeline,
    pipeline_layout: wgpu.WGPUPipelineLayout,
    bind_group_layout: wgpu.WGPUBindGroupLayout,
    bind_group: wgpu.WGPUBindGroup,
    uniform_buffer: wgpu.WGPUBuffer,
    vertex_buffer: wgpu.WGPUBuffer,

    pub fn init(ctx: *const Context) !GizmoRenderer {
        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("gizmo uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(GizmoUniforms),
            .mappedAtCreation = 0,
        }) orelse return error.BufferCreationFailed;

        const bgl_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Vertex,
            .bindingArraySize = 0,
            .buffer = .{
                .nextInChain = null,
                .type = wgpu.WGPUBufferBindingType_Uniform,
                .hasDynamicOffset = 0,
                .minBindingSize = @sizeOf(GizmoUniforms),
            },
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("gizmo bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{bgl_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("gizmo bind group"),
            .layout = bind_group_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = 0,
                .buffer = uniform_buffer,
                .offset = 0,
                .size = @sizeOf(GizmoUniforms),
                .sampler = null,
                .textureView = null,
            }},
        }) orelse return error.BindGroupCreationFailed;

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("gizmo pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{bind_group_layout},
            .immediateSize = 0,
        }) orelse return error.PipelineLayoutCreationFailed;

        var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(shader_src),
        };
        const module = wgpu.wgpuDeviceCreateShaderModule(ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&shader_desc_wgsl),
            .label = sv("gizmo shader"),
        }) orelse return error.ShaderModuleCreationFailed;
        defer wgpu.wgpuShaderModuleRelease(module);

        const vertex_attrs = [_]wgpu.WGPUVertexAttribute{
            .{ .nextInChain = null, .format = wgpu.WGPUVertexFormat_Float32x3, .offset = @offsetOf(GizmoVertex, "position"), .shaderLocation = 0 },
            .{ .nextInChain = null, .format = wgpu.WGPUVertexFormat_Float32x3, .offset = @offsetOf(GizmoVertex, "color"), .shaderLocation = 1 },
        };
        const vertex_buffer_layout = wgpu.WGPUVertexBufferLayout{
            .nextInChain = null,
            .stepMode = wgpu.WGPUVertexStepMode_Vertex,
            .arrayStride = @sizeOf(GizmoVertex),
            .attributeCount = vertex_attrs.len,
            .attributes = &vertex_attrs,
        };

        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = ctx.surface_format,
            .blend = null,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };

        const pipeline = wgpu.wgpuDeviceCreateRenderPipeline(ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("gizmo pipeline"),
            .layout = pipeline_layout,
            .vertex = .{
                .nextInChain = null,
                .module = module,
                .entryPoint = sv("vs_main"),
                .constantCount = 0,
                .constants = null,
                .bufferCount = 1,
                .buffers = &[_]wgpu.WGPUVertexBufferLayout{vertex_buffer_layout},
            },
            .primitive = .{
                .nextInChain = null,
                .topology = wgpu.WGPUPrimitiveTopology_LineList,
                .stripIndexFormat = wgpu.WGPUIndexFormat_Undefined,
                .frontFace = wgpu.WGPUFrontFace_CCW,
                .cullMode = wgpu.WGPUCullMode_None,
                .unclippedDepth = 0,
            },
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

        const vertex_buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("gizmo vertices"),
            .usage = wgpu.WGPUBufferUsage_Vertex | wgpu.WGPUBufferUsage_CopyDst,
            .size = max_vertices * @sizeOf(GizmoVertex),
            .mappedAtCreation = 0,
        }) orelse return error.VertexBufferCreationFailed;

        return .{
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .bind_group_layout = bind_group_layout,
            .bind_group = bind_group,
            .uniform_buffer = uniform_buffer,
            .vertex_buffer = vertex_buffer,
        };
    }

    pub fn deinit(self: *GizmoRenderer) void {
        wgpu.wgpuBufferRelease(self.vertex_buffer);
        wgpu.wgpuRenderPipelineRelease(self.pipeline);
        wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuBindGroupLayoutRelease(self.bind_group_layout);
        wgpu.wgpuPipelineLayoutRelease(self.pipeline_layout);
        wgpu.wgpuBufferRelease(self.uniform_buffer);
    }

    pub fn render(
        self: *GizmoRenderer,
        ctx: *const Context,
        pass: wgpu.WGPURenderPassEncoder,
        vertices: []const GizmoVertex,
        camera_pos: [3]f32,
        camera_right: [3]f32,
        camera_up: [3]f32,
        camera_forward: [3]f32,
        aspect: f32,
        slice_zoom: f32,
    ) void {
        if (vertices.len == 0) return;
        const n = @min(vertices.len, max_vertices);

        const uniforms = GizmoUniforms{
            .camera_pos = camera_pos,
            .aspect = aspect,
            .camera_right = camera_right,
            .camera_up = camera_up,
            .camera_forward = camera_forward,
            .slice_zoom = slice_zoom,
        };
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.uniform_buffer, 0, &uniforms, @sizeOf(GizmoUniforms));

        const bytes: u64 = n * @sizeOf(GizmoVertex);
        wgpu.wgpuQueueWriteBuffer(ctx.queue, self.vertex_buffer, 0, vertices.ptr, bytes);

        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetVertexBuffer(pass, 0, self.vertex_buffer, 0, bytes);
        wgpu.wgpuRenderPassEncoderDraw(pass, @intCast(n), 1, 0, 0);
    }
};
