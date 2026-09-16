//! `std.Io` for spawning child processes. `std.Io.Threaded.global_single_threaded` carries a
//! `.failing` allocator, and this Zig's `process.spawn`/`process.run` arena from it (env block,
//! wide cwd, PATH search) -- so every spawn through it dies with OutOfMemory before the exe is
//! even looked up. Plain file IO through the global instance is fine.
const std = @import("std");

var threaded: std.Io.Threaded = blk: {
    var t = std.Io.Threaded.init_single_threaded;
    t.allocator = std.heap.page_allocator;
    break :blk t;
};

pub fn io() std.Io {
    return threaded.io();
}
