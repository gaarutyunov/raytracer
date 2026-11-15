const std = @import("std");
const HitRecord = @import("HitRecord.zig");
const Ray = @import("Ray.zig");
const Hittable = @import("Hittable.zig");
const Interval = @import("Interval.zig");

pub fn HittableList(comptime T: type) type {
    return struct {
        const Self = @This();

        objects: std.ArrayList(*const T),
        interface: Hittable,

        pub fn init(gpa: std.mem.Allocator, capacity: usize) !Self {
            return .{
                .objects = try .initCapacity(gpa, capacity),
                .interface = .{ .vtable = &.{ .hit = hit } },
            };
        }

        pub fn add(self: *Self, gpa: std.mem.Allocator, obj: *const T) !void {
            try self.objects.append(gpa, obj);
        }

        pub fn hit(h: *const Hittable, ray: Ray, ray_t: Interval) ?HitRecord {
            const self: *const Self = @alignCast(@fieldParentPtr("interface", h));
            var rec: ?HitRecord = null;
            var closest = ray_t.max;

            for (self.objects.items) |elem| {
                if (elem.hit(ray, .{ .min = ray_t.min, .max = closest })) |r| {
                    closest = r.t;
                    rec = r;
                }
            }

            return rec;
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.objects.deinit(gpa);
        }
    };
}
