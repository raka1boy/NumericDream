const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const perf_probe = @import("../app/perf_probe.zig");
const oidn = @import("../bindings/oidn.zig");
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;
const fractal_gpu = @import("fractal_renderer.zig");
const FractalRenderer = fractal_gpu.FractalRenderer;
const MapState = fractal_gpu.MapState;

const settle_ms: u64 = 150;
const aov_bytes_per_pixel: u32 = 8;
const image_count = 3;

const Phase = enum { idle, mapping, denoising };

const Images = struct {
    w: u32 = 0,
    h: u32 = 0,
    color_bpp: u32 = 0,
    rows: [image_count]u32 = .{ 0, 0, 0 },
    sizes: [image_count]u64 = .{ 0, 0, 0 },
};

pub const PreviewDenoiser = struct {
    phase: Phase = .idle,

    epoch: u64 = 1,
    image_key: u64 = 1,
    last_reset_ms: u64 = 0,
    captured_key: u64 = 0,

    job_epoch: u64 = 0,
    job_key: u64 = 0,
    job_clean_aux: bool = true,
    job_float32: bool = true,
    job: Images = .{},

    buffers: [image_count]wgpu.WGPUBuffer = .{ null, null, null },
    buffer_layout: Images = .{},
    map_states: [image_count]MapState = .{ .{}, .{}, .{} },
    map_issued: [image_count]bool = .{ false, false, false },

    aov_albedo: wgpu.WGPUTexture = null,
    aov_albedo_view: wgpu.WGPUTextureView = null,
    aov_normal: wgpu.WGPUTexture = null,
    aov_normal_view: wgpu.WGPUTextureView = null,
    aov_w: u32 = 0,
    aov_h: u32 = 0,

    cpu: [image_count][]u8 = .{ &.{}, &.{}, &.{} },
    cpu_out: []u8 = &.{},

    strength: f32 = 1.0,
    job_strength: f32 = 1.0,

    thread: ?std.Thread = null,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    ok: bool = false,
    started_ms: u64 = 0,

    shown: wgpu.WGPUTexture = null,
    shown_view: wgpu.WGPUTextureView = null,
    shown_group: wgpu.WGPUBindGroup = null,
    shown_w: u32 = 0,
    shown_h: u32 = 0,
    shown_epoch: u64 = 0,

    pub fn deinit(self: *PreviewDenoiser) void {
        if (self.thread) |t| t.join();
        self.thread = null;
        self.releaseBuffers();
        self.releaseAovTargets();
        self.releaseShown();
        for (&self.cpu) |*c| {
            if (c.len > 0) std.heap.page_allocator.free(c.*);
            c.* = &.{};
        }
        if (self.cpu_out.len > 0) std.heap.page_allocator.free(self.cpu_out);
        self.cpu_out = &.{};
    }

    fn needsCapture(self: *const PreviewDenoiser) bool {
        return self.captured_key != self.image_key or self.job_strength != self.strength;
    }

    pub fn noteDraw(self: *PreviewDenoiser, fractal: *FractalRenderer, fresh_image: bool, now_ms: u64) void {
        self.image_key +%= 1;
        if (!fresh_image) return;
        self.epoch +%= 1;
        self.last_reset_ms = now_ms;
        fractal.display_override = null;
    }

    pub fn busy(self: *const PreviewDenoiser, wanted: bool) bool {
        return self.phase != .idle or (wanted and self.needsCapture());
    }

    pub fn update(self: *PreviewDenoiser, ctx: *const Context, fractal: *FractalRenderer, wanted: bool) void {
        if (!wanted) fractal.display_override = null;

        if (self.phase == .mapping) {
            wgpu.wgpuInstanceProcessEvents(ctx.instance);
            var all_done = true;
            var any_failed = false;
            for (self.map_states) |s| {
                if (!s.done) all_done = false else if (s.status != wgpu.WGPUMapAsyncStatus_Success) any_failed = true;
            }
            if (all_done) {
                if (any_failed or !self.copyMappedToCpu()) {
                    self.unmapAll();
                    self.phase = .idle;
                    std.debug.print("[denoise] preview readback failed\n", .{});
                } else {
                    self.unmapAll();
                    self.startWorker();
                }
            }
        }

        if (self.phase == .denoising and self.done.load(.acquire)) {
            self.thread.?.join();
            self.thread = null;
            self.phase = .idle;
            if (self.ok and wanted and self.job_epoch == self.epoch) {
                self.present(ctx, fractal);
            }
        }
    }

    pub fn maybeCapture(self: *PreviewDenoiser, ctx: *const Context, fractal: *FractalRenderer, wanted: bool, clean_aux: bool, now_ms: u64) void {
        if (!wanted or self.phase != .idle) return;
        if (!self.needsCapture()) return;
        if (now_ms -| self.last_reset_ms < settle_ms) return;
        self.captured_key = self.image_key;
        self.job_strength = self.strength;
        self.capture(ctx, fractal, clean_aux) catch |err| {
            std.debug.print("[denoise] preview capture skipped ({s})\n", .{@errorName(err)});
        };
    }

    fn capture(self: *PreviewDenoiser, ctx: *const Context, fractal: *FractalRenderer, clean_aux: bool) !void {
        const w = fractal.offscreen_width;
        const h = fractal.offscreen_height;
        if (w == 0 or h == 0 or fractal.offscreen_texture == null) return error.NoPreviewImage;
        try fractal.ensureAovPipeline(ctx);
        try self.ensureAovTargets(ctx, w, h);
        try self.ensureBuffers(ctx, w, h, ctx.float32_accum);

        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(ctx.device, null) orelse return error.EncoderCreationFailed;
        fractal.encodeAovPass(encoder, self.aov_albedo_view, self.aov_normal_view, false, 0, 1.0, null);
        const textures = [image_count]wgpu.WGPUTexture{ fractal.offscreen_texture, self.aov_albedo, self.aov_normal };
        for (0..image_count) |i| {
            wgpu.wgpuCommandEncoderCopyTextureToBuffer(
                encoder,
                &wgpu.WGPUTexelCopyTextureInfo{ .texture = textures[i], .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
                &wgpu.WGPUTexelCopyBufferInfo{ .layout = .{ .offset = 0, .bytesPerRow = self.buffer_layout.rows[i], .rowsPerImage = h }, .buffer = self.buffers[i] },
                &wgpu.WGPUExtent3D{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            );
        }
        const cmd = wgpu.wgpuCommandEncoderFinish(encoder, null);
        wgpu.wgpuCommandEncoderRelease(encoder);
        wgpu.wgpuQueueSubmit(ctx.queue, 1, &cmd);
        wgpu.wgpuCommandBufferRelease(cmd);

        for (0..image_count) |i| {
            self.map_states[i] = .{};
            self.map_issued[i] = true;
            _ = wgpu.wgpuBufferMapAsync(self.buffers[i], wgpu.WGPUMapMode_Read, 0, self.buffer_layout.sizes[i], wgpu.WGPUBufferMapCallbackInfo{
                .nextInChain = null,
                .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
                .callback = fractal_gpu.onBufferMapped,
                .userdata1 = &self.map_states[i],
                .userdata2 = null,
            });
        }

        self.job = self.buffer_layout;
        self.job_epoch = self.epoch;
        self.job_key = self.image_key;
        self.job_float32 = ctx.float32_accum;
        self.job_clean_aux = clean_aux;
        self.started_ms = sdl.SDL_GetTicks();
        self.phase = .mapping;
    }

    fn copyMappedToCpu(self: *PreviewDenoiser) bool {
        for (0..image_count) |i| {
            const size: usize = @intCast(self.job.sizes[i]);
            if (self.cpu[i].len != size) {
                if (self.cpu[i].len > 0) std.heap.page_allocator.free(self.cpu[i]);
                self.cpu[i] = std.heap.page_allocator.alloc(u8, size) catch {
                    self.cpu[i] = &.{};
                    return false;
                };
            }
            const ptr = wgpu.wgpuBufferGetConstMappedRange(self.buffers[i], 0, size) orelse return false;
            const src: [*]const u8 = @ptrCast(ptr);
            @memcpy(self.cpu[i], src[0..size]);
        }
        if (self.cpu_out.len != self.cpu[0].len) {
            if (self.cpu_out.len > 0) std.heap.page_allocator.free(self.cpu_out);
            self.cpu_out = std.heap.page_allocator.alloc(u8, self.cpu[0].len) catch {
                self.cpu_out = &.{};
                return false;
            };
        }
        return true;
    }

    fn unmapAll(self: *PreviewDenoiser) void {
        for (0..image_count) |i| {
            if (self.map_issued[i] and self.map_states[i].done and self.map_states[i].status == wgpu.WGPUMapAsyncStatus_Success) {
                wgpu.wgpuBufferUnmap(self.buffers[i]);
            }
            self.map_issued[i] = false;
        }
    }

    fn startWorker(self: *PreviewDenoiser) void {
        self.done.store(false, .release);
        self.ok = false;
        self.thread = std.Thread.spawn(.{}, worker, .{self}) catch |err| {
            std.debug.print("[denoise] could not start preview worker ({s})\n", .{@errorName(err)});
            self.phase = .idle;
            return;
        };
        self.phase = .denoising;
    }

    fn worker(self: *PreviewDenoiser) void {
        defer self.done.store(true, .release);
        @memcpy(self.cpu_out, self.cpu[0]);
        const format: oidn.Format = if (self.job_float32) .float3 else .half3;
        const raw = oidn.Image{ .ptr = self.cpu[0].ptr, .format = format, .pixel_stride = self.job.color_bpp, .row_stride = self.job.rows[0] };
        const out = oidn.Image{ .ptr = self.cpu_out.ptr, .format = format, .pixel_stride = self.job.color_bpp, .row_stride = self.job.rows[0] };
        oidn.denoise(.{
            .width = self.job.w,
            .height = self.job.h,
            .color = raw,
            .albedo = .{ .ptr = self.cpu[1].ptr, .format = .half3, .pixel_stride = aov_bytes_per_pixel, .row_stride = self.job.rows[1] },
            .normal = .{ .ptr = self.cpu[2].ptr, .format = .half3, .pixel_stride = aov_bytes_per_pixel, .row_stride = self.job.rows[2] },
            .clean_aux = self.job_clean_aux,
            .quality = oidn.quality_balanced,
            .output = out,
        }) catch return;
        oidn.blendTowardRaw(out, raw, self.job.w, self.job.h, self.job_strength);
        self.ok = true;
    }

    fn present(self: *PreviewDenoiser, ctx: *const Context, fractal: *FractalRenderer) void {
        if (self.job.w != fractal.offscreen_width or self.job.h != fractal.offscreen_height) return;
        self.ensureShown(ctx, fractal, self.job.w, self.job.h) catch |err| {
            std.debug.print("[denoise] could not allocate preview target ({s})\n", .{@errorName(err)});
            return;
        };
        wgpu.wgpuQueueWriteTexture(
            ctx.queue,
            &wgpu.WGPUTexelCopyTextureInfo{ .texture = self.shown, .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
            self.cpu_out.ptr,
            self.cpu_out.len,
            &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = self.job.rows[0], .rowsPerImage = self.job.h },
            &wgpu.WGPUExtent3D{ .width = self.job.w, .height = self.job.h, .depthOrArrayLayers = 1 },
        );
        fractal.display_override = self.shown_group;
        self.shown_epoch = self.job_epoch;
        if (perf_probe.enabled()) {
            std.debug.print("[denoise] preview {d}x{d} shown {d}ms after capture\n", .{ self.job.w, self.job.h, sdl.SDL_GetTicks() -| self.started_ms });
        }
    }

    fn ensureAovTargets(self: *PreviewDenoiser, ctx: *const Context, w: u32, h: u32) !void {
        if (self.aov_albedo != null and self.aov_w == w and self.aov_h == h) return;
        self.releaseAovTargets();
        self.aov_albedo = FractalRenderer.createAovTexture(ctx, "preview denoise albedo", w, h) orelse return error.TextureCreationFailed;
        self.aov_normal = FractalRenderer.createAovTexture(ctx, "preview denoise normal", w, h) orelse return error.TextureCreationFailed;
        self.aov_albedo_view = wgpu.wgpuTextureCreateView(self.aov_albedo, null) orelse return error.TextureViewCreationFailed;
        self.aov_normal_view = wgpu.wgpuTextureCreateView(self.aov_normal, null) orelse return error.TextureViewCreationFailed;
        self.aov_w = w;
        self.aov_h = h;
    }

    fn releaseAovTargets(self: *PreviewDenoiser) void {
        if (self.aov_albedo_view != null) wgpu.wgpuTextureViewRelease(self.aov_albedo_view);
        if (self.aov_normal_view != null) wgpu.wgpuTextureViewRelease(self.aov_normal_view);
        if (self.aov_albedo != null) wgpu.wgpuTextureRelease(self.aov_albedo);
        if (self.aov_normal != null) wgpu.wgpuTextureRelease(self.aov_normal);
        self.aov_albedo_view = null;
        self.aov_normal_view = null;
        self.aov_albedo = null;
        self.aov_normal = null;
        self.aov_w = 0;
        self.aov_h = 0;
    }

    fn ensureBuffers(self: *PreviewDenoiser, ctx: *const Context, w: u32, h: u32, float32: bool) !void {
        const color_bpp: u32 = if (float32) 16 else 8;
        const l = self.buffer_layout;
        if (self.buffers[0] != null and l.w == w and l.h == h and l.color_bpp == color_bpp) return;
        self.releaseBuffers();
        var layout = Images{ .w = w, .h = h, .color_bpp = color_bpp };
        const bpps = [image_count]u32{ color_bpp, aov_bytes_per_pixel, aov_bytes_per_pixel };
        for (0..image_count) |i| {
            layout.rows[i] = std.mem.alignForward(u32, w * bpps[i], 256);
            layout.sizes[i] = @as(u64, layout.rows[i]) * h;
            if (layout.sizes[i] > ctx.limits.maxBufferSize) return error.PreviewTooLargeToDenoise;
            self.buffers[i] = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
                .nextInChain = null,
                .label = sv("preview denoise readback"),
                .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_MapRead,
                .size = layout.sizes[i],
                .mappedAtCreation = 0,
            }) orelse return error.BufferCreationFailed;
        }
        self.buffer_layout = layout;
    }

    fn releaseBuffers(self: *PreviewDenoiser) void {
        for (&self.buffers) |*b| {
            if (b.* != null) wgpu.wgpuBufferRelease(b.*);
            b.* = null;
        }
        self.buffer_layout = .{};
    }

    fn ensureShown(self: *PreviewDenoiser, ctx: *const Context, fractal: *FractalRenderer, w: u32, h: u32) !void {
        if (self.shown != null and self.shown_w == w and self.shown_h == h) return;
        fractal.display_override = null;
        self.releaseShown();
        self.shown = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("preview denoised image"),
            .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = w, .height = h, .depthOrArrayLayers = 1 },
            .format = fractal_gpu.accumFormat(ctx),
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        self.shown_view = wgpu.wgpuTextureCreateView(self.shown, null) orelse return error.TextureViewCreationFailed;
        self.shown_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("preview denoised bind group"),
            .layout = fractal.blit_bind_group_layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = fractal.sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = self.shown_view },
            },
        }) orelse return error.BindGroupCreationFailed;
        self.shown_w = w;
        self.shown_h = h;
    }

    fn releaseShown(self: *PreviewDenoiser) void {
        if (self.shown_group != null) wgpu.wgpuBindGroupRelease(self.shown_group);
        if (self.shown_view != null) wgpu.wgpuTextureViewRelease(self.shown_view);
        if (self.shown != null) wgpu.wgpuTextureRelease(self.shown);
        self.shown_group = null;
        self.shown_view = null;
        self.shown = null;
        self.shown_w = 0;
        self.shown_h = 0;
    }
};
