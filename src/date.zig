const std = @import("std");
const testing = std.testing;
const common = @import("common.zig");
const croc = common.allocator;

pub const ParseDateError = error{
    InvalidCharacter,
    OutOfRange,
};

const ParseState = enum {
    day,
    month,
    year,
};

pub const Date = struct {
    day: u8,
    month: u8,
    year: u16,

    const Self = @This();

    pub fn parse(s: []const u8) ParseDateError!Date {
        var date = Date.new(0, 0, 0);
        if (s.len < "1.1.22".len or s.len > "12.12.1234".len) {
            return error.InvalidCharacter;
        }
        var state = ParseState.day;
        for (s) |char| {
            // day
            if (state == ParseState.day) {
                if (std.ascii.isDigit(char)) {
                    date.day = 10 * date.day + char - 48;
                } else if (char == '.') {
                    state = ParseState.month;
                } else {
                    return error.InvalidCharacter;
                }
            } else if (state == ParseState.month) {
                if (std.ascii.isDigit(char)) {
                    date.month = 10 * date.month + char - 48;
                } else if (char == '.') {
                    state = ParseState.year;
                } else {
                    return error.InvalidCharacter;
                }
            } else if (state == ParseState.year) {
                if (std.ascii.isDigit(char)) {
                    date.year = 10 * date.year + char - 48;
                } else {
                    return error.InvalidCharacter;
                }
            }
        }
        if (date.day < 1 or date.day > 31) {
            return error.OutOfRange;
        }
        if (date.month < 1 or date.month > 12) {
            return error.OutOfRange;
        }
        if (date.year < 100) {
            date.year += 2000;
        } else if (date.year < 1500 or date.year > 3000) {
            return error.OutOfRange;
        }
        return date;
    }

    fn writeWord(word: u8, writer: anytype) !void {
        _ = try writer.writeByte(word / 10 + 48);
        _ = try writer.writeByte(word % 10 + 48);
    }

    pub fn write(self: Self, writer: anytype) !void {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();

        try Date.writeWord(self.day, writer);
        _ = try writer.writeByte('.');
        try Date.writeWord(self.month, writer);
        _ = try writer.writeByte('.');
        try Date.writeWord(@truncate(u8, self.year / 100), writer);
        try Date.writeWord(@truncate(u8, self.year % 100), writer);
    }

    test "write" {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();

        const date1 = try Date.parse("5.12.2022");
        try date1.write(line.writer());
        try testing.expect(std.mem.eql(u8, line.items, "05.12.2022"));

        const date2 = try Date.parse("05.02.19");
        try line.resize(0); // reusing the line from above
        try date2.write(line.writer());
        try testing.expect(std.mem.eql(u8, line.items, "05.02.2019"));
    }

    pub fn new(day: u8, month: u8, year: u16) Date {
        return Date{ .day = day, .month = month, .year = year };
    }

    pub fn eql(self: Self, other: Date) bool {
        return self.day == other.day and self.month == other.month and self.year == other.year;
    }
};

test "Date.parse" {
    const date1 = try Date.parse("15.12.2022");
    const date2 = try Date.parse("16.12.2022");
    const date3 = try Date.parse("16.12.2022");
    try testing.expect(date1.eql(date2) == false);
    try testing.expect(date2.eql(date3) == true);
    const date4 = Date.parse("0.12.2022");
    try testing.expectError(ParseDateError.OutOfRange, date4);
    const date5 = Date.parse("1.1x.2022");
    try testing.expectError(ParseDateError.InvalidCharacter, date5);
}
