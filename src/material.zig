const Ray = @import("Ray.zig");
const vec = @import("vec.zig");
const std = @import("std");
const Color = vec.Color;

pub const Material = union(enum) {
    lambertian: struct {
        albedo: Color,

        pub fn scatter(
            self: @This(),
            rand: std.Random,
            r_in: Ray,
            point: vec.Point3,
            normal: vec.Vec3,
            _: bool,
        ) ?struct { Ray, Color } {
            var scatter_direction = normal + vec.randomUnit(rand);

            if (vec.isNearZero(scatter_direction)) scatter_direction = normal;

            return .{ .init(point, scatter_direction, r_in.time), self.albedo };
        }
    },
    metal: struct {
        albedo: Color,
        fuzz: f64,

        pub fn scatter(
            self: @This(),
            rand: std.Random,
            r_in: Ray,
            point: vec.Point3,
            normal: vec.Vec3,
            _: bool,
        ) ?struct { Ray, Color } {
            var reflected = vec.reflect(r_in.direction, normal);
            reflected = vec.unit(reflected) + @as(vec.Vec3, @splat(self.fuzz)) * vec.randomUnit(rand);

            const scattered: Ray = .init(point, reflected, 0);

            if (vec.dot(scattered.direction, normal) > 0) {
                return .{ .init(point, reflected, r_in.time), self.albedo };
            }

            return null;
        }
    },
    dielectric: struct {
        albedo: Color = .{ 1.0, 1.0, 1.0 },
        refraction_index: f64,

        pub fn scatter(
            self: @This(),
            rand: std.Random,
            r_in: Ray,
            point: vec.Point3,
            normal: vec.Vec3,
            front_face: bool,
        ) ?struct { Ray, Color } {
            const refraction_index: f64 = if (front_face) (1.0 / self.refraction_index) else self.refraction_index;

            const unit_direction = vec.unit(r_in.direction);
            const cos_theta = @min(vec.dot(-unit_direction, normal), 1.0);
            const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

            const cannot_refract = refraction_index * sin_theta > 1.0;
            var direction: vec.Vec3 = undefined;

            if (cannot_refract or reflectance(cos_theta, refraction_index) > rand.float(f64)) {
                direction = vec.reflect(unit_direction, normal);
            } else {
                direction = vec.refract(unit_direction, normal, refraction_index);
            }

            return .{ .init(point, direction, r_in.time), self.albedo };
        }

        fn reflectance(cosine: f64, refraction_index: f64) f64 {
            // Schlick approximation
            var r0 = (1 - refraction_index) / (1 + refraction_index);
            r0 = r0 * r0;
            return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
        }
    },

    pub fn scatter(
        self: @This(),
        rand: std.Random,
        r_in: Ray,
        point: vec.Point3,
        normal: vec.Vec3,
        front_face: bool,
    ) ?struct { Ray, Color } {
        return switch (self) {
            inline else => |m| m.scatter(rand, r_in, point, normal, front_face),
        };
    }
};
