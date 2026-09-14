const std = @import("std");
const builtin = @import("builtin");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;

pub fn sv(s: []const u8) wgpu.WGPUStringView {
    return .{ .data = s.ptr, .length = s.len };
}

pub fn dist3(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub const default_primitive_state = wgpu.WGPUPrimitiveState{
    .nextInChain = null,
    .topology = wgpu.WGPUPrimitiveTopology_TriangleList,
    .stripIndexFormat = wgpu.WGPUIndexFormat_Undefined,
    .frontFace = wgpu.WGPUFrontFace_CCW,
    .cullMode = wgpu.WGPUCullMode_None,
    .unclippedDepth = 0,
};

pub const default_multisample_state = wgpu.WGPUMultisampleState{
    .nextInChain = null,
    .count = 1,
    .mask = 0xFFFFFFFF,
    .alphaToCoverageEnabled = 0,
};

pub fn linearSamplerDesc(label: wgpu.WGPUStringView) wgpu.WGPUSamplerDescriptor {
    return .{
        .nextInChain = null,
        .label = label,
        .addressModeU = wgpu.WGPUAddressMode_ClampToEdge,
        .addressModeV = wgpu.WGPUAddressMode_ClampToEdge,
        .addressModeW = wgpu.WGPUAddressMode_ClampToEdge,
        .magFilter = wgpu.WGPUFilterMode_Linear,
        .minFilter = wgpu.WGPUFilterMode_Linear,
        .mipmapFilter = wgpu.WGPUMipmapFilterMode_Linear,
        .lodMinClamp = 0,
        .lodMaxClamp = 32,
        .compare = wgpu.WGPUCompareFunction_Undefined,
        .maxAnisotropy = 1,
    };
}

pub fn pollUntil(instance: wgpu.WGPUInstance, done: *const bool, max_spins: u32) u32 {
    var spins: u32 = 0;
    while (!done.* and spins < max_spins) : (spins += 1) {
        wgpu.wgpuInstanceProcessEvents(instance);
        if (!done.*) sdl.SDL_Delay(1);
    }
    return spins;
}

pub const adapter_request_timeout_spins: u32 = 10_000;

fn createSurface(instance: wgpu.WGPUInstance, window: *sdl.SDL_Window) !wgpu.WGPUSurface {
    const props = sdl.SDL_GetWindowProperties(window);

    var desc = wgpu.WGPUSurfaceDescriptor{
        .nextInChain = null,
        .label = sv("NumericDream surface"),
    };

    switch (builtin.os.tag) {
        .windows => {
            const hwnd = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);
            const hinstance = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null);
            if (hwnd == null) return error.NoWin32Hwnd;

            var source = wgpu.WGPUSurfaceSourceWindowsHWND{
                .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceWindowsHWND },
                .hinstance = hinstance,
                .hwnd = hwnd,
            };
            desc.nextInChain = @ptrCast(&source);
            return wgpu.wgpuInstanceCreateSurface(instance, &desc) orelse
                error.WebGPUSurfaceCreationFailed;
        },
        .linux => {
            const driver = std.mem.span(sdl.SDL_GetCurrentVideoDriver() orelse return error.NoSdlVideoDriver);

            if (std.mem.eql(u8, driver, "wayland")) {
                const display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null);
                const wl_surface = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null);
                if (display == null or wl_surface == null) return error.NoWaylandSurface;

                var source = wgpu.WGPUSurfaceSourceWaylandSurface{
                    .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceWaylandSurface },
                    .display = display,
                    .surface = wl_surface,
                };
                desc.nextInChain = @ptrCast(&source);
                return wgpu.wgpuInstanceCreateSurface(instance, &desc) orelse
                    error.WebGPUSurfaceCreationFailed;
            }

            if (std.mem.eql(u8, driver, "x11")) {
                const display = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null);
                // The X11 window id is an integer, not a pointer -- SDL hands
                // it over as a number property, and wgpu takes it as a u64.
                const xid = sdl.SDL_GetNumberProperty(props, sdl.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
                if (display == null or xid == 0) return error.NoX11Window;

                var source = wgpu.WGPUSurfaceSourceXlibWindow{
                    .chain = .{ .next = null, .sType = wgpu.WGPUSType_SurfaceSourceXlibWindow },
                    .display = display,
                    .window = @intCast(xid),
                };
                desc.nextInChain = @ptrCast(&source);
                return wgpu.wgpuInstanceCreateSurface(instance, &desc) orelse
                    error.WebGPUSurfaceCreationFailed;
            }

            std.log.err("unsupported SDL video driver '{s}' -- need wayland or x11", .{driver});
            return error.UnsupportedVideoDriver;
        },
        else => @compileError("createSurface: unsupported platform"),
    }
}

