const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;
const text_raster = @import("../bindings/text_raster.zig");

pub const cell_px: u32 = 64;
pub const cols: u32 = 8;
pub const max_glyphs: usize = 64;
pub const max_fields: usize = 4;
pub const atlas_px: u32 = cell_px * cols;
pub const mip_count: u32 = 7;
pub const default_aspect: f32 = 0.6;

const min_aspect: f32 = 0.25;
const colour_alpha_floor: f32 = 0.1;
const colour_chroma_floor: f32 = 0.08;

pub const GlyphInfo = extern struct {
    field_start: [max_fields]u32 = @splat(0),
    field_len: [max_fields]u32 = @splat(0),
    aspect: f32 = default_aspect,
    count: u32 = 0,
    cols: u32 = cols,
    mips: u32 = 1,
    ink: [max_glyphs]f32 = @splat(0),
    colour: [max_glyphs]u32 = @splat(0),
};

comptime {
    std.debug.assert(@sizeOf(GlyphInfo) == 560);
}

pub const Symbol = struct {
    field: u8 = 0,
    byte_start: u16 = 0,
    byte_len: u16 = 0,
};

pub const Status = enum { empty, ready, unavailable, bad_text, truncated };

var next_id: u32 = 2;

pub const GlyphAtlas = struct {
    texture: wgpu.WGPUTexture = null,
    view: wgpu.WGPUTextureView = null,
    uniform: wgpu.WGPUBuffer = null,
    group: wgpu.WGPUBindGroup = null,
    preview_texture: wgpu.WGPUTexture = null,
    preview_view: wgpu.WGPUTextureView = null,
    id: u32 = 0,
    info: GlyphInfo = .{},
    symbols: [max_glyphs]Symbol = @splat(.{}),
    status: Status = .empty,

    pub fn deinit(self: *GlyphAtlas) void {
        if (self.group != null) wgpu.wgpuBindGroupRelease(self.group);
        if (self.uniform != null) wgpu.wgpuBufferRelease(self.uniform);
        if (self.view != null) wgpu.wgpuTextureViewRelease(self.view);
        if (self.texture != null) wgpu.wgpuTextureRelease(self.texture);
        if (self.preview_view != null) wgpu.wgpuTextureViewRelease(self.preview_view);
        if (self.preview_texture != null) wgpu.wgpuTextureRelease(self.preview_texture);
        self.* = .{};
    }

    pub fn glyphCount(self: *const GlyphAtlas) usize {
        return self.info.count;
    }
};

pub fn createLayout(device: wgpu.WGPUDevice) ?wgpu.WGPUBindGroupLayout {
    const entries = [_]wgpu.WGPUBindGroupLayoutEntry{
        .{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Fragment,
            .bindingArraySize = 0,
            .buffer = .{ .nextInChain = null, .type = wgpu.WGPUBufferBindingType_Uniform, .hasDynamicOffset = 0, .minBindingSize = @sizeOf(GlyphInfo) },
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
            .texture = .{ .nextInChain = null, .sampleType = wgpu.WGPUTextureSampleType_Float, .viewDimension = wgpu.WGPUTextureViewDimension_2D, .multisampled = 0 },
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        },
        .{
            .nextInChain = null,
            .binding = 2,
            .visibility = wgpu.WGPUShaderStage_Fragment,
            .bindingArraySize = 0,
            .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
            .sampler = .{ .nextInChain = null, .type = wgpu.WGPUSamplerBindingType_Filtering },
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        },
    };
    return wgpu.wgpuDeviceCreateBindGroupLayout(device, &wgpu.WGPUBindGroupLayoutDescriptor{
        .nextInChain = null,
        .label = sv("glyph atlas bind group layout"),
        .entryCount = entries.len,
        .entries = &entries,
    });
}

pub fn createEmpty(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, sampler: wgpu.WGPUSampler) !GlyphAtlas {
    var atlas = GlyphAtlas{};
    errdefer atlas.deinit();
    try createGpu(ctx, layout, sampler, &atlas, 1, 1);
    const zero = [_]u16{ 0, 0, 0, 0 };
    writeLevel(ctx, atlas.texture, 0, 1, std.mem.sliceAsBytes(&zero));
    wgpu.wgpuQueueWriteBuffer(ctx.queue, atlas.uniform, 0, &atlas.info, @sizeOf(GlyphInfo));
    return atlas;
}

