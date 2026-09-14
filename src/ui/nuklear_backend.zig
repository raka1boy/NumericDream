const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const nk = @import("../bindings/nuklear.zig").c;
const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

const shader_src = @embedFile("shaders/ui.wgsl");

fn growBuffer(device: wgpu.WGPUDevice, buf: *wgpu.WGPUBuffer, cap: *u64, needed: u64, usage: wgpu.WGPUBufferUsage, label: []const u8) bool {
    if (needed <= cap.*) return true;
    const new_cap = std.math.ceilPowerOfTwo(u64, needed) catch needed;
    wgpu.wgpuBufferRelease(buf.*);
    buf.* = wgpu.wgpuDeviceCreateBuffer(device, &wgpu.WGPUBufferDescriptor{
        .nextInChain = null,
        .label = sv(label),
        .usage = usage,
        .size = new_cap,
        .mappedAtCreation = 0,
    }) orelse return false;
    cap.* = new_cap;
    return true;
}

const NkVertex = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    col: [4]u8,
};

const vertex_layout = [_]nk.nk_draw_vertex_layout_element{
    .{ .attribute = nk.NK_VERTEX_POSITION, .format = nk.NK_FORMAT_FLOAT, .offset = @offsetOf(NkVertex, "pos") },
    .{ .attribute = nk.NK_VERTEX_TEXCOORD, .format = nk.NK_FORMAT_FLOAT, .offset = @offsetOf(NkVertex, "uv") },
    .{ .attribute = nk.NK_VERTEX_COLOR, .format = nk.NK_FORMAT_R8G8B8A8, .offset = @offsetOf(NkVertex, "col") },
    .{ .attribute = nk.NK_VERTEX_ATTRIBUTE_COUNT, .format = nk.NK_FORMAT_COUNT, .offset = 0 },
};

const UiUniforms = extern struct {
    projection: [16]f32,
};

