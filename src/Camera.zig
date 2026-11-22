const std = @import("std");
const Ray = @import("Ray.zig");
const vec = @import("vec.zig");
const Interval = @import("Interval.zig");
const Hit = @import("Hit.zig");
const Object = @import("object.zig").Object;
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Color = vec.Color;

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
    defocus_angle: f64,
    focus_distance: f64,
};

image_height: u32,
image_width: u32,
center: Point3,
pixel00_loc: Point3,
pixel_delta_u: Vec3,
pixel_delta_v: Vec3,
pixel_samples_scale: f64,
samples_per_pixel: u32,
max_depth: u32,
defocus_disc_u: Vec3,
defocus_disc_v: Vec3,
defocus_angle: f64,

pub fn init(
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

    const defocus_radius = focus.focus_distance * std.math.tan(degreesToRadians(@trunc(focus.defocus_angle / 2)));

    return .{
        .pixel00_loc = pixel00_loc,
        .center = center,
        .pixel_delta_v = pixel_delta_v,
        .pixel_delta_u = pixel_delta_u,
        .image_width = size.image_width,
        .image_height = image_height,
        .samples_per_pixel = samples_per_pixel,
        .pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(samples_per_pixel)),
        .max_depth = max_depth,
        .defocus_disc_u = u * @as(Vec3, @splat(defocus_radius)),
        .defocus_disc_v = v * @as(Vec3, @splat(defocus_radius)),
        .defocus_angle = focus.defocus_angle,
    };
}

pub fn render(
    self: Self,
    gpa: std.mem.Allocator,
    io: std.Io,
    writer: *std.Io.Writer,
    world: Object,
    concurrency: usize,
) !usize {
    var errbuffer: [256]u8 = undefined;

    var group: std.Io.Group = .init;
    var semaphore: std.Io.Semaphore = .{ .permits = concurrency };
    var colors: []Color = try gpa.alloc(Color, self.image_width * self.image_height);
    _ = &colors;

    const pr = std.Progress.start(io, .{
        .draw_buffer = &errbuffer,
        .estimated_total_items = self.image_height,
        .root_name = "raytracing",
    });

    defer pr.end();

    const Context = struct {
        io: std.Io,
        semaphore: *std.Io.Semaphore,
        camera: Self,
        progress: std.Progress.Node,
        world: Object,

        pub fn worker(ctx: *@This(), result: []Color, row: usize) !void {
            try ctx.semaphore.wait(ctx.io);
            defer ctx.semaphore.post(ctx.io);
            defer ctx.progress.completeOne();

            var prng: std.Random.DefaultPrng = .init(42);
            const rand = prng.random();

            for (0..ctx.camera.image_width) |i| {
                var pixel_color: Color = .{ 0, 0, 0 };

                for (0..ctx.camera.samples_per_pixel) |_| {
                    pixel_color += ctx.camera.rayColor(
                        rand,
                        ctx.camera.getRay(rand, i, row),
                        ctx.world,
                        ctx.camera.max_depth,
                    );
                }

                result[i] = pixel_color * @as(Vec3, @splat(ctx.camera.pixel_samples_scale));
            }
        }
    };

    for (0..self.image_height) |j| {
        var ctx: Context = .{
            .io = io,
            .progress = pr,
            .semaphore = &semaphore,
            .world = world,
            .camera = self,
        };
        try group.concurrent(
            io,
            Context.worker,
            .{ &ctx, colors[self.image_width * j ..][0..self.image_width], j },
        );
    }

    try group.await(io);

    var written: usize = blk: {
        var buffer: [64]u8 = undefined;

        break :blk try writer.write(try std.mem.print(
            &buffer,
            "P3\n{d} {d}\n255\n",
            .{ self.image_width, self.image_height },
        ));
    };

    for (colors) |value| {
        written += try vec.write(value, writer);
    }

    try writer.flush();

    return written;
}

fn rayColor(self: Self, rand: std.Random, r: Ray, world: Object, depth: u32) Color {
    if (depth <= 0) return .{ 0, 0, 0 };

    if (world.hit(r, .{ .min = 0.001, .max = std.math.inf(f64) })) |rec| {
        if (rec.mat.scatter(rand, r, rec)) |srec| {
            const scattered, const attenuation = srec;
            return attenuation * self.rayColor(rand, scattered, world, depth - 1);
        }
        return .{ 0, 0, 0 };
    }
    const unit_dir = vec.unit(r.direction);
    const a: Vec3 = @splat(0.5 * unit_dir[1] + 1.0);

    return (@as(Vec3, @splat(1.0)) - a) * Color{ 1.0, 1.0, 1.0 } +
        a * Color{ 0.5, 0.7, 1.0 };
}

fn getRay(self: Self, rand: std.Random, i: usize, j: usize) Ray {
    const x = rand.float(f64) - 0.5;
    const y = rand.float(f64) - 0.5;
    const pixel_sample = self.pixel00_loc +
        @as(Vec3, @splat(@as(f64, @floatFromInt(i)) + x)) * self.pixel_delta_u +
        @as(Vec3, @splat(@as(f64, @floatFromInt(j)) + y)) * self.pixel_delta_v;
    const ray_origin = if (self.defocus_angle <= 0) self.center else self.defocusDiskSample(rand);
    const ray_time = rand.float(f64);

    return .init(ray_origin, pixel_sample - ray_origin, ray_time);
}

fn defocusDiskSample(self: Self, rand: std.Random) Point3 {
    const p = vec.randomInUnitDisk(rand);
    return self.center + @as(Vec3, @splat(p[0])) * self.defocus_disc_u + @as(Vec3, @splat(p[1])) * self.defocus_disc_v;
}

fn degreesToRadians(degrees: u32) f64 {
    return @as(f64, @floatFromInt(degrees)) * std.math.pi / 180.0;
}
