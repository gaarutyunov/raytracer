//! Random number interface. Pass `*Rng` around instead of a concrete generator.
//!
//! Same design as `std.Io.Reader`/`Writer`: the interface owns a view of a
//! buffer of raw u64s, so the per-value calls (`next`, `float`, `nextVec`,
//! `floatVec`) are a bounds check plus a load. The vtable is only called to
//! refill the buffer, or for bulk `fill`/`fillF64`, which go straight to the
//! SIMD generator and bypass the buffer.
//!
//! Only f64 is supported for floats. Floats are uniform on [0, 1), 52 bits.
//!
//! Usage:
//!     var src: Rng.Default = .init(.init(seed)); // must not move after use
//!     const r: *Rng = src.rng();
//!     const x = r.float(f64);
//!     const v: Vec3 = r.floatVec(3);
//!     r.fillF64(samples);
//!     const legacy: std.Random = r.random();  // for std.Random-only code

const std = @import("std");
const SimdXoshiro256 = @import("SimdXoshiro256.zig").SimdXoshiro256;

const Rng = @This();

vtable: *const VTable,
/// Raw random bits; `buffer[pos..]` are unread.
buffer: []u64,
pos: usize,

pub const VTable = struct {
    /// Replace `buffer` with fresh values and set `pos = 0`. `buffer.len` must be > 0.
    refill: *const fn (r: *Rng) void,
    /// Fill `out` with raw u64s directly from the generator.
    fill: *const fn (r: *Rng, out: []u64) void,
    /// Fill `out` with f64s on [0, 1) directly from the generator.
    fillF64: *const fn (r: *Rng, out: []f64) void,
};

/// Next raw u64.
pub inline fn next(r: *Rng) u64 {
    if (r.pos >= r.buffer.len) {
        @branchHint(.unlikely);
        r.vtable.refill(r);
    }
    const x = r.buffer[r.pos];
    r.pos += 1;
    return x;
}

/// Next `n` raw u64s as a vector. If fewer than `n` remain buffered, the
/// remainder is discarded and the buffer refilled. `n` must be <= buffer length.
pub inline fn nextVec(r: *Rng, comptime n: usize) @Vector(n, u64) {
    if (r.buffer.len - r.pos < n) {
        @branchHint(.unlikely);
        r.vtable.refill(r);
        std.debug.assert(r.buffer.len >= n);
    }
    const v: @Vector(n, u64) = r.buffer[r.pos..][0..n].*;
    r.pos += n;
    return v;
}

/// Uniform float on [0, 1), like `std.Random.float`. Only f64 is supported.
pub inline fn float(r: *Rng, comptime T: type) T {
    if (T != f64) @compileError("Rng only supports f64");
    return toF64(r.next());
}

/// `n` uniform floats on [0, 1) in one vector. `floatVec(3)` is a `Vec3`.
pub inline fn floatVec(r: *Rng, comptime n: usize) @Vector(n, f64) {
    return toF64Vec(n, r.nextVec(n));
}

/// Fill `out` with raw u64s (bulk, SIMD, bypasses the buffer).
pub fn fill(r: *Rng, out: []u64) void {
    r.vtable.fill(r, out);
}

/// Fill `out` with f64s on [0, 1) (bulk, SIMD, bypasses the buffer).
pub fn fillF64(r: *Rng, out: []f64) void {
    r.vtable.fillF64(r, out);
}

/// Adapter for code that still takes `std.Random`. Slower: goes through bytes.
pub fn random(r: *Rng) std.Random {
    return std.Random.init(r, fillBytes);
}

fn fillBytes(r: *Rng, buf: []u8) void {
    var i: usize = 0;
    while (i + 8 <= buf.len) : (i += 8) {
        std.mem.writeInt(u64, buf[i..][0..8], r.next(), .little);
    }
    if (i < buf.len) {
        var tail: [8]u8 = undefined;
        std.mem.writeInt(u64, &tail, r.next(), .little);
        @memcpy(buf[i..], tail[0 .. buf.len - i]);
    }
}

/// Top 52 bits into the mantissa of a double in [1, 2), minus 1.
pub inline fn toF64(x: u64) f64 {
    return @as(f64, @bitCast((x >> 12) | 0x3FF0_0000_0000_0000)) - 1.0;
}

pub inline fn toF64Vec(comptime n: usize, x: @Vector(n, u64)) @Vector(n, f64) {
    const one_bits: @Vector(n, u64) = @splat(0x3FF0_0000_0000_0000);
    const in_1_2: @Vector(n, f64) = @bitCast((x >> @splat(12)) | one_bits);
    return in_1_2 - @as(@Vector(n, f64), @splat(1.0));
}

// ---------------------------------------------------------------------------
// Implementations

