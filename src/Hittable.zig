const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");
const Interval = @import("Interval.zig");

const Hittable = @This();

vtable: *const VTable,

pub const VTable = struct {
    hit: *const fn (self: *const Hittable, ray: Ray, ray_t: Interval) ?HitRecord,
};

pub fn hit(self: *const Hittable, ray: Ray, ray_t: Interval) ?HitRecord {
    return self.vtable.hit(self, ray, ray_t);
}
