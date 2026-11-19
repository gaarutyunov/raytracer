const std = @import("std");
const Ray = @import("Ray.zig");
const Hittable = @import("Hittable.zig");
const vec = @import("vec3.zig");
const color = @import("color.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Color = color.Color;
const Rng = @import("Rng.zig");

const Self = @This();

pub const Size = struct {
    aspect_ratio: f64,
    image_width: u32,
};

pub const Orientation = struct {
    look_at: Vec3,
    look_from: Vec3,
    vup: Vec3,
    vfov: u32,
};

pub const Focus = struct {
    defocus_angle: u32,
    focus_distance: f64,
};

image_height: u32,
image_width: u32,
center: Point3,
pixel00_loc: Point3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
pixel_samples_scale: f64,
rand: *Rng,
samples_per_pixel: u32,
max_depth: u32,
buffer: []f64,
defocus_disc_u: Vec3,
defocus_disc_v: Vec3,
defocus_angle: u32,

pub fn init(
    gpa: std.mem.Allocator,
    rand: *Rng,
    max_depth: u32,
    samples_per_pixel: u32,
    size: Size,
    orientation: Orientation,
    focus: Focus,
) !Self {
    const image_height: u32 = @max(1, @as(u32, @trunc(@as(f64, @floatFromInt(size.image_width)) / size.aspect_ratio)));
    const center = orientation.look_from;

    const h = std.math.tan(degreesToRadians(orientation.vfov) / 2);
    const viewport_height = 2.0 * h * focus.focus_distance;
    const viewport_width = viewport_height * @as(f64, @floatFromInt(size.image_width)) / @as(f64, @floatFromInt(image_height));

    const w = vec.unit(orientation.look_from - orientation.look_at);
    const u = vec.unit(vec.cross(orientation.vup, w));
    const v = vec.cross(w, u);

    const viewport_u: Vec3 = @as(Vec3, @splat(viewport_width)) * u;
    const viewport_v: Vec3 = @as(Vec3, @splat(-viewport_height)) * v;

    const pixel_delta_u = viewport_u / @as(Vec3, @splat(@as(f64, @floatFromInt(size.image_width))));
    const pixel_delta_v = viewport_v / @as(Vec3, @splat(@as(f64, @floatFromInt(image_height))));

    const viewport_upper_left = center - (@as(Vec3, @splat(focus.focus_distance)) * w) -
        @as(Vec3, @splat(0.5)) * viewport_u - @as(Vec3, @splat(0.5)) * viewport_v;
    const pixel00_loc = viewport_upper_left + @as(Vec3, @splat(0.5)) * (pixel_delta_u + pixel_delta_v);

    const defocus_radius = focus.focus_distance * std.math.tan(degreesToRadians(focus.defocus_angle / 2));

    return .{
        .pixel00_loc = pixel00_loc,
        .center = center,
        .pixel_delta_v = pixel_delta_v,
        .pixel_delta_u = pixel_delta_u,
        .image_width = size.image_width,
        .image_height = image_height,
        .samples_per_pixel = samples_per_pixel,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
        .rand = rand,
        .max_depth = max_depth,
        .buffer = try gpa.alloc(f64, size.image_width * samples_per_pixel * 2),
        .defocus_disc_u = u * @as(Vec3, @splat(defocus_radius)),
        .defocus_disc_v = v * @as(Vec3, @splat(defocus_radius)),
        .defocus_angle = focus.defocus_angle,
    };
}

fn rayColor(self: Self, r: Ray, world: *const Hittable, depth: u32) Color {
    if (depth <= 0) return .{ 0, 0, 0 };

    if (world.hit(r, .{ .min = 0.001, .max = std.math.inf(f64) })) |rec| {
        if (rec.mat.scatter(r, rec.p, rec.normal, rec.front_face)) |srec| {
            const scattered, const attenuation = srec;
            return attenuation * self.rayColor(scattered, world, depth - 1);
        }
        return .{ 0, 0, 0 };
    }
    const unit_dir = vec.unit(r.direction);
    const a: Vec3 = @splat(0.5 * unit_dir[1] + 1.0);

    return (@as(Vec3, @splat(1.0)) - a) * Color{ 1.0, 1.0, 1.0 } + a * Color{ 0.5, 0.7, 1.0 };
}

pub fn render(self: Self, world: *const Hittable, writer: *std.Io.Writer, logger: *std.Io.Writer) !void {
    try writer.print("P3\n{d} {d}\n255\n", .{ self.image_width, self.image_height });

    var buffer = self.buffer;
    _ = &buffer;

    for (0..self.image_height) |j| {
        try logger.print("\rScanlines remaining: {d}", .{self.image_height - j});
        try logger.flush();

        self.rand.fillF64(buffer);
        for (0..self.image_width) |i| {
            var pixel_color: color.Color = .{ 0, 0, 0 };

            for (0..self.samples_per_pixel) |s| {
                const offset = (i * self.samples_per_pixel + s) * 2;
                pixel_color += self.rayColor(
                    self.getRay(i, j, buffer[offset], buffer[offset + 1]),
                    world,
                    self.max_depth,
                );
            }

            try color.write(pixel_color * @as(Vec3, @splat(self.pixel_samples_scale)), writer);
        }
    }
}

fn getRay(self: Self, i: usize, j: usize, x: f64, y: f64) Ray {
    const pixel_sample = self.pixel00_loc +
        @as(Vec3, @splat(@as(f64, @floatFromInt(i)) + x)) * self.pixel_delta_u +
        @as(Vec3, @splat(@as(f64, @floatFromInt(j)) + y)) * self.pixel_delta_v;
    const ray_origin = if (self.defocus_angle <= 0) self.center else self.defocusDiskSample();

    return .init(ray_origin, pixel_sample - ray_origin);
}

fn defocusDiskSample(self: Self) Point3 {
    const p = vec.randomInUnitDisk(self.rand);
    return self.center + @as(Vec3, @splat(p[0])) * self.defocus_disc_u + @as(Vec3, @splat(p[1])) * self.defocus_disc_v;
}

pub fn deinit(self: Self, gpa: std.mem.Allocator) void {
    gpa.free(self.buffer);
}

fn degreesToRadians(degrees: u32) f64 {
    return @as(f64, @floatFromInt(degrees)) * std.math.pi / 180.0;
}
