const Interval = @import("Interval.zig");
const Point3 = @import("vec3.zig").Point3;
const Ray = @import("Ray.zig");

const Self = @This();

x: Interval,
y: Interval,
z: Interval,

pub const empty: Self = .{ .x = .empty, .y = .empty, .z = .empty };

pub fn fromPoints(a: Point3, b: Point3) Self {
    return .{
        .x = if (a[0] <= b[0])
            .{ .min = a[0], .max = b[0] }
        else
            .{ .max = a[0], .min = b[0] },
        .y = if (a[1] <= b[1])
            .{ .min = a[1], .max = b[1] }
        else
            .{ .max = a[1], .min = b[1] },
        .z = if (a[2] <= b[2])
            .{ .min = a[2], .max = b[2] }
        else
            .{ .max = a[2], .min = b[2] },
    };
}

pub fn fromBoxes(a: Self, b: Self) Self {
    return .{
        .x = .fromIntervals(a.x, b.x),
        .y = .fromIntervals(a.y, b.y),
        .z = .fromIntervals(a.z, b.z),
    };
}

pub fn hit(self: Self, ray: Ray, ray_t: Interval) bool {
    var ray_t_ = ray_t;

    inline for (0..3) |axis| {
        const ax = self.axis_interval(axis);
        const adinv = 1.0 / ray.direction[axis];

        const t0 = (ax.min - ray.origin[axis]) * adinv;
        const t1 = (ax.max - ray.origin[axis]) * adinv;

        if (t0 < t1) {
            if (t0 > ray_t_.min) ray_t_.min = t0;
            if (t1 < ray_t_.max) ray_t_.max = t1;
        } else {
            if (t1 > ray_t_.min) ray_t_.min = t1;
            if (t0 < ray_t_.max) ray_t_.max = t0;
        }

        if (ray_t_.max <= ray_t_.min) return false;
    }

    return true;
}

pub fn axis_interval(self: Self, axis: usize) Interval {
    return switch (axis) {
        0 => self.x,
        1 => self.y,
        2 => self.z,
        else => unreachable,
    };
}
