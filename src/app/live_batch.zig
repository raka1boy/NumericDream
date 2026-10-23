const max_samples_per_frame: u32 = 32;
const grow_below_ms: u64 = 28;
const shrink_above_ms: u64 = 45;

pub const LiveBatch = struct {
    samples_per_frame: u32 = 1,

    pub fn update(self: *LiveBatch, eligible: bool, frame_ms: u64) void {
        if (!eligible) {
            self.samples_per_frame = 1;
        } else if (frame_ms < grow_below_ms) {
            self.samples_per_frame = @min(self.samples_per_frame + 1, max_samples_per_frame);
        } else if (frame_ms > shrink_above_ms) {
            self.samples_per_frame = @max(self.samples_per_frame / 2, 1);
        }
    }

    pub fn extra(self: *const LiveBatch) u32 {
        return self.samples_per_frame - 1;
    }
};
