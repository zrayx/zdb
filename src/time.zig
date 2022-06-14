const std = @import("std");
const testing = std.testing;
const common = @import("common.zig");
const croc = common.allocator;

pub const ParseTimeError = error{
    InvalidCharacter,
    OutOfRange,
};

const ParseState = enum {
    hour,
    minute,
};

pub const Time = struct {
    hour: u8,
    minute: u8,

    const Self = @This();

    pub fn parse(s: []const u8) ParseTimeError!Time {
        var time = Time.new(0, 0);
        if (s.len < "1.1".len or s.len > "12.12".len) {
            return error.InvalidCharacter;
        }
        var state = ParseState.hour;
        for (s) |char| {
            // hour
            if (state == ParseState.hour) {
                if (std.ascii.isDigit(char)) {
                    time.hour = 10 * time.hour + char - 48;
                } else if (char == ':') {
                    state = ParseState.minute;
                } else {
                    return error.InvalidCharacter;
                }
            } else if (state == ParseState.minute) {
                if (std.ascii.isDigit(char)) {
                    time.minute = 10 * time.minute + char - 48;
                } else {
                    return error.InvalidCharacter;
                }
            }
        }
        if (time.hour > 23) {
            return error.OutOfRange;
        }
        if (time.minute > 59) {
            return error.OutOfRange;
        }
        return time;
    }

    pub fn clone(self: Self) !Time {
        return Time{ .hour = self.hour, .minute = self.minute };
    }

    fn writeWord(word: u8, writer: anytype) !void {
        _ = try writer.writeByte(word / 10 + 48);
        _ = try writer.writeByte(word % 10 + 48);
    }

    pub fn write(self: Self, writer: anytype) !void {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();

        try Time.writeWord(self.hour, writer);
        _ = try writer.writeByte(':');
        try Time.writeWord(self.minute, writer);
    }

    test "write" {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();

        const time1 = try Time.parse("5:12");
        try time1.write(line.writer());
        try testing.expect(std.mem.eql(u8, line.items, "05:12"));

        const time2 = try Time.parse("05:02");
        try line.resize(0); // reusing the line from above
        try time2.write(line.writer());
        try testing.expect(std.mem.eql(u8, line.items, "05:02"));
    }

    pub fn new(hour: u8, minute: u8) Time {
        return Time{ .hour = hour, .minute = minute };
    }

    pub fn eql(self: Self, other: Time) bool {
        return self.hour == other.hour and self.minute == other.minute;
    }
};

test "Time.parse" {
    const time1 = try Time.parse("5:12");
    const time2 = try Time.parse("16:12");
    const time3 = try Time.parse("16:12");
    try testing.expect(time1.eql(time2) == false);
    try testing.expect(time2.eql(time3) == true);
    const time4 = Time.parse("24:12");
    try testing.expectError(ParseTimeError.OutOfRange, time4);
    const time5 = Time.parse("1.1x");
    try testing.expectError(ParseTimeError.InvalidCharacter, time5);
}
