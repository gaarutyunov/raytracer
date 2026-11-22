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
    const texture: Texture = .initPerlin(rand, 4);

    var objects = try gpa.alloc(Object, 2);
    objects[0] = try .init(.sphere, .{
        .static = .{
            .center = .{ 0, -1000, 0 },
            .radius = 1000,
            .material = .initLambertian(.{ .texture = texture }),
        },
    });
    objects[1] = try .init(.sphere, .{
        .static = .{
            .center = .{ 0, 2, 0 },
            .radius = 2,
            .material = .initLambertian(.{ .texture = texture }),
        },
    });

    return .{
        .world = try .init(.list, .{ .objects = objects }),
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
            .{},
        ),
    };
}
