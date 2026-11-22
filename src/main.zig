const std = @import("std");
const Object = @import("object.zig").Object;
const Camera = @import("Camera.zig");
const vec = @import("vec.zig");
const Material = @import("material.zig").Material;
const Texture = @import("texture.zig").Texture;

const Scene = struct {
    world: Object,
    camera: Camera,

    pub fn initBouncingSpheres(gpa: std.mem.Allocator, rand: std.Random) !Scene {
        var world: std.ArrayList(Object) = try .initCapacity(gpa, 1000);

        try world.append(gpa, .initStaticSphere(
            .{ 0, -1000, 0 },
            1000,
            .initLambertian(.{
                .texture = try .initChecker(
                    gpa,
                    0.32,
                    .{ 0.2, 0.3, 0.1 },
                    .{ 0.9, 0.9, 0.9 },
                ),
            }),
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
                            .initLambertian(
                                .{ .color = vec.random(rand) * vec.random(rand) },
                            ),
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
            .initStaticSphere(
                .{ 0, 1, 0 },
                1.0,
                .{ .dielectric = .{ .refraction_index = 1.5 } },
            ),
            .initStaticSphere(
                .{ -4, 1, 0 },
                1.0,
                .initLambertian(.{ .color = .{ 0.4, 0.2, 0.1 } }),
            ),
            .initStaticSphere(
                .{ 4, 1, 0 },
                1.0,
                .{
                    .metal = .{
                        .albedo = .{ 0.7, 0.6, 0.5 },
                        .fuzz = 0.0,
                    },
                },
            ),
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

    pub fn initCheckeredSpheres(gpa: std.mem.Allocator) !Scene {
        const checker: Texture = try .initChecker(
            gpa,
            0.32,
            .{ 0.2, 0.3, 0.1 },
            .{ 0.9, 0.9, 0.9 },
        );

        var objects = try gpa.alloc(Object, 2);
        objects[0] = .initStaticSphere(
            .{ 0, -10, 0 },
            10,
            .initLambertian(.{ .texture = checker }),
        );
        objects[1] = .initStaticSphere(
            .{ 0, 10, 0 },
            10,
            .initLambertian(.{ .texture = checker }),
        );

        return .{
            .world = .initList(objects),
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
                    .defocus_angle = 0,
                    .focus_distance = 10.0,
                },
            ),
        };
    }

    pub fn initEarth(gpa: std.mem.Allocator) !Scene {
        return .{
            .world = .initStaticSphere(
                .{ 0, 0, 0 },
                2,
                .initLambertian(
                    .{
                        .texture = try .loadImage(
                            gpa,
                            @embedFile("assets/earthmap.jpg"),
                        ),
                    },
                ),
            ),
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
                    .defocus_angle = 0,
                    .focus_distance = 10.0,
                },
            ),
        };
    }

    pub fn initPerlin(gpa: std.mem.Allocator, rand: std.Random) !Scene {
        const texture: Texture = .initPerlin(rand, 4);

        var objects = try gpa.alloc(Object, 2);
        objects[0] = .initStaticSphere(
            .{ 0, -1000, 0 },
            1000,
            .initLambertian(.{ .texture = texture }),
        );
        objects[1] = .initStaticSphere(
            .{ 0, 2, 0 },
            2,
            .initLambertian(.{ .texture = texture }),
        );

        return .{
            .world = .initList(objects),
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
                    .defocus_angle = 0,
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

    var iterArgs = try init.minimal.args.iterateAllocator(gpa);

    var scene_kind: enum {
        bouncing,
        checkered,
        earth,
        perlin,
    } = .bouncing;

    const map: std.StaticStringMap(@TypeOf(scene_kind)) = .initComptime(&.{
        .{ "1", .bouncing },
        .{ "2", .checkered },
        .{ "3", .earth },
        .{ "4", .perlin },
    });

    while (iterArgs.next()) |arg| {
        var name_and_value = std.mem.splitScalar(u8, arg, '=');
        const name = name_and_value.next().?;

        if (std.mem.eql(u8, name, "--scene")) {
            const value = name_and_value.next() orelse "1";

            scene_kind = map.get(value).?;
        }
    }

    const scene: Scene = switch (scene_kind) {
        .bouncing => try .initBouncingSpheres(gpa, rand),
        .checkered => try .initCheckeredSpheres(gpa),
        .earth => try .initEarth(gpa),
        .perlin => try .initPerlin(gpa, rand),
    };

    try scene.camera.render(gpa, init.io, scene.world, try std.Thread.getCpuCount());
}

test main {
    _ = @import("vec.zig");
    _ = @import("texture.zig");
}
