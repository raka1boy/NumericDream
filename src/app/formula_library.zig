const std = @import("std");
const FormulaState = @import("formula.zig").FormulaState;

pub const max_entries = 128;
pub const max_labels_per_entry = 6;
pub const max_name_len = 32;
pub const max_label_len = 24;
pub const max_path_len = 512;
pub const max_distinct_labels = 32;

pub const FormulaEntry = struct {
    path: [max_path_len:0]u8,
    path_len: usize,
    name: [max_name_len]u8,
    name_len: usize,
    labels: [max_labels_per_entry][max_label_len]u8,
    label_lens: [max_labels_per_entry]usize,
    label_count: usize,

    pub fn nameSlice(self: *const FormulaEntry) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn pathSlice(self: *const FormulaEntry) [:0]const u8 {
        return self.path[0..self.path_len :0];
    }

    pub fn labelSlice(self: *const FormulaEntry, i: usize) []const u8 {
        return self.labels[i][0..self.label_lens[i]];
    }

    pub fn hasLabel(self: *const FormulaEntry, label: []const u8) bool {
        for (0..self.label_count) |i| {
            if (std.mem.eql(u8, self.labelSlice(i), label)) return true;
        }
        return false;
    }
};

pub const Library = struct {
    entries: [max_entries]FormulaEntry,
    entry_count: usize,
    dir_missing: bool,

    pub fn empty() Library {
        return .{ .entries = undefined, .entry_count = 0, .dir_missing = false };
    }
};

fn parseFileName(file_name: []const u8, out: *FormulaEntry) bool {
    const ext = ".wgsl";
    if (!std.mem.endsWith(u8, file_name, ext)) return false;
    const stem = file_name[0 .. file_name.len - ext.len];
    if (stem.len == 0) return false;

    var tokens = std.mem.tokenizeScalar(u8, stem, '_');
    const name = tokens.next() orelse return false;
    const n = @min(name.len, out.name.len);
    @memcpy(out.name[0..n], name[0..n]);
    out.name_len = n;

    out.label_count = 0;
    while (tokens.next()) |label| {
        if (out.label_count >= max_labels_per_entry) break;
        const ln = @min(label.len, out.labels[out.label_count].len);
        @memcpy(out.labels[out.label_count][0..ln], label[0..ln]);
        out.label_lens[out.label_count] = ln;
        out.label_count += 1;
    }
    return true;
}

pub fn scan() Library {
    var lib = Library.empty();

    const io = std.Io.Threaded.global_single_threaded.io();
    var exe_dir_buf: [max_path_len]u8 = undefined;
    const exe_dir_len = std.process.executableDirPath(io, &exe_dir_buf) catch {
        lib.dir_missing = true;
        return lib;
    };
    const exe_dir = exe_dir_buf[0..exe_dir_len];

    var dir_path_buf: [max_path_len]u8 = undefined;
    const dir_path = std.fmt.bufPrint(&dir_path_buf, "{s}/formulas", .{exe_dir}) catch {
        lib.dir_missing = true;
        return lib;
    };

    var dir = std.Io.Dir.openDirAbsolute(io, dir_path, .{ .iterate = true }) catch {
        lib.dir_missing = true;
        return lib;
    };
    defer dir.close(io);

    var it = dir.iterate();
    while (lib.entry_count < max_entries) {
        const maybe_entry = it.next(io) catch break;
        const entry = maybe_entry orelse break;
        if (entry.kind != .file) continue;

        const out = &lib.entries[lib.entry_count];
        if (!parseFileName(entry.name, out)) continue;

        const full = std.fmt.bufPrint(out.path[0..max_path_len], "{s}/{s}", .{ dir_path, entry.name }) catch continue;
        out.path_len = full.len;
        out.path[full.len] = 0;

        lib.entry_count += 1;
    }
    return lib;
}

pub const SelectedLabels = struct {
    labels: [max_distinct_labels][max_label_len]u8,
    lens: [max_distinct_labels]usize,
    count: usize,

    pub fn empty() SelectedLabels {
        return .{ .labels = undefined, .lens = undefined, .count = 0 };
    }

    pub fn contains(self: *const SelectedLabels, label: []const u8) bool {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.labels[i][0..self.lens[i]], label)) return true;
        }
        return false;
    }

    pub fn toggle(self: *SelectedLabels, label: []const u8) void {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.labels[i][0..self.lens[i]], label)) {
                self.labels[i] = self.labels[self.count - 1];
                self.lens[i] = self.lens[self.count - 1];
                self.count -= 1;
                return;
            }
        }
        if (self.count >= max_distinct_labels) return;
        const n = @min(label.len, self.labels[self.count].len);
        @memcpy(self.labels[self.count][0..n], label[0..n]);
        self.lens[self.count] = n;
        self.count += 1;
    }

    pub fn clear(self: *SelectedLabels) void {
        self.count = 0;
    }

    pub fn matchesAll(self: *const SelectedLabels, entry: *const FormulaEntry) bool {
        for (0..self.count) |i| {
            if (!entry.hasLabel(self.labels[i][0..self.lens[i]])) return false;
        }
        return true;
    }
};

pub const LabelSet = struct {
    labels: [max_distinct_labels][max_label_len]u8,
    lens: [max_distinct_labels]usize,
    count: usize,

    pub fn slice(self: *const LabelSet, i: usize) []const u8 {
        return self.labels[i][0..self.lens[i]];
    }
};
pub fn distinctLabels(lib: *const Library) LabelSet {
    var set = LabelSet{ .labels = undefined, .lens = undefined, .count = 0 };
    for (0..lib.entry_count) |ei| {
        const entry = &lib.entries[ei];
        for (0..entry.label_count) |li| {
            const label = entry.labelSlice(li);
            var found = false;
            for (0..set.count) |si| {
                if (std.mem.eql(u8, set.slice(si), label)) {
                    found = true;
                    break;
                }
            }
            if (found or set.count >= max_distinct_labels) continue;
            const n = @min(label.len, set.labels[set.count].len);
            @memcpy(set.labels[set.count][0..n], label[0..n]);
            set.lens[set.count] = n;
            set.count += 1;
        }
    }

    var i: usize = 1;
    while (i < set.count) : (i += 1) {
        var j = i;
        while (j > 0 and std.mem.order(u8, set.slice(j - 1), set.slice(j)) == .gt) : (j -= 1) {
            const tmp_label = set.labels[j];
            const tmp_len = set.lens[j];
            set.labels[j] = set.labels[j - 1];
            set.lens[j] = set.lens[j - 1];
            set.labels[j - 1] = tmp_label;
            set.lens[j - 1] = tmp_len;
        }
    }
    return set;
}

pub const PanelState = struct {
    library: Library,
    scanned: bool,
    open: bool,
    selected: SelectedLabels,
    target: ?*FormulaState,

    pub fn init() PanelState {
        return .{
            .library = Library.empty(),
            .scanned = false,
            .open = false,
            .selected = SelectedLabels.empty(),
            .target = null,
        };
    }

    pub fn openFor(self: *PanelState, target: *FormulaState) void {
        if (!self.scanned) {
            self.library = scan();
            self.scanned = true;
        }
        self.target = target;
        self.open = true;
    }

    pub fn rescan(self: *PanelState) void {
        self.library = scan();
        self.scanned = true;
    }
};
