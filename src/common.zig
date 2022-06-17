const std = @import("std");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

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

pub fn split(comptime T: type, buffer: []const T, delimiter: []const T) SplitIterator(T) {
    std.debug.assert(delimiter.len != 0);
    return .{
        .index = 0,
        .buffer = buffer,
        .delimiter = delimiter,
    };
}

pub fn SplitIterator(comptime T: type) type {
    return struct {
        buffer: []const T,
        index: ?usize,
        delimiter: []const T,
        //
        const Self = @This();
        //
        /// Returns a slice of the next field, or null if splitting is complete.
        pub fn next(self: *Self) ?[]const T {
            const start = self.index orelse return null;
            const end = if (std.mem.indexOfPos(T, self.buffer, start, self.delimiter)) |delim_start| blk: {
                self.index = delim_start + self.delimiter.len;
                break :blk delim_start;
            } else blk: {
                self.index = null;
                break :blk self.buffer.len;
            };
            return self.buffer[start..end];
        }
        //
        /// Returns a slice of the remaining bytes. Does not affect iterator state.
        pub fn rest(self: Self) []const T {
            const end = self.buffer.len;
            const start = self.index orelse end;
            return self.buffer[start..end];
        }
    };
}

pub fn csvSplit(buffer: []const u8) CsvSplitIterator() {
    return .{
        .index = 0,
        .buffer = buffer,
    };
}

pub fn CsvSplitIterator() type {
    return struct {
        buffer: []const u8,
        index: ?usize,

        const Self = @This();

        /// Returns a slice of the next field, or null if splitting is complete.
        pub fn next(self: *Self) ?[]const u8 {
            var start = self.index orelse return null;
            if (self.index.? >= self.buffer.len) return null;
            var end = self.index.?;
            if (self.buffer[start] == '"') {
                end += 1;
                while (end < self.buffer.len) : (end += 1) {
                    if (self.buffer[end] == '"') {
                        // exclude quotes in result
                        start += 1;
                        if (end + 1 < self.buffer.len) {
                            self.index = end + 1;
                            //std.debug.print("buffer[end+1]='{c}'\n", .{self.buffer[end + 1]});
                            if (self.buffer[end + 1] == ',') {
                                self.index = end + 2;
                            }
                        } else {
                            self.index = null;
                        }
                        return self.buffer[start..end];
                    }
                }
                // Did not closing quote
                self.index = null;
            } else {
                while (end < self.buffer.len) : (end += 1) {
                    if (self.buffer[end] == ',') {
                        self.index = if (end + 1 < self.buffer.len) end + 1 else null;
                        return self.buffer[start..end];
                    }
                }
                self.index = null;
            }
            return self.buffer[start..end];
        }

        /// Returns a slice of the remaining bytes. Does not affect iterator state.
        pub fn rest(self: Self) []const u8 {
            const end = self.buffer.len;
            const start = self.index orelse end;
            return self.buffer[start..end];
        }
    };
}

test "csvSplit 1" {
    const text = "\"robust\", optimal,\" re,usable\", maintainable, ";
    var iter = csvSplit(text);
    try expectEqualSlices(u8, iter.next().?, "robust");
    try expectEqualSlices(u8, iter.next().?, " optimal");
    try expectEqualSlices(u8, iter.next().?, " re,usable");
    try expectEqualSlices(u8, iter.next().?, " maintainable");
    try expectEqualSlices(u8, iter.next().?, " ");
    try expect(iter.next() == null);
}

test "csvSplit 2" {
    const text = "end,comma,";
    var iter = csvSplit(text);
    try expectEqualSlices(u8, iter.next().?, "end");
    try expectEqualSlices(u8, iter.next().?, "comma");
    try expect(iter.next() == null);
}

test "csvSplit 3" {
    const text = "no,end,\"com,ma\"";
    var iter = csvSplit(text);
    try expectEqualSlices(u8, iter.next().?, "no");
    try expectEqualSlices(u8, iter.next().?, "end");
    try expectEqualSlices(u8, iter.next().?, "com,ma");
    try expect(iter.next() == null);
}

test "csvSplit 4" {
    const text = "empty,,commas";
    var iter = csvSplit(text);
    try expectEqualSlices(u8, iter.next().?, "empty");
    try expectEqualSlices(u8, iter.next().?, "");
    try expectEqualSlices(u8, iter.next().?, "commas");
    try expect(iter.next() == null);
}
