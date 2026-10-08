const std = @import("std");

var threaded: std.Io.Threaded = blk: {
    var t = std.Io.Threaded.init_single_threaded;
    t.allocator = std.heap.page_allocator;
    break :blk t;
};

pub fn io() std.Io {
    return threaded.io();
}