pub const ErrorSink = struct {
    buf: [512]u8 = undefined,
    len: usize = 0,
    has_error: bool = false,

    pub fn reset(self: *ErrorSink) void {
        self.len = 0;
        self.has_error = false;
    }

    pub fn message(self: *const ErrorSink) []const u8 {
        return self.buf[0..self.len];
    }
};

pub var g_error_sink: ErrorSink = .{};

//wgpu logging the assembled shader hangs the app and eats ~20GB.
const wgpu_log_level = wgpu.WGPULogLevel_Warn;

fn onWgpuLog(level: wgpu.WGPULogLevel, message: wgpu.WGPUStringView, userdata: ?*anyopaque) callconv(.c) void {
    _ = userdata;
    const msg = if (message.data != null) message.data[0..message.length] else "";
    std.debug.print("[wgpu {d}] {s}\n", .{ level, msg });
}

pub fn installWgpuLogging() void {
    wgpu.wgpuSetLogCallback(onWgpuLog, null);
    wgpu.wgpuSetLogLevel(wgpu_log_level);
}

pub var g_device_lost: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

fn onDeviceLost(
    device: [*c]const wgpu.WGPUDevice,
    reason: wgpu.WGPUDeviceLostReason,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = device;
    _ = userdata1;
    _ = userdata2;
    const msg = if (message.data != null) message.data[0..message.length] else "";
    std.debug.print("[wgpu] device lost (reason={d}): {s}\n", .{ reason, msg });
    g_device_lost.store(true, .release);
}

fn backendTypeName(backend_type: wgpu.WGPUBackendType) []const u8 {
    return switch (backend_type) {
        wgpu.WGPUBackendType_Undefined => "Undefined",
        wgpu.WGPUBackendType_Null => "Null",
        wgpu.WGPUBackendType_WebGPU => "WebGPU",
        wgpu.WGPUBackendType_D3D11 => "D3D11",
        wgpu.WGPUBackendType_D3D12 => "D3D12",
        wgpu.WGPUBackendType_Metal => "Metal",
        wgpu.WGPUBackendType_Vulkan => "Vulkan",
        wgpu.WGPUBackendType_OpenGL => "OpenGL",
        wgpu.WGPUBackendType_OpenGLES => "OpenGLES",
        else => "Unknown",
    };
}

pub fn printAdapterInfo(ctx: *const Context) void {
    var info: wgpu.WGPUAdapterInfo = std.mem.zeroes(wgpu.WGPUAdapterInfo);
    if (wgpu.wgpuAdapterGetInfo(ctx.adapter, &info) != wgpu.WGPUStatus_Success) return;
    defer wgpu.wgpuAdapterInfoFreeMembers(info);
    const vendor = if (info.vendor.data != null) info.vendor.data[0..info.vendor.length] else "";
    const device = if (info.device.data != null) info.device.data[0..info.device.length] else "";
    std.debug.print("[stage] adapter: backend={s} vendor={s} device={s}\n", .{ backendTypeName(info.backendType), vendor, device });
}

fn onUncapturedError(
    device: [*c]const wgpu.WGPUDevice,
    error_type: wgpu.WGPUErrorType,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = device;
    _ = error_type;
    _ = userdata2;
    const sink: *ErrorSink = @ptrCast(@alignCast(userdata1.?));
    const len = @min(message.length, sink.buf.len);
    if (len > 0 and message.data != null) {
        @memcpy(sink.buf[0..len], message.data[0..len]);
    }
    sink.len = len;
    sink.has_error = true;

    if (std.mem.indexOf(u8, sink.buf[0..len], "device is lost") != null) {
        g_device_lost.store(true, .release);
    }
}

