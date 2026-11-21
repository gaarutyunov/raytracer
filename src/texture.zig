const std = @import("std");
const zigimg = @import("zigimg");
const vec = @import("vec.zig");

pub const Texture = union(enum) {
    solid_color: struct {
        albedo: vec.Color,

        pub fn color(self: @This(), _: f64, _: f64, _: vec.Point3) vec.Color {
            return self.albedo;
        }
    },
    checker: struct {
        scale: f64,
        even: *const Texture,
        odd: *const Texture,

        pub fn color(self: @This(), u: f64, v: f64, p: vec.Point3) vec.Color {
            const x_int: i32 = @trunc(p[0] / self.scale);
            const y_int: i32 = @trunc(p[1] / self.scale);
            const z_int: i32 = @trunc(p[2] / self.scale);

            const is_even = @mod(x_int + y_int + z_int, 2) == 0;

            return if (is_even)
                self.even.color(u, v, p)
            else
                self.odd.color(u, v, p);
        }
    },
    image: struct {
        width: usize,
        height: usize,
        data: []u8,

        pub fn color(self: Texture, u: f64, v: f64, p: vec.Point3) vec.Color {}
    },

    pub fn initChecker(
        gpa: std.mem.Allocator,
        scale: f64,
        even_color: vec.Color,
        odd_color: vec.Color,
    ) !Texture {
        const even = try gpa.create(Texture);
        const odd = try gpa.create(Texture);

        even.* = .{
            .solid_color = .{
                .albedo = even_color,
            },
        };

        odd.* = .{
            .solid_color = .{
                .albedo = odd_color,
            },
        };

        return .{
            .checker = .{
                .scale = scale,
                .even = even,
                .odd = odd,
            },
        };
    }

    // data is embedded file not path
    pub fn loadImage(data: []const u8) !Texture {}

    pub fn color(self: Texture, u: f64, v: f64, p: vec.Point3) vec.Color {
        return switch (self) {
            inline else => |m| m.color(u, v, p),
        };
    }
};
