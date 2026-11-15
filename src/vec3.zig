const std = @import("std");

pub const Vec3 = @Vector(3, f32);
pub const Point3 = Vec3;
const Mask = @Vector(3, i32);

pub fn length(u: Vec3) f32 {
    return @sqrt(@reduce(.Add, u * u));
}

pub fn dot(u: Vec3, v: Vec3) f32 {
    return @reduce(.Add, u * v);
}

pub fn cross(u: Vec3, v: Vec3) Vec3 {
    return @shuffle(f32, u, undefined, Mask{ 1, 2, 0 }) * @shuffle(f32, v, undefined, Mask{ 2, 0, 1 }) -
        @shuffle(f32, u, undefined, Mask{ 2, 0, 1 }) * @shuffle(f32, v, undefined, Mask{ 1, 2, 0 });
}

pub fn unit(u: Vec3) Vec3 {
    return u / @as(Vec3, @splat(length(u)));
}

test cross {
    const u: Vec3 = .{ 3, 5, -7 };
    const v: Vec3 = .{ 2, -6, 4 };

    const r = cross(u, v);

    try std.testing.expectEqual(.{ -22, -26, -28 }, r);
    try std.testing.expectEqual(0, dot(u, r));
    try std.testing.expectEqual(0, dot(v, r));
}
