//! Vectorized PCG32 (XSH-RR 64/32), a Zig port of
//! https://github.com/lemire/simdpcg/blob/master/include/simdpcg32.h
//!
//! `lanes` independent 64-bit LCG states advance in lockstep. They are the
//! same stream leapfrogged: lane `i` starts `i` steps ahead of lane 0 and every
//! lane jumps `lanes` steps per call, using `mult^lanes` and the matching
//! summed increment. Concatenating the output vectors therefore yields exactly
//! the scalar PCG32 sequence for the same seed and stream.
//!
//! Unlike `std.Random.float(f32)`, which pulls one u64 per float and branches
//! on its leading zeros, floats here are produced `lanes` at a time with a
//! branch-free conversion: the top 24 bits of each u32 output are scaled by
//! 2^-24, giving values uniformly spaced on [0, 1).

const std = @import("std");

/// Same multiplier as `std.Random.Pcg` and the reference implementation.
pub const multiplier: u64 = 6364136223846793005;

/// Default width: 8 x u64 state fills one AVX-512 register / two AVX2 registers,
/// and LLVM splits it cleanly on narrower targets (NEON, SSE).
pub const default_lanes = 8;

pub fn SimdPcg32(comptime lanes: comptime_int) type {
    if (lanes < 1) @compileError("lanes must be >= 1");

    return struct {
        const Self = @This();

        pub const len = lanes;
        pub const U64s = @Vector(lanes, u64);
        pub const U32s = @Vector(lanes, u32);
        pub const F32s = @Vector(lanes, f32);

        state: U64s,
        /// Increment for a `lanes`-step jump. Always odd.
        inc: U64s,
        /// `multiplier^lanes`.
        mult: U64s,

        /// `seed` picks the starting point, `stream` picks one of 2^63 sequences.
        /// Seeding matches the reference `pcg32_srandom_r`.
        pub fn init(seed: u64, stream: u64) Self {
            const inc: u64 = (stream << 1) | 1;
            var state: u64 = 0;
            state = state *% multiplier +% inc;
            state +%= seed;
            state = state *% multiplier +% inc;
            return initRaw(state, inc);
        }

        /// Mirrors `avx512_pcg32_initialize`: `state` is used as-is for lane 0,
        /// `inc` must be odd.
        pub fn initRaw(state: u64, inc: u64) Self {
            std.debug.assert(inc & 1 == 1);
            var states: [lanes]u64 = undefined;
            var s = state;
            var inc_sum: u64 = 0;
            var mult_prod: u64 = 1;
            for (&states) |*lane| {
                lane.* = s;
                s = s *% multiplier +% inc;
                inc_sum = inc_sum *% multiplier +% inc;
                mult_prod *%= multiplier;
            }
            return .{
                .state = states,
                .inc = @splat(inc_sum),
                .mult = @splat(mult_prod),
            };
        }

        /// Next `lanes` u32 outputs.
        pub inline fn next(self: *Self) U32s {
            const old = self.state;
            self.state = old *% self.mult +% self.inc;

            const xorshifted: U32s = @truncate(((old >> @splat(18)) ^ old) >> @splat(27));
            const rot: @Vector(lanes, u5) = @intCast(old >> @splat(59));
            // Per-lane rotate right; std.math.rotr only takes a scalar amount.
            return (xorshifted >> rot) | (xorshifted << (@as(@Vector(lanes, u5), @splat(0)) -% rot));
        }

        /// Next `lanes` floats uniformly distributed on [0, 1).
        pub inline fn nextF32(self: *Self) F32s {
            return toF32(self.next());
        }

        /// Fill `out` with floats uniformly distributed on [0, 1).
        /// The tail (out.len % lanes) consumes one extra full step.
        pub fn fillF32(self: *Self, out: []f32) void {
            var i: usize = 0;
            while (i + lanes <= out.len) : (i += lanes) {
                out[i..][0..lanes].* = self.nextF32();
            }
            if (i < out.len) {
                const tail: [lanes]f32 = self.nextF32();
                @memcpy(out[i..], tail[0 .. out.len - i]);
            }
        }

        /// Fill `out` with raw u32 outputs.
        pub fn fillU32(self: *Self, out: []u32) void {
            var i: usize = 0;
            while (i + lanes <= out.len) : (i += lanes) {
                out[i..][0..lanes].* = self.next();
            }
            if (i < out.len) {
                const tail: [lanes]u32 = self.next();
                @memcpy(out[i..], tail[0 .. out.len - i]);
            }
        }

        /// Byte filler so the generator also works behind `std.Random`.
        pub fn fill(self: *Self, buf: []u8) void {
            var i: usize = 0;
            const block = lanes * 4;
            while (i + block <= buf.len) : (i += block) {
                const v: [lanes]u32 = self.next();
                inline for (v, 0..) |x, k| std.mem.writeInt(u32, buf[i + k * 4 ..][0..4], x, .little);
            }
            if (i < buf.len) {
                const v: [lanes]u32 = self.next();
                var bytes: [block]u8 = undefined;
                inline for (v, 0..) |x, k| std.mem.writeInt(u32, bytes[k * 4 ..][0..4], x, .little);
                @memcpy(buf[i..], bytes[0 .. buf.len - i]);
            }
        }

        pub fn random(self: *Self) std.Random {
            return std.Random.init(self, fill);
        }

        /// Top 24 bits -> [0, 1). 24 bits is the most an f32 can represent
        /// exactly at uniform spacing, so every result is exact and < 1.0.
        pub inline fn toF32(x: U32s) F32s {
            const top: F32s = @floatFromInt(x >> @splat(8));
            return top * @as(F32s, @splat(0x1.0p-24));
        }
    };
}

