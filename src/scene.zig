const std = @import("std");
const Object = @import("object.zig").Object;
const Texture = @import("texture.zig").Texture;
const Camera = @import("Camera.zig");
const vec = @import("vec.zig");
const zigimg = @import("zigimg");

pub const SceneKind = enum(u32) {
    all,
    bouncing,
    checkered,
    earth,
    perlin,
};

pub const Scene = union(SceneKind) {
    all: struct {
        scenes: []Scene,
    },
    bouncing: struct {
        world: Object,
        camera: Camera,

        pub fn init(gpa: std.mem.Allocator, rand: std.Random) !Scene {
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
                .bouncing = .{
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
                },
            };
        }
    },
    checkered: struct {
        world: Object,
        camera: Camera,

        pub fn init(gpa: std.mem.Allocator, _: std.Random) !Scene {
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
                .checkered = .{
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
                },
            };
        }
    },
    earth: struct {
        world: Object,
        camera: Camera,

        pub fn init(gpa: std.mem.Allocator, _: std.Random) !Scene {
            return .{
                .earth = .{
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
                },
            };
        }
    },
    perlin: struct {
        world: Object,
        camera: Camera,

        pub fn init(gpa: std.mem.Allocator, rand: std.Random) !Scene {
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
                .perlin = .{
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
                },
            };
        }
    },

    pub fn init(gpa: std.mem.Allocator, rand: std.Random, kind: SceneKind) !Scene {
        return switch (kind) {
            .all => {
                const n_scenes =
                    @typeInfo(SceneKind).@"enum".field_names.len - 1;

                var scenes: [n_scenes]Scene = undefined;

                inline for (0..n_scenes) |s| {
                    scenes[s] = try .init(gpa, rand, @fromBackingInt(@as(u32, @intCast(s)) + 1));
                }

                return .{
                    .all = .{
                        .scenes = &scenes,
                    },
                };
            },
            inline else => |k| @FieldType(Scene, @tagName(k)).init(gpa, rand),
        };
    }

    pub fn render(
        self: Scene,
        gpa: std.mem.Allocator,
        io: std.Io,
        pr: std.Progress.Node,
        concurrency: usize,
    ) !void {
        switch (self) {
            .all => |all| {
                const pr1 = pr.start("scenes", all.scenes.len);
                defer pr1.end();

                for (all.scenes) |scene| {
                    defer pr1.completeOne();
                    try scene.render(gpa, io, pr1, concurrency);
                }
            },
            inline else => |scene, tag| {
                const pr1 = pr.start(@tagName(tag), scene.camera.image_height);
                defer pr1.end();

                var buffer = try gpa.alloc(u8, 4 * 1024 * 1024);
                _ = &buffer;

                var writer: std.Io.Writer = .fixed(buffer);
                _ = &writer;

                const written = try scene.camera.render(
                    gpa,
                    io,
                    pr1,
                    &writer,
                    scene.world,
                    concurrency,
                );

                const image: zigimg.Image = try .fromMemory(gpa, buffer[0..written]);

                var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
                try image.writeToFilePath(gpa, io, @tagName(tag) ++ ".png", &write_buffer, .{
                    .png = .{},
                });
            },
        }
    }
};
