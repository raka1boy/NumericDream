const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const stbi = @import("../bindings/stb_image.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const max_slots = 16;
pub const max_edge: u32 = 2048;
pub const slope_radius_near: u32 = 8;
pub const slope_radius_far: u32 = 64;
pub const header_words: u32 = 8;
pub const texel_words: u32 = 4;
pub const data_base: u32 = max_slots * header_words;

pub const slope_steps_per_octave: f32 = 16;
pub const slope_code_max: f32 = 255;
pub const slope_code_max_log2: f32 = 1;

const dilate_margin: usize = 2;
const slope_round_up: f32 = 1.001;

const Rgba = @Vector(4, f32);

pub const Image = struct {
    path: []u8,
    width: u32 = 0,
    height: u32 = 0,
    source_width: u32 = 0,
    source_height: u32 = 0,
    depth: Depth = .bits8,
    texels: []u32 = &.{},
    slope: [4]f32 = .{ 0, 0, 0, 0 },
    key: u64 = 0,
    err: ?anyerror = null,

    pub const Depth = enum { bits8, bits16, hdr };

    fn deinit(self: *Image, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.texels);
    }
};

pub const HeightMaps = struct {
    allocator: std.mem.Allocator,
    images: std.ArrayList(Image) = .empty,
    slot_image: [max_slots]?usize = @splat(null),
    slot_path_hash: [max_slots]u64 = @splat(0),
    slot_keys: [max_slots]u64 = @splat(0),
    buffer: wgpu.WGPUBuffer = null,
    buffer_size: u64 = 0,
    dirty: bool = true,

    pub fn init(ctx: *const Context, allocator: std.mem.Allocator) !HeightMaps {
        var self = HeightMaps{ .allocator = allocator };
        if (!self.upload(ctx)) return error.BufferCreationFailed;
        return self;
    }

    pub fn deinit(self: *HeightMaps) void {
        for (self.images.items) |*img| img.deinit(self.allocator);
        self.images.deinit(self.allocator);
        if (self.buffer != null) wgpu.wgpuBufferRelease(self.buffer);
    }

    pub fn lookup(self: *const HeightMaps, path: []const u8) ?*const Image {
        for (self.images.items) |*img| {
            if (std.mem.eql(u8, img.path, path)) return img;
        }
        return null;
    }

    pub fn forget(self: *HeightMaps, path: []const u8) void {
        for (self.images.items, 0..) |*img, i| {
            if (std.mem.eql(u8, img.path, path)) {
                img.deinit(self.allocator);
                _ = self.images.swapRemove(i);
                self.dirty = true;
                return;
            }
        }
    }

    pub fn sync(self: *HeightMaps, ctx: *const Context, paths: [max_slots][]const u8) bool {
        var changed = self.dirty;
        for (paths, 0..) |path, s| {
            const h = if (path.len == 0) 0 else std.hash.Wyhash.hash(1, path);
            if (h != self.slot_path_hash[s]) changed = true;
            self.slot_path_hash[s] = h;
        }
        if (!changed) return false;
        self.dirty = false;

        var i = self.images.items.len;
        while (i > 0) {
            i -= 1;
            const wanted = for (paths) |path| {
                if (std.mem.eql(u8, path, self.images.items[i].path)) break true;
            } else false;
            if (wanted) continue;
            self.images.items[i].deinit(self.allocator);
            _ = self.images.orderedRemove(i);
        }

        for (paths, 0..) |path, s| {
            self.slot_image[s] = if (path.len == 0) null else self.ensureImage(ctx, path);
        }

        return self.upload(ctx);
    }

    fn ensureImage(self: *HeightMaps, ctx: *const Context, path: []const u8) ?usize {
        for (self.images.items, 0..) |img, i| {
            if (std.mem.eql(u8, img.path, path)) return if (img.err == null) i else null;
        }
        const owned = self.allocator.dupe(u8, path) catch return null;
        var img = Image{ .path = owned };
        decode(self.allocator, ctx, &img) catch |err| {
            img.err = err;
        };
        self.images.append(self.allocator, img) catch {
            img.deinit(self.allocator);
            return null;
        };
        if (img.err) |err| {
            std.log.warn("height map {s}: {s}", .{ path, @errorName(err) });
            return null;
        }
        return self.images.items.len - 1;
    }

    fn upload(self: *HeightMaps, ctx: *const Context) bool {
        const limit = @min(ctx.limits.maxStorageBufferBindingSize, ctx.limits.maxBufferSize);
        var offsets: [max_slots]u32 = @splat(0);
        var placed: std.ArrayList(u32) = .empty;
        defer placed.deinit(self.allocator);
        placed.appendNTimes(self.allocator, std.math.maxInt(u32), self.images.items.len) catch return false;

        var words: u64 = data_base;
        for (self.slot_image, 0..) |maybe, s| {
            const i = maybe orelse continue;
            if (placed.items[i] == std.math.maxInt(u32)) {
                const len = self.images.items[i].texels.len;
                if ((words + len) * 4 > limit) {
                    self.images.items[i].err = error.HeightMapsExceedBufferLimit;
                    self.slot_image[s] = null;
                    continue;
                }
                placed.items[i] = @intCast(words);
                words += len;
            }
            offsets[s] = placed.items[i];
        }

        const data = self.allocator.alloc(u32, @intCast(words)) catch return false;
        defer self.allocator.free(data);
        @memset(data[0..data_base], 0);
        for (self.images.items, 0..) |img, i| {
            const at = placed.items[i];
            if (at == std.math.maxInt(u32)) continue;
            @memcpy(data[at..][0..img.texels.len], img.texels);
        }
        for (self.slot_image, 0..) |maybe, s| {
            self.slot_keys[s] = 0;
            const i = maybe orelse continue;
            const img = &self.images.items[i];
            const hdr = data[s * header_words ..][0..header_words];
            hdr[0] = offsets[s];
            hdr[1] = img.width;
            hdr[2] = img.height;
            for (img.slope, 0..) |s_ch, ch| hdr[3 + ch] = @bitCast(s_ch);
            self.slot_keys[s] = img.key;
        }

        const size: u64 = words * 4;
        const buffer = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("height maps"),
            .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopyDst,
            .size = size,
            .mappedAtCreation = 0,
        }) orelse return false;
        wgpu.wgpuQueueWriteBuffer(ctx.queue, buffer, 0, data.ptr, size);
        if (self.buffer != null) wgpu.wgpuBufferRelease(self.buffer);
        self.buffer = buffer;
        self.buffer_size = size;
        return true;
    }
};

