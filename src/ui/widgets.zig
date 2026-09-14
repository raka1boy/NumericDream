const std = @import("std");
const nk = @import("../bindings/nuklear.zig").c;
const SliderRange = @import("../app/slider_range.zig").SliderRange;
const Vec3 = @import("../app/camera.zig").Vec3;
const scene_state = @import("../app/scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const max_color_stops = @import("../gpu/fractal_renderer.zig").max_color_stops;

var open_slider_menu: ?*f32 = null;
var open_menu_pos: nk.struct_nk_vec2 = undefined;

var value_field: NumberField = .{};
var min_field: NumberField = .{};
var max_field: NumberField = .{};

const float_slider_steps: f32 = 100000.0;

var dragging_slider: ?*f32 = null;

const NumberField = struct {
    buf: [48]u8 = @splat(0),
    len: c_int = 0,

    fn load(self: *NumberField, v: f32, integral: bool) void {
        const written = formatNumber(&self.buf, v, integral) catch "";
        self.len = @intCast(written.len);
    }

    fn parse(self: *const NumberField) ?f32 {
        const text = std.mem.trim(u8, self.buf[0..@intCast(self.len)], " \t");
        if (text.len == 0) return null;
        return std.fmt.parseFloat(f32, text) catch null;
    }
};

fn formatNumber(buf: []u8, v: f32, integral: bool) ![:0]const u8 {
    if (integral) return std.fmt.bufPrintSentinel(buf, "{d:.0}", .{v}, 0);
    return std.fmt.bufPrintSentinel(buf, "{d}", .{v}, 0) catch
        std.fmt.bufPrintSentinel(buf, "{e}", .{v}, 0);
}

fn textWidth(ctx: *const nk.nk_context, text: []const u8) f32 {
    const font = ctx.style.font orelse return @as(f32, @floatFromInt(text.len)) * 8.0;
    const measure = font.*.width orelse return @as(f32, @floatFromInt(text.len)) * 8.0;
    return measure(font.*.userdata, font.*.height, text.ptr, @intCast(text.len));
}

fn normalizeRange(range: *SliderRange, integral: bool) void {
    if (integral) {
        range.min = @round(range.min);
        range.max = @round(range.max);
    }
    const min_width: f32 = if (integral) 1.0 else 1e-12;
    //written as a negated >= so nan endpoint is repaired too
    if (!(range.max - range.min >= min_width)) range.max = range.min + min_width;
}

fn numberFieldRow(ctx: *nk.nk_context, label: [:0]const u8, field: *NumberField) void {
    nk.nk_layout_row_template_begin(ctx, 22);
    nk.nk_layout_row_template_push_static(ctx, 48);
    nk.nk_layout_row_template_push_dynamic(ctx);
    nk.nk_layout_row_template_end(ctx);
    nk.nk_label(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT));
    _ = nk.nk_edit_string(ctx, @intCast(nk.NK_EDIT_FIELD), &field.buf, &field.len, @intCast(field.buf.len), nk.nk_filter_float);
}

pub fn sliderFloat(ctx: *nk.nk_context, label: [:0]const u8, value: *f32, range: *SliderRange) void {
    slider(ctx, label, value, range, false);
}

pub fn sliderInt(ctx: *nk.nk_context, label: [:0]const u8, value: *f32, range: *SliderRange) void {
    slider(ctx, label, value, range, true);
}

pub fn sliderVec3(ctx: *nk.nk_context, label: []const u8, v: *Vec3, rx: *SliderRange, ry: *SliderRange, rz: *SliderRange) void {
    var buf: [48]u8 = undefined;
    sliderFloat(ctx, std.fmt.bufPrintSentinel(&buf, "{s} X", .{label}, 0) catch "X", &v.x, rx);
    sliderFloat(ctx, std.fmt.bufPrintSentinel(&buf, "{s} Y", .{label}, 0) catch "Y", &v.y, ry);
    sliderFloat(ctx, std.fmt.bufPrintSentinel(&buf, "{s} Z", .{label}, 0) catch "Z", &v.z, rz);
}

pub fn sectionLabel(ctx: *nk.nk_context, text: [:0]const u8) void {
    nk.nk_layout_row_dynamic(ctx, 16, 1);
    nk.nk_label(ctx, text.ptr, @intCast(nk.NK_TEXT_LEFT));
}