pub const Context = struct {
    instance: wgpu.WGPUInstance,
    surface: wgpu.WGPUSurface,
    adapter: wgpu.WGPUAdapter,
    device: wgpu.WGPUDevice,
    queue: wgpu.WGPUQueue,
    surface_format: wgpu.WGPUTextureFormat,
    width: u32,
    height: u32,
    limits: wgpu.WGPULimits,

    last_acquire_status: wgpu.WGPUSurfaceGetCurrentTextureStatus = wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal,
    reconfigure_count: u32 = 0,

    pub fn init(window: *sdl.SDL_Window) !Context {
        const instance = wgpu.wgpuCreateInstance(null) orelse return error.WebGPUInstanceCreationFailed;

        const surface = try createSurface(instance, window);

        const adapter = try requestAdapter(instance, surface);
        const device = try requestDevice(instance, adapter);
        const queue = wgpu.wgpuDeviceGetQueue(device) orelse return error.WebGPUNoQueue;

        var limits: wgpu.WGPULimits = std.mem.zeroes(wgpu.WGPULimits);
        _ = wgpu.wgpuDeviceGetLimits(device, &limits);

        var caps: wgpu.WGPUSurfaceCapabilities = std.mem.zeroes(wgpu.WGPUSurfaceCapabilities);
        if (wgpu.wgpuSurfaceGetCapabilities(surface, adapter, &caps) != wgpu.WGPUStatus_Success or caps.formatCount == 0) {
            return error.WebGPUNoSurfaceCapabilities;
        }
        const format = caps.formats[0];

        var w: c_int = 0;
        var h: c_int = 0;
        _ = sdl.SDL_GetWindowSizeInPixels(window, &w, &h);

        var ctx = Context{
            .instance = instance,
            .surface = surface,
            .adapter = adapter,
            .device = device,
            .queue = queue,
            .surface_format = format,
            .width = @intCast(w),
            .height = @intCast(h),
            .limits = limits,
        };
        ctx.configure();
        return ctx;
    }

    pub fn deinit(self: *Context) void {
        wgpu.wgpuQueueRelease(self.queue);
        wgpu.wgpuDeviceRelease(self.device);
        wgpu.wgpuAdapterRelease(self.adapter);
        wgpu.wgpuSurfaceRelease(self.surface);
        wgpu.wgpuInstanceRelease(self.instance);
    }

    fn configure(self: *Context) void {
        const config = wgpu.WGPUSurfaceConfiguration{
            .nextInChain = null,
            .device = self.device,
            .format = self.surface_format,
            .usage = wgpu.WGPUTextureUsage_RenderAttachment,
            .width = self.width,
            .height = self.height,
            .viewFormatCount = 0,
            .viewFormats = null,
            .alphaMode = wgpu.WGPUCompositeAlphaMode_Auto,
            .presentMode = wgpu.WGPUPresentMode_Fifo,
        };
        wgpu.wgpuSurfaceConfigure(self.surface, &config);
    }

    pub fn resize(self: *Context, width: u32, height: u32) void {
        if (width == 0 or height == 0) return;
        if (width == self.width and height == self.height) return;
        self.width = width;
        self.height = height;
        self.configure();
    }

    pub const Frame = struct {
        texture: wgpu.WGPUTexture,
        view: wgpu.WGPUTextureView,
        encoder: wgpu.WGPUCommandEncoder,
    };

    pub fn beginFrame(self: *Context) ?Frame {
        var surface_texture: wgpu.WGPUSurfaceTexture = std.mem.zeroes(wgpu.WGPUSurfaceTexture);
        wgpu.wgpuSurfaceGetCurrentTexture(self.surface, &surface_texture);
        self.last_acquire_status = surface_texture.status;
        switch (surface_texture.status) {
            wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal,
            wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal,
            => {},
            wgpu.WGPUSurfaceGetCurrentTextureStatus_Outdated,
            wgpu.WGPUSurfaceGetCurrentTextureStatus_Lost,
            => {
                if (surface_texture.texture != null) wgpu.wgpuTextureRelease(surface_texture.texture);
                self.configure();
                self.reconfigure_count +%= 1;
                surface_texture = std.mem.zeroes(wgpu.WGPUSurfaceTexture);
                wgpu.wgpuSurfaceGetCurrentTexture(self.surface, &surface_texture);
                switch (surface_texture.status) {
                    wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal,
                    wgpu.WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal,
                    => {},
                    else => {
                        if (surface_texture.texture != null) wgpu.wgpuTextureRelease(surface_texture.texture);
                        return null;
                    },
                }
            },
            else => {
                if (surface_texture.texture != null) wgpu.wgpuTextureRelease(surface_texture.texture);
                return null;
            },
        }
        const view = wgpu.wgpuTextureCreateView(surface_texture.texture, null) orelse {
            wgpu.wgpuTextureRelease(surface_texture.texture);
            return null;
        };
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(self.device, null) orelse {
            wgpu.wgpuTextureViewRelease(view);
            wgpu.wgpuTextureRelease(surface_texture.texture);
            return null;
        };
        return .{ .texture = surface_texture.texture, .view = view, .encoder = encoder };
    }

    pub fn endFrame(self: *Context, frame: Frame) void {
        const cmd_buffer = wgpu.wgpuCommandEncoderFinish(frame.encoder, null);
        wgpu.wgpuCommandEncoderRelease(frame.encoder);
        wgpu.wgpuQueueSubmit(self.queue, 1, &[_]wgpu.WGPUCommandBuffer{cmd_buffer});
        wgpu.wgpuCommandBufferRelease(cmd_buffer);
        _ = wgpu.wgpuSurfacePresent(self.surface);
        wgpu.wgpuTextureViewRelease(frame.view);
        wgpu.wgpuTextureRelease(frame.texture);
    }
};

