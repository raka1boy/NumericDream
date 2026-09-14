const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

//must match template.wgsl's MAX_CASCADES
pub const max_cascades = 8;

pub const min_resolution: u32 = 16;
pub const max_resolution: u32 = 160;

pub const default_resolution: u32 = 64;
pub const default_levels: u32 = 6;

pub const workgroup_dim: u32 = 4;

const voxels_per_submit: u32 = 1 << 16;

pub fn layersPerSubmit(resolution: u32) u32 {
    const layer_voxels = @max(resolution * resolution, 1);
    return @max(voxels_per_submit / layer_voxels, workgroup_dim);
}

pub const CascadeParams = [4]f32;

pub fn clampResolution(res: u32) u32 {
    const clamped = std.math.clamp(res, min_resolution, max_resolution);
    return (clamped / workgroup_dim) * workgroup_dim;
}

pub fn placeCascades(
    camera_pos: [3]f32,
    max_dist: f32,
    levels: u32,
    resolution: u32,
) [max_cascades]CascadeParams {
    var out: [max_cascades]CascadeParams = @splat(.{ 0, 0, 0, 0 });
    const n = std.math.clamp(levels, 1, max_cascades);
    const res_f: f32 = @floatFromInt(@max(resolution, 1));
    const coarsest_cell = @max(2.0 * max_dist / res_f, 1e-6);

    for (0..n) |l| {
        const halvings: u5 = @intCast(n - 1 - l);
        const cell = coarsest_cell / @as(f32, @floatFromInt(@as(u32, 1) << halvings));
        const half_extent = 0.5 * res_f * cell;
        var corner: [3]f32 = undefined;
        for (0..3) |axis| {
            corner[axis] = @floor((camera_pos[axis] - half_extent) / cell) * cell;
        }
        out[l] = .{ corner[0], corner[1], corner[2], cell };
    }
    return out;
}

pub fn recenterDistance(max_dist: f32) f32 {
    return @max(max_dist * 0.25, 0.01);
}

