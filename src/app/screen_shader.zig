const std = @import("std");
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("../gpu/webgpu_context.zig");
const Context = webgpu_context.Context;
const post = @import("../gpu/post_process.zig");
const PostChain = post.PostChain;
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const max_params = fractal_gpu.max_params;
const formula_mod = @import("formula.zig");
const CustomParam = formula_mod.CustomParam;
const glyph_atlas = @import("../gpu/glyph_atlas.zig");
const GlyphAtlas = glyph_atlas.GlyphAtlas;

pub const max_screen_shaders = post.max_effects;
pub const max_path_len: usize = 256;
pub const max_name_len: usize = 28;
pub const status_buf_len: usize = 160;
pub const max_text_fields = glyph_atlas.max_fields;
pub const max_text_bytes: usize = 256;
pub const max_text_name_len: usize = 23;
pub const max_font_bytes: usize = 64;

pub const TextField = struct {
    name: [max_text_name_len + 1:0]u8 = std.mem.zeroes([max_text_name_len + 1:0]u8),
    name_len: usize = 0,
    value: [max_text_bytes:0]u8 = std.mem.zeroes([max_text_bytes:0]u8),

    pub fn label(self: *const TextField) [:0]const u8 {
        return self.name[0..self.name_len :0];
    }

    pub fn text(self: *const TextField) []const u8 {
        const n = std.mem.indexOfScalar(u8, &self.value, 0) orelse self.value.len;
        return self.value[0..n];
    }

    pub fn setText(self: *TextField, value: []const u8) void {
        var n = @min(value.len, max_text_bytes - 1);
        while (n > 0 and n < value.len and (value[n] & 0xC0) == 0x80) n -= 1;
        @memset(&self.value, 0);
        @memcpy(self.value[0..n], value[0..n]);
    }
};

pub const ScreenShaderState = struct {
    path: [max_path_len:0]u8,
    name: [max_name_len:0]u8,
    name_len: usize,
    body: ?[]u8,
    compile_error: [192:0]u8,
    compile_error_len: usize,
    params: [max_params]CustomParam,
    param_count: usize,
    texts: [max_text_fields]TextField = @splat(.{}),
    text_count: usize = 0,
    font: [max_font_bytes:0]u8 = std.mem.zeroes([max_font_bytes:0]u8),
    glyphs: GlyphAtlas = .{},
    glyph_key: u64 = 0,
    enabled: bool = true,
    animated: bool = false,
    window_open: bool = false,
    pipeline: wgpu.WGPURenderPipeline = null,

    pub fn init() ScreenShaderState {
        return .{
            .path = std.mem.zeroes([max_path_len:0]u8),
            .name = std.mem.zeroes([max_name_len:0]u8),
            .name_len = 0,
            .body = null,
            .compile_error = std.mem.zeroes([192:0]u8),
            .compile_error_len = 0,
            .params = undefined,
            .param_count = 0,
        };
    }

    pub fn deinit(self: *ScreenShaderState, allocator: std.mem.Allocator) void {
        if (self.body) |b| allocator.free(b);
        self.body = null;
        if (self.pipeline != null) wgpu.wgpuRenderPipelineRelease(self.pipeline);
        self.pipeline = null;
        self.glyphs.deinit();
        self.glyph_key = 0;
    }

    pub fn fontSlice(self: *const ScreenShaderState) [:0]const u8 {
        const n = std.mem.indexOfScalar(u8, &self.font, 0) orelse self.font.len;
        return self.font[0..n :0];
    }

    pub fn setFont(self: *ScreenShaderState, family: []const u8) void {
        const n = @min(family.len, max_font_bytes - 1);
        @memset(&self.font, 0);
        @memcpy(self.font[0..n], family[0..n]);
    }

    pub fn textField(self: *ScreenShaderState, name: []const u8) ?*TextField {
        for (self.texts[0..self.text_count]) |*t| {
            if (std.mem.eql(u8, t.label(), name)) return t;
        }
        return null;
    }

    fn glyphSourceKey(self: *const ScreenShaderState) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(self.fontSlice());
        for (self.texts[0..self.text_count]) |*t| {
            h.update(&[_]u8{0xff});
            h.update(t.text());
        }
        return h.final() | 1;
    }

    pub fn refreshGlyphs(self: *ScreenShaderState, allocator: std.mem.Allocator, ctx: *const Context, chain: *const PostChain) void {
        if (self.text_count == 0) {
            if (self.glyph_key != 0) {
                self.glyphs.deinit();
                self.glyph_key = 0;
            }
            return;
        }
        const key = self.glyphSourceKey();
        if (key == self.glyph_key) return;
        self.glyph_key = key;
        var fields: [max_text_fields][]const u8 = undefined;
        for (0..self.text_count) |i| fields[i] = self.texts[i].text();
        const built = glyph_atlas.build(ctx, allocator, chain.glyph_layout, chain.glyph_sampler, fields[0..self.text_count], self.fontSlice()) catch |err| {
            std.debug.print("[screen shader] glyph atlas failed: {s}\n", .{@errorName(err)});
            return;
        };
        self.glyphs.deinit();
        self.glyphs = built;
    }

    pub fn pathSlice(self: *const ScreenShaderState) []const u8 {
        const n = std.mem.indexOfScalar(u8, &self.path, 0) orelse self.path.len;
        return self.path[0..n];
    }

    pub fn setPath(self: *ScreenShaderState, path: []const u8) void {
        const n = @min(path.len, max_path_len - 1);
        @memcpy(self.path[0..n], path[0..n]);
        self.path[n] = 0;
        self.refreshName();
    }

    fn refreshName(self: *ScreenShaderState) void {
        const path = self.pathSlice();
        var start: usize = 0;
        for (path, 0..) |c, i| {
            if (c == '/' or c == '\\') start = i + 1;
        }
        var stem = path[start..];
        if (std.mem.lastIndexOfScalar(u8, stem, '.')) |dot| stem = stem[0..dot];
        if (std.mem.indexOfScalar(u8, stem, '_')) |us| stem = stem[0..us];
        const n = @min(stem.len, max_name_len);
        @memcpy(self.name[0..n], stem[0..n]);
        self.name[n] = 0;
        self.name_len = n;
    }

    pub fn label(self: *const ScreenShaderState) [:0]const u8 {
        if (self.name_len == 0) return "(no shader)";
        return self.name[0..self.name_len :0];
    }

    pub fn setError(self: *ScreenShaderState, msg: []const u8) void {
        const n = @min(msg.len, 191);
        @memcpy(self.compile_error[0..n], msg[0..n]);
        self.compile_error[n] = 0;
        self.compile_error_len = n;
    }

    pub fn clearError(self: *ScreenShaderState) void {
        self.compile_error_len = 0;
    }

    pub fn packedParams(self: *const ScreenShaderState) fractal_gpu.PackedParams {
        return formula_mod.packParams(&self.params, self.param_count);
    }

    pub fn isActive(self: *const ScreenShaderState) bool {
        return self.enabled and self.pipeline != null;
    }
};