/// Wraps a SIMD generator (`Gen.len`, `Gen.U64s`, `next() U64s`, `fillF64`)
/// with a `buffer_len`-u64 buffer and exposes it as an `Rng`.
///
/// Like `std.Io.File.Writer`, do not copy or move this after calling `rng()`
/// and drawing values: the interface points into `buf`.
pub fn Buffered(comptime Gen: type, comptime buffer_len: usize) type {
    if (buffer_len == 0 or buffer_len % Gen.len != 0)
        @compileError("buffer_len must be a non-zero multiple of Gen.len");

    return struct {
        const Self = @This();

        gen: Gen,
        buf: [buffer_len]u64 align(@alignOf(Gen.U64s)) = undefined,
        interface: Rng = .{ .vtable = &vtable, .buffer = &.{}, .pos = 0 },

        const vtable: VTable = .{ .refill = refill, .fill = fill_, .fillF64 = fillF64_ };

        pub fn init(gen: Gen) Self {
            return .{ .gen = gen };
        }

        pub fn rng(self: *Self) *Rng {
            return &self.interface;
        }

        fn parent(r: *Rng) *Self {
            return @alignCast(@fieldParentPtr("interface", r));
        }

        fn refill(r: *Rng) void {
            const self = parent(r);
            var i: usize = 0;
            while (i < buffer_len) : (i += Gen.len) {
                self.buf[i..][0..Gen.len].* = self.gen.next();
            }
            r.buffer = &self.buf;
            r.pos = 0;
        }

        fn fill_(r: *Rng, out: []u64) void {
            const self = parent(r);
            var i: usize = 0;
            while (i + Gen.len <= out.len) : (i += Gen.len) {
                out[i..][0..Gen.len].* = self.gen.next();
            }
            if (i < out.len) {
                const tail: [Gen.len]u64 = self.gen.next();
                @memcpy(out[i..], tail[0 .. out.len - i]);
            }
        }

        fn fillF64_(r: *Rng, out: []f64) void {
            parent(r).gen.fillF64(out);
        }
    };
}

/// 8-lane xoshiro256++ with a 64-value (512 B) buffer.
pub const Default = Buffered(SimdXoshiro256(8), 64);

// ---------------------------------------------------------------------------

const testing = std.testing;

fn flatGen(seed: u64, out: []u64) void {
    var g = SimdXoshiro256(8).init(seed);
    var i: usize = 0;
    while (i < out.len) : (i += 8) {
        const v: [8]u64 = g.next();
        @memcpy(out[i..][0..8], &v);
    }
}

test "next follows generator output order across refills" {
    var src: Default = .init(.init(11));
    const r = src.rng();
    var expected: [200]u64 = undefined;
    flatGen(11, &expected);
    for (expected) |e| try testing.expectEqual(e, r.next());
}

test "float and floatVec convert the same bits" {
    var a: Default = .init(.init(5));
    var b: Default = .init(.init(5));
    for (0..21) |_| { // stay within one 64-value buffer (floatVec discards remainders)
        const v: [3]f64 = a.rng().floatVec(3);
        for (v) |x| try testing.expectEqual(b.rng().float(f64), x);
    }
}

test "nextVec discards a short remainder and refills" {
    var src: Default = .init(.init(3));
    const r = src.rng();
    var expected: [128]u64 = undefined;
    flatGen(3, &expected);
    for (0..21) |_| _ = r.nextVec(3); // 63 used, 1 left in buffer
    const v: [3]u64 = r.nextVec(3);
    try testing.expectEqualSlices(u64, expected[64..67], &v);
}

test "fillF64 goes straight to the generator" {
    var src: Default = .init(.init(9));
    var gen = SimdXoshiro256(8).init(9);
    var got: [37]f64 = undefined;
    var want: [37]f64 = undefined;
    src.rng().fillF64(&got);
    gen.fillF64(&want);
    try testing.expectEqualSlices(f64, &want, &got);
}

test "fill u64 handles tails" {
    var src: Default = .init(.init(21));
    var got: [19]u64 = undefined;
    src.rng().fill(&got);
    var want: [24]u64 = undefined;
    flatGen(21, &want);
    try testing.expectEqualSlices(u64, want[0..19], &got);
}

test "float range and mean" {
    var src: Default = .init(.init(0xabc));
    const r = src.rng();
    var sum: f64 = 0;
    const n = 100_000;
    for (0..n) |_| {
        const x = r.float(f64);
        try testing.expect(x >= 0 and x < 1);
        sum += x;
    }
    try testing.expect(@abs(sum / n - 0.5) < 0.005);
}

test "std.Random adapter" {
    var src: Default = .init(.init(1));
    const legacy = src.rng().random();
    for (0..100) |_| {
        const x = legacy.float(f64);
        try testing.expect(x >= 0 and x < 1);
    }
}

fn takesInterface(r: *Rng) @Vector(3, f64) {
    return r.floatVec(3);
}

test "usable through *Rng" {
    var src: Default = .init(.init(2));
    const v: [3]f64 = takesInterface(src.rng());
    for (v) |x| try testing.expect(x >= 0 and x < 1);
}
