const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("../gpu/webgpu_context.zig");

const max_tracked_events = 24;
const wake_trace_frames = 10;
const max_marks = 12;

var g_enabled: bool = false;

pub const BenchMode = enum { both, mega, wave };

pub const BenchConfig = struct {
    scene: []const u8,
    width: u32 = 960,
    height: u32 = 540,
    samples: u32 = 64,
    out_dir: []const u8 = "bench/out",
    mode: BenchMode = .both,
    repeats: u32 = 2,
    profile: bool = false,
};

pub const LiveBenchConfig = struct {
    scene: []const u8,
    seconds: f32 = 10,
    warmup_samples: u32 = 16,
};

var g_bench: ?BenchConfig = null;
var g_live_bench: ?LiveBenchConfig = null;

pub fn enabled() bool {
    return g_enabled;
}

pub fn bench() ?BenchConfig {
    return g_bench;
}

pub fn liveBench() ?LiveBenchConfig {
    return g_live_bench;
}

fn optionValue(it: anytype, name: []const u8) ?[]const u8 {
    const v = it.next() orelse {
        std.debug.print("option '{s}' needs a value\n", .{name});
        return null;
    };
    return v;
}

pub fn parseArgs(allocator: std.mem.Allocator, args: std.process.Args) bool {
    var it = args.iterateAllocator(allocator) catch return true;
    defer it.deinit();
    _ = it.next();
    var ok = true;
    var cfg = BenchConfig{ .scene = "" };
    var want_bench = false;
    var live = LiveBenchConfig{ .scene = "" };
    var want_live = false;
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-perf") or std.mem.eql(u8, arg, "--perf")) {
            g_enabled = true;
        } else if (std.mem.eql(u8, arg, "-bench-live")) {
            const v = optionValue(&it, arg) orelse return false;
            live.scene = allocator.dupe(u8, v) catch return false;
            want_live = true;
        } else if (std.mem.eql(u8, arg, "-bench-seconds")) {
            const v = optionValue(&it, arg) orelse return false;
            live.seconds = @max(std.fmt.parseFloat(f32, v) catch return false, 1);
        } else if (std.mem.eql(u8, arg, "-bench")) {
            const v = optionValue(&it, arg) orelse return false;
            cfg.scene = allocator.dupe(u8, v) catch return false;
            want_bench = true;
        } else if (std.mem.eql(u8, arg, "-bench-size")) {
            const v = optionValue(&it, arg) orelse return false;
            const x = std.mem.indexOfScalar(u8, v, 'x') orelse {
                std.debug.print("-bench-size wants WxH, got '{s}'\n", .{v});
                return false;
            };
            cfg.width = std.fmt.parseInt(u32, v[0..x], 10) catch return false;
            cfg.height = std.fmt.parseInt(u32, v[x + 1 ..], 10) catch return false;
        } else if (std.mem.eql(u8, arg, "-bench-samples")) {
            const v = optionValue(&it, arg) orelse return false;
            cfg.samples = std.fmt.parseInt(u32, v, 10) catch return false;
        } else if (std.mem.eql(u8, arg, "-bench-repeats")) {
            const v = optionValue(&it, arg) orelse return false;
            cfg.repeats = @max(std.fmt.parseInt(u32, v, 10) catch return false, 1);
        } else if (std.mem.eql(u8, arg, "-bench-out")) {
            const v = optionValue(&it, arg) orelse return false;
            cfg.out_dir = allocator.dupe(u8, v) catch return false;
        } else if (std.mem.eql(u8, arg, "-bench-profile")) {
            cfg.profile = true;
        } else if (std.mem.eql(u8, arg, "-bench-mode")) {
            const v = optionValue(&it, arg) orelse return false;
            cfg.mode = std.meta.stringToEnum(BenchMode, v) orelse {
                std.debug.print("-bench-mode wants both|mega|wave, got '{s}'\n", .{v});
                return false;
            };
        } else {
            std.debug.print("unknown option '{s}' (supported: -perf, -bench <scene.dream> [-bench-size WxH] [-bench-samples N] [-bench-repeats N] [-bench-mode both|mega|wave] [-bench-profile] [-bench-out dir], -bench-live <scene.dream> [-bench-seconds N])\n", .{arg});
            ok = false;
        }
    }
    if (want_bench) g_bench = cfg;
    if (want_live) g_live_bench = live;
    return ok;
}

const EventCount = struct { kind: u32, count: u32 };
const Mark = struct { label: []const u8, ns: u64 };

fn msSince(from_ns: u64, to_ns: u64) f64 {
    return @as(f64, @floatFromInt(to_ns -| from_ns)) / std.time.ns_per_ms;
}

fn onWorkDone(_: wgpu.WGPUQueueWorkDoneStatus, _: wgpu.WGPUStringView, userdata1: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const done: *bool = @ptrCast(@alignCast(userdata1.?));
    done.* = true;
}

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

    wait_start_ns: u64 = 0,
    wake_ns: u64 = 0,
    wake_frames_left: u32 = 0,
    wake_frame_index: u32 = 0,
    marks: [max_marks]Mark = undefined,
    mark_count: usize = 0,

    pub fn init() Probe {
        const on = enabled();
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

    pub fn waitBegin(self: *Probe) void {
        self.wait_start_ns = sdl.SDL_GetTicksNS();
    }

    pub fn countIteration(self: *Probe, blocked: bool) void {
        self.iterations +%= 1;
        if (!blocked) return;
        self.blocking_waits +%= 1;
        if (!self.enabled) return;
        const now = sdl.SDL_GetTicksNS();
        if (msSince(self.wait_start_ns, now) < 50) return;
        self.wake_ns = now;
        self.wake_frames_left = wake_trace_frames;
        self.wake_frame_index = 0;
        std.debug.print("[wake] after {d:.0}ms idle\n", .{msSince(self.wait_start_ns, now)});
    }

    pub fn tracing(self: *const Probe) bool {
        return self.enabled and self.wake_frames_left > 0;
    }

    pub fn mark(self: *Probe, label: []const u8) void {
        if (!self.tracing() or self.mark_count >= max_marks) return;
        self.marks[self.mark_count] = .{ .label = label, .ns = sdl.SDL_GetTicksNS() };
        self.mark_count += 1;
    }

    pub fn endTracedFrame(self: *Probe, instance: wgpu.WGPUInstance, queue: wgpu.WGPUQueue, notes: []const u8) void {
        if (!self.tracing()) return;
        const submitted_ns = sdl.SDL_GetTicksNS();
        var done = false;
        _ = wgpu.wgpuQueueOnSubmittedWorkDone(queue, .{
            .nextInChain = null,
            .mode = wgpu.WGPUCallbackMode_AllowProcessEvents,
            .callback = onWorkDone,
            .userdata1 = &done,
            .userdata2 = null,
        });
        _ = webgpu_context.pollUntil(instance, &done, 10_000);
        const gpu_done_ns = sdl.SDL_GetTicksNS();

        std.debug.print("[wake] frame {d}:", .{self.wake_frame_index});
        var prev = self.wake_ns;
        for (self.marks[0..self.mark_count]) |m| {
            std.debug.print(" {s}=+{d:.1}", .{ m.label, msSince(prev, m.ns) });
            prev = m.ns;
        }
        std.debug.print(" gpu_wait=+{d:.1} | at {d:.1}ms {s}\n", .{ msSince(submitted_ns, gpu_done_ns), msSince(self.wake_ns, gpu_done_ns), notes });

        self.mark_count = 0;
        self.wake_frame_index += 1;
        self.wake_frames_left -= 1;
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
