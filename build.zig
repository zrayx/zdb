const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zdb", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const test_step = b.step("test", "Run library tests");
    var files = [_][]const u8{
        "src/main.zig",
        "src/common.zig",
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
