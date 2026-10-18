const std = @import("std");
const builtin = @import("builtin");
const sdl = @import("sdl3.zig").c;

pub const Glyph = struct {
    width: f32,
    byte_start: u32,
    byte_len: u32,
};

pub const Error = error{ Unavailable, BadText, Failed };

pub fn rasterize(utf8: []const u8, family: [:0]const u8, cell_px: u32, out_bgra: []u8, out: []Glyph) Error!usize {
    if (utf8.len == 0 or out.len == 0) return 0;
    const cell_bytes = @as(usize, cell_px) * cell_px * 4;
    const max_glyphs = @min(out.len, out_bgra.len / cell_bytes);
    if (max_glyphs == 0) return 0;
    return switch (builtin.os.tag) {
        .windows => rasterizeWin32(utf8, family, cell_px, out_bgra, out[0..max_glyphs]),
        else => pango.rasterize(utf8, family, cell_px, out_bgra, out[0..max_glyphs]),
    };
}

pub fn unavailableReason() [:0]const u8 {
    return switch (builtin.os.tag) {
        .windows => "DirectWrite could not be started.",
        else => pango.reason(),
    };
}

extern fn nd_text_raster(
    utf8: [*]const u8,
    utf8_len: c_int,
    family_utf8: [*:0]const u8,
    cell_px: c_int,
    out_bgra: [*]u8,
    max_glyphs: c_int,
    out_width: [*]f32,
    out_byte_start: [*]c_int,
    out_byte_len: [*]c_int,
) c_int;

const max_batch = 256;

fn rasterizeWin32(utf8: []const u8, family: [:0]const u8, cell_px: u32, out_bgra: []u8, out: []Glyph) Error!usize {
    var widths: [max_batch]f32 = undefined;
    var starts: [max_batch]c_int = undefined;
    var lens: [max_batch]c_int = undefined;
    const cap = @min(out.len, max_batch);
    const n = nd_text_raster(utf8.ptr, @intCast(utf8.len), family.ptr, @intCast(cell_px), out_bgra.ptr, @intCast(cap), &widths, &starts, &lens);
    if (n == -2) return error.BadText;
    if (n < 0) return error.Unavailable;
    const count: usize = @intCast(n);
    for (0..count) |i| out[i] = .{ .width = widths[i], .byte_start = @intCast(starts[i]), .byte_len = @intCast(lens[i]) };
    return count;
}

