const std = @import("std");

const Self = @This();

pub const empty: Self = .{ .min = std.math.inf(f32), .max = -std.math.inf(f32) };
pub const universe: Self = .{ .min = -std.math.inf(f32), .max = std.math.inf(f32) };

min: f32,
max: f32,

pub fn size(self: Self) f32 {
    return self.max - self.min;
}

pub fn contains(self: Self, x: f32) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f32) bool {
    return self.min < x and x < self.max;
}
