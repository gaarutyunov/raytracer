const std = @import("std");
const Hittable = @import("Hittable.zig");
const HittableList = @import("HittableList.zig").HittableList;
const Sphere = @import("Sphere.zig");
const Camera = @import("Camera.zig");

pub fn main(init: std.process.Init) !void {
    const rng: std.Random.IoSource = .{ .io = init.io };
    const rand: std.Random = rng.interface();

    const aspect_ratio: f32 = 16.0 / 9.0;
    const image_width = 400;
    const samples_per_pixel = 100;

    const camera: Camera = .init(rand, .{ 0, 0, 0 }, aspect_ratio, image_width, samples_per_pixel);

    var world: HittableList(Hittable) = try .init(init.gpa, 2);
    const hittable = &world.interface;
    defer world.deinit(init.gpa);

    try world.add(init.gpa, &Sphere.init(.{ 0, 0, -1 }, 0.5).interface);
    try world.add(init.gpa, &Sphere.init(.{ 0, -100.5, -1 }, 100).interface);

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
}