const AdapterRequest = struct {
    adapter: wgpu.WGPUAdapter = null,
    status: wgpu.WGPURequestAdapterStatus = wgpu.WGPURequestAdapterStatus_Error,
    done: bool = false,
};

fn onAdapterReady(
    status: wgpu.WGPURequestAdapterStatus,
    adapter: wgpu.WGPUAdapter,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;
    const req: *AdapterRequest = @ptrCast(@alignCast(userdata1.?));
    req.status = status;
    req.adapter = adapter;
    req.done = true;
}

fn requestAdapter(instance: wgpu.WGPUInstance, surface: wgpu.WGPUSurface) !wgpu.WGPUAdapter {
    std.debug.print("[stage] requestAdapter: begin\n", .{});
    var req = AdapterRequest{};
    const options = wgpu.WGPURequestAdapterOptions{
        .nextInChain = null,
        .featureLevel = wgpu.WGPUFeatureLevel_Core,
        .powerPreference = wgpu.WGPUPowerPreference_HighPerformance,
        .forceFallbackAdapter = 0,
        .backendType = wgpu.WGPUBackendType_Undefined,
        .compatibleSurface = surface,
    };
    const callback_info = wgpu.WGPURequestAdapterCallbackInfo{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = onAdapterReady,
        .userdata1 = &req,
        .userdata2 = null,
    };
    _ = wgpu.wgpuInstanceRequestAdapter(instance, &options, callback_info);
    std.debug.print("[stage] requestAdapter: wgpuInstanceRequestAdapter returned, polling\n", .{});
    const spins = pollUntil(instance, &req.done, adapter_request_timeout_spins);
    std.debug.print("[stage] requestAdapter: poll loop exited after {d} spins, done={} status={d}\n", .{ spins, req.done, req.status });

    if (!req.done or req.status != wgpu.WGPURequestAdapterStatus_Success or req.adapter == null) {
        return error.WebGPUAdapterRequestFailed;
    }
    return req.adapter;
}

const DeviceRequest = struct {
    device: wgpu.WGPUDevice = null,
    status: wgpu.WGPURequestDeviceStatus = wgpu.WGPURequestDeviceStatus_Error,
    done: bool = false,
};

fn onDeviceReady(
    status: wgpu.WGPURequestDeviceStatus,
    device: wgpu.WGPUDevice,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.c) void {
    _ = message;
    _ = userdata2;
    const req: *DeviceRequest = @ptrCast(@alignCast(userdata1.?));
    req.status = status;
    req.device = device;
    req.done = true;
}

fn requestDevice(instance: wgpu.WGPUInstance, adapter: wgpu.WGPUAdapter) !wgpu.WGPUDevice {
    std.debug.print("[stage] requestDevice: begin\n", .{});
    var req = DeviceRequest{};

    var adapter_limits: wgpu.WGPULimits = std.mem.zeroes(wgpu.WGPULimits);
    _ = wgpu.wgpuAdapterGetLimits(adapter, &adapter_limits);
    std.debug.print(
        "[stage] requestDevice: adapter_limits maxTextureDimension2D={d} maxBufferSize={d} maxComputeWorkgroupStorageSize={d}\n",
        .{ adapter_limits.maxTextureDimension2D, adapter_limits.maxBufferSize, adapter_limits.maxComputeWorkgroupStorageSize },
    );

    const descriptor = wgpu.WGPUDeviceDescriptor{
        .nextInChain = null,
        .label = sv("NumericDream device"),
        .requiredFeatureCount = 0,
        .requiredFeatures = null,
        .requiredLimits = &adapter_limits,
        .defaultQueue = .{ .nextInChain = null, .label = sv("NumericDream queue") },
        .deviceLostCallbackInfo = .{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowSpontaneous,
            .callback = onDeviceLost,
            .userdata1 = null,
            .userdata2 = null,
        },
        .uncapturedErrorCallbackInfo = .{
            .nextInChain = null,
            .callback = onUncapturedError,
            .userdata1 = &g_error_sink,
            .userdata2 = null,
        },
    };
    const callback_info = wgpu.WGPURequestDeviceCallbackInfo{
        .nextInChain = null,
        .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
        .callback = onDeviceReady,
        .userdata1 = &req,
        .userdata2 = null,
    };
    _ = wgpu.wgpuAdapterRequestDevice(adapter, &descriptor, callback_info);
    std.debug.print("[stage] requestDevice: wgpuAdapterRequestDevice returned, polling\n", .{});
    const spins = pollUntil(instance, &req.done, adapter_request_timeout_spins);
    std.debug.print("[stage] requestDevice: poll loop exited after {d} spins, done={} status={d}\n", .{ spins, req.done, req.status });

    if (!req.done or req.status != wgpu.WGPURequestDeviceStatus_Success or req.device == null) {
        return error.WebGPUDeviceRequestFailed;
    }
    return req.device;
}
