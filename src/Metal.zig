const Color = @import("color.zig").Color;
const Material = @import("Material.zig");
const Ray = @import("Ray.zig");
const vec = @import("vec3.zig");
const std = @import("std");

const Self = @This();

albedo: Color,
interface: Material,
fuzz: f64,
rand: std.Random,

pub fn init(albedo: Color, rand: std.Random, fuzz: f64) Self {
    return .{
        .albedo = albedo,
        .interface = .{ .vtable = &.{ .scatter = scatter } },
        .fuzz = if (fuzz < 1) fuzz else 1,
        .rand = rand,
    };
}

fn scatter(material: *const Material, r_in: Ray, point: vec.Point3, normal: vec.Vec3) ?struct { Ray, Color } {
    const self: *const Self = @alignCast(@fieldParentPtr("interface", material));

    var reflected = vec.reflect(r_in.direction, normal);
    reflected = vec.unit(reflected) + @as(vec.Vec3, @splat(self.fuzz)) * vec.randomUnit(self.rand);

    const scattered: Ray = .init(point, reflected);

    if (vec.dot(scattered.direction, normal) > 0) return .{ .init(point, reflected), self.albedo };

    return null;
}
