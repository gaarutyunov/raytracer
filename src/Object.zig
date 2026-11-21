const std = @import("std");
const vec = @import("vec3.zig");
const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");
const Interval = @import("Interval.zig");
const Material = @import("Material.zig").Material;
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;

pub const Object = union(enum) {
    sphere: struct {
        center: Point3,
        radius: f64,
        material: Material,

        pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
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

            return .init(p, (p - self.center) / @as(Vec3, @splat(self.radius)), root, ray, self.material);
        }
    },

    pub fn hit(self: @This(), ray: Ray, ray_t: Interval) ?HitRecord {
        return switch (self) {
            inline else => |m| m.hit(ray, ray_t),
        };
    }
};
