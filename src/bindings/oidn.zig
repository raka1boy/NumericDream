const std = @import("std");
const builtin = @import("builtin");
const sdl = @import("sdl3.zig").c;

pub const Device = *opaque {};
pub const Filter = *opaque {};

pub const device_type_cpu: c_int = 1;
pub const error_none: c_int = 0;
pub const quality_balanced: c_int = 5;
pub const quality_high: c_int = 6;

pub const Format = enum(c_int) {
    float3 = 3,
    half3 = 259,
};

const Api = struct {
    newDevice: *const fn (c_int) callconv(.c) ?Device,
    commitDevice: *const fn (Device) callconv(.c) void,
    releaseDevice: *const fn (Device) callconv(.c) void,
    getDeviceError: *const fn (Device, *?[*:0]const u8) callconv(.c) c_int,
    newFilter: *const fn (Device, [*:0]const u8) callconv(.c) ?Filter,
    releaseFilter: *const fn (Filter) callconv(.c) void,
    setSharedFilterImage: *const fn (Filter, [*:0]const u8, *anyopaque, c_int, usize, usize, usize, usize, usize) callconv(.c) void,
    setFilterBool: *const fn (Filter, [*:0]const u8, bool) callconv(.c) void,
    setFilterInt: *const fn (Filter, [*:0]const u8, c_int) callconv(.c) void,
    commitFilter: *const fn (Filter) callconv(.c) void,
    executeFilter: *const fn (Filter) callconv(.c) void,
};

const library_name = switch (builtin.os.tag) {
    .windows => "OpenImageDenoise.dll",
    else => "libOpenImageDenoise.so.2",
};

const State = enum { untried, ready, unavailable };

var state: State = .untried;
var api: Api = undefined;
var device: ?Device = null;
var unavailable_buf: [256]u8 = undefined;
var unavailable_len: usize = 0;

fn noteUnavailable(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.bufPrint(&unavailable_buf, fmt, args) catch unavailable_buf[0..0];
    unavailable_len = msg.len;
    state = .unavailable;
    std.debug.print("[denoise] unavailable: {s}\n", .{msg});
}

fn openLibrary() ?*sdl.SDL_SharedObject {
    if (sdl.SDL_GetBasePath()) |base| {
        var path_buf: [1024]u8 = undefined;
        if (std.fmt.bufPrintSentinel(&path_buf, "{s}{s}", .{ std.mem.span(base), library_name }, 0)) |full| {
            if (sdl.SDL_LoadObject(full.ptr)) |lib| return lib;
        } else |_| {}
    }
    return sdl.SDL_LoadObject(library_name);
}

fn load() bool {
    switch (state) {
        .ready => return true,
        .unavailable => return false,
        .untried => {},
    }
    const lib = openLibrary() orelse {
        noteUnavailable("{s} not found next to the app ({s})", .{ library_name, std.mem.span(sdl.SDL_GetError()) });
        return false;
    };
    inline for (@typeInfo(Api).@"struct".field_names) |name| {
        const symbol = comptime std.fmt.comptimePrint("oidn{c}{s}", .{ std.ascii.toUpper(name[0]), name[1..] });
        const ptr = sdl.SDL_LoadFunction(lib, symbol) orelse {
            noteUnavailable("{s} lacks {s}", .{ library_name, symbol });
            return false;
        };
        @field(api, name) = @ptrCast(ptr);
    }

    const dev = api.newDevice(device_type_cpu) orelse {
        noteUnavailable("could not create a CPU denoising device", .{});
        return false;
    };
    api.commitDevice(dev);
    if (deviceError(dev)) |msg| {
        api.releaseDevice(dev);
        noteUnavailable("device setup failed: {s}", .{msg});
        return false;
    }
    device = dev;
    state = .ready;
    std.debug.print("[denoise] Open Image Denoise CPU device ready\n", .{});
    return true;
}

fn deviceError(dev: Device) ?[]const u8 {
    var msg: ?[*:0]const u8 = null;
    if (api.getDeviceError(dev, &msg) == error_none) return null;
    return if (msg) |m| std.mem.span(m) else "unknown error";
}

pub fn available() bool {
    return load();
}

pub fn unavailableReason() []const u8 {
    return unavailable_buf[0..unavailable_len];
}

pub const Image = struct {
    ptr: [*]u8,
    format: Format,
    pixel_stride: usize,
    row_stride: usize,
};

pub const Job = struct {
    width: usize,
    height: usize,
    color: Image,
    albedo: Image,
    normal: Image,
    clean_aux: bool,
    quality: c_int = quality_high,
    output: ?Image = null,
};

pub fn blendTowardRaw(out: Image, raw: Image, width: usize, height: usize, strength: f32) void {
    if (strength >= 1.0) return;
    const keep = std.math.clamp(strength, 0.0, 1.0);
    switch (out.format) {
        .float3 => blendRows(f32, out, raw, width, height, keep),
        .half3 => blendRows(f16, out, raw, width, height, keep),
    }
}

fn blendRows(comptime T: type, out: Image, raw: Image, width: usize, height: usize, keep: f32) void {
    const out_step = out.pixel_stride / @sizeOf(T);
    const raw_step = raw.pixel_stride / @sizeOf(T);
    for (0..height) |y| {
        const o: [*]align(1) T = @ptrCast(out.ptr + y * out.row_stride);
        const r: [*]align(1) const T = @ptrCast(raw.ptr + y * raw.row_stride);
        for (0..width) |x| {
            const oi = x * out_step;
            const ri = x * raw_step;
            inline for (0..3) |ch| {
                const raw_v: f32 = @floatCast(r[ri + ch]);
                const den_v: f32 = @floatCast(o[oi + ch]);
                o[oi + ch] = @floatCast(raw_v + (den_v - raw_v) * keep);
            }
        }
    }
}

pub fn denoise(job: Job) !void {
    if (!load()) return error.DenoiserUnavailable;
    const dev = device.?;
    const filter = api.newFilter(dev, "RT") orelse return error.DenoiserFilterFailed;
    defer api.releaseFilter(filter);

    const slots = [_]struct { name: [*:0]const u8, image: Image }{
        .{ .name = "color", .image = job.color },
        .{ .name = "albedo", .image = job.albedo },
        .{ .name = "normal", .image = job.normal },
        .{ .name = "output", .image = job.output orelse job.color },
    };
    for (slots) |slot| {
        api.setSharedFilterImage(
            filter,
            slot.name,
            slot.image.ptr,
            @intFromEnum(slot.image.format),
            job.width,
            job.height,
            0,
            slot.image.pixel_stride,
            slot.image.row_stride,
        );
    }
    api.setFilterBool(filter, "hdr", true);
    api.setFilterBool(filter, "cleanAux", job.clean_aux);
    api.setFilterInt(filter, "quality", job.quality);
    api.commitFilter(filter);
    if (deviceError(dev)) |msg| {
        std.debug.print("[denoise] filter setup failed: {s}\n", .{msg});
        return error.DenoiserFilterFailed;
    }
    api.executeFilter(filter);
    if (deviceError(dev)) |msg| {
        std.debug.print("[denoise] filter failed: {s}\n", .{msg});
        return error.DenoiserFilterFailed;
    }
}
