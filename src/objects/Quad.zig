const vec = @import("../vec.zig");
const Material = @import("../material.zig").Material;
const BoundingBox = @import("../BoundingBox.zig");
const Ray = @import("../Ray.zig");
const Interval = @import("../Interval.zig");
const Hit = @import("../Hit.zig");

const Self = @This();

pub const Options = struct {
    q: vec.Point3,
    u: vec.Vec3,
    v: vec.Vec3,
    material: Material,
};

q: vec.Point3,
u: vec.Vec3,
v: vec.Vec3,
material: Material,
bbox: BoundingBox,

pub fn init(options: Options) !Self {
    return .{
        .q = options.q,
        .u = options.u,
        .v = options.v,
        .material = options.material,
        .bbox = .fromBoxes(
            .fromPoints(options.q, options.q + options.u + options.v),
            .fromPoints(options.q + options.u, options.q + options.v),
        ),
    };
}

pub fn bounding_box(self: Self) BoundingBox {
    return self.bbox;
}

pub fn hit(self: Self, ray: Ray, ray_t: Interval) ?Hit {
    _ = self;
    _ = ray;
    _ = ray_t;
    return null;
}
