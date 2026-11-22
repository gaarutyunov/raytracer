const std = @import("std");
const Ray = @import("../Ray.zig");
const Material = @import("../material.zig").Material;
const BoundingBox = @import("../BoundingBox.zig");
const Interval = @import("../Interval.zig");
const Hit = @import("../Hit.zig");
const vec = @import("../vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;

const Self = @This();

pub const Options = union(enum) {
    moving: struct {
        center1: Point3,
        center2: Point3,
        radius: f64,
        material: Material,
    },
    static: struct {
        center: Point3,
        radius: f64,
        material: Material,
    },
};

center: Ray,
radius: f64,
material: Material,
bbox: BoundingBox,

pub fn init(options: Options) !Self {
    return switch (options) {
        .static => |op| .{
            .center = .init(op.center, .{ 0, 0, 0 }, 0),
            .radius = op.radius,
            .material = op.material,
            .bbox = .fromPoints(
                op.center - @as(Vec3, @splat(op.radius)),
                op.center + @as(Vec3, @splat(op.radius)),
            ),
        },
        .moving => |op| {
            const rvec: Vec3 = @splat(op.radius);
            const center: Ray = .init(op.center1, op.center2 - op.center1, 0);
            return .{
                .center = center,
                .radius = op.radius,
                .material = op.material,
                .bbox = .fromBoxes(
                    .fromPoints(center.at(0) - rvec, center.at(0) + rvec),
                    .fromPoints(center.at(1) - rvec, center.at(1) + rvec),
                ),
            };
        },
    };
}

pub fn bounding_box(self: Self) BoundingBox {
    return self.bbox;
}

pub fn hit(self: Self, ray: Ray, ray_t: Interval) ?Hit {
    const current_center = self.center.at(ray.time);
    const oc: Vec3 = current_center - ray.origin;
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
    const outward_normal = (p - current_center) /
        @as(Vec3, @splat(self.radius));

    var rec: Hit = .init(p, outward_normal, root, ray, self.material);

    rec.u, rec.v = point_to_uv(outward_normal);

    return rec;
}

fn point_to_uv(p: Point3) struct { f64, f64 } {
    const theta = std.math.acos(-p[1]); // 𝜃=arccos(−𝑦)
    const phi = std.math.atan2(-p[2], p[0]) + std.math.pi; // 𝜙=atan2(−𝑧,𝑥)+𝜋
    return .{
        phi / (2 * std.math.pi), // 𝑢=𝜙/2𝜋
        theta / std.math.pi, // 𝑣=𝜃/𝜋
    };
}
