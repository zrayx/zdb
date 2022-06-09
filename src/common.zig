const std = @import("std");
const expect = std.testing.expect;

//const GPA = std.heap.GeneralPurposeAllocator(.{});
//var gpa = GPA{};
//const allocator = gpa.allocator();

pub const allocator = std.testing.allocator;

pub const Compare = enum {
    lesser,
    equal,
    greater,
};

pub fn strcat(s1: []const u8, s2: []const u8) !std.ArrayList(u8) {
    var s = std.ArrayList(u8).init(allocator);
    try s.appendSlice(s1);
    try s.appendSlice(s2);
    return s;
}

test "strcat" {
    var r1 = try strcat("abc", "");
    defer r1.deinit();
    var r2 = try strcat("", "abc");
    defer r2.deinit();
    var r3 = try strcat("a", "bc");
    defer r3.deinit();
    try expect(strcmp(r1.items, "abc") == Compare.equal);
    try expect(strcmp(r2.items, "abc") == Compare.equal);
    try expect(strcmp(r3.items, "abc") == Compare.equal);
}

/// strcmp("a", "b") returns Compare.lesser
/// strcmp("a", "") returns Compare.greater
/// strcmp("", "") returns Compare.equal
pub fn strcmp(s1: []const u8, s2: []const u8) Compare {
    if (s1.len == 0) {
        if (s2.len == 0) {
            return Compare.equal;
        }
        return Compare.lesser;
    }
    if (s2.len == 0) {
        return Compare.greater;
    }

    var i: usize = 0;
    while (i < s1.len and i < s2.len) : (i += 1) {
        if (s1[i] > s2[i]) return Compare.greater;
        if (s1[i] < s2[i]) return Compare.lesser;
    }

    if (s1.len > s2.len) return Compare.greater;
    if (s1.len < s2.len) return Compare.lesser;

    return Compare.equal;
}

test "strcmp" {
    try expect(strcmp("", "") == Compare.equal);
    try expect(strcmp("abc", "") == Compare.greater);
    try expect(strcmp("", "abc") == Compare.lesser);
    try expect(strcmp("abc", "bca") == Compare.lesser);
    try expect(strcmp("bca", "abc") == Compare.greater);
    try expect(strcmp("ab", "abc") == Compare.lesser);
    try expect(strcmp("abc", "ab") == Compare.greater);
}

pub fn print_with_line(s: []const u8) void {
    std.debug.print("{s}\n", .{s});
    for (s) |_| {
        std.debug.print("-", .{});
    }
    std.debug.print("\n", .{});
}
