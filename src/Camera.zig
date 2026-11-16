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
pixel_samples_scale: f64,
rand: std.Random,
samples_per_pixel: u32,
max_depth: u32,

pub fn init(
    rand: std.Random,
    center: Point3,
    aspect_ratio: f64,
    image_width: u32,
    samples_per_pixel: u32,
    max_depth: u32,
) Self {
    const image_height: u32 = @max(1, @as(u32, @trunc(@as(f64, @floatFromInt(image_width)) / aspect_ratio)));
    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * @as(f64, @floatFromInt(image_width)) / @as(f64, @floatFromInt(image_height));

    const viewport_u: Vec3 = .{ viewport_width, 0, 0 };
    const viewport_v: Vec3 = .{ 0, -viewport_height, 0 };

    const pixel_delta_u = viewport_u / @as(Vec3, @splat(@as(f64, @floatFromInt(image_width))));
    const pixel_delta_v = viewport_v / @as(Vec3, @splat(@as(f64, @floatFromInt(image_height))));

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
        .samples_per_pixel = samples_per_pixel,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
        .rand = rand,
        .max_depth = max_depth,
    };
}

fn ray_color(self: Self, r: Ray, world: *const Hittable, depth: u32) Color {
    if (depth <= 0) return .{ 0, 0, 0 };

    if (world.hit(r, .{ .min = 0.001, .max = std.math.inf(f64) })) |rec| {
        const direction = rec.normal + vec.random_unit(self.rand);
        return @as(Vec3, @splat(0.5)) * self.ray_color(.init(rec.p, direction), world, depth - 1);
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
            var pixel_color: color.Color = .{ 0, 0, 0 };

            for (0..self.samples_per_pixel) |_| {
                pixel_color += self.ray_color(self.get_ray(i, j), world, self.max_depth);
            }

            try color.write(pixel_color * @as(Vec3, @splat(self.pixel_samples_scale)), writer);
        }
    }
}

fn sample_square(self: Self) Vec3 {
    return .{ self.rand.float(f64) - 0.5, self.rand.float(f64) - 0.5, 0 };
}

fn get_ray(self: Self, i: usize, j: usize) Ray {
    const offset = self.sample_square();
    const pixel_sample = self.pixel00_loc +
        @as(Vec3, @splat(@as(f64, @floatFromInt(i)) + offset[0])) * self.pixel_delta_u +
        @as(Vec3, @splat(@as(f64, @floatFromInt(j)) + offset[1])) * self.pixel_delta_v;

    return .init(self.center, pixel_sample - self.center);
}
