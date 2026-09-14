const std = @import("std");
const sdl = @import("sdl3.zig").c;
const file_dialog = @import("file_dialog.zig");

pub const ImageFormat = file_dialog.ImageFormat;
pub const SavedImagePath = file_dialog.SavedImagePath;

const Flavor = enum { zenity, kdialog };

const Helper = struct { exe: []const u8, flavor: Flavor };

const helpers = [_]Helper{
    .{ .exe = "zenity", .flavor = .zenity },
    .{ .exe = "kdialog", .flavor = .kdialog },
    .{ .exe = "qarma", .flavor = .zenity }, // Qt port of zenity
    .{ .exe = "matedialog", .flavor = .zenity }, // MATE fork of zenity
};

const Filter = struct { desc: []const u8, patterns: []const []const u8 };

const wgsl_filters = [_]Filter{
    .{ .desc = "WGSL formula files (*.wgsl)", .patterns = &.{"*.wgsl"} },
    .{ .desc = "All files", .patterns = &.{"*"} },
};

const image_filters = [_]Filter{
    .{ .desc = "PNG image (*.png)", .patterns = &.{"*.png"} },
    .{ .desc = "JPEG image (*.jpg, *.jpeg)", .patterns = &.{ "*.jpg", "*.jpeg" } },
    .{ .desc = "BMP image (*.bmp)", .patterns = &.{"*.bmp"} },
};

const sky_image_filters = [_]Filter{
    .{ .desc = "Environment images", .patterns = &.{ "*.hdr", "*.png", "*.jpg", "*.jpeg", "*.tga", "*.bmp" } },
    .{ .desc = "Radiance HDR (*.hdr)", .patterns = &.{"*.hdr"} },
    .{ .desc = "All files", .patterns = &.{"*"} },
};

const dream_filters = [_]Filter{
    .{ .desc = "Numeric Dream scene (*.dream)", .patterns = &.{"*.dream"} },
};

const Kind = enum { open_file, save_file, folder };

fn x11WindowId(window: *sdl.SDL_Window) ?u64 {
    const driver = std.mem.span(sdl.SDL_GetCurrentVideoDriver() orelse return null);
    if (!std.mem.eql(u8, driver, "x11")) return null;

    const props = sdl.SDL_GetWindowProperties(window);
    const xid = sdl.SDL_GetNumberProperty(props, sdl.SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
    if (xid == 0) return null;
    return @intCast(xid);
}

fn tryHelper(
    helper: Helper,
    window: *sdl.SDL_Window,
    kind: Kind,
    title: []const u8,
    filters: []const Filter,
    out: []u8,
) anyerror!?usize {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var argv: std.ArrayList([]const u8) = .empty;
    const attach = x11WindowId(window);

    switch (helper.flavor) {
        .zenity => {
            argv.appendSlice(arena, &.{ helper.exe, "--file-selection" }) catch return null;
            argv.append(arena, std.fmt.allocPrint(arena, "--title={s}", .{title}) catch return null) catch return null;
            switch (kind) {
                .open_file => {},
                .save_file => argv.appendSlice(arena, &.{ "--save", "--confirm-overwrite" }) catch return null,
                .folder => argv.append(arena, "--directory") catch return null,
            }
            for (filters) |f| {
                var pat_buf: std.ArrayList(u8) = .empty;
                pat_buf.appendSlice(arena, "--file-filter=") catch return null;
                pat_buf.appendSlice(arena, f.desc) catch return null;
                pat_buf.appendSlice(arena, " | ") catch return null;
                for (f.patterns, 0..) |pat, i| {
                    if (i != 0) pat_buf.append(arena, ' ') catch return null;
                    pat_buf.appendSlice(arena, pat) catch return null;
                }
                argv.append(arena, pat_buf.items) catch return null;
            }
            if (attach) |xid| {
                argv.append(arena, "--modal") catch return null;
                argv.append(arena, std.fmt.allocPrint(arena, "--attach={d}", .{xid}) catch return null) catch return null;
            }
        },
        .kdialog => {
            const sub = switch (kind) {
                .open_file => "--getopenfilename",
                .save_file => "--getsavefilename",
                .folder => "--getexistingdirectory",
            };
            argv.appendSlice(arena, &.{ helper.exe, "--title", title, sub, "." }) catch return null;
            if (kind != .folder and filters.len > 0) {
                var filt: std.ArrayList(u8) = .empty;
                for (filters, 0..) |f, i| {
                    if (i != 0) filt.append(arena, '\n') catch return null;
                    for (f.patterns, 0..) |pat, j| {
                        if (j != 0) filt.append(arena, ' ') catch return null;
                        filt.appendSlice(arena, pat) catch return null;
                    }
                    filt.append(arena, '|') catch return null;
                    filt.appendSlice(arena, f.desc) catch return null;
                }
                argv.append(arena, filt.items) catch return null;
            }
            if (attach) |xid| {
                argv.appendSlice(arena, &.{ "--attach", std.fmt.allocPrint(arena, "{d}", .{xid}) catch return null }) catch return null;
            }
        },
    }

    const io = std.Io.Threaded.global_single_threaded.io();
    const result = try std.process.run(arena, io, .{ .argv = argv.items });

    if (!result.term.success()) return null;

    const path = std.mem.trim(u8, result.stdout, " \r\n");
    if (path.len == 0 or path.len > out.len) return null;
    @memcpy(out[0..path.len], path);
    return path.len;
}

fn pick(window: *sdl.SDL_Window, kind: Kind, title: []const u8, filters: []const Filter, out: []u8) ?usize {
    for (helpers) |helper| {
        return tryHelper(helper, window, kind, title, filters, out) catch continue;
    }
    std.log.err(
        "no file dialog helper found -- install one of: zenity, kdialog, qarma, matedialog",
        .{},
    );
    return null;
}

fn ensureExtension(out: []u8, len: usize, ext: []const u8) ?usize {
    if (std.ascii.endsWithIgnoreCase(out[0..len], ext)) return len;
    if (len + ext.len > out.len) return null;
    @memcpy(out[len..][0..ext.len], ext);
    return len + ext.len;
}

pub fn pickWgslFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return pick(window, .open_file, "Choose formula file", &wgsl_filters, out);
}
pub fn pickSaveImageFile(window: *sdl.SDL_Window, out: []u8) ?SavedImagePath {
    const len = pick(window, .save_file, "Save image as", &image_filters, out) orelse return null;
    const format = file_dialog.imageFormatFromPath(out[0..len]) orelse .png;
    const final_len = ensureExtension(out, len, file_dialog.defaultExtension(format)) orelse return null;
    return .{ .len = final_len, .format = format };
}

pub fn pickSkyImageFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return pick(window, .open_file, "Choose sky image", &sky_image_filters, out);
}

pub fn pickSaveDreamFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    const len = pick(window, .save_file, "Save scene as", &dream_filters, out) orelse return null;
    return ensureExtension(out, len, ".dream");
}

pub fn pickOpenDreamFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return pick(window, .open_file, "Open scene", &dream_filters, out);
}

pub fn pickFolder(window: *sdl.SDL_Window, out: []u8) ?usize {
    return pick(window, .folder, "Choose output folder", &.{}, out);
}
