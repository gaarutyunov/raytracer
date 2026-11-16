const std = @import("std");
const vec3 = @import("vec3.zig");
const Interval = @import("Interval.zig");
const Vec3 = vec3.Vec3;

pub const Color = Vec3;

const intensity: Interval = .{ .min = 0.000, .max = 0.999 };

pub fn write(c: Color, writer: *std.Io.Writer) !void {
    const ir = @trunc(256 * intensity.clamp(c[0]));
    const ig = @trunc(256 * intensity.clamp(c[1]));
    const ib = @trunc(256 * intensity.clamp(c[2]));

    try writer.print("{d} {d} {d}\n", .{ ir, ig, ib });
}
