const std = @import("std");
const vec = @import("vec.zig");

const point_count = 256;

pub const Noise = union(enum) {
    perlin: struct {
        randvec: [point_count]vec.Vec3 = undefined,
        perm: [point_count * 3]i64 = blk: {
            var perm: [point_count * 3]i64 = undefined;
            for (0..point_count) |i| {
                perm[i * 3 ..][0] = @intCast(i);
                perm[i * 3 ..][1] = @intCast(i);
                perm[i * 3 ..][2] = @intCast(i);
            }

            break :blk perm;
        },

        pub fn generate(self: @This(), p: vec.Point3) f64 {
            const ijk = @floor(p);
            const uvw = p - ijk;

            var accum: f64 = 0.0;
            const uvw_h = blk: {
                const v2: vec.Vec3 = @splat(2);
                const v3: vec.Vec3 = @splat(3);
                break :blk uvw * uvw * (v3 - v2 * uvw);
            };

            inline for (0..2) |i| {
                inline for (0..2) |j| {
                    inline for (0..2) |k| {
                        const dijk: vec.Vec3 = .{
                            @floatFromInt(i),
                            @floatFromInt(j),
                            @floatFromInt(k),
                        };

                        const a = blk: {
                            const v1: vec.Vec3 = @splat(1);
                            break :blk @reduce(
                                .Mul,
                                uvw_h * dijk + (v1 - dijk) * (v1 - uvw_h),
                            );
                        };

                        const weight: vec.Vec3 = uvw - dijk;

                        const randvec = blk: {
                            const idx: @Vector(3, usize) = blk1: {
                                var v: @Vector(3, i64) = @trunc(ijk + dijk);
                                v &= @as(vec.Vec3, @splat(255));

                                break :blk1 @intCast(v);
                            };

                            var rand_idx: i64 = 0;

                            inline for (0..3) |pi| {
                                rand_idx ^= self.perm[idx[pi] * 3 + pi];
                            }

                            break :blk self.randvec[@intCast(rand_idx)];
                        };

                        accum += a * vec.dot(weight, randvec);
                    }
                }
            }

            return accum;
        }

        fn permute(self: *@This(), rand: std.Random) void {
            @setEvalBranchQuota(point_count * 3 * 3);
            comptime var i = point_count - 1;

            inline while (i > 0) : (i -= 1) {
                inline for (0..3) |j| {
                    const tmp = self.perm[i * 3 + j];
                    const target = rand.uintAtMost(usize, i);
                    self.perm[i * 3 + j] = self.perm[target * 3 + j];
                    self.perm[target * 3 + j] = tmp;
                }
            }
        }
    },

    pub fn initPerlin(rand: std.Random) Noise {
        var perlin: Noise = .{
            .perlin = .{},
        };

        for (0..point_count) |i| {
            perlin.perlin.randvec[i] = vec.unit(vec.randomRange(rand, -1, 1));
        }

        perlin.perlin.permute(rand);

        return perlin;
    }

    pub fn generate(self: Noise, p: vec.Point3) f64 {
        return switch (self) {
            inline else => |n| n.generate(p),
        };
    }

    pub fn turbulence(self: Noise, p: vec.Point3, comptime depth: usize) f64 {
        var accum: f64 = 0.0;
        var temp_p = p;
        var weight: f64 = 1.0;

        inline for (0..depth) |_| {
            accum += weight * self.generate(temp_p);
            weight *= 0.5;
            temp_p *= @as(vec.Vec3, @splat(2));
        }

        return @abs(accum);
    }
};

test "perlin" {
    var src: std.Random.DefaultPrng = .init(std.testing.random_seed);
    const rand = src.random();
    const noise: Noise = .initPerlin(rand);

    const v = noise.generate(.{ 0, -4, 1 });
    try std.testing.expectEqual(true, v == 0);
}
