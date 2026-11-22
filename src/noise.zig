const std = @import("std");
const vec = @import("vec.zig");

const point_count = 256;

pub const Noise = union(enum) {
    perlin: struct {
        randfloat: [point_count]f64 = undefined,
        perm_x: [point_count]u32 = undefined,
        perm_y: [point_count]u32 = undefined,
        perm_z: [point_count]u32 = undefined,

        pub fn generate(self: @This(), p: vec.Point3) f64 {
            var g = p - @floor(p);
            g = g * g * (@as(vec.Vec3, @splat(3)) - @as(vec.Vec3, @splat(2)) * g);
            const pi: @Vector(3, i32) = @trunc(p);
            const i, const j, const k = pi;

            var c: [2][2][2]f64 = undefined;

            inline for (0..2) |di| {
                inline for (0..2) |dj| {
                    inline for (0..2) |dk| {
                        const xi: usize = @intCast(
                            (i + @as(i32, @intCast(di))) & 255,
                        );
                        const yi: usize = @intCast(
                            (j + @as(i32, @intCast(dj))) & 255,
                        );
                        const zi: usize = @intCast(
                            (k + @as(i32, @intCast(dk))) & 255,
                        );
                        c[di][dj][dk] = self.randfloat[
                            self.perm_x[xi] ^ self.perm_y[yi] ^ self.perm_z[zi]
                        ];
                    }
                }
            }

            return trilinearInterpolate(c, g[0], g[1], g[2]);
        }
    },

    pub fn initPerlin(rand: std.Random) Noise {
        var perlin: Noise = .{
            .perlin = .{},
        };

        for (0..point_count) |i| {
            perlin.perlin.randfloat[i] = rand.float(f64);
        }

        generatePermute(rand, &perlin.perlin.perm_x);
        generatePermute(rand, &perlin.perlin.perm_y);
        generatePermute(rand, &perlin.perlin.perm_z);

        return perlin;
    }

    fn generatePermute(rand: std.Random, p: []u32) void {
        for (0..point_count) |i| {
            p[i] = @intCast(i);
        }

        permute(rand, p, point_count);
    }

    fn permute(rand: std.Random, p: []u32, n: usize) void {
        var i = n - 1;

        while (i > 0) : (i -= 1) {
            const target = rand.uintAtMost(u32, @intCast(i));
            const tmp = p[i];
            p[i] = p[target];
            p[target] = tmp;
        }
    }

    fn trilinearInterpolate(c: [2][2][2]f64, u: f64, v: f64, w: f64) f64 {
        var accum: f64 = 0.0;

        inline for (0..2) |i| {
            const ifl: f64 = @floatFromInt(i);
            inline for (0..2) |j| {
                const jfl: f64 = @floatFromInt(j);
                inline for (0..2) |k| {
                    const kfl: f64 = @floatFromInt(k);
                    accum += (ifl * u + (1 - ifl) * (1 - u)) *
                        (jfl * v + (1 - jfl) * (1 - v)) *
                        (kfl * w + (1 - kfl) * (1 - w)) *
                        c[i][j][k];
                }
            }
        }

        return accum;
    }

    pub fn generate(self: Noise, p: vec.Point3) f64 {
        return switch (self) {
            inline else => |n| n.generate(p),
        };
    }
};
