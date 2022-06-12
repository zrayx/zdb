const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zdb", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    // new part for examples
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("io", "examples/io.zig");

    exe.addPackagePath("table", "./src/table.zig");
    exe.addPackagePath("value", "./src/value.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run library tests");
    var files = [_][]const u8{
        "src/main.zig",
        "src/common.zig",
        "src/date.zig",
        "src/time.zig",
        "src/value.zig",
        "src/column.zig",
        "src/table.zig",
        "src/test.zig",
    };
    for (files) |file| {
        const tests = b.addTest(file);
        tests.setBuildMode(mode);
        test_step.dependOn(&tests.step);
    }
}