pub fn build(
    ctx: *const Context,
    allocator: std.mem.Allocator,
    layout: wgpu.WGPUBindGroupLayout,
    sampler: wgpu.WGPUSampler,
    fields: []const []const u8,
    family: [:0]const u8,
) !GlyphAtlas {
    var atlas = GlyphAtlas{};
    errdefer atlas.deinit();

    const cell_bytes = @as(usize, cell_px) * cell_px * 4;
    const raw = try allocator.alloc(u8, cell_bytes * max_glyphs);
    defer allocator.free(raw);
    @memset(raw, 0);

    var glyphs: [max_glyphs]text_raster.Glyph = undefined;
    var total: usize = 0;
    var status: Status = .ready;
    for (fields[0..@min(fields.len, max_fields)], 0..) |text, f| {
        atlas.info.field_start[f] = @intCast(total);
        if (text.len == 0) continue;
        if (total >= max_glyphs) {
            status = .truncated;
            continue;
        }
        const n = text_raster.rasterize(text, family, cell_px, raw[cell_bytes * total ..], glyphs[total..]) catch |err| {
            status = switch (err) {
                error.BadText => .bad_text,
                else => .unavailable,
            };
            continue;
        };
        for (0..n) |i| {
            atlas.symbols[total + i] = .{ .field = @intCast(f), .byte_start = @intCast(glyphs[total + i].byte_start), .byte_len = @intCast(glyphs[total + i].byte_len) };
        }
        atlas.info.field_len[f] = @intCast(n);
        const covered: usize = if (n == 0) 0 else glyphs[total + n - 1].byte_start + glyphs[total + n - 1].byte_len;
        if (total + n >= max_glyphs and covered < text.len) status = .truncated;
        total += n;
    }
    atlas.info.count = @intCast(total);
    atlas.info.mips = mip_count;

    var widest: f32 = 0;
    for (glyphs[0..total]) |g| widest = @max(widest, g.width);
    atlas.info.aspect = if (total == 0) default_aspect else std.math.clamp(widest, min_aspect, 1.0);

    try createGpu(ctx, layout, sampler, &atlas, atlas_px, mip_count);

    const px = @as(usize, atlas_px) * atlas_px;
    const linear = try allocator.alloc([4]f32, px);
    defer allocator.free(linear);
    @memset(linear, .{ 0, 0, 0, 0 });
    const preview = try allocator.alloc([4]u8, px);
    defer allocator.free(preview);
    @memset(preview, .{ 0, 0, 0, 0 });

    for (0..total) |g| {
        const cx = (g % cols) * cell_px;
        const cy = (g / cols) * cell_px;
        const cell = raw[cell_bytes * g ..][0..cell_bytes];
        var alpha_sum: f32 = 0;
        var colourful = false;
        for (0..cell_px) |y| {
            for (0..cell_px) |x| {
                const s = cell[(y * cell_px + x) * 4 ..][0..4];
                const a = @as(f32, @floatFromInt(s[3])) / 255.0;
                alpha_sum += a;
                var straight: [3]f32 = .{ 0, 0, 0 };
                if (a > 0) {
                    for (0..3) |c| straight[c] = @min(@as(f32, @floatFromInt(s[2 - c])) / 255.0 / a, 1.0);
                }
                if (a > colour_alpha_floor) {
                    const hi = @max(straight[0], @max(straight[1], straight[2]));
                    const lo = @min(straight[0], @min(straight[1], straight[2]));
                    if (hi - lo > colour_chroma_floor) colourful = true;
                }
                const dst = (cy + y) * atlas_px + cx + x;
                linear[dst] = .{ srgbToLinear(straight[0]) * a, srgbToLinear(straight[1]) * a, srgbToLinear(straight[2]) * a, a };
                preview[dst] = .{ toByte(straight[0]), toByte(straight[1]), toByte(straight[2]), s[3] };
            }
        }
        atlas.info.ink[g] = alpha_sum / @as(f32, @floatFromInt(cell_px * cell_px));
        atlas.info.colour[g] = @intFromBool(colourful);
    }

    var level_size: u32 = atlas_px;
    const src = linear;
    const scratch = try allocator.alloc([4]f32, px / 4);
    defer allocator.free(scratch);
    const halves = try allocator.alloc(u16, px * 4);
    defer allocator.free(halves);
    for (0..mip_count) |level| {
        if (level > 0) {
            const half = level_size / 2;
            for (0..half) |y| {
                for (0..half) |x| {
                    var acc: [4]f32 = .{ 0, 0, 0, 0 };
                    for ([_][2]usize{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } }) |o| {
                        const t = src[(y * 2 + o[1]) * level_size + x * 2 + o[0]];
                        for (0..4) |c| acc[c] += t[c];
                    }
                    scratch[y * half + x] = .{ acc[0] * 0.25, acc[1] * 0.25, acc[2] * 0.25, acc[3] * 0.25 };
                }
            }
            level_size = half;
            @memcpy(src[0 .. half * half], scratch[0 .. half * half]);
        }
        const n = @as(usize, level_size) * level_size;
        for (0..n) |i| {
            for (0..4) |c| halves[i * 4 + c] = @bitCast(@as(f16, @floatCast(src[i][c])));
        }
        writeLevel(ctx, atlas.texture, @intCast(level), level_size, std.mem.sliceAsBytes(halves[0 .. n * 4]));
    }

    wgpu.wgpuQueueWriteTexture(
        ctx.queue,
        &wgpu.WGPUTexelCopyTextureInfo{ .texture = atlas.preview_texture, .mipLevel = 0, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
        preview.ptr,
        px * 4,
        &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = atlas_px * 4, .rowsPerImage = atlas_px },
        &wgpu.WGPUExtent3D{ .width = atlas_px, .height = atlas_px, .depthOrArrayLayers = 1 },
    );
    wgpu.wgpuQueueWriteBuffer(ctx.queue, atlas.uniform, 0, &atlas.info, @sizeOf(GlyphInfo));

    atlas.status = if (total == 0 and status == .ready) .empty else status;
    return atlas;
}

