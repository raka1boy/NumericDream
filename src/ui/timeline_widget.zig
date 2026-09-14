const std = @import("std");
const nk = @import("../bindings/nuklear.zig").c;

const scene_state = @import("../app/scene_state.zig");
const FractalInstanceState = scene_state.FractalInstanceState;
const LightState = scene_state.LightState;
const FogEmitterState = scene_state.FogEmitterState;
const WarpState = @import("../app/warp.zig").WarpState;
const FreeCamera = @import("../app/camera.zig").FreeCamera;

const animation = @import("../app/animation.zig");
const TimelineState = animation.TimelineState;

const panel_h: f32 = 116;
const controls_h: f32 = 24;
const ruler_h: f32 = 18;
const track_h: f32 = 40;
const marker_w: f32 = 10;

var ruler_dragging: bool = false;

pub fn build(
    ctx: *nk.nk_context,
    timeline: *TimelineState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    lights: []const LightState,
    light_count: usize,
    fog_emitters: []const FogEmitterState,
    fog_count: usize,
    warps: []const WarpState,
    warp_count: usize,
    camera: FreeCamera,
    width: f32,
    height: f32,
) void {
    timeline.playhead = std.math.clamp(timeline.playhead, 0, timeline.duration);

    if (nk.nk_begin(
        ctx,
        "Timeline",
        nk.nk_rect(0, height - panel_h, width, panel_h),
        @intCast(nk.NK_WINDOW_BORDER | nk.NK_WINDOW_NO_SCROLLBAR),
    ) != 0) {
        buildControlsRow(ctx, timeline);
        buildRulerRow(ctx, timeline);
        buildTrackRow(ctx, timeline, instances, instance_count, lights, light_count, fog_emitters, fog_count, warps, warp_count, camera);
    }
    nk.nk_end(ctx);
}

fn buildControlsRow(ctx: *nk.nk_context, timeline: *TimelineState) void {
    nk.nk_layout_row_dynamic(ctx, controls_h, 3);

    _ = nk.nk_property_float(ctx, "Duration (s)", timeline.duration_range.min, &timeline.duration, timeline.duration_range.max, 0.5, 0.1);

    if (nk.nk_button_label(ctx, if (timeline.playing) "Pause" else "Play") != 0) {
        timeline.playing = !timeline.playing;
    }

    var buf: [64]u8 = undefined;
    const label: [:0]const u8 = std.fmt.bufPrintSentinel(&buf, "{d} keyframes  t={d:.2}s", .{ timeline.keyframe_count, timeline.playhead }, 0) catch "Timeline";
    nk.nk_label(ctx, label.ptr, @intCast(nk.NK_TEXT_CENTERED));
}

fn buildRulerRow(ctx: *nk.nk_context, timeline: *TimelineState) void {
    nk.nk_layout_row_dynamic(ctx, ruler_h, 1);
    var bounds: nk.struct_nk_rect = undefined;
    const state = nk.nk_widget(&bounds, ctx);
    if (state == nk.NK_WIDGET_INVALID) return;

    const canvas = nk.nk_window_get_canvas(ctx);
    nk.nk_fill_rect(canvas, bounds, 2, nk.nk_rgb(30, 30, 34));
    nk.nk_stroke_rect(canvas, bounds, 2, 1.0, nk.nk_rgb(20, 20, 20));

    const px = bounds.x + (timeline.playhead / @max(timeline.duration, 0.001)) * bounds.w;
    nk.nk_stroke_line(canvas, px, bounds.y, px, bounds.y + bounds.h, 2.0, nk.nk_rgb(255, 220, 80));

    if (nk.nk_input_is_mouse_pressed(&ctx.input, nk.NK_BUTTON_LEFT) != 0 and nk.nk_input_is_mouse_hovering_rect(&ctx.input, bounds) != 0) {
        ruler_dragging = true;
    }
    if (ruler_dragging) {
        if (nk.nk_input_is_mouse_down(&ctx.input, nk.NK_BUTTON_LEFT) != 0) {
            const t = std.math.clamp((ctx.input.mouse.pos.x - bounds.x) / bounds.w, 0.0, 1.0) * timeline.duration;
            timeline.playhead = t;
            timeline.dirty = true;
        } else {
            ruler_dragging = false;
        }
    }
}

fn buildTrackRow(
    ctx: *nk.nk_context,
    timeline: *TimelineState,
    instances: []const FractalInstanceState,
    instance_count: usize,
    lights: []const LightState,
    light_count: usize,
    fog_emitters: []const FogEmitterState,
    fog_count: usize,
    warps: []const WarpState,
    warp_count: usize,
    camera: FreeCamera,
) void {
    nk.nk_layout_row_dynamic(ctx, track_h, 1);
    var bounds: nk.struct_nk_rect = undefined;
    const state = nk.nk_widget(&bounds, ctx);
    if (state == nk.NK_WIDGET_INVALID) return;

    const canvas = nk.nk_window_get_canvas(ctx);
    nk.nk_fill_rect(canvas, bounds, 2, nk.nk_rgb(46, 46, 52));
    nk.nk_stroke_rect(canvas, bounds, 2, 1.0, nk.nk_rgb(20, 20, 20));

    const duration = @max(timeline.duration, 0.001);
    var remove_index: ?usize = null;
    var recapture_index: ?usize = null;
    var handled_click = false;

    for (0..timeline.keyframe_count) |i| {
        const kf_time = timeline.keyframes[i].time;
        const cx = bounds.x + (kf_time / duration) * bounds.w;
        const marker = nk.nk_rect(cx - marker_w / 2, bounds.y, marker_w, bounds.h);
        nk.nk_fill_rect(canvas, marker, 2, nk.nk_rgb(120, 170, 230));
        nk.nk_stroke_rect(canvas, marker, 2, 1.0, nk.nk_rgb(230, 230, 230));

        if (nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_RIGHT, marker) != 0) {
            remove_index = i;
            handled_click = true;
        } else if (nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_LEFT, marker) != 0) {
            recapture_index = i;
            handled_click = true;
        }
    }

    if (remove_index) |idx| {
        animation.removeKeyframeAt(timeline, idx);
    } else if (recapture_index) |idx| {
        const snap = animation.captureSnapshot(instances, instance_count, lights, light_count, fog_emitters, fog_count, warps, warp_count, camera);
        animation.updateKeyframeAt(timeline, idx, snap);
        timeline.playhead = timeline.keyframes[idx].time;
    } else if (!handled_click and nk.nk_input_mouse_clicked(&ctx.input, nk.NK_BUTTON_LEFT, bounds) != 0) {
        const t = std.math.clamp((ctx.input.mouse.pos.x - bounds.x) / bounds.w, 0.0, 1.0) * timeline.duration;
        const snap = animation.captureSnapshot(instances, instance_count, lights, light_count, fog_emitters, fog_count, warps, warp_count, camera);
        if (animation.addKeyframe(timeline, t, snap)) |_| {
            timeline.playhead = t;
        }
    }
}
