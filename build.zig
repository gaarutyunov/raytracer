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

    const test_main = b.addTest(.{
        .root_module = main_mod,
    });

    const run_test = b.addRunArtifact(test_main);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test.step);
}
