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
    const n = vec.cross(self.u, self.v);
    const normal = vec.unit(n);
    const d = vec.dot(normal, self.q);
    const denom = vec.dot(normal, ray.direction);
    const w = n / @as(vec.Vec3, @splat(vec.dot(n, n)));

    // parallel to the plain
    if (@abs(denom) < 1e-8) return null;

    const t = (d - vec.dot(normal, ray.origin)) / denom;
    if (!ray_t.contains(t)) return null;

    const intersection = ray.at(t);
    const planar_hitpt_vector = intersection - self.q;
    const alpha = vec.dot(w, vec.cross(planar_hitpt_vector, self.v));
    const beta = vec.dot(w, vec.cross(self.u, planar_hitpt_vector));

    var rec: Hit = .init(intersection, normal, t, ray, self.material);

    rec.u, rec.v = isInterior(alpha, beta) orelse return null;

    return rec;
}

fn isInterior(a: f64, b: f64) ?struct { f64, f64 } {
    const interval: Interval = .{ .min = 0, .max = 1 };

    if (!interval.contains(a) or !interval.contains(b)) {
        return null;
    }

    return .{ a, b };
}
