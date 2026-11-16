const std = @import("std");
const Hittable = @import("Hittable.zig");
const HittableList = @import("HittableList.zig").HittableList;
const Sphere = @import("Sphere.zig");
const Camera = @import("Camera.zig");
const Lambertian = @import("Lambertian.zig");
const Metal = @import("Metal.zig");

pub fn main(init: std.process.Init) !void {
    const rng: std.Random.IoSource = .{ .io = init.io };
    const rand: std.Random = rng.interface();

    const aspect_ratio: f32 = 16.0 / 9.0;
    const image_width = 400;
    const samples_per_pixel = 100;
    const max_depth = 50;

    const camera: Camera = .init(
        rand,
        .{ 0, 0, 0 },
        aspect_ratio,
        image_width,
        samples_per_pixel,
        max_depth,
    );

    var world: HittableList(Hittable) = try .init(init.gpa, 2);
    const hittable = &world.interface;
    defer world.deinit(init.gpa);
    // left
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ -1.0, 0, -1.0 },
            0.5,
            &Metal.init(.{ 0.8, 0.8, 0.8 }, rand, 0.3).interface,
        ).interface,
    );
    // center
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 0, 0, -1.2 },
            0.5,
            &Lambertian.init(.{ 0.1, 0.2, 0.5 }, rand).interface,
        ).interface,
    );
    // right
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 1.0, 0, -1.0 },
            0.5,
            &Metal.init(.{ 0.2, 0.6, 0.2 }, rand, 1.0).interface,
        ).interface,
    );
    // ground
    try world.add(
        init.gpa,
        &Sphere.init(
            .{ 0, -100.5, -1 },
            100,
            &Lambertian.init(.{ 0.8, 0.8, 0 }, rand).interface,
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
