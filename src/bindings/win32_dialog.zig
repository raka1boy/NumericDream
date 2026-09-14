const std = @import("std");
const sdl = @import("sdl3.zig").c;
const file_dialog = @import("file_dialog.zig");

const DWORD = u32;
const WORD = u16;
const HWND = ?*anyopaque;
const LPCWSTR = ?[*]const u16;
const LPWSTR = ?[*]u16;
const LPARAM = isize;

const OFN_PATHMUSTEXIST: DWORD = 0x00000800;
const OFN_FILEMUSTEXIST: DWORD = 0x00001000;
const OFN_EXPLORER: DWORD = 0x00080000;
const OFN_HIDEREADONLY: DWORD = 0x00000004;
const OFN_OVERWRITEPROMPT: DWORD = 0x00000002;

const OPENFILENAMEW = extern struct {
    lStructSize: DWORD,
    hwndOwner: HWND,
    hInstance: ?*anyopaque,
    lpstrFilter: LPCWSTR,
    lpstrCustomFilter: LPWSTR,
    nMaxCustFilter: DWORD,
    nFilterIndex: DWORD,
    lpstrFile: LPWSTR,
    nMaxFile: DWORD,
    lpstrFileTitle: LPWSTR,
    nMaxFileTitle: DWORD,
    lpstrInitialDir: LPCWSTR,
    lpstrTitle: LPCWSTR,
    Flags: DWORD,
    nFileOffset: WORD,
    nFileExtension: WORD,
    lpstrDefExt: LPCWSTR,
    lCustData: LPARAM,
    lpfnHook: ?*anyopaque,
    lpTemplateName: LPCWSTR,
    pvReserved: ?*anyopaque,
    dwReserved: DWORD,
    FlagsEx: DWORD,
};

extern "comdlg32" fn GetOpenFileNameW(*OPENFILENAMEW) callconv(.c) i32;
extern "comdlg32" fn GetSaveFileNameW(*OPENFILENAMEW) callconv(.c) i32;

fn filterOf(comptime segments: []const []const u8) [filterLen(segments):0]u16 {
    var buf: [filterLen(segments):0]u16 = std.mem.zeroes([filterLen(segments):0]u16);
    var idx: usize = 0;
    for (segments) |seg| {
        for (seg) |c| {
            buf[idx] = c;
            idx += 1;
        }
        buf[idx] = 0;
        idx += 1;
    }
    return buf;
}

fn filterLen(comptime segments: []const []const u8) usize {
    var total: usize = 1; // final extra NUL
    for (segments) |seg| total += seg.len + 1;
    return total;
}

const filter = filterOf(&.{ "WGSL formula files (*.wgsl)", "*.wgsl", "All files (*.*)", "*.*" });
const image_filter = filterOf(&.{
    "PNG image (*.png)",         "*.png",
    "JPEG image (*.jpg;*.jpeg)", "*.jpg;*.jpeg",
    "BMP image (*.bmp)",         "*.bmp",
});
const sky_image_filter = filterOf(&.{
    "Environment images (*.hdr;*.png;*.jpg;*.jpeg;*.tga;*.bmp)", "*.hdr;*.png;*.jpg;*.jpeg;*.tga;*.bmp",
    "Radiance HDR (*.hdr)",                                      "*.hdr",
    "All files (*.*)",                                           "*.*",
});
const dream_filter = filterOf(&.{ "Numeric Dream scene (*.dream)", "*.dream" });
const dream_default_ext = [_:0]u16{ 'd', 'r', 'e', 'a', 'm' };

const max_path_wide_len: usize = 1024;

fn runFileDialog(window: *sdl.SDL_Window, filt: LPCWSTR, def_ext: LPCWSTR, flags: DWORD, proc: *const fn (*OPENFILENAMEW) callconv(.c) i32, out: []u8, out_filter_index: ?*u32) ?usize {
    const props = sdl.SDL_GetWindowProperties(window);
    const hwnd = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);

    var wide_file: [max_path_wide_len]u16 = std.mem.zeroes([max_path_wide_len]u16);

    var ofn: OPENFILENAMEW = std.mem.zeroes(OPENFILENAMEW);
    ofn.lStructSize = @sizeOf(OPENFILENAMEW);
    ofn.hwndOwner = hwnd;
    ofn.lpstrFilter = filt;
    ofn.lpstrFile = &wide_file;
    ofn.nMaxFile = wide_file.len;
    ofn.lpstrDefExt = def_ext;
    ofn.Flags = flags;
    if (out_filter_index) |idx| ofn.nFilterIndex = idx.*;

    if (proc(&ofn) == 0) return null;

    if (out_filter_index) |idx| idx.* = ofn.nFilterIndex;

    const wlen = std.mem.indexOfScalar(u16, &wide_file, 0) orelse wide_file.len;
    return std.unicode.utf16LeToUtf8(out, wide_file[0..wlen]) catch null;
}