pub const AccelGrid = struct {
    render_layout: wgpu.WGPUBindGroupLayout,
    compute_layout: wgpu.WGPUBindGroupLayout,

    texture: wgpu.WGPUTexture = null,
    sampled_view: wgpu.WGPUTextureView = null,
    storage_view: wgpu.WGPUTextureView = null,
    render_bind_group: wgpu.WGPUBindGroup = null,
    compute_bind_group: wgpu.WGPUBindGroup = null,

    resolution: u32 = 0,
    levels: u32 = 0,

    params: [max_cascades]CascadeParams = @splat(.{ 0, 0, 0, 0 }),
    centre: [3]f32 = .{ 0, 0, 0 },
    valid: bool = false,

    last_build_ms: u64 = 0,

    pub fn init(ctx: *const Context) !AccelGrid {
        const render_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 0,
            .visibility = wgpu.WGPUShaderStage_Fragment | wgpu.WGPUShaderStage_Compute,
            .bindingArraySize = 0,
            .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = .{
                .nextInChain = null,
                .sampleType = wgpu.WGPUTextureSampleType_UnfilterableFloat,
                .viewDimension = wgpu.WGPUTextureViewDimension_3D,
                .multisampled = 0,
            },
            .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
        };
        const render_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("accel read bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{render_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(render_layout);

        const compute_entry = wgpu.WGPUBindGroupLayoutEntry{
            .nextInChain = null,
            .binding = 1,
            .visibility = wgpu.WGPUShaderStage_Compute,
            .bindingArraySize = 0,
            .buffer = std.mem.zeroes(wgpu.WGPUBufferBindingLayout),
            .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
            .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
            .storageTexture = .{
                .nextInChain = null,
                .access = wgpu.WGPUStorageTextureAccess_WriteOnly,
                .format = wgpu.WGPUTextureFormat_R32Float,
                .viewDimension = wgpu.WGPUTextureViewDimension_3D,
            },
        };
        const compute_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("accel write bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{compute_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;

        return .{ .render_layout = render_layout, .compute_layout = compute_layout };
    }

    pub fn deinit(self: *AccelGrid) void {
        self.releaseTexture();
        wgpu.wgpuBindGroupLayoutRelease(self.render_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.compute_layout);
    }

    fn releaseTexture(self: *AccelGrid) void {
        if (self.render_bind_group != null) wgpu.wgpuBindGroupRelease(self.render_bind_group);
        if (self.compute_bind_group != null) wgpu.wgpuBindGroupRelease(self.compute_bind_group);
        if (self.sampled_view != null) wgpu.wgpuTextureViewRelease(self.sampled_view);
        if (self.storage_view != null) wgpu.wgpuTextureViewRelease(self.storage_view);
        if (self.texture != null) wgpu.wgpuTextureRelease(self.texture);
        self.render_bind_group = null;
        self.compute_bind_group = null;
        self.sampled_view = null;
        self.storage_view = null;
        self.texture = null;
        self.resolution = 0;
        self.levels = 0;
        self.valid = false;
    }

    pub fn isAllocated(self: *const AccelGrid) bool {
        return self.texture != null;
    }

    pub fn bytes(self: *const AccelGrid) u64 {
        if (!self.isAllocated()) return 0;
        const r: u64 = self.resolution;
        return r * r * r * self.levels * 4;
    }

    pub fn ensureSize(self: *AccelGrid, ctx: *const Context, resolution: u32, levels: u32) bool {
        const res = clampResolution(resolution);
        const lv = std.math.clamp(levels, 1, max_cascades);
        if (self.texture != null and self.resolution == res and self.levels == lv) return true;

        const depth = res * lv;
        if (depth > ctx.limits.maxTextureDimension3D or res > ctx.limits.maxTextureDimension3D) {
            return self.texture != null;
        }

        const texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("accel cascade grid"),
            .usage = wgpu.WGPUTextureUsage_StorageBinding | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_3D,
            .size = .{ .width = res, .height = res, .depthOrArrayLayers = depth },
            .format = wgpu.WGPUTextureFormat_R32Float,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse return self.texture != null;

        const sampled_view = wgpu.wgpuTextureCreateView(texture, null);
        const storage_view = wgpu.wgpuTextureCreateView(texture, null);
        if (sampled_view == null or storage_view == null) {
            if (sampled_view != null) wgpu.wgpuTextureViewRelease(sampled_view);
            if (storage_view != null) wgpu.wgpuTextureViewRelease(storage_view);
            wgpu.wgpuTextureRelease(texture);
            return self.texture != null;
        }

        const render_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("accel read bind group"),
            .layout = self.render_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = 0,
                .buffer = null,
                .offset = 0,
                .size = 0,
                .sampler = null,
                .textureView = sampled_view,
            }},
        });
        const compute_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("accel write bind group"),
            .layout = self.compute_layout,
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupEntry{.{
                .nextInChain = null,
                .binding = 1,
                .buffer = null,
                .offset = 0,
                .size = 0,
                .sampler = null,
                .textureView = storage_view,
            }},
        });
        if (render_bind_group == null or compute_bind_group == null) {
            if (render_bind_group != null) wgpu.wgpuBindGroupRelease(render_bind_group);
            if (compute_bind_group != null) wgpu.wgpuBindGroupRelease(compute_bind_group);
            wgpu.wgpuTextureViewRelease(sampled_view);
            wgpu.wgpuTextureViewRelease(storage_view);
            wgpu.wgpuTextureRelease(texture);
            return self.texture != null;
        }

        self.releaseTexture();
        self.texture = texture;
        self.sampled_view = sampled_view;
        self.storage_view = storage_view;
        self.render_bind_group = render_bind_group;
        self.compute_bind_group = compute_bind_group;
        self.resolution = res;
        self.levels = lv;
        self.valid = false;
        return true;
    }

    pub fn invalidate(self: *AccelGrid) void {
        self.valid = false;
    }

    pub fn drift(self: *const AccelGrid, camera_pos: [3]f32) f32 {
        return webgpu_context.dist3(camera_pos, self.centre);
    }
};
