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

    pub fn clone(self: Self) !Value {
        var v: Value = undefined;
        _ = switch (self) {
            .float => v = Value{ .float = self.float },
            .string => {
                v = Value{ .string = std.ArrayList(u8).init(croc) };
                try v.string.appendSlice(self.string.items);
            },
            .date => v = Value{ .date = try self.date.clone() },
            .time => v = Value{ .time = try self.time.clone() },
            .empty => v = Value.empty,
        };
        return v;
    }

    test "clone" {
        const v = Value{ .float = 3.1 };
        const w = try v.clone();
        _ = w;
    }

    pub fn writeString(s: []const u8, writer: anytype) !void {
        if (std.mem.indexOfScalar(u8, s, ',')) |_| {
            _ = try writer.write("\"");
            _ = try writer.write(s);
            _ = try writer.write("\"");
        } else {
            _ = try writer.write(s);
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

    pub fn writeQuoted(self: Self, writer: anytype) !void {
        _ = switch (self) {
            .string => |s| try writeString(s.items, writer),
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

        try s.resize(0);
        try line.resize(0);
        _ = try s.writer().write("some,string");
        const v11 = Value{ .string = s };
        try v11.write(line.writer());
        try testing.expectEqualStrings(line.items, "some,string");

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

    test "writeQuoted" {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();
        var s = std.ArrayList(u8).init(croc);
        defer s.deinit();
        _ = try s.writer().write("some string");

        const v1 = Value{ .string = s };
        try v1.writeQuoted(line.writer());
        try testing.expectEqualStrings(line.items, "some string");

        try s.resize(0);
        try line.resize(0);
        _ = try s.writer().write("some,string");
        const v11 = Value{ .string = s };
        try v11.writeQuoted(line.writer());
        try testing.expectEqualStrings(line.items, "\"some,string\"");

        try line.resize(0);
        const v2 = Value{ .float = 1 };
        try v2.writeQuoted(line.writer());
        try testing.expectEqualStrings(line.items, "1");

        try line.resize(0);
        var v3: Value = undefined;
        v3 = Value.empty;
        try v3.writeQuoted(line.writer());
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
