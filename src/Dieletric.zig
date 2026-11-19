const Color = @import("color.zig").Color;
const Material = @import("Material.zig");
const Ray = @import("Ray.zig");
const vec = @import("vec3.zig");
const std = @import("std");
const Rng = @import("Rng.zig");

const Self = @This();

albedo: Color,
interface: Material,
refraction_index: f64,
rand: *Rng,

pub fn init(rand: *Rng, refraction_index: f64) Self {
    return .{
        .albedo = .{ 1, 1, 1 },
        .interface = .{ .vtable = &.{ .scatter = scatter } },
        .refraction_index = refraction_index,
        .rand = rand,
    };
}

fn scatter(
    material: *const Material,
    r_in: Ray,
    point: vec.Point3,
    normal: vec.Vec3,
    front_face: bool,
) ?struct { Ray, Color } {
    const self: *const Self = @alignCast(@fieldParentPtr("interface", material));

    const refraction_index: f64 = if (front_face) (1.0 / self.refraction_index) else self.refraction_index;

    const unit_direction = vec.unit(r_in.direction);
    const cos_theta = @min(vec.dot(-unit_direction, normal), 1.0);
    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

    const cannot_refract = refraction_index * sin_theta > 1.0;
    var direction: vec.Vec3 = undefined;

    if (cannot_refract or reflectance(cos_theta, refraction_index) > self.rand.float(f64)) {
        direction = vec.reflect(unit_direction, normal);
    } else {
        direction = vec.refract(unit_direction, normal, refraction_index);
    }

    return .{ .init(point, direction), self.albedo };
}

fn reflectance(cosine: f64, refraction_index: f64) f64 {
    // Schlick approximation
    var r0 = (1 - refraction_index) / (1 + refraction_index);
    r0 = r0 * r0;
    return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
}
