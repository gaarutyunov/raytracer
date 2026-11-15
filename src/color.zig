const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;

pub const Color = Vec3;

pub fn write(c: Color, writer: *std.Io.Writer) !void {
    const ir = @trunc(255.999 * c[0]);
    const ig = @trunc(255.999 * c[1]);
    const ib = @trunc(255.999 * c[2]);

    try writer.print("{d} {d} {d}\n", .{ ir, ig, ib });
}
