const std = @import("std");
const sdl = @import("../bindings/sdl3.zig").c;
const wgpu = @import("../bindings/webgpu.zig").c;
const webgpu_context = @import("webgpu_context.zig");
const Context = webgpu_context.Context;
const FractalRenderer = @import("fractal_renderer.zig").FractalRenderer;

const capacity = 8;

const Entry = struct {
    module: wgpu.WGPUShaderModule,
    parts_off: u32,
    pipeline: wgpu.WGPURenderPipeline,
    last_used: u64,
};

const Job = struct {
    module: wgpu.WGPUShaderModule,
    parts_off: u32,
    thread: std.Thread = undefined,
    pipeline: wgpu.WGPURenderPipeline = null,
    elapsed_ms: u64 = 0,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn worker(job: *Job, ctx: *const Context, layout: wgpu.WGPUPipelineLayout) void {
    defer job.done.store(true, .release);
    const started = sdl.SDL_GetTicks();
    const errors_before = webgpu_context.g_error_count.load(.acquire);
    const pipeline = FractalRenderer.createPartsPipeline(ctx, layout, job.module, job.parts_off);
    const failed = pipeline == null or webgpu_context.g_error_count.load(.acquire) != errors_before;
    if (failed and pipeline != null) wgpu.wgpuRenderPipelineRelease(pipeline);
    job.pipeline = if (failed) null else pipeline;
    job.elapsed_ms = sdl.SDL_GetTicks() -| started;
}

pub const PartsPipelines = struct {
    entries: [capacity]?Entry = @splat(null),
    clock: u64 = 0,
    job: ?*Job = null,

    pub fn lookup(self: *PartsPipelines, ctx: *const Context, layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, parts_off: u32) wgpu.WGPURenderPipeline {
        self.collect(false);
        if (module == null or parts_off == 0) return null;
        for (&self.entries) |*slot| {
            if (slot.*) |*entry| {
                if (entry.module == module and entry.parts_off == parts_off) {
                    self.clock += 1;
                    entry.last_used = self.clock;
                    return entry.pipeline;
                }
            }
        }
        if (self.job == null) self.start(ctx, layout, module, parts_off);
        return null;
    }

    pub fn compiling(self: *const PartsPipelines) bool {
        return self.job != null;
    }

    pub fn waitIdle(self: *PartsPipelines) void {
        self.collect(true);
    }

    pub fn deinit(self: *PartsPipelines) void {
        self.collect(true);
        for (&self.entries) |*slot| {
            if (slot.*) |entry| release(entry);
            slot.* = null;
        }
    }

    fn start(self: *PartsPipelines, ctx: *const Context, layout: wgpu.WGPUPipelineLayout, module: wgpu.WGPUShaderModule, parts_off: u32) void {
        const job = std.heap.page_allocator.create(Job) catch return;
        job.* = .{ .module = module, .parts_off = parts_off };
        wgpu.wgpuShaderModuleAddRef(module);
        job.thread = std.Thread.spawn(.{}, worker, .{ job, ctx, layout }) catch {
            wgpu.wgpuShaderModuleRelease(module);
            std.heap.page_allocator.destroy(job);
            return;
        };
        self.job = job;
    }

    fn collect(self: *PartsPipelines, wait: bool) void {
        const job = self.job orelse return;
        if (!wait and !job.done.load(.acquire)) return;
        job.thread.join();
        self.job = null;
        std.debug.print("[parts] specialised pipeline for mask {x}: {s} in {d}ms\n", .{
            job.parts_off,
            if (job.pipeline != null) "ready" else "failed, staying on the full shader",
            job.elapsed_ms,
        });
        self.insert(.{ .module = job.module, .parts_off = job.parts_off, .pipeline = job.pipeline, .last_used = 0 });
        std.heap.page_allocator.destroy(job);
    }

    fn insert(self: *PartsPipelines, entry: Entry) void {
        self.clock += 1;
        var victim: usize = 0;
        var victim_used: u64 = std.math.maxInt(u64);
        for (self.entries, 0..) |slot, i| {
            const used = if (slot) |e| e.last_used else 0;
            if (used < victim_used) {
                victim_used = used;
                victim = i;
            }
        }
        if (self.entries[victim]) |old| release(old);
        self.entries[victim] = entry;
        self.entries[victim].?.last_used = self.clock;
    }

    fn release(entry: Entry) void {
        if (entry.pipeline != null) wgpu.wgpuRenderPipelineRelease(entry.pipeline);
        wgpu.wgpuShaderModuleRelease(entry.module);
    }
};
