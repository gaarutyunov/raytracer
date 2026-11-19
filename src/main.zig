const std = @import("std");
const Hittable = @import("Hittable.zig");
const HittableList = @import("HittableList.zig");
const Sphere = @import("Sphere.zig");
const Camera = @import("Camera.zig");
const Lambertian = @import("Lambertian.zig");
const Metal = @import("Metal.zig");
const Dielectric = @import("Dieletric.zig");
const Rng = @import("Rng.zig");

pub fn main(init: std.process.Init) !void {
    var src: Rng.Default = .init(.init(42));

    const aspect_ratio: f32 = 16.0 / 9.0;
    const image_width = 400;
    const samples_per_pixel = 100;
    const max_depth = 50;

    const camera: Camera = try .init(init.gpa, src.rng(), max_depth, samples_per_pixel, .{
        .image_width = image_width,
        .aspect_ratio = aspect_ratio,
    }, .{
        .vfov = 20,
        .look_from = .{ -2, 2, 1 },
        .look_at = .{ 0, 0, -1 },
        .vup = .{ 0, 1, 0 },
    }, .{
        .defocus_angle = 10.0,
        .focus_distance = 3.4,
    });
    defer camera.deinit(init.gpa);

    var world: HittableList = try .init(init.gpa, 10);
    const hittable = &world.interface;
    defer world.deinit(init.gpa);
    // left
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ -1.0, 0, -1.0 },
            0.5,
            &Dielectric.init(src.rng(), 1.5).interface,
        ).interface,
    );
    // bubble
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ -1.0, 0, -1.0 },
            0.4,
            &Dielectric.init(src.rng(), 1.0 / 1.5).interface,
        ).interface,
    );
    // center
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 0, 0, -1.2 },
            0.5,
            &Lambertian.init(.{ 0.1, 0.2, 0.5 }, src.rng()).interface,
        ).interface,
    );
    // right
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 1.0, 0, -1.0 },
            0.5,
            &Metal.init(.{ 0.2, 0.6, 0.2 }, src.rng(), 1.0).interface,
        ).interface,
    );
    // ground
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 0, -100.5, -1 },
            100,
            &Lambertian.init(.{ 0.8, 0.8, 0 }, src.rng()).interface,
        ).interface,
    );

    const io = init.io;
    var buffer: [4096]u8 = undefined;
    var errbuffer: [256]u8 = undefined;

    const stdout = std.Io.File.stdout();
    defer stdout.close(io);
    var stdout_writer = stdout.writer(io, &buffer);
    const writer = &stdout_writer.interface;

    const stderr = std.Io.File.stderr();
    defer stderr.close(io);
    var stderr_writer = stderr.writer(io, &errbuffer);
    const logger = &stderr_writer.interface;

    try camera.render(hittable, writer, logger);
    try writer.flush();
    try logger.print("\rDone", .{});
    try logger.flush();
}

test main {
    _ = @import("vec3.zig");
    _ = @import("SimdPcg32.zig");
    _ = @import("SimdXoshiro256.zig");
}
