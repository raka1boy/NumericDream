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

pub const max_screen_shaders = post.max_effects;
pub const max_path_len: usize = 256;
pub const max_name_len: usize = 28;
pub const status_buf_len: usize = 160;

pub const ScreenShaderState = struct {
    path: [max_path_len:0]u8,
    name: [max_name_len:0]u8,
    name_len: usize,
    body: ?[]u8,
    compile_error: [192:0]u8,
    compile_error_len: usize,
    params: [max_params]CustomParam,
    param_count: usize,
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

    pub fn packedParams(self: *const ScreenShaderState) [2][4]f32 {
        var out: [2][4]f32 = .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } };
        for (0..@min(self.param_count, max_params)) |i| out[i / 4][i % 4] = self.params[i].value;
        return out;
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
    state.clearError();
}

pub fn buildEffects(shaders: []const ScreenShaderState, out: *[max_screen_shaders]post.Effect) []const post.Effect {
    var n: usize = 0;
    for (shaders) |*s| {
        if (n >= max_screen_shaders) break;
        if (!s.isActive()) continue;
        const p = s.packedParams();
        out[n] = .{ .pipeline = s.pipeline, .params0 = p[0], .params1 = p[1] };
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
