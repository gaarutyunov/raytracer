const std = @import("std");
const Object = @import("object.zig").Object;
const Camera = @import("Camera.zig");
const vec = @import("vec.zig");
const Material = @import("material.zig").Material;

const Scene = struct {
    const Self = @This();

    world: Object,
    camera: Camera,

    pub fn initSpheres(gpa: std.mem.Allocator, rand: std.Random) !Self {
        var world: std.ArrayList(Object) = try .initCapacity(gpa, 1000);

        try world.append(gpa, .initStaticSphere(
            .{ 0, -1000, 0 },
            1000,
            .{ .lambertian = .{ .albedo = .{ 0.5, 0.5, 0.5 } } },
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
                        .initMovingSphere(
                            center,
                            center + vec.Vec3{ 0, 0.5 * rand.float(f64), 0 },
                            0.2,
                            .{
                                .lambertian = .{
                                    .albedo = vec.random(rand) * vec.random(rand),
                                },
                            },
                        )
                    else if (choose_mat < 0.95)
                        .initStaticSphere(center, 0.2, .{
                            .metal = .{
                                .albedo = vec.randomRange(rand, 0.5, 1.0),
                                .fuzz = 0.5 * rand.float(f64),
                            },
                        })
                    else
                        .initStaticSphere(
                            center,
                            0.2,
                            .{
                                .dielectric = .{
                                    .refraction_index = 1.5,
                                },
                            },
                        );

                    try world.append(gpa, sphere);
                }
            }
        }

        try world.appendSlice(gpa, &.{
            .initStaticSphere(.{ 0, 1, 0 }, 1.0, .{
                .dielectric = .{ .refraction_index = 1.5 },
            }),
            .initStaticSphere(.{ -4, 1, 0 }, 1.0, .{
                .lambertian = .{ .albedo = .{ 0.4, 0.2, 0.1 } },
            }),
            .initStaticSphere(.{ 4, 1, 0 }, 1.0, .{
                .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0.0 },
            }),
        });

        return .{
            .world = try .initTree(gpa, world.items),
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
};

pub fn main(init: std.process.Init) !void {
    var src: std.Random.DefaultPrng = .init(42);
    const rand: std.Random = src.random();

    const gpa = init.arena.allocator();

    const scene: Scene = try .initSpheres(gpa, rand);

    try scene.camera.render(gpa, init.io, scene.world, 4);
}

test main {
    _ = @import("vec.zig");
}