const pango = struct {
    const Rect = extern struct { x: c_int, y: c_int, width: c_int, height: c_int };
    const P = ?*anyopaque;
    const pango_scale: f64 = 1024.0;
    const cairo_format_argb32: c_int = 0;
    const cairo_operator_clear: c_int = 0;
    const cairo_operator_over: c_int = 2;
    const cursor_position_bit: u32 = 1 << 4;

    const Api = struct {
        cairo_image_surface_create: *const fn (c_int, c_int, c_int) callconv(.c) P,
        cairo_surface_destroy: *const fn (P) callconv(.c) void,
        cairo_surface_flush: *const fn (P) callconv(.c) void,
        cairo_image_surface_get_data: *const fn (P) callconv(.c) ?[*]u8,
        cairo_image_surface_get_stride: *const fn (P) callconv(.c) c_int,
        cairo_create: *const fn (P) callconv(.c) P,
        cairo_destroy: *const fn (P) callconv(.c) void,
        cairo_set_operator: *const fn (P, c_int) callconv(.c) void,
        cairo_paint: *const fn (P) callconv(.c) void,
        cairo_set_source_rgba: *const fn (P, f64, f64, f64, f64) callconv(.c) void,
        cairo_identity_matrix: *const fn (P) callconv(.c) void,
        cairo_translate: *const fn (P, f64, f64) callconv(.c) void,
        cairo_scale: *const fn (P, f64, f64) callconv(.c) void,
        cairo_move_to: *const fn (P, f64, f64) callconv(.c) void,
        pango_cairo_create_layout: *const fn (P) callconv(.c) P,
        pango_cairo_update_layout: *const fn (P, P) callconv(.c) void,
        pango_cairo_show_layout: *const fn (P, P) callconv(.c) void,
        pango_layout_set_text: *const fn (P, [*]const u8, c_int) callconv(.c) void,
        pango_layout_set_font_description: *const fn (P, P) callconv(.c) void,
        pango_layout_get_pixel_extents: *const fn (P, ?*Rect, ?*Rect) callconv(.c) void,
        pango_layout_get_baseline: *const fn (P) callconv(.c) c_int,
        pango_layout_get_log_attrs_readonly: *const fn (P, *c_int) callconv(.c) ?[*]const u32,
        pango_font_description_from_string: *const fn ([*:0]const u8) callconv(.c) P,
        pango_font_description_set_absolute_size: *const fn (P, f64) callconv(.c) void,
        pango_font_description_free: *const fn (P) callconv(.c) void,
        g_object_unref: *const fn (P) callconv(.c) void,
    };

    const libraries = [_][:0]const u8{ "libcairo.so.2", "libpango-1.0.so.0", "libpangocairo-1.0.so.0", "libgobject-2.0.so.0" };

    const State = enum { untried, ready, unavailable };
    var state: State = .untried;
    var api: Api = undefined;
    var reason_buf: [160]u8 = undefined;
    var reason_text: [:0]const u8 = "Pango/Cairo could not be loaded.";

    fn reason() [:0]const u8 {
        return reason_text;
    }

    fn noteUnavailable(comptime fmt: []const u8, args: anytype) void {
        reason_text = std.fmt.bufPrintSentinel(&reason_buf, fmt, args, 0) catch "Pango/Cairo could not be loaded.";
        state = .unavailable;
    }

    fn load() bool {
        if (state == .ready) return true;
        if (state == .unavailable) return false;
        var libs: [libraries.len]*sdl.SDL_SharedObject = undefined;
        for (libraries, 0..) |name, i| {
            libs[i] = sdl.SDL_LoadObject(name.ptr) orelse {
                noteUnavailable("Text rendering needs {s} (Pango/Cairo).", .{name});
                return false;
            };
        }
        @setEvalBranchQuota(100_000);
        inline for (@typeInfo(Api).@"struct".field_names) |field| {
            const symbol = comptime std.fmt.comptimePrint("{s}", .{field});
            var found = false;
            for (libs) |lib| {
                if (sdl.SDL_LoadFunction(lib, symbol)) |f| {
                    @field(api, field) = @ptrCast(f);
                    found = true;
                    break;
                }
            }
            if (!found) {
                noteUnavailable("Pango/Cairo is missing {s}.", .{symbol});
                return false;
            }
        }
        state = .ready;
        return true;
    }

    fn rasterize(utf8: []const u8, family: [:0]const u8, cell_px: u32, out_bgra: []u8, out: []Glyph) Error!usize {
        if (!std.unicode.utf8ValidateSlice(utf8)) return error.BadText;
        if (!load()) return error.Unavailable;

        const cell: f64 = @floatFromInt(cell_px);
        const em = cell * 0.75;
        const baseline_target = cell * 0.74;
        const side: c_int = @intCast(cell_px);

        const surface = api.cairo_image_surface_create(cairo_format_argb32, side, side) orelse return error.Failed;
        defer api.cairo_surface_destroy(surface);
        const cr = api.cairo_create(surface) orelse return error.Failed;
        defer api.cairo_destroy(cr);
        const layout = api.pango_cairo_create_layout(cr) orelse return error.Failed;
        defer api.g_object_unref(layout);

        const desc = api.pango_font_description_from_string(if (family.len > 0) family.ptr else "monospace") orelse return error.Failed;
        defer api.pango_font_description_free(desc);
        api.pango_font_description_set_absolute_size(desc, em * pango_scale);
        api.pango_layout_set_font_description(layout, desc);

        api.pango_layout_set_text(layout, utf8.ptr, @intCast(utf8.len));
        var n_attrs: c_int = 0;
        const attrs_ptr = api.pango_layout_get_log_attrs_readonly(layout, &n_attrs) orelse return error.Failed;
        const attrs = attrs_ptr[0..@intCast(@max(n_attrs, 0))];

        var bounds: [max_batch + 1]usize = undefined;
        var bound_count: usize = 0;
        {
            var char_index: usize = 0;
            var byte: usize = 0;
            while (byte < utf8.len) : (char_index += 1) {
                const at_cursor = char_index < attrs.len and (attrs[char_index] & cursor_position_bit) != 0;
                if ((char_index == 0 or at_cursor) and bound_count < bounds.len) {
                    bounds[bound_count] = byte;
                    bound_count += 1;
                }
                byte += std.unicode.utf8ByteSequenceLength(utf8[byte]) catch 1;
            }
        }

        const cell_bytes = @as(usize, cell_px) * cell_px * 4;
        var glyphs: usize = 0;
        for (0..bound_count) |b| {
            if (glyphs >= out.len) break;
            const start = bounds[b];
            const end = if (b + 1 < bound_count) bounds[b + 1] else utf8.len;
            if (end <= start) continue;

            api.cairo_identity_matrix(cr);
            api.pango_cairo_update_layout(cr, layout);
            api.pango_layout_set_text(layout, utf8[start..].ptr, @intCast(end - start));
            var logical: Rect = undefined;
            api.pango_layout_get_pixel_extents(layout, null, &logical);
            const width: f64 = @floatFromInt(@max(logical.width, 0));
            const baseline = @as(f64, @floatFromInt(api.pango_layout_get_baseline(layout))) / pango_scale;

            const s: f64 = if (width > cell * 0.98) cell * 0.98 / width else 1.0;
            const ox = (cell - width) * 0.5;
            const oy = baseline_target - baseline;

            api.cairo_set_operator(cr, cairo_operator_clear);
            api.cairo_paint(cr);
            api.cairo_set_operator(cr, cairo_operator_over);
            api.cairo_set_source_rgba(cr, 1, 1, 1, 1);
            api.cairo_translate(cr, cell * 0.5 * (1.0 - s), cell * 0.5 * (1.0 - s));
            api.cairo_scale(cr, s, s);
            api.cairo_move_to(cr, ox, oy);
            api.pango_cairo_update_layout(cr, layout);
            api.pango_cairo_show_layout(cr, layout);
            api.cairo_surface_flush(surface);

            const data = api.cairo_image_surface_get_data(surface) orelse continue;
            const stride: usize = @intCast(api.cairo_image_surface_get_stride(surface));
            const dst = out_bgra[cell_bytes * glyphs ..][0..cell_bytes];
            const row = @as(usize, cell_px) * 4;
            for (0..cell_px) |y| @memcpy(dst[y * row ..][0..row], data[y * stride ..][0..row]);

            out[glyphs] = .{ .width = @floatCast(width * s / cell), .byte_start = @intCast(start), .byte_len = @intCast(end - start) };
            glyphs += 1;
        }
        return glyphs;
    }
};
