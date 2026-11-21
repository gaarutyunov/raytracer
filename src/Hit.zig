const vec = @import("vec.zig");
const Ray = @import("Ray.zig");
const Material = @import("material.zig").Material;

const Self = @This();

p: vec.Point3,
normal: vec.Vec3,
t: f64,
front_face: bool,
mat: Material,
u: f64 = 0,
v: f64 = 0,

pub fn init(
    p: vec.Point3,
    outward_normal: vec.Vec3,
    t: f64,
    ray: Ray,
    mat: Material,
) Self {
    const front_face = vec.dot(ray.direction, outward_normal) < 0;
    return .{
        .p = p,
        .t = t,
        .front_face = front_face,
        .normal = if (front_face) outward_normal else -outward_normal,
        .mat = mat,
    };
}
