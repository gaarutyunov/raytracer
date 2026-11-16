//! Vectorized xoshiro256++ for fast f64 generation.
//!
//! Same algorithm as `std.Random.Xoshiro256`, run `lanes` generators in
//! lockstep with the state stored column-wise (s0..s3 are each a vector). Lane
//! `i` is `std.Random.Xoshiro256.init(seed)` advanced by `i` calls to `jump()`
//! (2^128 steps each), so lanes never overlap and lane `i` reproduces that
//! scalar sequence exactly.
//!
//! Why not PCG for f64: PCG32 yields 32 bits per 64-bit multiply, so an f64
//! costs two LCG steps, and AVX2 has no 64-bit vector multiply (it is emulated
//! with three 32x32 multiplies). xoshiro256++ produces 64 bits per step using
//! only add/xor/shift/rotate.
//!
//! f64 conversion: top 52 bits go into the mantissa of a double in [1, 2),
//! then 1.0 is subtracted. That avoids u64->f64 conversion, which AVX2 lacks
//! (it needs AVX-512DQ), and yields values uniformly spaced on [0, 1).

const std = @import("std");
const Scalar = std.Random.Xoshiro256;

pub const default_lanes = 8;

pub fn SimdXoshiro256(comptime lanes: comptime_int) type {
    if (lanes < 1) @compileError("lanes must be >= 1");

    return struct {
        const Self = @This();

        pub const len = lanes;
        pub const U64s = @Vector(lanes, u64);
        pub const F64s = @Vector(lanes, f64);

        s0: U64s,
        s1: U64s,
        s2: U64s,
        s3: U64s,

        /// Lane `i` = `std.Random.Xoshiro256.init(seed)` jumped `i` times.
        /// For multiple threads, give each its own seed.
        pub fn init(seed: u64) Self {
            var base = Scalar.init(seed);
            var cols: [4][lanes]u64 = undefined;
            for (0..lanes) |i| {
                inline for (0..4) |w| cols[w][i] = base.s[w];
                base.jump();
            }
            return .{ .s0 = cols[0], .s1 = cols[1], .s2 = cols[2], .s3 = cols[3] };
        }

        inline fn rotl(x: U64s, comptime k: u6) U64s {
            return (x << @splat(k)) | (x >> @splat(64 - @as(u7, k)));
        }

        /// Next `lanes` u64 outputs.
        pub inline fn next(self: *Self) U64s {
            const r = rotl(self.s0 +% self.s3, 23) +% self.s0;
            const t = self.s1 << @splat(17);

            self.s2 ^= self.s0;
            self.s3 ^= self.s1;
            self.s1 ^= self.s2;
            self.s0 ^= self.s3;
            self.s2 ^= t;
            self.s3 = rotl(self.s3, 45);

            return r;
        }

        /// Next `lanes` doubles uniformly distributed on [0, 1).
        pub inline fn nextF64(self: *Self) F64s {
            return toF64(self.next());
        }

        /// Fill `out` with doubles uniformly distributed on [0, 1).
        /// Element `k` comes from lane `k % lanes`. The tail consumes one full step.
        pub fn fillF64(self: *Self, out: []f64) void {
            var i: usize = 0;
            while (i + lanes <= out.len) : (i += lanes) {
                out[i..][0..lanes].* = self.nextF64();
            }
            if (i < out.len) {
                const tail: [lanes]f64 = self.nextF64();
                @memcpy(out[i..], tail[0 .. out.len - i]);
            }
        }

        /// 52 random bits -> [0, 1) without int->float conversion.
        pub inline fn toF64(x: U64s) F64s {
            const one_bits: U64s = @splat(0x3FF0_0000_0000_0000);
            const in_1_2: F64s = @bitCast((x >> @splat(12)) | one_bits);
            return in_1_2 - @as(F64s, @splat(1.0));
        }
    };
}

pub const Default = SimdXoshiro256(default_lanes);

// ---------------------------------------------------------------------------

fn expectMatchesStd(comptime lanes: comptime_int, seed: u64) !void {
    var simd = SimdXoshiro256(lanes).init(seed);

    var refs: [lanes]Scalar = undefined;
    var base = Scalar.init(seed);
    for (&refs) |*r| {
        r.* = base;
        base.jump();
    }

    for (0..64) |_| {
        const v: [lanes]u64 = simd.next();
        for (v, &refs) |x, *r| try std.testing.expectEqual(r.next(), x);
    }
}

test "each lane equals std.Random.Xoshiro256 jumped i times" {
    try expectMatchesStd(1, 0);
    try expectMatchesStd(2, 42);
    try expectMatchesStd(4, 0xdeadbeef);
    try expectMatchesStd(8, 12345);
    try expectMatchesStd(16, 7);
}

test "lane 0 matches std known sequence (seed 0)" {
    var r = SimdXoshiro256(4).init(0);
    const seq = [_]u64{ 0x53175d61490b23df, 0x61da6f3dc380d507, 0x5c0fdf91ec9a7bfc };
    for (seq) |e| {
        const v: [4]u64 = r.next();
        try std.testing.expectEqual(e, v[0]);
    }
}

test "toF64 bounds and exactness" {
    const F = Default;
    const hi: [F.len]f64 = F.toF64(@splat(std.math.maxInt(u64)));
    try std.testing.expectEqual(1.0 - 0x1.0p-52, hi[0]);
    const lo: [F.len]f64 = F.toF64(@splat(0));
    try std.testing.expectEqual(@as(f64, 0), lo[0]);
    const mid: [F.len]f64 = F.toF64(@splat(1 << 63));
    try std.testing.expectEqual(@as(f64, 0.5), mid[0]);
}

test "fillF64 range, tail handling and moments" {
    var rng = Default.init(0xabcdef);
    var buf: [100_003]f64 = undefined;
    rng.fillF64(&buf);

    var sum: f64 = 0;
    var sum_sq: f64 = 0;
    for (buf) |x| {
        try std.testing.expect(x >= 0.0 and x < 1.0);
        sum += x;
        sum_sq += x * x;
    }
    const n: f64 = @floatFromInt(buf.len);
    const mean = sum / n;
    const variance = sum_sq / n - mean * mean;
    try std.testing.expect(@abs(mean - 0.5) < 0.005);
    try std.testing.expect(@abs(variance - 1.0 / 12.0) < 0.002);
}

test "fillF64 matches nextF64 order" {
    var a = Default.init(9);
    var b = Default.init(9);
    var buf: [3 * Default.len + 5]f64 = undefined;
    a.fillF64(&buf);
    var k: usize = 0;
    while (k < buf.len) : (k += Default.len) {
        const v: [Default.len]f64 = b.nextF64();
        for (v, 0..) |x, j| {
            if (k + j < buf.len) try std.testing.expectEqual(x, buf[k + j]);
        }
    }
}
