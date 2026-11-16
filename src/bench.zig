//! RNG benchmarks. Run with `zig build bench` (always ReleaseFast).
//!
//! Two groups:
//!   * Vec3: producing one random Vec3 at a time, as `vec3.random` does inside
//!     rejection-sampling loops.
//!   * Arrays: filling a slice up front, from a cache-resident size up to every
//!     sample offset of a whole frame (x and y per sample).
//!
//! Each case runs repeatedly for at least `min_trial_ns`; the best of `trials`
//! is reported as ns per generated float.

const std = @import("std");
const Io = std.Io;
const SimdPcg32 = @import("SimdPcg32.zig").SimdPcg32;
const SimdXoshiro256 = @import("SimdXoshiro256.zig").SimdXoshiro256;
const vec = @import("vec3.zig");
const Vec3 = vec.Vec3;

const trials = 5;
const min_trial_ns = 100 * std.time.ns_per_ms;

// Matches main.zig: 400x225 image, 100 samples per pixel, x and y per sample.
const frame_values = 400 * 225 * 100 * 2;
const array_sizes = [_]struct { name: []const u8, n: usize }{
    .{ .name = "1K (L1)", .n = 1024 },
    .{ .name = "64K (L2/L3)", .n = 1 << 16 },
    .{ .name = "frame 18M", .n = frame_values },
};

const vec3_batch = 4096; // Vec3s produced per timed call

// ---------------------------------------------------------------------------
// Harness

fn bestNsPerValue(io: Io, ctx: anytype, values_per_call: usize) f64 {
    var best = std.math.inf(f64);
    ctx.run(); // warm-up: page in buffers, settle caches
    for (0..trials) |_| {
        var calls: usize = 0;
        const start = Io.Timestamp.now(io, .awake);
        var elapsed: i96 = 0;
        while (elapsed < min_trial_ns) {
            ctx.run();
            calls += 1;
            elapsed = start.untilNow(io, .awake).nanoseconds;
        }
        const per: f64 = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(calls * values_per_call));
        best = @min(best, per);
    }
    return best;
}

fn report(name: []const u8, ns: f64, baseline: f64) void {
    std.debug.print("  {s:<40} {d:>8.3} ns/value  {d:>6.2}x\n", .{ name, ns, baseline / ns });
}

// ---------------------------------------------------------------------------
// Vec3 cases. All accumulate into `sink` so nothing is optimized away.

/// Current vec3.zig path behind a std.Random interface.
const StdVec3 = struct {
    rand: std.Random,
    sink: Vec3 = @splat(0),

    fn run(self: *@This()) void {
        var acc: Vec3 = @splat(0);
        for (0..vec3_batch) |_| acc += vec.random(self.rand);
        self.sink += acc;
        std.mem.doNotOptimizeAway(self.sink);
    }
};

/// One SIMD step per Vec3: 4 lanes (one AVX2 register of f64), 3 used.
const SimdDirectVec3 = struct {
    rng: SimdXoshiro256(4),
    sink: Vec3 = @splat(0),

    fn run(self: *@This()) void {
        var acc: Vec3 = @splat(0);
        for (0..vec3_batch) |_| {
            const v = self.rng.nextF64();
            acc += @shuffle(f64, v, undefined, @Vector(3, i32){ 0, 1, 2 });
        }
        self.sink += acc;
        std.mem.doNotOptimizeAway(self.sink);
    }
};

/// Buffered pool: refill `pool_len` floats with fillF64, hand out 3 at a time.
/// No lanes wasted; refill is a tight SIMD loop.
fn PoolVec3(comptime lanes: comptime_int, comptime pool_len: usize) type {
    comptime std.debug.assert(pool_len % 3 == 0);
    return struct {
        rng: SimdXoshiro256(lanes),
        buf: [pool_len]f64 = undefined,
        pos: usize = pool_len,
        sink: Vec3 = @splat(0),

        inline fn nextVec3(self: *@This()) Vec3 {
            if (self.pos == pool_len) {
                @branchHint(.unlikely);
                self.rng.fillF64(&self.buf);
                self.pos = 0;
            }
            const v: Vec3 = self.buf[self.pos..][0..3].*;
            self.pos += 3;
            return v;
        }

        fn run(self: *@This()) void {
            var acc: Vec3 = @splat(0);
            for (0..vec3_batch) |_| acc += self.nextVec3();
            self.sink += acc;
            std.mem.doNotOptimizeAway(self.sink);
        }
    };
}

// ---------------------------------------------------------------------------
// Array cases

