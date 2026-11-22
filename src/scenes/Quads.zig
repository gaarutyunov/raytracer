const std = @import("std");
const Object = @import("../object.zig").Object;
const Texture = @import("../texture.zig").Texture;
const Material = @import("../material.zig").Material;
const Camera = @import("../Camera.zig");
const vec = @import("../vec.zig");
const zigimg = @import("zigimg");

const Self = @This();

world: Object,
camera: Camera,

pub fn init(gpa: std.mem.Allocator, _: std.Random) !Self {
    var list: std.ArrayList(Object) = try .initCapacity(gpa, 5);

    // Materials
    const left_red: Material = .initLambertian(.{ .color = .{ 1.0, 0.2, 0.2 } });
    const back_green: Material = .initLambertian(.{ .color = .{ 0.2, 1.0, 0.2 } });
    const right_blue: Material = .initLambertian(.{ .color = .{ 0.2, 0.2, 1.0 } });
    const upper_orange: Material = .initLambertian(.{ .color = .{ 1.0, 0.5, 0.0 } });
    const lower_teal: Material = .initLambertian(.{ .color = .{ 0.2, 0.8, 0.8 } });

    // Quads
    try list.appendSlice(gpa, &.{
        try .init(.quad, .{
            .q = .{ -3, -2, 5 },
            .u = .{ 0, 0, -4 },
            .v = .{ 0, 4, 0 },
            .material = left_red,
        }),
        try .init(.quad, .{
            .q = .{ -2, -2, 0 },
            .u = .{ 4, 0, 0 },
            .v = .{ 0, 4, 0 },
            .material = back_green,
        }),
        try .init(.quad, .{
            .q = .{ 3, -2, 1 },
            .u = .{ 0, 0, 4 },
            .v = .{ 0, 4, 0 },
            .material = right_blue,
        }),
        try .init(.quad, .{
            .q = .{ -2, 3, 1 },
            .u = .{ 4, 0, 0 },
            .v = .{ 0, 0, 4 },
            .material = upper_orange,
        }),
        try .init(.quad, .{
            .q = .{ -2, -3, 5 },
            .u = .{ 4, 0, 0 },
            .v = .{ 0, 0, -4 },
            .material = lower_teal,
        }),
    });

    return .{
        .world = try .init(.list, .{ .objects = list.items }),
        .camera = try .init(
            50,
            100,
            .{
                .aspect_ratio = 1.0,
                .image_width = 400,
            },
            .{
                .vfov = 80,
                .look_from = .{ 0, 0, 9 },
                .look_at = .{ 0, 0, 0 },
                .vup = .{ 0, 1, 0 },
            },
            .{},
        ),
    };
}
