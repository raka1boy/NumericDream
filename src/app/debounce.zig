const std = @import("std");

pub const Decision = enum {
    idle,
    rebuild,
};

pub const Update = struct {
    decision: Decision,
    moving: bool,
    scene_changed: bool,
};

pub const DebouncedDirty = struct {
    dirty: bool = true,
    dirty_since_ms: u64 = 0,

    last_camera_pos: [3]f32 = .{ 0, 0, 0 },
    has_camera_pos: bool = false,

    scene_hash: u64 = 0,
    has_scene_hash: bool = false,

    pub fn reset(self: *DebouncedDirty) void {
        self.has_camera_pos = false;
    }

    pub fn update(
        self: *DebouncedDirty,
        extra_wants_rebuild: bool,
        now_ms: u64,
        hash: u64,
        camera_pos: [3]f32,
        debounce_ms: f32,
    ) Update {
        const moving = self.has_camera_pos and !std.meta.eql(camera_pos, self.last_camera_pos);
        self.last_camera_pos = camera_pos;
        self.has_camera_pos = true;

        const scene_changed = !self.has_scene_hash or hash != self.scene_hash;
        self.scene_hash = hash;
        self.has_scene_hash = true;

        const wants_rebuild = scene_changed or extra_wants_rebuild;
        if (wants_rebuild and !self.dirty) {
            self.dirty = true;
            self.dirty_since_ms = now_ms;
        }
        if (!self.dirty) return .{ .decision = .idle, .moving = moving, .scene_changed = scene_changed };

        if (moving or scene_changed) self.dirty_since_ms = now_ms;

        if (now_ms -| self.dirty_since_ms < @as(u64, @intFromFloat(@max(debounce_ms, 0))))
            return .{ .decision = .idle, .moving = moving, .scene_changed = scene_changed };
        return .{ .decision = .rebuild, .moving = moving, .scene_changed = scene_changed };
    }

    pub fn noteBuilt(self: *DebouncedDirty) void {
        self.dirty = false;
    }

    pub fn noteFailed(self: *DebouncedDirty, now_ms: u64) void {
        self.dirty = true;
        self.dirty_since_ms = now_ms;
    }
};
