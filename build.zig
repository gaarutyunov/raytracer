const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const main_exe = b.addExecutable(.{
        .name = "rtx",
        .root_module = main_mod,
    });
    b.installArtifact(main_exe);

    const run_exe = b.addRunArtifact(main_exe);

    const run_step = b.step("run", "Run rtx");
    run_step.dependOn(&run_exe.step);

    // Benchmarks are only meaningful optimized, so ignore -Doptimize here.
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = bench_mod,
    });
    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run RNG benchmarks (ReleaseFast)");
    bench_step.dependOn(&run_bench.step);

    const test_main = b.addTest(.{
        .root_module = main_mod,
    });

    const run_test = b.addRunArtifact(test_main);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
