const builtin = @import("builtin");

const impl = switch (builtin.os.tag) {
    .windows => @import("win32_dialog.zig"),
    else => @import("posix_dialog.zig"),
};

pub const pickWgslFile = impl.pickWgslFile;
pub const pickSaveImageFile = impl.pickSaveImageFile;
pub const pickSkyImageFile = impl.pickSkyImageFile;
pub const pickSaveDreamFile = impl.pickSaveDreamFile;
pub const pickOpenDreamFile = impl.pickOpenDreamFile;
pub const pickFolder = impl.pickFolder;
pub const pickSaveMeshFile = impl.pickSaveMeshFile;
pub const MeshFormat = enum { obj, ply };
pub const SavedMeshPath = struct { len: usize, format: MeshFormat };
pub fn meshFormatFromPath(path: []const u8) ?MeshFormat {
    const std = @import("std");
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".obj")) return .obj;
    if (std.ascii.eqlIgnoreCase(ext, ".ply")) return .ply;
    return null;
}

pub fn meshExtension(format: MeshFormat) []const u8 {
    return switch (format) {
        .obj => ".obj",
        .ply => ".ply",
    };
}
pub const ImageFormat = enum { png, jpeg, bmp };
pub const SavedImagePath = struct { len: usize, format: ImageFormat };
pub fn imageFormatFromPath(path: []const u8) ?ImageFormat {
    const std = @import("std");
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".png")) return .png;
    if (std.ascii.eqlIgnoreCase(ext, ".jpg")) return .jpeg;
    if (std.ascii.eqlIgnoreCase(ext, ".jpeg")) return .jpeg;
    if (std.ascii.eqlIgnoreCase(ext, ".bmp")) return .bmp;
    return null;
}

pub fn defaultExtension(format: ImageFormat) []const u8 {
    return switch (format) {
        .png => ".png",
        .jpeg => ".jpg",
        .bmp => ".bmp",
    };
}
