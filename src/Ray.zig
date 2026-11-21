const vec = @import("vec3.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;

const Ray = @This();

origin: Point3,
direction: Vec3,
time: f64,

pub fn init(origin: Point3, direction: Vec3, time: f64) Ray {
    return .{
        .origin = origin,
        .direction = direction,
        .time = time,
    };
}

pub fn at(self: Ray, t: f64) Point3 {
    return self.origin + @as(Vec3, @splat(t)) * self.direction;
}
