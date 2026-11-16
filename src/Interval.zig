const std = @import("std");

const Self = @This();

pub const empty: Self = .{ .min = std.math.inf(f64), .max = -std.math.inf(f64) };
pub const universe: Self = .{ .min = -std.math.inf(f64), .max = std.math.inf(f64) };

min: f64,
max: f64,

pub fn size(self: Self) f64 {
    return self.max - self.min;
}

pub fn contains(self: Self, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: Self, x: f64) f64 {
    if (x < self.min) return self.min;
    if (x > self.max) return self.max;
    return x;
}
