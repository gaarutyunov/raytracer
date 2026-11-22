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
    bouncing: @import("scenes/Bouncing.zig"),
    checkered: @import("scenes/Checkered.zig"),
    earth: @import("scenes/Earth.zig"),
    perlin: @import("scenes/Perlin.zig"),

    pub fn init(gpa: std.mem.Allocator, rand: std.Random, kind: SceneKind) !Scene {
        return switch (kind) {
            .all => {
                const n_scenes =
                    @typeInfo(SceneKind).@"enum".field_names.len - 1;

                var scenes: []Scene = try gpa.alloc(Scene, n_scenes);

                inline for (0..n_scenes) |s| {
                    scenes[s] = try .init(gpa, rand, @fromBackingInt(@as(u32, @intCast(s)) + 1));
                }

                return .{
                    .all = .{
                        .scenes = scenes,
                    },
                };
            },
            inline else => |k| @unionInit(
                Scene,
                @tagName(k),
                try @FieldType(Scene, @tagName(k)).init(gpa, rand),
            ),
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
