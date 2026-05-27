const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "wayplug",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayplug.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    lib.installHeader(b.path("include/wayplug.h"), "wayplug.h");
    b.installArtifact(lib);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wayplug.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const c_abi_smoke = b.addExecutable(.{
        .name = "wayplug-c-abi-smoke",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    c_abi_smoke.root_module.addCSourceFile(.{
        .file = b.path("tests/c_abi_smoke.c"),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-Werror" },
    });
    c_abi_smoke.root_module.addIncludePath(b.path("include"));
    c_abi_smoke.root_module.linkLibrary(lib);

    const run_c_abi_smoke = b.addRunArtifact(c_abi_smoke);

    const test_step = b.step("test", "Run unit and C ABI smoke tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_c_abi_smoke.step);
}
