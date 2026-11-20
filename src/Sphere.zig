const std = @import("std");
const vec = @import("vec3.zig");
const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");
const Hittable = @import("Hittable.zig");
const Interval = @import("Interval.zig");
const Material = @import("Material.zig").Material;
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;

const Sphere = @This();

center: Point3,
radius: f64,
interface: Hittable,
mat: Material,

pub fn init(center: Point3, radius: f64, mat: Material) Sphere {
    return .{
        .center = center,
        .radius = @max(0, radius),
        .interface = .{ .vtable = &.{ .hit = hit } },
        .mat = mat,
    };
}

fn hit(hittable: *const Hittable, ray: Ray, ray_t: Interval) ?HitRecord {
    const self: *const Sphere = @alignCast(@fieldParentPtr("interface", hittable));
    const oc: Vec3 = self.center - ray.origin;
    const a = vec.dot(ray.direction, ray.direction);
    const h = vec.dot(ray.direction, oc);
    const c = vec.dot(oc, oc) - self.radius * self.radius;

    const d = h * h - a * c;

    if (d < 0) {
        return null;
    }

    const sqrtd = std.math.sqrt(d);

    var root = (h - sqrtd) / a;

    if (!ray_t.surrounds(root)) {
        root = (h + sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            return null;
        }
    }

    const p = ray.at(root);

    return .init(p, (p - self.center) / @as(Vec3, @splat(self.radius)), root, ray, self.mat);
}
