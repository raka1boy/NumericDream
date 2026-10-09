const std = @import("std");
const nk = @import("../bindings/nuklear.zig").c;
const timeline_widget = @import("timeline_widget.zig");

pub const menu_h: f32 = 28;
pub const side_w: f32 = 290;
const margin: f32 = 6;
const slot_w: f32 = 344;
const cascade: f32 = 28;
const reachable_px: f32 = 60;

pub const Workspace = struct {
    width: f32,
    height: f32,

    pub fn top(self: Workspace) f32 {
        _ = self;
        return menu_h + margin;
    }

    pub fn bottom(self: Workspace) f32 {
        return @max(self.height - timeline_widget.panel_h - margin, self.top() + 120);
    }

    pub fn availH(self: Workspace) f32 {
        return self.bottom() - self.top();
    }

    fn leftX(self: Workspace) f32 {
        _ = self;
        return margin;
    }

    fn rightX(self: Workspace) f32 {
        return @max(self.width - side_w - margin, margin);
    }

    pub fn renderRect(self: Workspace) nk.struct_nk_rect {
        return nk.nk_rect(self.leftX(), self.top(), side_w, self.availH() * 0.68);
    }

    pub fn cameraRect(self: Workspace) nk.struct_nk_rect {
        const y = self.top() + self.availH() * 0.68 + margin;
        return nk.nk_rect(self.leftX(), y, side_w, self.bottom() - y);
    }

    pub fn sceneRect(self: Workspace) nk.struct_nk_rect {
        return nk.nk_rect(self.rightX(), self.top(), side_w, self.availH() * 0.6);
    }

    pub fn outputRect(self: Workspace) nk.struct_nk_rect {
        const y = self.top() + self.availH() * 0.6 + margin;
        return nk.nk_rect(self.rightX(), y, side_w, self.bottom() - y);
    }
};

pub const Placement = union(enum) {
    fixed: nk.struct_nk_rect,
    floating: [2]f32,
};

const window_flags = nk.NK_WINDOW_BORDER | nk.NK_WINDOW_MOVABLE | nk.NK_WINDOW_TITLE | nk.NK_WINDOW_SCALABLE | nk.NK_WINDOW_CLOSABLE;

pub fn begin(ctx: *nk.nk_context, ws: Workspace, title: [:0]const u8, placement: Placement) bool {
    const existing = nk.nk_window_find(ctx, title.ptr);
    const rect = if (existing != null) blk: {
        keepReachable(ws, &existing.*.bounds);
        break :blk existing.*.bounds;
    } else switch (placement) {
        .fixed => |r| fit(ws, r),
        .floating => |size| freeSlot(ctx, ws, size[0], size[1]),
    };
    return nk.nk_begin(ctx, title.ptr, rect, @intCast(window_flags)) != 0;
}

pub fn end(ctx: *nk.nk_context, title: [:0]const u8, open: *bool) void {
    nk.nk_end(ctx);
    if (nk.nk_window_is_hidden(ctx, title.ptr) != 0) open.* = false;
}

fn keepReachable(ws: Workspace, b: *nk.struct_nk_rect) void {
    b.h = @min(b.h, @max(ws.height - menu_h, 60));
    b.y = @max(menu_h, @min(b.y, ws.height - 40));
    b.x = @max(reachable_px - b.w, @min(b.x, ws.width - reachable_px));
}

fn fit(ws: Workspace, r: nk.struct_nk_rect) nk.struct_nk_rect {
    var out = r;
    out.w = @min(out.w, @max(ws.width - 2 * margin, 120));
    out.x = @max(margin, @min(out.x, ws.width - out.w - margin));
    out.y = @max(ws.top(), @min(out.y, ws.bottom() - 120));
    out.h = @max(@min(out.h, ws.bottom() - out.y), 120);
    return out;
}

fn freeSlot(ctx: *const nk.nk_context, ws: Workspace, w: f32, h: f32) nk.struct_nk_rect {
    const x0 = ws.leftX() + side_w + margin;
    const x1 = ws.rightX() - margin;
    const cols: usize = if (x1 - x0 >= slot_w) @intFromFloat(@floor((x1 - x0 + margin) / (slot_w + margin))) else 1;
    for (0..10) |row| {
        const shift = @as(f32, @floatFromInt(row)) * cascade;
        for (0..cols) |col| {
            const x = x0 + @as(f32, @floatFromInt(col)) * (slot_w + margin) + shift;
            const y = ws.top() + shift;
            if (!occupied(ctx, x, y)) return fit(ws, nk.nk_rect(x, y, w, h));
        }
    }
    return fit(ws, nk.nk_rect(x0, ws.top(), w, h));
}

fn occupied(ctx: *const nk.nk_context, x: f32, y: f32) bool {
    const hidden: u32 = @intCast(nk.NK_WINDOW_HIDDEN);
    var it = ctx.begin;
    while (it != null) : (it = it.*.next) {
        if (it.*.flags & hidden != 0) continue;
        const b = it.*.bounds;
        if (@abs(b.x - x) < 20 and @abs(b.y - y) < 20) return true;
    }
    return false;
}
