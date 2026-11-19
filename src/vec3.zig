const std = @import("std");
const Rng = @import("Rng.zig");

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

pub fn reflect(u: Vec3, normal: Vec3) Vec3 {
    return u - @as(Vec3, @splat(2 * dot(u, normal))) * normal;
}

pub fn refract(u: Vec3, normal: Vec3, refraction_index: f64) Vec3 {
    const cos_theta: Vec3 = @splat(@min(dot(-u, normal), 1.0));
    const r_out_perp: Vec3 = @as(Vec3, @splat(refraction_index)) * (u + cos_theta * normal);
    const r_out_parallel: Vec3 = @as(Vec3, @splat(-@sqrt(@abs(1 - dot(r_out_perp, r_out_perp))))) * normal;

    return r_out_perp + r_out_parallel;
}

pub fn isNearZero(u: Vec3) bool {
    const s: Vec3 = @splat(1e-8);

    return @reduce(.And, @abs(u) < s);
}

pub fn randomUnit(rand: *Rng) Vec3 {
    while (true) {
        const p = randomRange(rand, -1, 1);
        const lensq = dot(p, p);
        if (1e-160 < lensq and lensq <= 1) return p / @as(Vec3, @splat(@sqrt(lensq)));
    }
}

pub fn randomInUnitDisk(rand: *Rng) Vec3 {
    while (true) {
        var v = randomRange(rand, -1, 1);
        v[2] = 0;
        if (dot(v, v) < 1) {
            return v;
        }
    }
}

pub fn randomOnHemisphere(rand: *Rng, normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnit(rand);
    if (dot(on_unit_sphere, normal) > 0.0) {
        return on_unit_sphere;
    }

    return -on_unit_sphere;
}

pub fn random(rand: *Rng) Vec3 {
    return rand.floatVec(3);
}

pub fn randomRange(rand: *Rng, min: f64, max: f64) Vec3 {
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
