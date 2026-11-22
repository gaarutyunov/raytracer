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
    sphere: @import("objects/Sphere.zig"),
    quad: @import("objects/Quad.zig"),

    list: struct {
        const List = @This();

        pub const Options = struct {
            objects: []const Object,
        };

        objects: []const Object,
        bbox: BoundingBox = .empty,

        pub fn init(options: Options) !List {
            var bbox: BoundingBox = .empty;

            for (options.objects) |obj| {
                bbox = .fromBoxes(bbox, obj.bounding_box());
            }

            return .{ .objects = options.objects, .bbox = bbox };
        }

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

        pub const Options = struct {
            gpa: std.mem.Allocator,
            objects: []Object,
        };

        left: *Object,
        right: *Object,
        bbox: BoundingBox,

        pub fn init(options: Options) !Tree {
            const gpa = options.gpa;
            var objects = options.objects;

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
                left.* = .{
                    .tree = try Tree.init(.{
                        .gpa = gpa,
                        .objects = objects[0..mid],
                    }),
                };
                right.* = .{
                    .tree = try Tree.init(.{
                        .gpa = gpa,
                        .objects = objects[mid..],
                    }),
                };
            }

            return .{
                .left = left,
                .right = right,
                .bbox = bbox,
            };
        }

        const SortContext = struct {
            axis: u32,
        };

        fn compareTree(ctx: SortContext, lhs: Object, rhs: Object) bool {
            const l_axis_interval = lhs.bounding_box().axis_interval(ctx.axis);
            const r_axis_interval = rhs.bounding_box().axis_interval(ctx.axis);

            return l_axis_interval.min < r_axis_interval.min;
        }

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

    pub fn init(
        comptime kind: std.meta.Tag(Object),
        options: @FieldType(Object, @tagName(kind)).Options,
    ) !Object {
        return @unionInit(
            Object,
            @tagName(kind),
            try @FieldType(Object, @tagName(kind)).init(options),
        );
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

test "init" {
    const quad: Object = try .init(.quad, .{
        .q = .{ 0, 0, 0 },
        .u = .{ 0, 0, 0 },
        .v = .{ 0, 0, 0 },
        .material = .initLambertian(.{ .color = .{ 0, 0, 0 } }),
    });

    switch (quad) {
        .quad => {},
        else => return error.NotQuad,
    }
}
