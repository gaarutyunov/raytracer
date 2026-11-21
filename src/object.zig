const std = @import("std");
const vec = @import("vec.zig");
const Ray = @import("Ray.zig");
const Hit = @import("Hit.zig");
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const BoundingBox = @import("BoundingBox.zig");
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;

pub const Object = union(enum) {
    sphere: struct {
        const Sphere = @This();

        center: Ray,
        radius: f64,
        material: Material,
        bbox: BoundingBox,

        pub fn bounding_box(self: Sphere) BoundingBox {
            return self.bbox;
        }

        pub fn hit(self: Sphere, ray: Ray, ray_t: Interval) ?Hit {
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
    },

    list: struct {
        const List = @This();

        objects: []const Object,
        bbox: BoundingBox = .empty,

        pub fn bounding_box(self: List) BoundingBox {
            return self.bbox;
        }

        pub fn hit(self: List, ray: Ray, ray_t: Interval) ?Hit {
            var rec: ?Hit = null;
            var closest = ray_t.max;

            for (self.objects) |elem| {
                if (elem.hit(ray, .{ .min = ray_t.min, .max = closest })) |r| {
                    closest = r.t;
                    rec = r;
                }
            }

            return rec;
        }
    },

    tree: struct {
        const Tree = @This();

        left: *Object,
        right: *Object,
        bbox: BoundingBox,

        pub fn bounding_box(self: Tree) BoundingBox {
            return self.bbox;
        }

        pub fn hit(self: Tree, ray: Ray, ray_t: Interval) ?Hit {
            if (!self.bounding_box().hit(ray, ray_t)) {
                return null;
            }

            var record: ?Hit = null;

            if (self.left.hit(ray, ray_t)) |rec| record = rec;
            if (self.right.hit(ray, .{
                .min = ray_t.min,
                .max = if (record) |rec| rec.t else ray_t.max,
            })) |rec| record = rec;

            return record;
        }
    },

    pub fn initList(objects: []const Object) Object {
        var bbox: BoundingBox = .empty;

        for (objects) |obj| {
            bbox = .fromBoxes(bbox, obj.bounding_box());
        }

        return .{ .list = .{ .objects = objects, .bbox = bbox } };
    }

    const SortContext = struct {
        axis: u32,
    };

    pub fn initTree(
        gpa: std.mem.Allocator,
        objects: []Object,
    ) !Object {
        var bbox: BoundingBox = .empty;
        for (objects) |object| {
            bbox = .fromBoxes(bbox, object.bounding_box());
        }
        const axis = bbox.longest_axis();

        const left = try gpa.create(Object);
        const right = try gpa.create(Object);

        if (objects.len == 1) {
            left.* = objects[0];
            right.* = objects[0];
        } else if (objects.len == 2) {
            left.* = objects[0];
            right.* = objects[1];
        } else {
            std.sort.pdq(Object, objects, SortContext{ .axis = axis }, compareTree);
            const mid = objects.len / 2;
            left.* = try .initTree(gpa, objects[0..mid]);
            right.* = try .initTree(gpa, objects[mid..]);
        }

        return .{
            .tree = .{
                .left = left,
                .right = right,
                .bbox = bbox,
            },
        };
    }

    fn compareTree(ctx: SortContext, lhs: Object, rhs: Object) bool {
        const l_axis_interval = lhs.bounding_box().axis_interval(ctx.axis);
        const r_axis_interval = rhs.bounding_box().axis_interval(ctx.axis);

        return l_axis_interval.min < r_axis_interval.min;
    }

    pub fn initStaticSphere(center: Point3, radius: f64, material: Material) Object {
        return .{
            .sphere = .{
                .center = .init(center, .{ 0, 0, 0 }, 0),
                .radius = radius,
                .material = material,
                .bbox = .fromPoints(
                    center - @as(Vec3, @splat(radius)),
                    center + @as(Vec3, @splat(radius)),
                ),
            },
        };
    }

    pub fn initMovingSphere(
        center1: Point3,
        center2: Point3,
        radius: f64,
        material: Material,
    ) Object {
        const rvec: Vec3 = @splat(radius);
        const center: Ray = .init(center1, center2 - center1, 0);
        return .{
            .sphere = .{
                .center = center,
                .radius = radius,
                .material = material,
                .bbox = .fromBoxes(
                    .fromPoints(center.at(0) - rvec, center.at(0) + rvec),
                    .fromPoints(center.at(1) - rvec, center.at(1) + rvec),
                ),
            },
        };
    }

    pub fn hit(self: Object, ray: Ray, ray_t: Interval) ?Hit {
        return switch (self) {
            inline else => |m| m.hit(ray, ray_t),
        };
    }

    pub fn bounding_box(self: Object) BoundingBox {
        return switch (self) {
            inline else => |m| m.bounding_box(),
        };
    }
};
