const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const Compare = common.Compare;
const croc = common.allocator;

pub const Type = enum {
    float,
    string,
    empty,
};

pub const Value = union(Type) {
    float: f64,
    string: std.ArrayList(u8),
    empty,

    const Self = @This();

    pub fn parse(s: []const u8) !Value {
        if (s.len == 0) {
            return Value.empty;
        }

        const f_err = std.fmt.parseFloat(f64, s);
        if (f_err) |f| {
            return Value{ .float = f };
        } else |_| {
            var v = Value{ .string = std.ArrayList(u8).init(croc) };
            try v.string.appendSlice(s);
            return v;
        }
    }

    pub fn compare(self: Self, other: Value) Compare {
        _ = switch (self) {
            .string => |self_s| {
                _ = switch (other) {
                    .string => |other_s| return common.strcmp(self_s.items, other_s.items),
                    .float => |other_f| {
                        var other_line = std.ArrayList(u8).init(croc);
                        defer other_line.deinit();
                        other_line.writer().print("{d}", .{other_f}) catch {
                            @panic("out of memory");
                        };
                        return common.strcmp(self_s.items, other_line.items);
                    },
                    .empty => return Compare.greater,
                };
            },
            .float => |self_f| {
                _ = switch (other) {
                    .float => |other_f| return if (self_f > other_f) Compare.greater else if (self_f < other_f) Compare.lesser else Compare.equal,
                    .string => |other_s| {
                        var self_line = std.ArrayList(u8).init(croc);
                        defer self_line.deinit();
                        self_line.writer().print("{d}", .{self_f}) catch {
                            @panic("out of memory");
                        };
                        return common.strcmp(self_line.items, other_s.items);
                    },
                    .empty => return Compare.greater,
                };
            },
            .empty => {
                _ = switch (other) {
                    .empty => return Compare.equal,
                    else => return Compare.lesser,
                };
            },
        };
    }

    test "Value.compare" {
        const fa = Value{ .float = 1 };
        const fb = Value{ .float = 2 };
        var sa = Value{ .string = std.ArrayList(u8).init(croc) };
        defer sa.string.deinit();
        try sa.string.writer().print("{d}", .{1});
        var sb = Value{ .string = std.ArrayList(u8).init(croc) };
        defer sb.string.deinit();
        try sb.string.writer().print("{d}", .{2});

        // float <> float
        try testing.expectEqual(fa.compare(fb), Compare.lesser);
        try testing.expectEqual(fb.compare(fa), Compare.greater);

        // str <> float
        try testing.expectEqual(fa.compare(sa), Compare.equal);
        try testing.expectEqual(fb.compare(sa), Compare.greater);

        // str <> str
        try testing.expectEqual(sa.compare(sa), Compare.equal);
        try testing.expectEqual(sb.compare(sa), Compare.greater);
    }

    pub fn deinit(self: Self) void {
        _ = switch (self) {
            .string => |s| s.deinit(),
            else => .{},
        };
        return {};
    }
};
