const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const min_resolution: u32 = 16;
pub const max_resolution: u32 = 128;
pub const default_resolution: u32 = 64;

pub const workgroup_dim: u32 = 4;
pub const out_binding: u32 = 15;
pub const max_lights = 8;

const format = wgpu.WGPUTextureFormat_RGBA16Float;
const bytes_per_voxel: u64 = 8;
const voxels_per_submit: u32 = 1 << 14;

pub fn layersPerSubmit(dims: [3]u32) u32 {
    const layer_voxels = @max(dims[0] * dims[1], 1);
    return @max(voxels_per_submit / layer_voxels, workgroup_dim);
}

pub fn clampResolution(res: u32) u32 {
    return std.math.clamp(res, min_resolution, max_resolution);
}

pub const Placement = struct {
    origin: [3]f32,
    cell: f32,
    dims: [3]u32,
};

pub fn place(fogs: anytype, resolution: u32) ?Placement {
    if (fogs.len == 0) return null;
    var lo: [3]f32 = @splat(std.math.inf(f32));
    var hi: [3]f32 = @splat(-std.math.inf(f32));
    for (fogs) |*f| {
        const r = @max(f.radius, 0);
        for (0..3) |a| {
            lo[a] = @min(lo[a], f.position[a] - r);
            hi[a] = @max(hi[a], f.position[a] + r);
        }
    }
    const extent = @max(hi[0] - lo[0], @max(hi[1] - lo[1], hi[2] - lo[2]));
    if (!(extent > 1e-6)) return null;
    const res = clampResolution(resolution);
    const cell = extent / @as(f32, @floatFromInt(res));
    var dims: [3]u32 = undefined;
    for (0..3) |a| {
        const n: u32 = @intFromFloat(@ceil((hi[a] - lo[a]) / cell));
        dims[a] = std.math.clamp(n, 1, res);
    }
    return .{ .origin = lo, .cell = cell, .dims = dims };
}

pub const FogVisGrid = struct {
    compute_layout: wgpu.WGPUBindGroupLayout,

    texture: wgpu.WGPUTexture = null,
    sampled_view: wgpu.WGPUTextureView = null,
    storage_view: wgpu.WGPUTextureView = null,
    compute_bind_group: wgpu.WGPUBindGroup = null,

    size: [3]u32 = .{ 0, 0, 0 },

    placement: Placement = .{ .origin = .{ 0, 0, 0 }, .cell = 0, .dims = .{ 0, 0, 0 } },
    layers: u32 = 0,
    light_layer: [max_lights]f32 = @splat(-1),
    layer_light: [max_lights]f32 = @splat(0),
    key: u64 = 0,
    valid: bool = false,
    generation: u32 = 0,

    last_build_ms: u64 = 0,

    pub fn init(ctx: *const Context) !FogVisGrid {
        const entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = out_binding,
            .visibility = wgpu.WGPUShaderStage_Compute,
            .bindingArraySize = 0,
            .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = .{
                .nextInChain = null,
                .access = wgpu.WGPUStorageTextureAccess_WriteOnly,
                .format = format,
                .viewDimension = wgpu.WGPUTextureViewDimension_3D,
            },
        };
        const compute_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fog visibility write bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        var grid = FogVisGrid{ .compute_layout = compute_layout };
        if (!grid.ensureSize(ctx, .{ 1, 1, 1 })) {
            wgpu.wgpuBindGroupLayoutRelease(compute_layout);
            return error.TextureCreationFailed;
        }
        return grid;
    }

    pub fn deinit(self: *FogVisGrid) void {
        self.releaseTexture();
        wgpu.wgpuBindGroupLayoutRelease(self.compute_layout);
    }

    fn releaseTexture(self: *FogVisGrid) void {
        if (self.compute_bind_group != null) wgpu.wgpuBindGroupRelease(self.compute_bind_group);
        if (self.sampled_view != null) wgpu.wgpuTextureViewRelease(self.sampled_view);
        if (self.storage_view != null) wgpu.wgpuTextureViewRelease(self.storage_view);
        if (self.texture != null) wgpu.wgpuTextureRelease(self.texture);
        self.compute_bind_group = null;
        self.sampled_view = null;
        self.storage_view = null;
        self.texture = null;
        self.size = .{ 0, 0, 0 };
        self.valid = false;
    }

    pub fn bytes(self: *const FogVisGrid) u64 {
        return @as(u64, self.size[0]) * self.size[1] * self.size[2] * bytes_per_voxel;
    }

    pub fn ensureSize(self: *FogVisGrid, ctx: *const Context, size: [3]u32) bool {
        if (self.texture != null and std.meta.eql(self.size, size)) return true;
        const max_dim = ctx.limits.maxTextureDimension3D;
        if (size[0] > max_dim or size[1] > max_dim or size[2] > max_dim) return false;

        const texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fog visibility grid"),
            .usage = wgpu.WGPUTextureUsage_StorageBinding | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_3D,
            .size = .{ .width = size[0], .height = size[1], .depthOrArrayLayers = size[2] },
            .format = format,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return false;

        const sampled_view = wgpu.wgpuTextureCreateView(texture, null);
        const storage_view = wgpu.wgpuTextureCreateView(texture, null);
        const compute_bind_group = if (storage_view != null) wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fog visibility write bind group"),
            .layout = self.compute_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = out_binding,
                .buffer = null,
                .offset = 0,
                .size = 0,
                .sampler = null,
                .textureView = storage_view,
            }},
        }) else null;
        if (sampled_view == null or storage_view == null or compute_bind_group == null) {
            if (compute_bind_group != null) wgpu.wgpuBindGroupRelease(compute_bind_group);
            if (sampled_view != null) wgpu.wgpuTextureViewRelease(sampled_view);
            if (storage_view != null) wgpu.wgpuTextureViewRelease(storage_view);
            wgpu.wgpuTextureRelease(texture);
            return false;
        }

        self.releaseTexture();
        self.texture = texture;
        self.sampled_view = sampled_view;
        self.storage_view = storage_view;
        self.compute_bind_group = compute_bind_group;
        self.size = size;
        self.generation +%= 1;
        return true;
    }

    pub fn invalidate(self: *FogVisGrid) void {
        self.valid = false;
    }
};