const StdFillF64 = struct {
    rand: std.Random,
    buf: []f64,
    fn run(self: *@This()) void {
        for (self.buf) |*x| x.* = self.rand.float(f64);
        std.mem.doNotOptimizeAway(self.buf.ptr);
    }
};

const StdFillF32 = struct {
    rand: std.Random,
    buf: []f32,
    fn run(self: *@This()) void {
        for (self.buf) |*x| x.* = self.rand.float(f32);
        std.mem.doNotOptimizeAway(self.buf.ptr);
    }
};

fn XoshiroFill(comptime lanes: comptime_int) type {
    return struct {
        rng: SimdXoshiro256(lanes),
        buf: []f64,
        fn run(self: *@This()) void {
            self.rng.fillF64(self.buf);
            std.mem.doNotOptimizeAway(self.buf.ptr);
        }
    };
}

fn PcgFill(comptime lanes: comptime_int) type {
    return struct {
        rng: SimdPcg32(lanes),
        buf: []f32,
        fn run(self: *@This()) void {
            self.rng.fillF32(self.buf);
            std.mem.doNotOptimizeAway(self.buf.ptr);
        }
    };
}

// ---------------------------------------------------------------------------

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const seed = 0x5eed;

    std.debug.print("RNG benchmark ({s}, {s})\n", .{ @tagName(@import("builtin").mode), @import("builtin").cpu.model.name });

    // ---- Vec3 ----
    std.debug.print("\nVec3 (one random Vec3 per call, f64), speedup vs std Xoshiro256:\n", .{});
    {
        var xs = std.Random.Xoshiro256.init(seed);
        var std_case: StdVec3 = .{ .rand = xs.random() };
        const base = bestNsPerValue(io, &std_case, vec3_batch * 3);

        const io_src: std.Random.IoSource = .{ .io = io };
        var io_case: StdVec3 = .{ .rand = io_src.interface() };
        report("std.Random.IoSource (current main.zig)", bestNsPerValue(io, &io_case, vec3_batch * 3), base);
        report("std.Random.Xoshiro256 (vec.random)", base, base);

        var direct: SimdDirectVec3 = .{ .rng = .init(seed) };
        report("SimdXoshiro256(4) nextF64 per Vec3", bestNsPerValue(io, &direct, vec3_batch * 3), base);

        inline for (.{ .{ 4, 96 }, .{ 8, 96 }, .{ 8, 384 }, .{ 16, 768 } }) |cfg| {
            var pool: PoolVec3(cfg[0], cfg[1]) = .{ .rng = .init(seed) };
            const name = std.fmt.comptimePrint("SimdXoshiro256({d}) pool of {d}", .{ cfg[0], cfg[1] });
            report(name, bestNsPerValue(io, &pool, vec3_batch * 3), base);
        }
    }

    // ---- Arrays ----
    const max_n = array_sizes[array_sizes.len - 1].n;
    const buf64 = try gpa.alloc(f64, max_n);
    defer gpa.free(buf64);
    const buf32 = try gpa.alloc(f32, max_n);
    defer gpa.free(buf32);

    for (array_sizes) |size| {
        const b64 = buf64[0..size.n];
        const b32 = buf32[0..size.n];

        std.debug.print("\nArray {s} ({d} values), f64 speedup vs std Xoshiro256 float(f64):\n", .{ size.name, size.n });
        var xs = std.Random.Xoshiro256.init(seed);
        var std64: StdFillF64 = .{ .rand = xs.random(), .buf = b64 };
        const base64 = bestNsPerValue(io, &std64, size.n);
        report("std.Random.Xoshiro256 float(f64)", base64, base64);
        inline for (.{ 2, 4, 8, 16 }) |lanes| {
            var c: XoshiroFill(lanes) = .{ .rng = .init(seed), .buf = b64 };
            report(std.fmt.comptimePrint("SimdXoshiro256({d}) fillF64", .{lanes}), bestNsPerValue(io, &c, size.n), base64);
        }

        std.debug.print("  -- f32, speedup vs std Pcg float(f32):\n", .{});
        var pcg = std.Random.Pcg.init(seed);
        var std32: StdFillF32 = .{ .rand = pcg.random(), .buf = b32 };
        const base32 = bestNsPerValue(io, &std32, size.n);
        report("std.Random.Pcg float(f32)", base32, base32);
        inline for (.{ 4, 8, 16 }) |lanes| {
            var c: PcgFill(lanes) = .{ .rng = .init(seed, 1), .buf = b32 };
            report(std.fmt.comptimePrint("SimdPcg32({d}) fillF32", .{lanes}), bestNsPerValue(io, &c, size.n), base32);
        }
    }
}