fn slider(ctx: *nk.nk_context, label: [:0]const u8, value: *f32, range: *SliderRange, integral: bool) void {
    normalizeRange(range, integral);
    const step = if (integral) 1.0 else (range.max - range.min) / float_slider_steps;

    var value_buf: [48]u8 = undefined;
    const value_text = formatNumber(&value_buf, value.*, integral) catch "";
    nk.nk_layout_row_template_begin(ctx, 16);
    nk.nk_layout_row_template_push_static(ctx, textWidth(ctx, label) + 4);
    nk.nk_layout_row_template_push_dynamic(ctx);
    nk.nk_layout_row_template_end(ctx);
    nk.nk_label(ctx, label.ptr, @intCast(nk.NK_TEXT_LEFT));
    nk.nk_label(ctx, value_text.ptr, @intCast(nk.NK_TEXT_RIGHT));

    nk.nk_layout_row_dynamic(ctx, 20, 1);
    const bounds = nk.nk_widget_bounds(ctx);

    const inner_x = bounds.x + ctx.style.slider.padding.x;
    const inner_w = bounds.w - 2 * ctx.style.slider.padding.x;
    if (inner_w > 0) {
        if (open_slider_menu == null and
            nk.nk_input_is_mouse_pressed(&ctx.input, nk.NK_BUTTON_LEFT) != 0 and
            nk.nk_widget_is_hovered(ctx) != 0)
        {
            dragging_slider = value;
        }
        if (dragging_slider == value) {
            if (nk.nk_input_is_mouse_down(&ctx.input, nk.NK_BUTTON_LEFT) != 0) {
                const t = (ctx.input.mouse.pos.x - inner_x) / inner_w;
                value.* = range.min + t * (range.max - range.min);
            } else {
                dragging_slider = null;
            }
        }
    }

    var display = std.math.clamp(value.*, range.min, range.max);
    const left_down = ctx.input.mouse.buttons[nk.NK_BUTTON_LEFT].down;
    ctx.input.mouse.buttons[nk.NK_BUTTON_LEFT].down = 0;
    _ = nk.nk_slider_float(ctx, range.min, &display, range.max, step);
    ctx.input.mouse.buttons[nk.NK_BUTTON_LEFT].down = left_down;

    if (open_slider_menu == null and nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_RIGHT, bounds) != 0) {
        const clip = nk.nk_window_get_content_region(ctx);
        open_slider_menu = value;
        open_menu_pos = nk.nk_vec2(ctx.input.mouse.pos.x - clip.x, ctx.input.mouse.pos.y - clip.y);
        value_field.load(value.*, integral);
        min_field.load(range.min, integral);
        max_field.load(range.max, integral);
    }

    if (open_slider_menu == value) {
        const popup_bounds = nk.nk_rect(open_menu_pos.x, open_menu_pos.y, 244, 100);
        if (nk.nk_popup_begin(ctx, nk.NK_POPUP_STATIC, "##slider_range_popup", nk.NK_WINDOW_NO_SCROLLBAR, popup_bounds) != 0) {
            numberFieldRow(ctx, "Value:", &value_field);
            numberFieldRow(ctx, "Min:", &min_field);
            numberFieldRow(ctx, "Max:", &max_field);

            if (min_field.parse()) |v| range.min = v;
            if (max_field.parse()) |v| range.max = v;
            normalizeRange(range, integral);
            if (value_field.parse()) |v| value.* = v;

            const win_bounds = nk.nk_window_get_bounds(ctx);
            const clicked_outside = (ctx.input.mouse.buttons[nk.NK_BUTTON_LEFT].clicked != 0 or
                ctx.input.mouse.buttons[nk.NK_BUTTON_RIGHT].clicked != 0) and
                nk.nk_input_is_mouse_hovering_rect(&ctx.input, win_bounds) == 0;
            if (clicked_outside) {
                nk.nk_popup_close(ctx);
                open_slider_menu = null;
            }
            nk.nk_popup_end(ctx);
        } else {
            open_slider_menu = null;
        }
    }
    if (integral) value.* = @round(value.*);
}

pub fn colorPickerCombo(ctx: *nk.nk_context, color: *[3]f32) void {
    const nkc = nk.nk_rgb_f(color[0], color[1], color[2]);
    if (nk.nk_combo_begin_color(ctx, nkc, nk.nk_vec2(nk.nk_widget_width(ctx), 260)) != 0) {
        nk.nk_layout_row_dynamic(ctx, 120, 1);
        var colorf = nk.nk_colorf{ .r = color[0], .g = color[1], .b = color[2], .a = 1.0 };
        colorf = nk.nk_color_picker(ctx, colorf, @intCast(nk.NK_RGB));
        color.* = .{ colorf.r, colorf.g, colorf.b };
        nk.nk_combo_end(ctx);
    }
}

pub fn separator(ctx: *nk.nk_context) void {
    nk.nk_layout_row_dynamic(ctx, 8, 1);
    nk.nk_rule_horizontal(ctx, nk.nk_rgb(70, 70, 70), 0);
}

pub fn selectableRemovableRow(ctx: *nk.nk_context, label: [:0]const u8, window_open: *bool, row_height: f32) bool {
    nk.nk_layout_row_dynamic(ctx, row_height, 2);
    var selected: nk.nk_bool = if (window_open.*) 1 else 0;
    _ = nk.nk_selectable_label(ctx, label.ptr, @intCast(nk.NK_TEXT_CENTERED), &selected);
    window_open.* = selected != 0;
    return nk.nk_button_label(ctx, "Remove") != 0;
}

var dragging_inst: ?*FractalInstanceState = null;
var dragging_index: usize = 0;