fn createGpu(ctx: *const Context, layout: wgpu.WGPUBindGroupLayout, sampler: wgpu.WGPUSampler, atlas: *GlyphAtlas, size: u32, mips: u32) !void {
    atlas.id = next_id;
    next_id +%= 1;
    if (next_id < 2) next_id = 2;

    atlas.texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
        .nextInChain = null,
        .label = sv("glyph atlas"),
        .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
        .dimension = wgpu.WGPUTextureDimension_2D,
        .size = .{ .width = size, .height = size, .depthOrArrayLayers = 1 },
        .format = wgpu.WGPUTextureFormat_RGBA16Float,
        .mipLevelCount = mips,
        .sampleCount = 1,
        .viewFormatCount = 0,
        .viewFormats = null,
    }) orelse return error.TextureCreationFailed;
    atlas.view = wgpu.wgpuTextureCreateView(atlas.texture, null) orelse return error.TextureViewCreationFailed;

    atlas.preview_texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
        .nextInChain = null,
        .label = sv("glyph atlas preview"),
        .usage = wgpu.WGPUTextureUsage_TextureBinding | wgpu.WGPUTextureUsage_CopyDst,
        .dimension = wgpu.WGPUTextureDimension_2D,
        .size = .{ .width = size, .height = size, .depthOrArrayLayers = 1 },
        .format = wgpu.WGPUTextureFormat_RGBA8Unorm,
        .mipLevelCount = 1,
        .sampleCount = 1,
        .viewFormatCount = 0,
        .viewFormats = null,
    }) orelse return error.TextureCreationFailed;
    atlas.preview_view = wgpu.wgpuTextureCreateView(atlas.preview_texture, null) orelse return error.TextureViewCreationFailed;

    atlas.uniform = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
        .nextInChain = null,
        .label = sv("glyph atlas info"),
        .usage = wgpu.WGPUBufferUsage_Uniform | wgpu.WGPUBufferUsage_CopyDst,
        .size = @sizeOf(GlyphInfo),
        .mappedAtCreation = 0,
    }) orelse return error.BufferCreationFailed;

    atlas.group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
        .nextInChain = null,
        .label = sv("glyph atlas bind group"),
        .layout = layout,
        .entryCount = 3,
        .entries = &[_]wgpu.WGPUBindGroupEntry{
            .{ .nextInChain = null, .binding = 0, .buffer = atlas.uniform, .offset = 0, .size = @sizeOf(GlyphInfo), .sampler = null, .textureView = null },
            .{ .nextInChain = null, .binding = 1, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = atlas.view },
            .{ .nextInChain = null, .binding = 2, .buffer = null, .offset = 0, .size = 0, .sampler = sampler, .textureView = null },
        },
    }) orelse return error.BindGroupCreationFailed;
}

fn writeLevel(ctx: *const Context, texture: wgpu.WGPUTexture, level: u32, size: u32, bytes: []const u8) void {
    wgpu.wgpuQueueWriteTexture(
        ctx.queue,
        &wgpu.WGPUTexelCopyTextureInfo{ .texture = texture, .mipLevel = level, .origin = .{ .x = 0, .y = 0, .z = 0 }, .aspect = wgpu.WGPUTextureAspect_All },
        bytes.ptr,
        bytes.len,
        &wgpu.WGPUTexelCopyBufferLayout{ .offset = 0, .bytesPerRow = size * 8, .rowsPerImage = size },
        &wgpu.WGPUExtent3D{ .width = size, .height = size, .depthOrArrayLayers = 1 },
    );
}

fn srgbToLinear(c: f32) f32 {
    if (c <= 0.04045) return c / 12.92;
    return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
}

fn toByte(c: f32) u8 {
    return @intFromFloat(std.math.clamp(c * 255.0 + 0.5, 0.0, 255.0));
}