pub const Default = SimdPcg32(default_lanes);

// ---------------------------------------------------------------------------

/// Plain scalar PCG32 used as the reference in tests.
const ScalarPcg32 = struct {
    state: u64,
    inc: u64,

    fn init(seed: u64, stream: u64) ScalarPcg32 {
        var r: ScalarPcg32 = .{ .state = 0, .inc = (stream << 1) | 1 };
        _ = r.next();
        r.state +%= seed;
        _ = r.next();
        return r;
    }

    fn next(r: *ScalarPcg32) u32 {
        const old = r.state;
        r.state = old *% multiplier +% r.inc;
        const xorshifted: u32 = @truncate(((old >> 18) ^ old) >> 27);
        const rot: u5 = @intCast(old >> 59);
        return std.math.rotr(u32, xorshifted, rot);
    }
};

test "pcg32 reference vector (pcg32-demo, seed 42, stream 54)" {
    var r = ScalarPcg32.init(42, 54);
    const expected = [_]u32{ 0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e };
    for (expected) |e| try std.testing.expectEqual(e, r.next());
}

fn expectMatchesScalar(comptime lanes: comptime_int) !void {
    var simd = SimdPcg32(lanes).init(42, 54);
    var scalar = ScalarPcg32.init(42, 54);
    for (0..64) |_| {
        const v: [lanes]u32 = simd.next();
        for (v) |x| try std.testing.expectEqual(scalar.next(), x);
    }
}

test "simd output equals scalar pcg32 sequence" {
    try expectMatchesScalar(1);
    try expectMatchesScalar(2);
    try expectMatchesScalar(4);
    try expectMatchesScalar(8);
    try expectMatchesScalar(16);
}

test "fillF32 range, tail handling and mean" {
    var rng = Default.init(0xdeadbeef, 7);
    var buf: [10_003]f32 = undefined;
    rng.fillF32(&buf);

    var sum: f64 = 0;
    for (buf) |x| {
        try std.testing.expect(x >= 0.0 and x < 1.0);
        sum += x;
    }
    const mean = sum / buf.len;
    try std.testing.expect(@abs(mean - 0.5) < 0.01);
}

test "fillF32 matches toF32 of fillU32" {
    var a = Default.init(1, 2);
    var b = Default.init(1, 2);
    var fs: [37]f32 = undefined;
    var us: [37]u32 = undefined;
    a.fillF32(&fs);
    b.fillU32(&us);
    for (fs, us) |f, u| {
        try std.testing.expectEqual(@as(f32, @floatFromInt(u >> 8)) * 0x1.0p-24, f);
    }
}

test "toF32 bounds" {
    const F = Default;
    const r: [F.len]f32 = F.toF32(@splat(0xffff_ffff));
    try std.testing.expect(r[0] < 1.0);
    const z: [F.len]f32 = F.toF32(@splat(0));
    try std.testing.expectEqual(@as(f32, 0), z[0]);
}

test "std.Random interface" {
    var rng = Default.init(3, 4);
    const r = rng.random();
    const x = r.float(f32);
    try std.testing.expect(x >= 0 and x < 1);
}