pub fn pickWgslFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return runFileDialog(window, &filter, null, OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER | OFN_HIDEREADONLY, GetOpenFileNameW, out, null);
}

pub const ImageFormat = file_dialog.ImageFormat;
pub const SavedImagePath = file_dialog.SavedImagePath;

pub fn pickSaveImageFile(window: *sdl.SDL_Window, out: []u8) ?SavedImagePath {
    var filter_index: u32 = 1;
    var len = runFileDialog(window, &image_filter, null, OFN_PATHMUSTEXIST | OFN_EXPLORER | OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT, GetSaveFileNameW, out, &filter_index) orelse return null;

    const format: ImageFormat = switch (filter_index) {
        2 => .jpeg,
        3 => .bmp,
        else => .png,
    };

    if (file_dialog.imageFormatFromPath(out[0..len]) == null) {
        const ext = file_dialog.defaultExtension(format);
        if (len + ext.len > out.len) return null;
        @memcpy(out[len..][0..ext.len], ext);
        len += ext.len;
    }

    return .{ .len = len, .format = format };
}

pub fn pickSkyImageFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return runFileDialog(window, &sky_image_filter, null, OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER | OFN_HIDEREADONLY, GetOpenFileNameW, out, null);
}

pub fn pickSaveDreamFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return runFileDialog(window, &dream_filter, &dream_default_ext, OFN_PATHMUSTEXIST | OFN_EXPLORER | OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT, GetSaveFileNameW, out, null);
}

pub fn pickOpenDreamFile(window: *sdl.SDL_Window, out: []u8) ?usize {
    return runFileDialog(window, &dream_filter, null, OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_EXPLORER | OFN_HIDEREADONLY, GetOpenFileNameW, out, null);
}

const BFFCALLBACK = ?*const fn (?*anyopaque, u32, isize, isize) callconv(.c) c_int;
const BROWSEINFOW = extern struct {
    hwndOwner: HWND,
    pidlRoot: ?*anyopaque,
    pszDisplayName: LPWSTR,
    lpszTitle: LPCWSTR,
    ulFlags: DWORD,
    lpfn: BFFCALLBACK,
    lParam: LPARAM,
    iImage: i32,
};

const BIF_RETURNONLYFSDIRS: DWORD = 0x00000001;
const BIF_NEWDIALOGSTYLE: DWORD = 0x00000040;
const COINIT_APARTMENTTHREADED: DWORD = 0x2;

extern "shell32" fn SHBrowseForFolderW(*BROWSEINFOW) callconv(.c) ?*anyopaque; // LPITEMIDLIST
extern "shell32" fn SHGetPathFromIDListW(?*anyopaque, [*]u16) callconv(.c) i32; // BOOL
extern "ole32" fn CoTaskMemFree(?*anyopaque) callconv(.c) void;
extern "ole32" fn CoInitializeEx(?*anyopaque, DWORD) callconv(.c) i32;

const folder_title = std.unicode.utf8ToUtf16LeStringLiteral("Choose output folder");

pub fn pickFolder(window: *sdl.SDL_Window, out: []u8) ?usize {
    _ = CoInitializeEx(null, COINIT_APARTMENTTHREADED);

    const props = sdl.SDL_GetWindowProperties(window);
    const hwnd = sdl.SDL_GetPointerProperty(props, sdl.SDL_PROP_WINDOW_WIN32_HWND_POINTER, null);

    var display_name: [260]u16 = std.mem.zeroes([260]u16);
    var bi: BROWSEINFOW = std.mem.zeroes(BROWSEINFOW);
    bi.hwndOwner = hwnd;
    bi.pszDisplayName = &display_name;
    bi.lpszTitle = folder_title;
    bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;

    const pidl = SHBrowseForFolderW(&bi) orelse return null;
    defer CoTaskMemFree(pidl);

    var wide_path: [max_path_wide_len]u16 = std.mem.zeroes([max_path_wide_len]u16);
    if (SHGetPathFromIDListW(pidl, &wide_path) == 0) return null;

    const wlen = std.mem.indexOfScalar(u16, &wide_path, 0) orelse wide_path.len;
    return std.unicode.utf16LeToUtf8(out, wide_path[0..wlen]) catch null;
}
