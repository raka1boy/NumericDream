//use this by setting NUMERICDREAM_PERF=1 in the env

const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;

const max_tracked_events = 24;

const EventCount = struct { kind: u32, count: u32 };

pub const Probe = struct {
    enabled: bool = false,
    window_start_ms: u64 = 0,
    iterations: u32 = 0,
    renders: u32 = 0,
    blocking_waits: u32 = 0,
    skipped_frames: u32 = 0,
    render_ms: u64 = 0,
    render_start_ms: u64 = 0,

    events: [max_tracked_events]EventCount = @splat(.{ .kind = 0, .count = 0 }),
    event_kinds: usize = 0,
    events_other: u32 = 0,
    last_reconfigure_total: u32 = 0,

    pub fn init() Probe {
        const on = sdl.SDL_getenv("NUMERICDREAM_PERF") != null;
        if (on) {
            std.debug.print(
                "[perf] enabled. iter=loop passes, render=frames drawn, wait=idle blocks, " ++
                    "skip=failed acquires, recfg=swapchain reconfigures, cpu_ms=main-thread " ++
                    "ms in render.\n",
                .{},
            );
        }
        return .{ .enabled = on, .window_start_ms = sdl.SDL_GetTicks() };
    }

    pub fn countIteration(self: *Probe, blocked: bool) void {
        self.iterations +%= 1;
        if (blocked) self.blocking_waits +%= 1;
    }

    pub fn countEvent(self: *Probe, kind: u32) void {
        for (self.events[0..self.event_kinds]) |*e| {
            if (e.kind == kind) {
                e.count +%= 1;
                return;
            }
        }
        if (self.event_kinds < self.events.len) {
            self.events[self.event_kinds] = .{ .kind = kind, .count = 1 };
            self.event_kinds += 1;
            return;
        }
        self.events_other +%= 1;
    }

    pub fn renderBegin(self: *Probe) void {
        self.render_start_ms = sdl.SDL_GetTicks();
    }

    pub fn renderEnd(self: *Probe) void {
        self.renders +%= 1;
        self.render_ms +%= sdl.SDL_GetTicks() -| self.render_start_ms;
    }

    pub fn countSkippedFrame(self: *Probe) void {
        self.skipped_frames +%= 1;
    }

    pub fn maybeReport(self: *Probe, reconfigure_total: u32, last_status: c_uint) void {
        const now = sdl.SDL_GetTicks();
        const elapsed = now -| self.window_start_ms;
        if (elapsed < 1000) return;
        defer self.reset(now, reconfigure_total);
        if (!self.enabled) return;

        std.debug.print(
            "[perf] iter={d} render={d} wait={d} skip={d} recfg={d} cpu_ms={d}/{d} last_acquire={s}",
            .{
                self.iterations,
                self.renders,
                self.blocking_waits,
                self.skipped_frames,
                reconfigure_total -% self.last_reconfigure_total,
                self.render_ms,
                elapsed,
                acquireStatusName(last_status),
            },
        );
        for (self.events[0..self.event_kinds]) |e| {
            const name = eventName(e.kind);
            if (std.mem.eql(u8, name, "evt")) {
                std.debug.print(" evt:0x{x}={d}", .{ e.kind, e.count });
            } else {
                std.debug.print(" {s}={d}", .{ name, e.count });
            }
        }
        if (self.events_other > 0) std.debug.print(" other={d}", .{self.events_other});
        std.debug.print("\n", .{});
    }

    fn reset(self: *Probe, now: u64, reconfigure_total: u32) void {
        self.window_start_ms = now;
        self.iterations = 0;
        self.renders = 0;
        self.blocking_waits = 0;
        self.skipped_frames = 0;
        self.render_ms = 0;
        self.event_kinds = 0;
        self.events_other = 0;
        self.last_reconfigure_total = reconfigure_total;
    }
};

fn wgpuStatus(comptime name: []const u8) c_uint {
    return @field(wgpu, "WGPUSurfaceGetCurrentTextureStatus_" ++ name);
}

fn acquireStatusName(status: c_uint) []const u8 {
    if (status == wgpuStatus("SuccessOptimal")) return "Optimal";
    if (status == wgpuStatus("SuccessSuboptimal")) return "Suboptimal";
    if (status == wgpuStatus("Timeout")) return "Timeout";
    if (status == wgpuStatus("Outdated")) return "Outdated";
    if (status == wgpuStatus("Lost")) return "Lost";
    if (status == wgpuStatus("Error")) return "Error";
    return "?";
}

fn eventName(kind: u32) []const u8 {
    if (kind == sdl.SDL_EVENT_QUIT) return "quit";
    if (kind == sdl.SDL_EVENT_KEY_DOWN) return "key_dn";
    if (kind == sdl.SDL_EVENT_KEY_UP) return "key_up";
    if (kind == sdl.SDL_EVENT_TEXT_INPUT) return "text";
    if (kind == sdl.SDL_EVENT_MOUSE_MOTION) return "motion";
    if (kind == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) return "btn_dn";
    if (kind == sdl.SDL_EVENT_MOUSE_BUTTON_UP) return "btn_up";
    if (kind == sdl.SDL_EVENT_MOUSE_WHEEL) return "wheel";
    if (kind == sdl.SDL_EVENT_WINDOW_EXPOSED) return "exposed";
    if (kind == sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED) return "pixsize";
    if (kind == sdl.SDL_EVENT_WINDOW_RESIZED) return "resized";
    if (kind == sdl.SDL_EVENT_WINDOW_MOVED) return "moved";
    if (kind == sdl.SDL_EVENT_WINDOW_OCCLUDED) return "occluded";
    if (kind == sdl.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED) return "dpiscale";
    if (kind == sdl.SDL_EVENT_WINDOW_FOCUS_GAINED) return "focus_in";
    if (kind == sdl.SDL_EVENT_WINDOW_FOCUS_LOST) return "focus_out";
    if (kind == sdl.SDL_EVENT_WINDOW_MOUSE_ENTER) return "enter";
    if (kind == sdl.SDL_EVENT_WINDOW_MOUSE_LEAVE) return "leave";
    return "evt";
}
