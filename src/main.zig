const std = @import("std");
const Object = @import("object.zig").Object;
const Camera = @import("Camera.zig");
const vec = @import("vec.zig");
const Material = @import("material.zig").Material;
const Texture = @import("texture.zig").Texture;
const scene = @import("scene.zig");
const Scene = scene.Scene;
const SceneKind = scene.SceneKind;

pub fn main(init: std.process.Init) !void {
    var src: std.Random.DefaultPrng = .init(42);
    const rand: std.Random = src.random();

    const gpa = init.arena.allocator();

    var iterArgs = try init.minimal.args.iterateAllocator(gpa);

    var scene_kind: SceneKind = .all;

    while (iterArgs.next()) |arg| {
        var name_and_value = std.mem.splitScalar(u8, arg, '=');
        const name = name_and_value.next().?;

        if (std.mem.eql(u8, name, "--scene")) {
            const value = name_and_value.next() orelse "1";

            const value_int = try std.fmt.parseUnsigned(u32, value, 10);

            scene_kind = @fromBackingInt(value_int);
        }
    }

    const s: Scene = try .init(gpa, rand, scene_kind);

    try s.render(gpa, init.io, try std.Thread.getCpuCount());
}

test main {
    _ = @import("vec.zig");
    _ = @import("texture.zig");
    _ = @import("noise.zig");
}