pub const NuklearBackend = struct {
    ctx: nk.nk_context,
    atlas: nk.nk_font_atlas,
    font: [*c]nk.nk_font,
    cmds: nk.nk_buffer,
    vbuf: nk.nk_buffer,
    ebuf: nk.nk_buffer,
    null_texture: nk.nk_draw_null_texture,

    pipeline: wgpu.WGPURenderPipeline,
    bind_group: wgpu.WGPUBindGroup,
    uniform_buffer: wgpu.WGPUBuffer,
    font_texture: wgpu.WGPUTexture,
    font_texture_view: wgpu.WGPUTextureView,
    sampler: wgpu.WGPUSampler,

    vertex_buffer: wgpu.WGPUBuffer,
    vertex_buffer_cap: u64,
    index_buffer: wgpu.WGPUBuffer,
    index_buffer_cap: u64,

    pub fn init(gpu_ctx: *const Context) !NuklearBackend {
        var atlas: nk.nk_font_atlas = std.mem.zeroes(nk.nk_font_atlas);
        nk.nk_font_atlas_init_default(&atlas);
        nk.nk_font_atlas_begin(&atlas);
        const font = nk.nk_font_atlas_add_default(&atlas, 16.0, null) orelse return error.NuklearFontLoadFailed;

        var w: c_int = 0;
        var h: c_int = 0;
        const pixels = nk.nk_font_atlas_bake(&atlas, &w, &h, @intCast(nk.NK_FONT_ATLAS_ALPHA8)) orelse
            return error.NuklearFontBakeFailed;

        const font_texture = wgpu.wgpuDeviceCreateTexture(gpu_ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("nuklear font atlas"),
            .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = @intCast(w), .height = @intCast(h), .depthOrArrayLayers = 1 },
            .format = wgpu.WGPUTextureFormat_R8Unorm,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.NuklearFontTextureCreationFailed;

        wgpu.wgpuQueueWriteTexture(
            gpu_ctx.queue,
            &wgpu.WGPUTexelCopyTextureInfo{
                .texture = font_texture,
                .mipLevel = 0,
                .origin = .{ .x = 0, .y = 0, .z = 0 },
                .aspect = wgpu.WGPUTextureAspect_All,
            },
            pixels,
            @intCast(w * h),
            &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = @intCast(w), .rowsPerImage = @intCast(h) },
            &wgpu.WGPUExtent3D{ .width = @intCast(w), .height = @intCast(h), .depthOrArrayLayers = 1 },
        );

        var null_texture: nk.nk_draw_null_texture = undefined;
        nk.nk_font_atlas_end(&atlas, nk.nk_handle_id(1), &null_texture);

        var ctx: nk.nk_context = std.mem.zeroes(nk.nk_context);
        if (nk.nk_init_default(&ctx, &font.*.handle) == 0) return error.NuklearInitFailed;

        var cmds: nk.nk_buffer = std.mem.zeroes(nk.nk_buffer);
        var vbuf: nk.nk_buffer = std.mem.zeroes(nk.nk_buffer);
        var ebuf: nk.nk_buffer = std.mem.zeroes(nk.nk_buffer);
        nk.nk_buffer_init_default(&cmds);
        nk.nk_buffer_init_default(&vbuf);
        nk.nk_buffer_init_default(&ebuf);

        const font_texture_view = wgpu.wgpuTextureCreateView(font_texture, null) orelse return error.NuklearFontViewFailed;
        const sampler = wgpu.wgpuDeviceCreateSampler(gpu_ctx.device, &webgpu_context.linearSamplerDesc(sv("nuklear font sampler"))) orelse return error.NuklearSamplerCreationFailed;

        const uniform_buffer = wgpu.wgpuDeviceCreateBuffer(gpu_ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("nuklear ui uniforms"),
            .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
            .size = @sizeOf(UiUniforms),
            .mappedAtCreation = 0,
        }) orelse return error.NuklearUniformBufferFailed;

        const bgl_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            .{
                .nextInChain = null,
                .binding = 0,
                .visibility = wgpu.WGPUShaderStage_Vertex,
                .bindingArraySize = 0,
                .buffer = .{ .nextInChain = null, .type = wgpu.WGPUBufferBindingType_Uniform, .hasDynamicOffset = 0, .minBindingSize = @sizeOf(UiUniforms) },
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
                .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
                .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 2,
                .visibility = wgpu.WGPUShaderStage_Fragment,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = .{ .nextInChain = null, .sampleType = wgpu.WGPUTextureSampleType_Float, .viewDimension = wgpu.WGPUTextureViewDimension_2D, .multisampled = 0 },
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
        };
        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(gpu_ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("nuklear bind group layout"),
            .entryCount = bgl_entries.len,
            .entries = &bgl_entries,
        }) orelse return error.NuklearBindGroupLayoutFailed;
        defer wgpu.wgpuBindGroupLayoutRelease(bind_group_layout);

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(gpu_ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("nuklear bind group"),
            .layout = bind_group_layout,
            .entryCount = 3,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = uniform_buffer, .offset = 0, .size = @sizeOf(UiUniforms), .sampler = null, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 2, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = font_texture_view },
            },
        }) orelse return error.NuklearBindGroupFailed;

        var shader_desc_wgsl = wgpu.WGPUShaderSourceWGSL{
            .chain = .{ .next = null, .sType = wgpu.WGPUSType_ShaderSourceWGSL },
            .code = sv(shader_src),
        };
        const shader_module = wgpu.wgpuDeviceCreateShaderModule(gpu_ctx.device, &wgpu.WGPUShaderModuleDescriptor{
            .nextInChain = @ptrCast(&shader_desc_wgsl),
            .label = sv("nuklear ui shader"),
        }) orelse return error.NuklearShaderModuleFailed;
        defer wgpu.wgpuShaderModuleRelease(shader_module);

        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(gpu_ctx.device, &wgpu.WGPUPipelineLayoutDescriptor{
            .nextInChain = null,
            .label = sv("nuklear pipeline layout"),
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = &[_]wgpu.WGPUBindGroupLayout{bind_group_layout},
            .immediateSize = 0,
        }) orelse return error.NuklearPipelineLayoutFailed;
        defer wgpu.wgpuPipelineLayoutRelease(pipeline_layout);

        const vertex_attrs = [_]wgpu.WGPUVertexAttribute{
            .{ .nextInChain = null, .format = wgpu.WGPUVertexFormat_Float32x2, .offset = @offsetOf(NkVertex, "pos"), .shaderLocation = 0 },
            .{ .nextInChain = null, .format = wgpu.WGPUVertexFormat_Float32x2, .offset = @offsetOf(NkVertex, "uv"), .shaderLocation = 1 },
            .{ .nextInChain = null, .format = wgpu.WGPUVertexFormat_Unorm8x4, .offset = @offsetOf(NkVertex, "col"), .shaderLocation = 2 },
        };
        const vertex_buffer_layout = wgpu.WGPUVertexBufferLayout{
            .nextInChain = null,
            .stepMode = wgpu.WGPUVertexStepMode_Vertex,
            .arrayStride = @sizeOf(NkVertex),
            .attributeCount = vertex_attrs.len,
            .attributes = &vertex_attrs,
        };

        const blend = wgpu.WGPUBlendState{
            .color = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_SrcAlpha, .dstFactor = wgpu.WGPUBlendFactor_OneMinusSrcAlpha },
            .alpha = .{ .operation = wgpu.WGPUBlendOperation_Add, .srcFactor = wgpu.WGPUBlendFactor_One, .dstFactor = wgpu.WGPUBlendFactor_OneMinusSrcAlpha },
        };
        const color_target = wgpu.WGPUColorTargetState{
            .nextInChain = null,
            .format = gpu_ctx.surface_format,
            .blend = &blend,
            .writeMask = wgpu.WGPUColorWriteMask_All,
        };

        const pipeline = wgpu.wgpuDeviceCreateRenderPipeline(gpu_ctx.device, &wgpu.WGPURenderPipelineDescriptor{
            .nextInChain = null,
            .label = sv("nuklear pipeline"),
            .layout = pipeline_layout,
            .vertex = .{
                .nextInChain = null,
                .module = shader_module,
                .entryPoint = sv("vs_main"),
                .constantCount = 0,
                .constants = null,
                .bufferCount = 1,
                .buffers = &[_]wgpu.WGPUVertexBufferLayout{vertex_buffer_layout},
            },
            .primitive = webgpu_context.default_primitive_state,
            .depthStencil = null,
            .multisample = webgpu_context.default_multisample_state,
            .fragment = &wgpu.WGPUFragmentState{
                .nextInChain = null,
                .module = shader_module,
                .entryPoint = sv("fs_main"),
                .constantCount = 0,
                .constants = null,
                .targetCount = 1,
                .targets = &[_]wgpu.WGPUColorTargetState{color_target},
            },
        }) orelse return error.NuklearPipelineCreationFailed;

        const initial_vcap: u64 = 256 * 1024 * @sizeOf(NkVertex);
        const initial_icap: u64 = 64 * 1024 * @sizeOf(u16);
        const vertex_buffer = wgpu.wgpuDeviceCreateBuffer(gpu_ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("nuklear vertices"),
            .usage = wgpu.WGPUBufferUsage_Vertex | wgpu.WGPUBufferUsage_CopyDst,
            .size = initial_vcap,
            .mappedAtCreation = 0,
        }) orelse return error.NuklearVertexBufferFailed;
        const index_buffer = wgpu.wgpuDeviceCreateBuffer(gpu_ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("nuklear indices"),
            .usage = wgpu.WGPUBufferUsage_Index | wgpu.WGPUBufferUsage_CopyDst,
            .size = initial_icap,
            .mappedAtCreation = 0,
        }) orelse return error.NuklearIndexBufferFailed;

        return .{
            .ctx = ctx,
            .atlas = atlas,
            .font = font,
            .cmds = cmds,
            .vbuf = vbuf,
            .ebuf = ebuf,
            .null_texture = null_texture,
            .pipeline = pipeline,
            .bind_group = bind_group,
            .uniform_buffer = uniform_buffer,
            .font_texture = font_texture,
            .font_texture_view = font_texture_view,
            .sampler = sampler,
            .vertex_buffer = vertex_buffer,
            .vertex_buffer_cap = initial_vcap,
            .index_buffer = index_buffer,
            .index_buffer_cap = initial_icap,
        };
    }

    pub fn deinit(self: *NuklearBackend) void {
        wgpu.wgpuBufferRelease(self.vertex_buffer);
        wgpu.wgpuBufferRelease(self.index_buffer);
        wgpu.wgpuRenderPipelineRelease(self.pipeline);
        wgpu.wgpuBindGroupRelease(self.bind_group);
        wgpu.wgpuBufferRelease(self.uniform_buffer);
        wgpu.wgpuSamplerRelease(self.sampler);
        wgpu.wgpuTextureViewRelease(self.font_texture_view);
        wgpu.wgpuTextureRelease(self.font_texture);
        nk.nk_buffer_free(&self.cmds);
        nk.nk_buffer_free(&self.vbuf);
        nk.nk_buffer_free(&self.ebuf);
        nk.nk_font_atlas_clear(&self.atlas);
        nk.nk_free(&self.ctx);
    }

    pub fn beginInput(self: *NuklearBackend) void {
        nk.nk_input_begin(&self.ctx);
    }

    pub fn endInput(self: *NuklearBackend) void {
        nk.nk_input_end(&self.ctx);
    }

    pub fn discardFrame(self: *NuklearBackend) void {
        nk.nk_clear(&self.ctx);
    }

    pub fn isHoveringUi(self: *const NuklearBackend) bool {
        return nk.nk_window_is_any_hovered(&self.ctx) != 0;
    }

    pub fn handleSdlEvent(self: *NuklearBackend, event: *const sdl.SDL_Event) void {
        switch (event.type) {
            sdl.SDL_EVENT_MOUSE_MOTION => {
                nk.nk_input_motion(&self.ctx, @intFromFloat(event.motion.x), @intFromFloat(event.motion.y));
            },
            sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                const down: nk.nk_bool = if (event.button.down) 1 else 0;
                const x: c_int = @intFromFloat(event.button.x);
                const y: c_int = @intFromFloat(event.button.y);
                const button: c_uint = switch (event.button.button) {
                    @as(u8, sdl.SDL_BUTTON_LEFT) => nk.NK_BUTTON_LEFT,
                    @as(u8, sdl.SDL_BUTTON_RIGHT) => nk.NK_BUTTON_RIGHT,
                    @as(u8, sdl.SDL_BUTTON_MIDDLE) => nk.NK_BUTTON_MIDDLE,
                    else => return,
                };
                nk.nk_input_button(&self.ctx, button, x, y, down);
            },
            sdl.SDL_EVENT_MOUSE_WHEEL => {
                nk.nk_input_scroll(&self.ctx, .{ .x = event.wheel.x, .y = event.wheel.y });
            },
            sdl.SDL_EVENT_TEXT_INPUT => {
                const text: [*:0]const u8 = @ptrCast(event.text.text);
                const view = std.unicode.Utf8View.initUnchecked(std.mem.span(text));
                var it = view.iterator();
                while (it.nextCodepoint()) |cp| {
                    nk.nk_input_unicode(&self.ctx, cp);
                }
            },
            sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_KEY_UP => {
                const down: nk.nk_bool = if (event.key.down) 1 else 0;
                const ctrl_held = (event.key.mod & sdl.SDL_KMOD_CTRL) != 0;
                const down_ctrl: nk.nk_bool = if (event.key.down and ctrl_held) 1 else 0;
                switch (event.key.scancode) {
                    sdl.SDL_SCANCODE_LSHIFT, sdl.SDL_SCANCODE_RSHIFT => nk.nk_input_key(&self.ctx, nk.NK_KEY_SHIFT, down),
                    sdl.SDL_SCANCODE_DELETE => nk.nk_input_key(&self.ctx, nk.NK_KEY_DEL, down),
                    sdl.SDL_SCANCODE_RETURN, sdl.SDL_SCANCODE_KP_ENTER => nk.nk_input_key(&self.ctx, nk.NK_KEY_ENTER, down),
                    sdl.SDL_SCANCODE_TAB => nk.nk_input_key(&self.ctx, nk.NK_KEY_TAB, down),
                    sdl.SDL_SCANCODE_BACKSPACE => nk.nk_input_key(&self.ctx, nk.NK_KEY_BACKSPACE, down),
                    sdl.SDL_SCANCODE_HOME => {
                        nk.nk_input_key(&self.ctx, nk.NK_KEY_TEXT_START, down);
                        nk.nk_input_key(&self.ctx, nk.NK_KEY_SCROLL_START, down);
                    },
                    sdl.SDL_SCANCODE_END => {
                        nk.nk_input_key(&self.ctx, nk.NK_KEY_TEXT_END, down);
                        nk.nk_input_key(&self.ctx, nk.NK_KEY_SCROLL_END, down);
                    },
                    sdl.SDL_SCANCODE_PAGEDOWN => nk.nk_input_key(&self.ctx, nk.NK_KEY_SCROLL_DOWN, down),
                    sdl.SDL_SCANCODE_PAGEUP => nk.nk_input_key(&self.ctx, nk.NK_KEY_SCROLL_UP, down),
                    sdl.SDL_SCANCODE_C => nk.nk_input_key(&self.ctx, nk.NK_KEY_COPY, down_ctrl),
                    sdl.SDL_SCANCODE_V => nk.nk_input_key(&self.ctx, nk.NK_KEY_PASTE, down_ctrl),
                    sdl.SDL_SCANCODE_X => nk.nk_input_key(&self.ctx, nk.NK_KEY_CUT, down_ctrl),
                    sdl.SDL_SCANCODE_Z => nk.nk_input_key(&self.ctx, nk.NK_KEY_TEXT_UNDO, down_ctrl),
                    sdl.SDL_SCANCODE_Y => nk.nk_input_key(&self.ctx, nk.NK_KEY_TEXT_REDO, down_ctrl),
                    sdl.SDL_SCANCODE_A => nk.nk_input_key(&self.ctx, nk.NK_KEY_TEXT_SELECT_ALL, down_ctrl),
                    sdl.SDL_SCANCODE_UP => nk.nk_input_key(&self.ctx, nk.NK_KEY_UP, down),
                    sdl.SDL_SCANCODE_DOWN => nk.nk_input_key(&self.ctx, nk.NK_KEY_DOWN, down),
                    sdl.SDL_SCANCODE_LEFT => nk.nk_input_key(&self.ctx, if (ctrl_held) nk.NK_KEY_TEXT_WORD_LEFT else nk.NK_KEY_LEFT, down),
                    sdl.SDL_SCANCODE_RIGHT => nk.nk_input_key(&self.ctx, if (ctrl_held) nk.NK_KEY_TEXT_WORD_RIGHT else nk.NK_KEY_RIGHT, down),
                    else => {},
                }
            },
            else => {},
        }
    }

    pub fn render(self: *NuklearBackend, gpu_ctx: *const Context, pass: wgpu.WGPURenderPassEncoder, width: f32, height: f32) void {
        const projection = orthoProjection(width, height);
        wgpu.wgpuQueueWriteBuffer(gpu_ctx.queue, self.uniform_buffer, 0, &UiUniforms{ .projection = projection }, @sizeOf(UiUniforms));

        nk.nk_buffer_clear(&self.cmds);
        nk.nk_buffer_clear(&self.vbuf);
        nk.nk_buffer_clear(&self.ebuf);

        const convert_config = nk.nk_convert_config{
            .global_alpha = 1.0,
            .line_AA = @intCast(nk.NK_ANTI_ALIASING_ON),
            .shape_AA = @intCast(nk.NK_ANTI_ALIASING_ON),
            .circle_segment_count = 22,
            .arc_segment_count = 22,
            .curve_segment_count = 22,
            .tex_null = self.null_texture,
            .vertex_layout = &vertex_layout,
            .vertex_size = @sizeOf(NkVertex),
            .vertex_alignment = @alignOf(NkVertex),
        };
        _ = nk.nk_convert(&self.ctx, &self.cmds, &self.vbuf, &self.ebuf, &convert_config);

        const vbytes: u64 = @intCast(self.vbuf.needed);
        const ibytes: u64 = @intCast(self.ebuf.needed);
        if (!growBuffer(gpu_ctx.device, &self.vertex_buffer, &self.vertex_buffer_cap, vbytes, wgpu.WGPUBufferUsage_Vertex | wgpu.WGPUBufferUsage_CopyDst, "nuklear vertices")) {
            nk.nk_clear(&self.ctx);
            return;
        }
        if (!growBuffer(gpu_ctx.device, &self.index_buffer, &self.index_buffer_cap, ibytes, wgpu.WGPUBufferUsage_Index | wgpu.WGPUBufferUsage_CopyDst, "nuklear indices")) {
            nk.nk_clear(&self.ctx);
            return;
        }
        if (vbytes > 0) wgpu.wgpuQueueWriteBuffer(gpu_ctx.queue, self.vertex_buffer, 0, self.vbuf.memory.ptr, std.mem.alignForward(u64, vbytes, 4));
        if (ibytes > 0) wgpu.wgpuQueueWriteBuffer(gpu_ctx.queue, self.index_buffer, 0, self.ebuf.memory.ptr, std.mem.alignForward(u64, ibytes, 4));

        wgpu.wgpuRenderPassEncoderSetPipeline(pass, self.pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(pass, 0, self.bind_group, 0, null);
        wgpu.wgpuRenderPassEncoderSetVertexBuffer(pass, 0, self.vertex_buffer, 0, vbytes);
        wgpu.wgpuRenderPassEncoderSetIndexBuffer(pass, self.index_buffer, wgpu.WGPUIndexFormat_Uint16, 0, ibytes);

        var offset: u32 = 0;
        var cmd = nk.nk__draw_begin(&self.ctx, &self.cmds);
        while (cmd != null) : (cmd = nk.nk__draw_next(cmd, &self.cmds, &self.ctx)) {
            if (cmd.*.elem_count == 0) continue;
            const clip = cmd.*.clip_rect;
            const x: u32 = @intFromFloat(@max(clip.x, 0));
            const y: u32 = @intFromFloat(@max(clip.y, 0));
            const w: u32 = @intFromFloat(@max(clip.w, 0));
            const h: u32 = @intFromFloat(@max(clip.h, 0));
            wgpu.wgpuRenderPassEncoderSetScissorRect(
                pass,
                @min(x, @as(u32, @intFromFloat(width))),
                @min(y, @as(u32, @intFromFloat(height))),
                @min(w, @as(u32, @intFromFloat(width)) -| x),
                @min(h, @as(u32, @intFromFloat(height)) -| y),
            );
            wgpu.wgpuRenderPassEncoderDrawIndexed(pass, cmd.*.elem_count, 1, offset, 0, 0);
            offset += cmd.*.elem_count;
        }

        nk.nk_clear(&self.ctx);
    }
};

fn orthoProjection(width: f32, height: f32) [16]f32 {
    //maps screenspace to wgpus clip space
    const l: f32 = 0;
    const r: f32 = width;
    const t: f32 = 0;
    const b: f32 = height;
    return .{
        2.0 / (r - l),     0,                 0,   0,
        0,                 2.0 / (t - b),     0,   0,
        0,                 0,                 0.5, 0,
        (r + l) / (l - r), (t + b) / (b - t), 0.5, 1,
    };
}
