const std = @import("std");
const fractal_gpu = @import("../gpu/fractal_renderer.zig");
const max_params = fractal_gpu.max_params;
const SliderRange = @import("slider_range.zig").SliderRange;

pub const CustomParam = struct {
    name: [24:0]u8,
    name_len: usize,
    value: f32,
    default: f32,
    range: SliderRange,
    integral: bool = false,

    pub fn label(self: *const CustomParam) [:0]const u8 {
        return self.name[0..self.name_len :0];
    }
};

pub fn makeParam(name: []const u8, min: f32, max: f32, default: f32, integral: bool) CustomParam {
    var p = CustomParam{
        .name = std.mem.zeroes([24:0]u8),
        .name_len = 0,
        .value = default,
        .default = default,
        .range = .{ .min = min, .max = max },
        .integral = integral,
    };
    const n = @min(name.len, 23);
    @memcpy(p.name[0..n], name[0..n]);
    p.name[n] = 0;
    p.name_len = n;
    return p;
}

pub fn defaultBuiltinParams(out: *[max_params]CustomParam) usize {
    out[0] = makeParam("Power", 2.0, 16.0, 8.0, false);
    out[1] = makeParam("Iterations", 2.0, 16.0, 6.0, true);
    for (2..max_params) |i| out[i] = makeParam("", 0, 1, 0, false);
    return 2;
}

pub const FormulaState = struct {
    formula_path: [256:0]u8,
    formula_body: ?[]u8,
    formula_error: [192:0]u8,
    formula_error_len: usize,
    custom_params: [max_params]CustomParam,
    custom_param_count: usize,
    compile_pending: bool = false,
    pending_old_body: ?[]u8 = null,
    pending_new_body: ?[]u8 = null,
    pending_params: [max_params]CustomParam = undefined,
    pending_param_count: usize = 0,

    pub fn init() FormulaState {
        var f = FormulaState{
            .formula_path = std.mem.zeroes([256:0]u8),
            .formula_body = null,
            .formula_error = std.mem.zeroes([192:0]u8),
            .formula_error_len = 0,
            .custom_params = undefined,
            .custom_param_count = 0,
        };
        f.custom_param_count = defaultBuiltinParams(&f.custom_params);
        return f;
    }

    pub fn deinit(self: *const FormulaState, allocator: std.mem.Allocator) void {
        if (self.formula_body) |b| allocator.free(b);
    }

    pub fn setError(self: *FormulaState, msg: []const u8) void {
        const n = @min(msg.len, 191);
        @memcpy(self.formula_error[0..n], msg[0..n]);
        self.formula_error[n] = 0;
        self.formula_error_len = n;
    }

    pub fn clearError(self: *FormulaState) void {
        self.formula_error_len = 0;
    }

    pub fn packedParams(self: *const FormulaState) [2][4]f32 {
        var out: [2][4]f32 = .{ .{ 0, 0, 0, 0 }, .{ 0, 0, 0, 0 } };
        for (0..@min(self.custom_param_count, max_params)) |i| out[i / 4][i % 4] = self.custom_params[i].value;
        return out;
    }
};

fn parseParamLine(line: []const u8) ?CustomParam {
    const marker = "@param";
    const idx = std.mem.indexOf(u8, line, marker) orelse return null;
    const rest = std.mem.trim(u8, line[idx + marker.len ..], " \t");
    var tokens = std.mem.tokenizeAny(u8, rest, " \t");
    const name = tokens.next() orelse return null;

    var min_v: f32 = 0.0;
    var max_v: f32 = 1.0;
    var default_v: f32 = 0.0;
    var integral = false;
    while (tokens.next()) |tok| {
        const eq = std.mem.indexOfScalar(u8, tok, '=') orelse {
            if (std.mem.eql(u8, tok, "int")) integral = true;
            continue;
        };
        const key = tok[0..eq];
        const val = std.fmt.parseFloat(f32, tok[eq + 1 ..]) catch continue;
        if (std.mem.eql(u8, key, "min")) {
            min_v = val;
        } else if (std.mem.eql(u8, key, "max")) {
            max_v = val;
        } else if (std.mem.eql(u8, key, "default")) {
            default_v = val;
        }
    }
    return makeParam(name, min_v, max_v, default_v, integral);
}

pub fn parseFormulaParams(content: []const u8, out: *[max_params]CustomParam, out_count: *usize) void {
    out_count.* = 0;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_raw| {
        if (out_count.* >= max_params) break;
        const line = std.mem.trim(u8, line_raw, " \t\r");
        const param = parseParamLine(line) orelse continue;
        out[out_count.*] = param;
        out_count.* += 1;
    }
}

pub fn missingContractFn(content: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, content, "fn de_step(") == null) {
        return "fn de_step(carry: IterCarry, pos: vec3f, p: array<f32, 8>) -> IterCarry";
    }
    if (std.mem.indexOf(u8, content, "fn de_finalize(") == null) {
        return "fn de_finalize(carry: IterCarry) -> f32";
    }
    if (std.mem.indexOf(u8, content, "fn de_iterations(") == null) {
        return "fn de_iterations(p: array<f32, 8>) -> i32";
    }
    return null;
}
