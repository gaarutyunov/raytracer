const std = @import("std");
const Ray = @import("Ray.zig");
const Hittable = @import("Hittable.zig");
const vec = @import("vec3.zig");
const color = @import("color.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Color = color.Color;

const Self = @This();

image_height: u32,
image_width: u32,
center: Point3,
pixel00_loc: Point3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,

pub fn init(center: Point3, aspect_ratio: f32, image_width: u32) Self {
    const image_height: u32 = @max(1, @as(u32, @trunc(@as(f32, @floatFromInt(image_width)) / aspect_ratio)));
    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * @as(f32, @floatFromInt(image_width)) / @as(f32, @floatFromInt(image_height));

    const viewport_u: Vec3 = .{ viewport_width, 0, 0 };
    const viewport_v: Vec3 = .{ 0, -viewport_height, 0 };

    const pixel_delta_u = viewport_u / @as(Vec3, @splat(@as(f32, @floatFromInt(image_width))));
    const pixel_delta_v = viewport_v / @as(Vec3, @splat(@as(f32, @floatFromInt(image_height))));

    const viewport_upper_left = center - Vec3{ 0, 0, focal_length } -
        @as(Vec3, @splat(0.5)) * viewport_u - @as(Vec3, @splat(0.5)) * viewport_v;
    const pixel00_loc = viewport_upper_left + @as(Vec3, @splat(0.5)) * (pixel_delta_u + pixel_delta_v);

    return .{
        .pixel00_loc = pixel00_loc,
        .center = center,
        .pixel_delta_v = pixel_delta_v,
        .pixel_delta_u = pixel_delta_u,
        .image_width = image_width,
        .image_height = image_height,
    };
}

fn ray_color(r: Ray, world: *const Hittable) Color {
    if (world.hit(r, .{ .min = 0, .max = std.math.inf(f32) })) |rec| {
        return @as(Vec3, @splat(0.5)) * (rec.normal + Color{ 1, 1, 1 });
    }
    const unit_dir = vec.unit(r.direction);
    const a: Vec3 = @splat(0.5 * unit_dir[1] + 1.0);

    return (@as(Vec3, @splat(1.0)) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

pub fn render(self: Self, world: *const Hittable, writer: *std.Io.Writer, logger: *std.Io.Writer) !void {
    try writer.print("P3\n{d} {d}\n255\n", .{ self.image_width, self.image_height });

    for (0..self.image_height) |j| {
        try logger.print("\rScanlines remaining: {d}", .{self.image_height - j});
        try logger.flush();
        for (0..self.image_width) |i| {
            const pixel_center = self.pixel00_loc + @as(Vec3, @splat(@floatFromInt(i))) * self.pixel_delta_u +
                @as(Vec3, @splat(@floatFromInt(j))) * self.pixel_delta_v;
            const ray_direction = pixel_center - self.center;
            const ray: Ray = .init(self.center, ray_direction);
            const c: Color = ray_color(ray, world);
            try color.write(c, writer);
        }
    }
}