fn decode(allocator: std.mem.Allocator, ctx: *const Context, img: *Image) !void {
    var path_buf: [1024]u8 = undefined;
    if (img.path.len >= path_buf.len) return error.PathTooLong;
    @memcpy(path_buf[0..img.path.len], img.path);
    path_buf[img.path.len] = 0;
    const path_z: [*:0]const u8 = @ptrCast(&path_buf);

    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;
    var pixels: []Rgba = undefined;

    if (stbi.stbi_is_hdr(path_z) != 0) {
        const px = stbi.stbi_loadf(path_z, &w, &h, &channels, 4);
        if (px == null) return error.DecodeFailed;
        defer stbi.stbi_image_free(px);
        if (w <= 0 or h <= 0) return error.DecodeFailed;
        const n: usize = @as(usize, @intCast(w)) * @as(usize, @intCast(h));
        pixels = try allocator.alloc(Rgba, n);
        var lo: f32 = std.math.inf(f32);
        var hi: f32 = -std.math.inf(f32);
        for (0..n) |i| {
            for (0..3) |ch| {
                const v = px[i * 4 + ch];
                if (!std.math.isFinite(v)) continue;
                lo = @min(lo, v);
                hi = @max(hi, v);
            }
        }
        const span = if (hi > lo) hi - lo else 1.0;
        for (0..n) |i| {
            var c: Rgba = .{ 0, 0, 0, 1 };
            inline for (0..3) |ch| {
                const v = px[i * 4 + ch];
                c[ch] = if (std.math.isFinite(v)) std.math.clamp((v - lo) / span, 0.0, 1.0) else 0.0;
            }
            pixels[i] = c;
        }
        img.depth = .hdr;
    } else {
        const px = stbi.stbi_load_16(path_z, &w, &h, &channels, 4);
        if (px == null) return error.DecodeFailed;
        defer stbi.stbi_image_free(px);
        if (w <= 0 or h <= 0) return error.DecodeFailed;
        const n: usize = @as(usize, @intCast(w)) * @as(usize, @intCast(h));
        pixels = try allocator.alloc(Rgba, n);
        const inv: f32 = 1.0 / 65535.0;
        for (0..n) |i| {
            const a = @as(f32, @floatFromInt(px[i * 4 + 3])) * inv;
            pixels[i] = .{
                @as(f32, @floatFromInt(px[i * 4])) * inv * a,
                @as(f32, @floatFromInt(px[i * 4 + 1])) * inv * a,
                @as(f32, @floatFromInt(px[i * 4 + 2])) * inv * a,
                a,
            };
        }
        img.depth = if (stbi.stbi_is_16_bit(path_z) != 0) .bits16 else .bits8;
    }
    defer allocator.free(pixels);

    const src_w: u32 = @intCast(w);
    const src_h: u32 = @intCast(h);
    img.source_width = src_w;
    img.source_height = src_h;

    const limit = @min(max_edge, @max(ctx.limits.maxTextureDimension2D, 1));
    var factor: u32 = 1;
    while (src_w / factor > limit or src_h / factor > limit) factor += 1;
    const dst_w = @max(src_w / factor, 1);
    const dst_h = @max(src_h / factor, 1);
    const n: usize = @as(usize, dst_w) * dst_h;

    const values = try allocator.alloc(Rgba, n);
    defer allocator.free(values);
    const inv_samples: Rgba = @splat(1.0 / @as(f32, @floatFromInt(factor * factor)));
    for (0..dst_h) |y| {
        for (0..dst_w) |x| {
            var acc: Rgba = @splat(0);
            for (0..factor) |sy| {
                const row = @min(y * factor + sy, src_h - 1) * src_w;
                for (0..factor) |sx| acc += pixels[row + @min(x * factor + sx, src_w - 1)];
            }
            values[y * dst_w + x] = quantize(acc * inv_samples);
        }
    }

    const slopes = try allocator.alloc(Rgba, n);
    defer allocator.free(slopes);
    var global: Rgba = @splat(0);
    for (0..dst_h) |y| {
        for (0..dst_w) |x| {
            const x1 = @min(x + 1, dst_w - 1);
            const y1 = @min(y + 1, dst_h - 1);
            const a = values[y * dst_w + x];
            const b = values[y * dst_w + x1];
            const c = values[y1 * dst_w + x];
            const d = values[y1 * dst_w + x1];
            const dx = @max(@abs(b - a), @abs(d - c));
            const dy = @max(@abs(c - a), @abs(d - b));
            const g = @sqrt(dx * dx + dy * dy);
            global = @max(global, g);
            slopes[y * dst_w + x] = g;
        }
    }

    const near = try allocator.dupe(Rgba, slopes);
    defer allocator.free(near);
    const scratch = try allocator.alloc(Rgba, @max(dst_w, dst_h) * 3);
    defer allocator.free(scratch);
    dilate(near, dst_w, dst_h, slope_radius_near + dilate_margin, scratch);
    dilate(slopes, dst_w, dst_h, slope_radius_far + dilate_margin, scratch);

    const texels = try allocator.alloc(u32, n * texel_words);
    errdefer allocator.free(texels);
    for (0..n) |i| {
        var q: [4]u32 = undefined;
        inline for (0..4) |ch| q[ch] = @intFromFloat(@round(values[i][ch] * 65535.0));
        const t = texels[i * texel_words ..][0..texel_words];
        t[0] = q[0] | (q[1] << 16);
        t[1] = q[2] | (q[3] << 16);
        t[2] = packSlopes(near[i]);
        t[3] = packSlopes(slopes[i]);
    }

    img.width = dst_w;
    img.height = dst_h;
    img.texels = texels;
    inline for (0..4) |ch| img.slope[ch] = global[ch] * slope_round_up;
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.asBytes(&dst_w));
    hasher.update(std.mem.asBytes(&dst_h));
    hasher.update(std.mem.sliceAsBytes(texels));
    img.key = hasher.final();
}

