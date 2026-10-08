const std = @import("std");
const debounce = @import("debounce.zig");
const DebouncedDirty = debounce.DebouncedDirty;

pub const FftBakeState = struct {
    debounce_ms: f32 = 180,
    debounce_state: DebouncedDirty = .{},
};

pub fn sceneHash(inst: anytype) u64 {
    var h = std.hash.Wyhash.init(0);
    h.update(std.mem.asBytes(&inst.fft_box_radius));
    h.update(std.mem.asBytes(&inst.fft_lowpass));
    h.update(std.mem.asBytes(&inst.fft_highpass));
    h.update(std.mem.asBytes(&inst.fft_normalize));
    hashFormula(&h, inst.formula);
    for (0..inst.mixin_count) |j| {
        hashFormula(&h, inst.mixins[j].formula);
        h.update(std.mem.asBytes(&inst.mixins[j].iterations));
    }
    h.update(std.mem.asBytes(&inst.mixin_count));
    h.update(std.mem.asBytes(&inst.hybrid_base_iters));
    h.update(std.mem.asBytes(&inst.hybrid_total_iters));
    return h.final();
}

fn hashFormula(h: *std.hash.Wyhash, formula: anytype) void {
    if (formula.formula_body) |body| h.update(body);
    for (0..formula.custom_param_count) |i| {
        h.update(std.mem.asBytes(&formula.custom_params[i].value));
    }
    h.update(std.mem.asBytes(&formula.custom_param_count));
}

pub const Decision = enum {
    idle,
    rebuild,
};

pub fn update(state: *FftBakeState, active: bool, now_ms: u64, hash: u64) Decision {
    if (!active) {
        state.debounce_state.reset();
        return .idle;
    }
    const result = state.debounce_state.update(false, now_ms, hash, .{ 0, 0, 0 }, state.debounce_ms);
    return switch (result.decision) {
        .idle => .idle,
        .rebuild => .rebuild,
    };
}

pub fn noteBuilt(state: *FftBakeState) void {
    state.debounce_state.noteBuilt();
}

pub fn noteFailed(state: *FftBakeState, now_ms: u64) void {
    state.debounce_state.noteFailed(now_ms);
}