pub fn colorStripWidget(ctx: *nk.nk_context, inst: *FractalInstanceState) void {
    nk.nk_layout_row_dynamic(ctx, 36, 1);
    var bounds: nk.struct_nk_rect = undefined;
    const state = nk.nk_widget(&bounds, ctx);
    if (state == nk.NK_WIDGET_INVALID) return;

    var handled_click = false;
    if (dragging_inst == inst) {
        if (dragging_index >= inst.color_count) {
            dragging_inst = null;
        } else if (nk.nk_input_is_mouse_down(&ctx.input, nk.NK_BUTTON_LEFT) != 0) {
            inst.colors[dragging_index].position = std.math.clamp((ctx.input.mouse.pos.x - bounds.x) / bounds.w, 0.0, 1.0);
            handled_click = true;
        } else {
            dragging_inst = null;
            handled_click = true;
        }
    }

    const canvas = nk.nk_window_get_canvas(ctx);
    const order = scene_state.sortedColorOrder(&inst.colors, inst.color_count);

    if (inst.color_count == 0) {
        nk.nk_fill_rect(canvas, bounds, 2, nk.nk_rgb(40, 40, 40));
    } else if (inst.color_count == 1) {
        const c = inst.colors[0].color;
        nk.nk_fill_rect(canvas, bounds, 2, nk.nk_rgb_f(c[0], c[1], c[2]));
    } else {
        const first = inst.colors[order[0]];
        const first_col = nk.nk_rgb_f(first.color[0], first.color[1], first.color[2]);
        const first_x = bounds.x + first.position * bounds.w;
        if (first_x > bounds.x) {
            nk.nk_fill_rect(canvas, nk.nk_rect(bounds.x, bounds.y, first_x - bounds.x, bounds.h), 0, first_col);
        }
        for (0..inst.color_count - 1) |oi| {
            const a = inst.colors[order[oi]];
            const b = inst.colors[order[oi + 1]];
            const ax = bounds.x + a.position * bounds.w;
            const bx = bounds.x + b.position * bounds.w;
            const ca = nk.nk_rgb_f(a.color[0], a.color[1], a.color[2]);
            const cb = nk.nk_rgb_f(b.color[0], b.color[1], b.color[2]);
            if (bx > ax) {
                nk.nk_fill_rect_multi_color(canvas, nk.nk_rect(ax, bounds.y, bx - ax, bounds.h), ca, cb, cb, ca);
            }
        }
        const last = inst.colors[order[inst.color_count - 1]];
        const last_col = nk.nk_rgb_f(last.color[0], last.color[1], last.color[2]);
        const last_x = bounds.x + last.position * bounds.w;
        if (last_x < bounds.x + bounds.w) {
            nk.nk_fill_rect(canvas, nk.nk_rect(last_x, bounds.y, bounds.x + bounds.w - last_x, bounds.h), 0, last_col);
        }
    }
    nk.nk_stroke_rect(canvas, bounds, 2, 1.0, nk.nk_rgb(20, 20, 20));

    const marker_w: f32 = 10;
    var remove_index: ?usize = null;
    for (0..inst.color_count) |i| {
        const stop = inst.colors[i];
        const cx = bounds.x + stop.position * bounds.w;
        const marker = nk.nk_rect(cx - marker_w / 2, bounds.y - 4, marker_w, bounds.h + 8);
        const col = nk.nk_rgb_f(stop.color[0], stop.color[1], stop.color[2]);
        nk.nk_fill_rect(canvas, marker, 2, col);
        const is_selected = inst.selected_color != null and inst.selected_color.? == i;
        nk.nk_stroke_rect(canvas, marker, 2, if (is_selected) 2.5 else 1.0, if (is_selected) nk.nk_rgb(255, 220, 80) else nk.nk_rgb(230, 230, 230));

        if (nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_RIGHT, marker) != 0) {
            remove_index = i;
            handled_click = true;
        } else if (dragging_inst == null and
            nk.nk_input_is_mouse_pressed(&ctx.input, nk.NK_BUTTON_LEFT) != 0 and
            nk.nk_input_is_mouse_hovering_rect(&ctx.input, marker) != 0)
        {
            inst.selected_color = i;
            dragging_inst = inst;
            dragging_index = i;
            handled_click = true;
        }
    }

    if (remove_index) |idx| {
        var i = idx;
        while (i + 1 < inst.color_count) : (i += 1) inst.colors[i] = inst.colors[i + 1];
        inst.color_count -= 1;
        if (dragging_inst == inst) dragging_inst = null;
        if (inst.selected_color) |sel| {
            if (sel == idx) {
                inst.selected_color = null;
            } else if (sel > idx) {
                inst.selected_color = sel - 1;
            }
        }
    } else if (!handled_click and inst.color_count < max_color_stops and nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_LEFT, bounds) != 0) {
        const t = std.math.clamp((ctx.input.mouse.pos.x - bounds.x) / bounds.w, 0.0, 1.0);
        const new_index = inst.color_count;
        inst.colors[new_index] = .{ .position = t, .color = .{ 0.7, 0.7, 0.7 } };
        inst.color_count += 1;
        inst.selected_color = new_index;
    }
}