fn quantize(v: Rgba) Rgba {
    const scale: Rgba = @splat(65535.0);
    return @round(@min(@max(v, @as(Rgba, @splat(0.0))), @as(Rgba, @splat(1.0))) * scale) / scale;
}

pub fn slopeCode(s: f32) u32 {
    if (!(s > 0)) return 0;
    const steps = @ceil(slope_steps_per_octave * (@log2(s * slope_round_up) - slope_code_max_log2) + slope_code_max);
    return @intFromFloat(std.math.clamp(steps, 1, slope_code_max));
}

fn packSlopes(s: Rgba) u32 {
    var out: u32 = 0;
    inline for (0..4) |ch| out |= slopeCode(s[ch]) << (ch * 8);
    return out;
}

fn dilate(data: []Rgba, w: usize, h: usize, radius: usize, scratch: []Rgba) void {
    for (0..h) |y| dilateLine(data, y * w, 1, w, radius, scratch);
    for (0..w) |x| dilateLine(data, x, w, h, radius, scratch);
}

fn dilateLine(data: []Rgba, start: usize, stride: usize, len: usize, radius: usize, scratch: []Rgba) void {
    const k = 2 * radius + 1;
    const fwd = scratch[0..len];
    const bwd = scratch[len .. 2 * len];
    const out = scratch[2 * len .. 3 * len];
    for (0..len) |i| {
        const v = data[start + i * stride];
        fwd[i] = if (i % k == 0) v else @max(fwd[i - 1], v);
    }
    var i = len;
    while (i > 0) {
        i -= 1;
        const v = data[start + i * stride];
        bwd[i] = if (i == len - 1 or (i + 1) % k == 0) v else @max(bwd[i + 1], v);
    }
    for (0..len) |j| {
        const lo = j -| radius;
        const hi = @min(j + radius, len - 1);
        out[j] = @max(bwd[lo], fwd[hi]);
    }
    for (0..len) |j| data[start + j * stride] = out[j];
}
