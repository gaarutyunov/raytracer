const std = @import("std");

pub const Vec3 = @Vector(3, f64);
pub const Point3 = Vec3;
const Mask = @Vector(3, i32);

pub fn length(u: Vec3) f64 {
    return @sqrt(dot(u, u));
}

pub fn dot(u: Vec3, v: Vec3) f64 {
    return @reduce(.Add, u * v);
}

pub fn cross(u: Vec3, v: Vec3) Vec3 {
    return @shuffle(f64, u, undefined, Mask{ 1, 2, 0 }) * @shuffle(f64, v, undefined, Mask{ 2, 0, 1 }) -
        @shuffle(f64, u, undefined, Mask{ 2, 0, 1 }) * @shuffle(f64, v, undefined, Mask{ 1, 2, 0 });
}

pub fn unit(u: Vec3) Vec3 {
    return u / @as(Vec3, @splat(length(u)));
}

pub fn random_unit(rand: std.Random) Vec3 {
    while (true) {
        const p = random_range(rand, -1, 1);
        const lensq = dot(p, p);
        if (1e-160 < lensq and lensq <= 1) return p / @as(Vec3, @splat(@sqrt(lensq)));
    }
}

pub fn random_on_hemisphere(rand: std.Random, normal: Vec3) Vec3 {
    const on_unit_sphere = random_unit(rand);
    if (dot(on_unit_sphere, normal) > 0.0) {
        return on_unit_sphere;
    }

    return -on_unit_sphere;
}

pub fn random(rand: std.Random) Vec3 {
    return .{ rand.float(f64), rand.float(f64), rand.float(f64) };
}

pub fn random_range(rand: std.Random, min: f64, max: f64) Vec3 {
    const minVec: Vec3 = @splat(min);
    const maxVec: Vec3 = @splat(max);

    return minVec + (maxVec - minVec) * random(rand);
}

test cross {
    const u: Vec3 = .{ 3, 5, -7 };
    const v: Vec3 = .{ 2, -6, 4 };

    const r = cross(u, v);

    try std.testing.expectEqual(.{ -22, -26, -28 }, r);
    try std.testing.expectEqual(0, dot(u, r));
    try std.testing.expectEqual(0, dot(v, r));
}
