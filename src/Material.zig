const Ray = @import("Ray.zig");
const color = @import("color.zig");
const vec = @import("vec3.zig");

const Self = @This();

vtable: *const VTable,

pub const VTable = struct {
    scatter: *const fn (
        self: *const Self,
        r_in: Ray,
        point: vec.Point3,
        normal: vec.Vec3,
        front_face: bool,
    ) ?struct { Ray, color.Color },
};

pub fn scatter(
    self: *const Self,
    r_in: Ray,
    point: vec.Point3,
    normal: vec.Vec3,
    front_face: bool,
) ?struct { Ray, color.Color } {
    return self.vtable.scatter(self, r_in, point, normal, front_face);
}
