const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;
const fractal_gpu = @import("fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const Uniforms = fractal_gpu.Uniforms;

pub const size: u32 = 320;
const uniform_slot: u32 = fractal_gpu.uniform_ring_slots - 1;
const image_id_base: u32 = 1 << 30;

pub const NavigatorRenderer = struct {
    accum_texture: wgpu.WGPUTexture = null,
    accum_view: wgpu.WGPUTextureView = null,
    gbuf: fractal_gpu.GBuffer = .{},
    display_texture: wgpu.WGPUTexture = null,
    display_view: wgpu.WGPUTextureView = null,
    resolve_group: wgpu.WGPUBindGroup = null,
    image_id: u32 = image_id_base,
    drawn_key: ?u64 = null,

    pub fn deinit(self: *NavigatorRenderer) void {
        if (self.resolve_group != null) wgpu.wgpuBindGroupRelease(self.resolve_group);
        if (self.display_view != null) wgpu.wgpuTextureViewRelease(self.display_view);
        if (self.display_texture != null) wgpu.wgpuTextureRelease(self.display_texture);
        if (self.accum_view != null) wgpu.wgpuTextureViewRelease(self.accum_view);
        if (self.accum_texture != null) wgpu.wgpuTextureRelease(self.accum_texture);
        fractal_gpu.releaseGBuffer(self.gbuf);
        const next_id = self.image_id +% 1;
        self.* = .{ .image_id = next_id };
    }

    pub fn ready(self: *const NavigatorRenderer) bool {
        return self.display_view != null and self.drawn_key != null;
    }

    fn texture(ctx: *const Context, label: []const u8, format: wgpu.WGPUTextureFormat) wgpu.WGPUTexture {
        return wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv(label),
            .usage = wgpu.WGPUTextureUsage_RenderAttachment | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = size, .height = size, .depthOrArrayLayers = 1 },
            .format = format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        });
    }

    fn ensure(self: *NavigatorRenderer, ctx: *const Context, fractal: *const FractalRenderer) bool {
        if (self.resolve_group != null) return true;
        if (self.create(ctx, fractal)) return true;
        self.deinit();
        return false;
    }

    fn create(self: *NavigatorRenderer, ctx: *const Context, fractal: *const FractalRenderer) bool {
        self.accum_texture = texture(ctx, "navigator accumulation", fractal_gpu.accumFormat(ctx)) orelse return false;
        self.accum_view = wgpu.wgpuTextureCreateView(self.accum_texture, null) orelse return false;
        self.gbuf = fractal_gpu.createGBuffer(ctx, size, size);
        self.display_texture = texture(ctx, "navigator display", ctx.surface_format) orelse return false;
        self.display_view = wgpu.wgpuTextureCreateView(self.display_texture, null) orelse return false;
        self.resolve_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("navigator resolve bind group"),
            .layout = fractal.blit_bind_group_layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = fractal.sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = self.accum_view },
            },
        }) orelse return false;
        return self.gbuf.depth_view != null and self.gbuf.normal_view != null;
    }

    pub fn render(self: *NavigatorRenderer, ctx: *const Context, fractal: *FractalRenderer, encoder: wgpu.WGPUCommandEncoder, uniforms: Uniforms) void {
        if (!fractal.drawReady(ctx, .slice)) return;
        if (!self.ensure(ctx, fractal)) return;
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&uniforms));
        const generation = fractal.imageGeneration();
        h.update(std.mem.asBytes(&generation));
        const key = h.final();
        if (self.drawn_key) |k| {
            if (k == key) return;
        }

        fractal.writeUniformSlot(ctx, uniform_slot, uniforms);
        const attachments = fractal_gpu.marchAttachments(self.accum_view, self.gbuf, false);
        const pass = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("navigator slice pass"),
            .colorAttachmentCount = attachments.len,
            .colorAttachments = &attachments,
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }) orelse return;
        fractal.drawSlot(pass, 1.0, .slice, uniform_slot);
        wgpu.wgpuRenderPassEncoderEnd(pass);
        wgpu.wgpuRenderPassEncoderRelease(pass);

        const resolve = wgpu.wgpuCommandEncoderBeginRenderPass(encoder, &wgpu.WGPURenderPassDescriptor{
            .nextInChain = null,
            .label = sv("navigator resolve pass"),
            .colorAttachmentCount = 1,
            .colorAttachments = &[_]wgpu.WGPURenderPassColorAttachment{.{
                .nextInChain = null,
                .view = self.display_view,
                .depthSlice = wgpu.WGPU_DEPTH_SLICE_UNDEFINED,
                .resolveTarget = null,
                .loadOp = wgpu.WGPULoadOp_Clear,
                .storeOp = wgpu.WGPUStoreOp_Store,
                .clearValue = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            }},
            .depthStencilAttachment = null,
            .occlusionQuerySet = null,
            .timestampWrites = null,
        }) orelse return;
        wgpu.wgpuRenderPassEncoderSetPipeline(resolve, fractal.blit_pipeline);
        wgpu.wgpuRenderPassEncoderSetBindGroup(resolve, 0, self.resolve_group, 0, null);
        wgpu.wgpuRenderPassEncoderDraw(resolve, 3, 1, 0, 0);
        wgpu.wgpuRenderPassEncoderEnd(resolve);
        wgpu.wgpuRenderPassEncoderRelease(resolve);
        self.drawn_key = key;
    }
};