pub fn newScreenShader() ScreenShaderState {
    return ScreenShaderState.init();
}

pub fn compileInto(
    allocator: std.mem.Allocator,
    ctx: *const Context,
    chain: *const PostChain,
    state: *ScreenShaderState,
) void {
    const path = state.pathSlice();
    if (path.len == 0) {
        state.setError("No file path given.");
        return;
    }

    const io = std.Io.Threaded.global_single_threaded.io();
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(post.max_source_bytes)) catch |err| {
        var buf: [status_buf_len]u8 = undefined;
        state.setError(std.fmt.bufPrint(&buf, "Could not read file ({s}).", .{@errorName(err)}) catch "Could not read file.");
        return;
    };

    if (post.missingContractFn(content)) |sig| {
        allocator.free(content);
        var buf: [status_buf_len]u8 = undefined;
        state.setError(std.fmt.bufPrint(&buf, "File must define `{s}`.", .{sig}) catch "File is missing the effect entry point.");
        return;
    }

    const pipeline = chain.compile(ctx, allocator, content) catch |err| {
        allocator.free(content);
        const sink = webgpu_context.g_error_sink.message();
        if (sink.len > 0) {
            state.setError(sink);
        } else {
            var buf: [status_buf_len]u8 = undefined;
            state.setError(std.fmt.bufPrint(&buf, "Shader failed to compile ({s}).", .{@errorName(err)}) catch "Shader failed to compile.");
        }
        return;
    };

    if (state.pipeline != null) wgpu.wgpuRenderPipelineRelease(state.pipeline);
    state.pipeline = pipeline;
    if (state.body) |old| allocator.free(old);
    state.body = content;
    state.refreshName();
    formula_mod.parseFormulaParams(content, &state.params, &state.param_count);
    parseTextFields(content, state);
    state.clearError();
}

pub fn buildEffects(shaders: []const ScreenShaderState, out: *[max_screen_shaders]post.Effect) []const post.Effect {
    var n: usize = 0;
    for (shaders) |*s| {
        if (n >= max_screen_shaders) break;
        if (!s.isActive()) continue;
        out[n] = .{
            .pipeline = s.pipeline,
            .glyph_group = if (s.text_count > 0) s.glyphs.group else null,
            .params = s.packedParams(),
        };
        n += 1;
    }
    return out[0..n];
}

pub fn anyActive(shaders: []const ScreenShaderState) bool {
    for (shaders) |*s| {
        if (s.isActive()) return true;
    }
    return false;
}

pub fn anyAnimated(shaders: []const ScreenShaderState) bool {
    for (shaders) |*s| {
        if (s.isActive() and s.animated) return true;
    }
    return false;
}

pub fn refreshAllGlyphs(allocator: std.mem.Allocator, ctx: *const Context, chain: *const PostChain, shaders: []ScreenShaderState) void {
    for (shaders) |*s| s.refreshGlyphs(allocator, ctx, chain);
}

fn parseTextLine(line: []const u8) ?struct { name: []const u8, default: []const u8 } {
    const marker = "@text";
    const idx = std.mem.indexOf(u8, line, marker) orelse return null;
    const rest = line[idx + marker.len ..];
    const open = std.mem.indexOfScalar(u8, rest, '"');
    const close = std.mem.lastIndexOfScalar(u8, rest, '"');
    if (open != null and close != null and close.? > open.?) {
        const name = std.mem.trim(u8, rest[0..open.?], " \t");
        if (name.len == 0) return null;
        return .{ .name = name, .default = rest[open.? + 1 .. close.?] };
    }
    const name = std.mem.trim(u8, rest, " \t\r");
    if (name.len == 0) return null;
    return .{ .name = name, .default = "" };
}

fn parseTextFields(content: []const u8, state: *ScreenShaderState) void {
    const old = state.texts;
    const old_count = state.text_count;
    state.text_count = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        if (state.text_count >= max_text_fields) break;
        const line = std.mem.trimEnd(u8, line_raw, "\r");
        const parsed = parseTextLine(line) orelse continue;
        const field = &state.texts[state.text_count];
        field.* = .{};
        const n = @min(parsed.name.len, max_text_name_len);
        @memcpy(field.name[0..n], parsed.name[0..n]);
        field.name_len = n;
        field.setText(parsed.default);
        for (old[0..old_count]) |*o| {
            if (std.mem.eql(u8, o.label(), field.label())) {
                field.setText(o.text());
                break;
            }
        }
        state.text_count += 1;
    }
}
