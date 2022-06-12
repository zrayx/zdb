const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const Compare = common.Compare;
const croc = common.allocator;
const Date = @import("date.zig").Date;
const Time = @import("time.zig").Time;

pub const Type = enum {
    float,
    string,
    date,
    time,
    empty,
};

pub const Value = union(Type) {
    float: f64,
    string: std.ArrayList(u8),
    date: Date,
    time: Time,
    empty,

    const Self = @This();

    pub fn parse(s: []const u8) !Value {
        if (s.len == 0) {
            return Value.empty;
        }

        if (std.fmt.parseFloat(f64, s)) |f| {
            return Value{ .float = f };
        } else |_| if (Time.parse(s)) |time| {
            return Value{ .time = time };
        } else |_| if (Date.parse(s)) |date| {
            return Value{ .date = date };
        } else |_| {
            var v = Value{ .string = std.ArrayList(u8).init(croc) };
            try v.string.appendSlice(s);
            return v;
        }
    }

    pub fn write(self: Self, writer: anytype) !void {
        _ = switch (self) {
            .string => |s| _ = try writer.write(s.items),
            .float => |f| _ = try writer.print("{d}", .{f}),
            .date => |d| try d.write(writer),
            .time => |t| try t.write(writer),
            .empty => {},
        };
    }

    test "write" {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();
        var s = std.ArrayList(u8).init(croc);
        defer s.deinit();
        _ = try s.writer().write("some string");

        const v1 = Value{ .string = s };
        try v1.write(line.writer());
        try testing.expectEqualStrings(line.items, "some string");

        try line.resize(0);
        const v2 = Value{ .float = 1 };
        try v2.write(line.writer());
        try testing.expectEqualStrings(line.items, "1");

        try line.resize(0);
        var v3: Value = undefined;
        v3 = Value.empty;
        try v3.write(line.writer());
        try testing.expectEqualStrings(line.items, "");
    }

    pub fn compare(self: Self, other: Value) !Compare {
        _ = switch (self) {
            .float => |self_f| {
                _ = switch (other) {
                    .float => |other_f| {
                        return if (self_f > other_f) Compare.greater else if (self_f < other_f) Compare.lesser else Compare.equal;
                    },
                    else => {},
                };
            },
            else => {},
        };
        var line_self = std.ArrayList(u8).init(croc);
        defer line_self.deinit();
        var line_other = std.ArrayList(u8).init(croc);
        defer line_other.deinit();

        try self.write(line_self.writer());
        try other.write(line_other.writer());
        return common.strcmp(line_self.items, line_other.items);
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
            .float => .{},
            .date => .{},
            .time => .{},
            .empty => .{},
        };
        return {};
    }
};
