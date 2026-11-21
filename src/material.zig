const Ray = @import("Ray.zig");
const Texture = @import("texture.zig").Texture;
const vec = @import("vec.zig");
const std = @import("std");
const Color = vec.Color;

pub const Material = union(enum) {
    lambertian: struct {
        texture: Texture,

        pub fn scatter(
            self: @This(),
            rand: std.Random,
            r_in: Ray,
            rec: anytype,
        ) ?struct { Ray, Color } {
            var scatter_direction = rec.normal + vec.randomUnit(rand);

            if (vec.isNearZero(scatter_direction)) scatter_direction = rec.normal;

            return .{
                .init(rec.p, scatter_direction, r_in.time),
                self.texture.color(rec.u, rec.v, rec.p),
            };
        }
    },
    metal: struct {
        albedo: Color,
        fuzz: f64,

        pub fn scatter(
            self: @This(),
            rand: std.Random,
            r_in: Ray,
            rec: anytype,
        ) ?struct { Ray, Color } {
            var reflected = vec.reflect(r_in.direction, rec.normal);
            reflected = vec.unit(reflected) + @as(vec.Vec3, @splat(self.fuzz)) * vec.randomUnit(rand);

            const scattered: Ray = .init(rec.p, reflected, 0);

            if (vec.dot(scattered.direction, rec.normal) > 0) {
                return .{ .init(rec.p, reflected, r_in.time), self.albedo };
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
            rec: anytype,
        ) ?struct { Ray, Color } {
            const refraction_index: f64 = if (rec.front_face) (1.0 / self.refraction_index) else self.refraction_index;

            const unit_direction = vec.unit(r_in.direction);
            const cos_theta = @min(vec.dot(-unit_direction, rec.normal), 1.0);
            const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

            const cannot_refract = refraction_index * sin_theta > 1.0;
            var direction: vec.Vec3 = undefined;

            if (cannot_refract or reflectance(cos_theta, refraction_index) > rand.float(f64)) {
                direction = vec.reflect(unit_direction, rec.normal);
            } else {
                direction = vec.refract(unit_direction, rec.normal, refraction_index);
            }

            return .{ .init(rec.p, direction, r_in.time), self.albedo };
        }

        fn reflectance(cosine: f64, refraction_index: f64) f64 {
            // Schlick approximation
            var r0 = (1 - refraction_index) / (1 + refraction_index);
            r0 = r0 * r0;
            return r0 + (1 - r0) * std.math.pow(f64, 1 - cosine, 5);
        }
    },

    pub fn initLambertian(
        txt: union(enum) { color: vec.Color, texture: Texture },
    ) Material {
        return .{
            .lambertian = .{
                .texture = switch (txt) {
                    .color => |c| .{
                        .solid_color = .{ .albedo = c },
                    },
                    .texture => |t| t,
                },
            },
        };
    }

    pub fn scatter(
        self: @This(),
        rand: std.Random,
        r_in: Ray,
        rec: anytype,
    ) ?struct { Ray, Color } {
        return switch (self) {
            inline else => |m| m.scatter(rand, r_in, rec),
        };
    }
};
