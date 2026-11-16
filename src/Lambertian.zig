const Color = @import("color.zig").Color;
const Material = @import("Material.zig");
const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");
const vec = @import("vec3.zig");
const std = @import("std");

const Self = @This();

albedo: Color,
interface: Material,
rand: std.Random,

pub fn init(albedo: Color, rand: std.Random) Self {
    return .{
        .albedo = albedo,
        .interface = .{ .vtable = &.{ .scatter = scatter } },
        .rand = rand,
    };
}

fn scatter(material: *const Material, _: Ray, point: vec.Point3, normal: vec.Vec3) ?struct { Ray, Color } {
    const self: *const Self = @alignCast(@fieldParentPtr("interface", material));

    var scatter_direction = normal + vec.randomUnit(self.rand);

    if (vec.isNearZero(scatter_direction)) scatter_direction = normal;

    return .{ .init(point, scatter_direction), self.albedo };
}
