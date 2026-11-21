const std = @import("std");
const zigimg = @import("zigimg");
const vec = @import("vec.zig");
const Interval = @import("Interval.zig");

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
        data: zigimg.color.PixelStorage,

        pub fn color(self: @This(), u: f64, v: f64, _: vec.Point3) vec.Color {
            const interval: Interval = .{ .min = 0, .max = 1 };
            const u_ = interval.clamp(u);
            const v_ = 1.0 - interval.clamp(v);

            const i: usize = @trunc(u_ * @as(f64, @floatFromInt(self.width)));
            const j: usize = @trunc(v_ * @as(f64, @floatFromInt(self.height)));

            return self.pixelColor(i, j);
        }

        pub fn pixelColor(self: @This(), i: usize, j: usize) vec.Color {
            return switch (self.data) {
                .rgb24 => |pixels| {
                    const pixel: zigimg.color.Rgb24 = pixels[
                        clamp(j, 0, self.height) * self.width +
                            clamp(i, 0, self.width)
                    ];
                    const c = pixel.to.color(zigimg.color.Colorf32);

                    return .{ c.r, c.g, c.b };
                },
                else => .{ 0, 1, 1 },
            };
        }

        fn clamp(x: usize, low: usize, high: usize) usize {
            return if (x < low)
                low
            else if (x < high)
                x
            else
                high - 1;
        }
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
    pub fn loadImage(gpa: std.mem.Allocator, data: []const u8) !Texture {
        const image: zigimg.Image = try .fromMemory(gpa, data);

        return .{
            .image = .{
                .width = image.width,
                .height = image.height,
                .data = image.pixels,
            },
        };
    }

    pub fn color(self: Texture, u: f64, v: f64, p: vec.Point3) vec.Color {
        return switch (self) {
            inline else => |m| m.color(u, v, p),
        };
    }
};

test "loadImage" {
    const txt: Texture = try .loadImage(std.testing.allocator, @embedFile("assets/earthmap.jpg"));
    defer txt.image.data.deinit(std.testing.allocator);

    const interval: Interval = .{ .min = 0, .max = 1 };
    const color: [3]f64 = txt.image.pixelColor(100, 200);
    try std.testing.expectEqual(false, std.mem.eql(f64, &color, &.{ 0, 1, 1 }));
    try std.testing.expectEqual(true, interval.contains(color[0]));
}
