const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const sv = webgpu_context.sv;

pub const resolution: u32 = 64;

pub const workgroup_dim_3d: u32 = 4;
pub const workgroup_dim_2d: u32 = 8;

pub fn groups3d() u32 {
    return (resolution + workgroup_dim_3d - 1) / workgroup_dim_3d;
}

pub fn groups2d() u32 {
    return (resolution + workgroup_dim_2d - 1) / workgroup_dim_2d;
}

pub const FftVolume = struct {
    render_layout: wgpu.WGPUBindGroupLayout,
    compute_layout: wgpu.WGPUBindGroupLayout,

    density_buf: wgpu.WGPUBuffer = null,
    complex_a_buf: wgpu.WGPUBuffer = null,
    complex_b_buf: wgpu.WGPUBuffer = null,
    peak_buf: wgpu.WGPUBuffer = null,

    magnitude_texture: wgpu.WGPUTexture = null,
    magnitude_sampled_view: wgpu.WGPUTextureView = null,
    magnitude_storage_view: wgpu.WGPUTextureView = null,

    render_bind_group: wgpu.WGPUBindGroup = null,
    compute_bind_group: wgpu.WGPUBindGroup = null,

    allocated: bool = false,
    valid: bool = false,

    pub fn init(ctx: *const Context) !FftVolume {
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
            .label = sv("fft read bind group layout"),
            .entryCount = 1,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{render_entry},
        }) orelse return error.BindGroupLayoutCreationFailed;
        errdefer wgpu.wgpuBindGroupLayoutRelease(render_layout);

        const storageBufferEntry = struct {
            fn f(binding: u32) wgpu.WGPUBindGroupLayoutEntry {
                return .{
                    .nextInChain = null,
                    .binding = binding,
                    .visibility = wgpu.WGPUShaderStage_Compute,
                    .bindingArraySize = 0,
                    .buffer = .{
                        .nextInChain = null,
                        .type = wgpu.WGPUBufferBindingType_Storage,
                        .hasDynamicOffset = 0,
                        .minBindingSize = 0,
                    },
                    .sampler = std.mem.zeroes(wgpu.WGPUSamplerBindingLayout),
                    .texture = std.mem.zeroes(wgpu.WGPUTextureBindingLayout),
                    .storageTexture = std.mem.zeroes(wgpu.WGPUStorageTextureBindingLayout),
                };
            }
        }.f;

        const compute_entries = [_]wgpu.WGPUBindGroupLayoutEntry{
            storageBufferEntry(0),
            storageBufferEntry(1),
            storageBufferEntry(2),
            .{
                .nextInChain = null,
                .binding = 3,
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
            },
            storageBufferEntry(4),
        };
        const compute_layout = wgpu.wgpuDeviceCreateBindGroupLayout(ctx.device, &wgpu.WGPUBindGroupLayoutDescriptor{
            .nextInChain = null,
            .label = sv("fft write bind group layout"),
            .entryCount = compute_entries.len,
            .entries = &compute_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;

        return .{ .render_layout = render_layout, .compute_layout = compute_layout };
    }

    pub fn deinit(self: *FftVolume) void {
        self.release();
        wgpu.wgpuBindGroupLayoutRelease(self.render_layout);
        wgpu.wgpuBindGroupLayoutRelease(self.compute_layout);
    }

    fn release(self: *FftVolume) void {
        if (self.render_bind_group != null) wgpu.wgpuBindGroupRelease(self.render_bind_group);
        if (self.compute_bind_group != null) wgpu.wgpuBindGroupRelease(self.compute_bind_group);
        if (self.magnitude_sampled_view != null) wgpu.wgpuTextureViewRelease(self.magnitude_sampled_view);
        if (self.magnitude_storage_view != null) wgpu.wgpuTextureViewRelease(self.magnitude_storage_view);
        if (self.magnitude_texture != null) wgpu.wgpuTextureRelease(self.magnitude_texture);
        if (self.density_buf != null) wgpu.wgpuBufferRelease(self.density_buf);
        if (self.complex_a_buf != null) wgpu.wgpuBufferRelease(self.complex_a_buf);
        if (self.complex_b_buf != null) wgpu.wgpuBufferRelease(self.complex_b_buf);
        if (self.peak_buf != null) wgpu.wgpuBufferRelease(self.peak_buf);
        self.render_bind_group = null;
        self.compute_bind_group = null;
        self.magnitude_sampled_view = null;
        self.magnitude_storage_view = null;
        self.magnitude_texture = null;
        self.density_buf = null;
        self.complex_a_buf = null;
        self.complex_b_buf = null;
        self.peak_buf = null;
        self.allocated = false;
        self.valid = false;
    }

    pub fn isAllocated(self: *const FftVolume) bool {
        return self.allocated;
    }

    pub fn ensureAllocated(self: *FftVolume, ctx: *const Context) bool {
        if (self.allocated) return true;

        const n: u64 = resolution;
        const voxel_count = n * n * n;
        const density_bytes = voxel_count * 4;
        const complex_bytes = voxel_count * 8;

        const density_buf = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fft density buffer"),
            .usage = wgpu.WGPUBufferUsage_Storage,
            .size = density_bytes,
            .mappedAtCreation = 0,
        }) orelse return false;
        const complex_a_buf = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fft complex buffer a"),
            .usage = wgpu.WGPUBufferUsage_Storage,
            .size = complex_bytes,
            .mappedAtCreation = 0,
        }) orelse {
            wgpu.wgpuBufferRelease(density_buf);
            return false;
        };
        const complex_b_buf = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fft complex buffer b"),
            .usage = wgpu.WGPUBufferUsage_Storage,
            .size = complex_bytes,
            .mappedAtCreation = 0,
        }) orelse {
            wgpu.wgpuBufferRelease(density_buf);
            wgpu.wgpuBufferRelease(complex_a_buf);
            return false;
        };

        const peak_bytes: u64 = 16;
        const peak_buf = wgpu.wgpuDeviceCreateBuffer(ctx.device, &wgpu.WGPUBufferDescriptor{
            .nextInChain = null,
            .label = sv("fft peak buffer"),
            .usage = wgpu.WGPUBufferUsage_Storage,
            .size = peak_bytes,
            .mappedAtCreation = 0,
        }) orelse {
            wgpu.wgpuBufferRelease(density_buf);
            wgpu.wgpuBufferRelease(complex_a_buf);
            wgpu.wgpuBufferRelease(complex_b_buf);
            return false;
        };

        const texture = wgpu.wgpuDeviceCreateTexture(ctx.device, &wgpu.WGPUTextureDescriptor{
            .nextInChain = null,
            .label = sv("fft magnitude volume"),
            .usage = wgpu.WGPUTextureUsage_StorageBinding | wgpu.WGPUTextureUsage_TextureBinding,
            .dimension = wgpu.WGPUTextureDimension_3D,
            .size = .{ .width = resolution, .height = resolution, .depthOrArrayLayers = resolution },
            .format = wgpu.WGPUTextureFormat_R32Float,
            .mipLevelCount = 1,
            .sampleCount = 1,
            .viewFormatCount = 0,
            .viewFormats = null,
        }) orelse {
            wgpu.wgpuBufferRelease(density_buf);
            wgpu.wgpuBufferRelease(complex_a_buf);
            wgpu.wgpuBufferRelease(complex_b_buf);
            wgpu.wgpuBufferRelease(peak_buf);
            return false;
        };
        const sampled_view = wgpu.wgpuTextureCreateView(texture, null);
        const storage_view = wgpu.wgpuTextureCreateView(texture, null);
        if (sampled_view == null or storage_view == null) {
            if (sampled_view != null) wgpu.wgpuTextureViewRelease(sampled_view);
            if (storage_view != null) wgpu.wgpuTextureViewRelease(storage_view);
            wgpu.wgpuTextureRelease(texture);
            wgpu.wgpuBufferRelease(density_buf);
            wgpu.wgpuBufferRelease(complex_a_buf);
            wgpu.wgpuBufferRelease(complex_b_buf);
            wgpu.wgpuBufferRelease(peak_buf);
            return false;
        }

        const render_bind_group = wgpu.wgpuDeviceCreateBindGroup(ctx.device, &wgpu.WGPUBindGroupDescriptor{
            .nextInChain = null,
            .label = sv("fft read bind group"),
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
            .label = sv("fft write bind group"),
            .layout = self.compute_layout,
            .entryCount = 5,
            .entries = &[_]wgpu.WGPUBindGroupEntry{
                .{ .nextInChain = null, .binding = 0, .buffer = density_buf, .offset = 0, .size = density_bytes, .sampler = null, .textureView = null },
                .{ .nextInChain = null, .binding = 1, .buffer = complex_a_buf, .offset = 0, .size = complex_bytes, .sampler = null, .textureView = null },
                .{ .nextInChain = null, .binding = 2, .buffer = complex_b_buf, .offset = 0, .size = complex_bytes, .sampler = null, .textureView = null },
                .{ .nextInChain = null, .binding = 3, .buffer = null, .offset = 0, .size = 0, .sampler = null, .textureView = storage_view },
                .{ .nextInChain = null, .binding = 4, .buffer = peak_buf, .offset = 0, .size = peak_bytes, .sampler = null, .textureView = null },
            },
        });
        if (render_bind_group == null or compute_bind_group == null) {
            if (render_bind_group != null) wgpu.wgpuBindGroupRelease(render_bind_group);
            if (compute_bind_group != null) wgpu.wgpuBindGroupRelease(compute_bind_group);
            wgpu.wgpuTextureViewRelease(sampled_view);
            wgpu.wgpuTextureViewRelease(storage_view);
            wgpu.wgpuTextureRelease(texture);
            wgpu.wgpuBufferRelease(density_buf);
            wgpu.wgpuBufferRelease(complex_a_buf);
            wgpu.wgpuBufferRelease(complex_b_buf);
            wgpu.wgpuBufferRelease(peak_buf);
            return false;
        }

        self.density_buf = density_buf;
        self.complex_a_buf = complex_a_buf;
        self.complex_b_buf = complex_b_buf;
        self.peak_buf = peak_buf;
        self.magnitude_texture = texture;
        self.magnitude_sampled_view = sampled_view;
        self.magnitude_storage_view = storage_view;
        self.render_bind_group = render_bind_group;
        self.compute_bind_group = compute_bind_group;
        self.allocated = true;
        return true;
    }

    pub fn invalidate(self: *FftVolume) void {
        self.valid = false;
    }
};
