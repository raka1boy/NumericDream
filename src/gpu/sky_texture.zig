const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const stbi = @import("../bindings/stb_image.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const max_edge: u32 = 4096;

pub const SkyTexture = struct {
    layout: wgpu.WGPUBindGroupLayout,
    sampler: wgpu.WGPUSampler,

    texture: wgpu.WGPUTexture = null,
    view: wgpu.WGPUTextureView = null,
    bind_group: wgpu.WGPUBindGroup = null,

    loaded: bool = false,
    width: u32 = 0,
    height: u32 = 0,

    pub fn init(ctx: *const Context) !SkyTexture {
        const entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            .{
                .nextInChain = null,
                .binding = 0,
                .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Compute,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
                .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
            .{
                .nextInChain = null,
                .binding = 1,
                .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Compute,
                .bindingArraySize = 0,
                .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
                .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                .texture = .{
                    .nextInChain = null,
                    .sampleType = wgpu.WGPUTextureSampleType_Float,
                    .viewDimension = wgpu.WGPUTextureViewDimension_2D,
                    .multisampled = 0,
                },
                .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
            },
        };
        const layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("sky bind group layout"),
            .entryCount = entries.len,
            .entries = &entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(layout);

        var desc = webgpu_context.linearSamplerDesc(sv("sky sampler"));
        desc.addressModeU = wgpu.WGPUAddressMode_Repeat;
        desc.addressModeV = wgpu.WGPUAddressMode_ClampToEdge;
        const sampler = wgpu.wgpuDeviceCreateSampler(ctx.device, &desc) orelse return error.SamplerCreationFailed;
        errdefer wgpu.wgpuSamplerRelease(sampler);

        var self = SkyTexture{ .layout = layout, .sampler = sampler };
        try self.installPlaceholder(ctx);
        return self;
    }

    pub fn deinit(self: *SkyTexture) void {
        self.releaseTexture();
        wgpu.wgpuSamplerRelease(self.sampler);
        wgpu.wgpuBindGroupLayoutRelease(self.layout);
    }

    fn releaseTexture(self: *SkyTexture) void {
        if (self.bind_group != null) wgpu.wgpuBindGroupRelease(self.bind_group);
        if (self.view != null) wgpu.wgpuTextureViewRelease(self.view);
        if (self.texture != null) wgpu.wgpuTextureRelease(self.texture);
        self.bind_group = null;
        self.view = null;
        self.texture = null;
        self.loaded = false;
        self.width = 0;
        self.height = 0;
    }

    fn installPlaceholder(self: *SkyTexture, ctx: *const Context) !void {
        const one: [4]f16 = .{ 1.0, 1.0, 1.0, 1.0 };
        try self.upload(ctx, std.mem.asBytes(&one), 1, 1);
        self.loaded = false;
    }

    fn upload(self: *SkyTexture, ctx: *const Context, data: []const u8, width: u32, height: u32) !void {
        const texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("sky environment"),
            .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
            .dimension = wgpu.WGPUTextureDimension_2D,
            .size = .{ .width = width, .height = height, .depthOrArrayLayers = 1 },
            .format = wgpu.WGPUTextureFormat_RGBA16Float,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return error.TextureCreationFailed;
        errdefer wgpu.wgpuTextureRelease(texture);

        wgpu.wgpuQueueWriteTexture(
            ctx.queue,
            &wgpu.WGPUTexelCopyTextureInfo{
                .texture = texture,
                .mipLevel = 0,
                .origin = .{ .x = 0, .y = 0, .z = 0 },
                .aspect = wgpu.WGPUTextureAspect_All,
            },
            data.ptr,
            data.len,
            &wgpu.WGPUTexelCopyBufferLayout{
                .offset = 0,
                .bytesPerRow = width * 8,
                .rowsPerImage = height,
            },
            &wgpu.WGPUExtent3D{ .width = width, .height = height, .depthOrArrayLayers = 1 },
        );

        const view = wgpu.wgpuTextureCreateView(texture, null) orelse return error.TextureViewCreationFailed;
        errdefer wgpu.wgpuTextureViewRelease(view);

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("sky bind group"),
            .layout = self.layout,
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = null, .offset = 0, .size = 0, .sampler = self.sampler, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = view },
            },
        }) orelse return error.BindGroupCreationFailed;

        self.releaseTexture();
        self.texture = texture;
        self.view = view;
        self.bind_group = bind_group;
        self.width = width;
        self.height = height;
        self.loaded = true;
    }

    pub fn clear(self: *SkyTexture, ctx: *const Context) void {
        self.installPlaceholder(ctx) catch {};
    }

    pub const LoadInfo = struct {
        source_width: u32,
        source_height: u32,
        width: u32,
        height: u32,
        is_hdr: bool,
    };

    pub fn loadFromFile(
        self: *SkyTexture,
        ctx: *const Context,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !LoadInfo {
        var path_buf: [1024]u8 = undefined;
        if (path.len == 0) return error.EmptyPath;
        if (path.len >= path_buf.len) return error.PathTooLong;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;
        const path_z: [*:0]const u8 = @ptrCast(&path_buf);

        var w: c_int = 0;
        var h: c_int = 0;
        var channels: c_int = 0;
        const is_hdr = stbi.stbi_is_hdr(path_z) != 0;

        const decoded = stbi.stbi_loadf(path_z, &w, &h, &channels, 4);
        if (decoded == null) return error.DecodeFailed;
        defer stbi.stbi_image_free(decoded);

        if (w <= 0 or h <= 0) return error.DecodeFailed;
        const src_w: u32 = @intCast(w);
        const src_h: u32 = @intCast(h);
        const src = decoded[0 .. @as(usize, src_w) * src_h * 4];

        const limit = @min(max_edge, @max(ctx.limits.maxTextureDimension2D, 1));
        var factor: u32 = 1;
        while (src_w / factor > limit or src_h / factor > limit) factor += 1;

        const dst_w = @max(src_w / factor, 1);
        const dst_h = @max(src_h / factor, 1);

        const texels = try allocator.alloc([4]f16, @as(usize, dst_w) * dst_h);
        defer allocator.free(texels);

        const inv_samples = 1.0 / @as(f32, @floatFromInt(factor * factor));
        for (0..dst_h) |y| {
            for (0..dst_w) |x| {
                var acc: [4]f32 = .{ 0, 0, 0, 0 };
                for (0..factor) |sy| {
                    const src_y = @min(y * factor + sy, src_h - 1);
                    for (0..factor) |sx| {
                        const src_x = @min(x * factor + sx, src_w - 1);
                        const i = (src_y * src_w + src_x) * 4;
                        acc[0] += src[i];
                        acc[1] += src[i + 1];
                        acc[2] += src[i + 2];
                        acc[3] += src[i + 3];
                    }
                }
                const o = y * dst_w + x;
                for (0..4) |ch| {
                    texels[o][ch] = @floatCast(std.math.clamp(acc[ch] * inv_samples, 0.0, 65504.0));
                }
            }
        }

        try self.upload(ctx, std.mem.sliceAsBytes(texels), dst_w, dst_h);
        return .{
            .source_width = src_w,
            .source_height = src_h,
            .width = dst_w,
            .height = dst_h,
            .is_hdr = is_hdr,
        };
    }

    pub fn bytes(self: *const SkyTexture) u64 {
        return @as(u64, self.width) * self.height * 8;
    }
};
