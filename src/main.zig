const std = @import("std");
const Object = @import("Object.zig").Object;
const Camera = @import("Camera.zig");
const vec = @import("vec3.zig");
const Material = @import("Material.zig").Material;

pub fn main(init: std.process.Init) !void {
    const src: std.Random.IoSource = .{ .io = init.io };
    const rand: std.Random = src.interface();

    const gpa = init.arena.allocator();

    var world: std.ArrayList(Object) = try .initCapacity(gpa, 1000);

    try world.append(gpa, .{
        .sphere = .{
            .center = .{ 0, -1000, 0 },
            .radius = 1000,
            .material = .{ .lambertian = .{ .albedo = .{ 0.5, 0.5, 0.5 } } },
        },
    });

    for (0..22) |i| {
        const a: f64 = @floatFromInt(@as(i64, @intCast(i)) - 11);
        for (0..22) |j| {
            const b: f64 = @floatFromInt(@as(i64, @intCast(j)) - 11);
            const choose_mat = rand.float(f64);
            const center: vec.Point3 = .{
                a + 0.9 * rand.float(f64),
                0.2,
                b + 0.9 * rand.float(f64),
            };

            if (vec.length(center - vec.Point3{ 4, 0.2, 0 }) > 0.9) {
                try world.append(gpa, .{
                    .sphere = .{
                        .radius = 0.2,
                        .center = center,
                        .material = if (choose_mat < 0.8)
                            .{
                                .lambertian = .{
                                    .albedo = vec.random(rand) * vec.random(rand),
                                },
                            }
                        else if (choose_mat < 0.95)
                            .{
                                .metal = .{
                                    .albedo = vec.randomRange(rand, 0.5, 1.0),
                                    .fuzz = 0.5 * rand.float(f64),
                                },
                            }
                        else
                            .{
                                .dielectric = .{
                                    .refraction_index = 1.5,
                                },
                            },
                    },
                });
            }
        }
    }

    try world.appendSlice(gpa, &.{
        .{
            .sphere = .{
                .center = .{ 0, 1, 0 },
                .radius = 1.0,
                .material = .{
                    .dielectric = .{ .refraction_index = 1.5 },
                },
            },
        },
        .{
            .sphere = .{
                .center = .{ -4, 1, 0 },
                .radius = 1.0,
                .material = .{
                    .lambertian = .{ .albedo = .{ 0.4, 0.2, 0.1 } },
                },
            },
        },
        .{
            .sphere = .{
                .center = .{ 4, 1, 0 },
                .radius = 1.0,
                .material = .{
                    .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0.0 },
                },
            },
        },
    });

    const camera: Camera = try .init(
        50,
        500,
        .{
            .image_width = 1200,
            .aspect_ratio = 16.0 / 9.0,
        },
        .{
            .vfov = 20,
            .look_from = .{ 13, 2, 3 },
            .look_at = .{ 0, 0, 0 },
            .vup = .{ 0, 1, 0 },
        },
        .{
            .defocus_angle = 0.6,
            .focus_distance = 10.0,
        },
    );

    try camera.render(gpa, init.io, world.items, 4);
}

test main {
    _ = @import("vec3.zig");
}
