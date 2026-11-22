const std = @import("std");
const Object = @import("../object.zig").Object;
const Texture = @import("../texture.zig").Texture;
const Camera = @import("../Camera.zig");
const vec = @import("../vec.zig");
const zigimg = @import("zigimg");

const Self = @This();

world: Object,
camera: Camera,

pub fn init(gpa: std.mem.Allocator, rand: std.Random) !Self {
    var world: std.ArrayList(Object) = try .initCapacity(gpa, 1000);

    try world.append(gpa, try .init(
        .sphere,
        .{
            .static = .{
                .center = .{ 0, -1000, 0 },
                .radius = 1000,
                .material = .initLambertian(.{
                    .texture = try .initChecker(
                        gpa,
                        0.32,
                        .{ 0.2, 0.3, 0.1 },
                        .{ 0.9, 0.9, 0.9 },
                    ),
                }),
            },
        },
    ));

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
                const sphere: Object = if (choose_mat < 0.8)
                    try .init(.sphere, .{
                        .moving = .{
                            .center1 = center,
                            .center2 = vec.Vec3{ 0, 0.5 * rand.float(f64), 0 },
                            .radius = 0.2,
                            .material = .initLambertian(
                                .{ .color = vec.random(rand) * vec.random(rand) },
                            ),
                        },
                    })
                else if (choose_mat < 0.95)
                    try .init(.sphere, .{
                        .static = .{
                            .center = center,
                            .radius = 0.2,
                            .material = .{
                                .metal = .{
                                    .albedo = vec.randomRange(rand, 0.5, 1.0),
                                    .fuzz = 0.5 * rand.float(f64),
                                },
                            },
                        },
                    })
                else
                    try .init(.sphere, .{
                        .static = .{
                            .center = center,
                            .radius = 0.2,
                            .material = .{
                                .dielectric = .{
                                    .refraction_index = 1.5,
                                },
                            },
                        },
                    });

                try world.append(gpa, sphere);
            }
        }
    }

    try world.appendSlice(gpa, &.{
        try .init(.sphere, .{
            .static = .{
                .center = .{ 0, 1, 0 },
                .radius = 1.0,
                .material = .{ .dielectric = .{ .refraction_index = 1.5 } },
            },
        }),
        try .init(.sphere, .{
            .static = .{
                .center = .{ -4, 1, 0 },
                .radius = 1.0,
                .material = .initLambertian(.{ .color = .{ 0.4, 0.2, 0.1 } }),
            },
        }),
        try .init(.sphere, .{
            .static = .{
                .center = .{ 4, 1, 0 },
                .radius = 1.0,
                .material = .{
                    .metal = .{
                        .albedo = .{ 0.7, 0.6, 0.5 },
                        .fuzz = 0.0,
                    },
                },
            },
        }),
    });

    return .{
        .world = try .init(.tree, .{
            .gpa = gpa,
            .objects = world.items,
        }),
        .camera = try .init(
            50,
            100,
            .{
                .image_width = 400,
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
        ),
    };
}
