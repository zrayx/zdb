const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const Compare = common.Compare;
const croc = common.allocator;
const value = @import("value.zig");
const Value = value.Value;

pub const Column = struct {
    name: std.ArrayList(u8),
    rows: std.ArrayList(Value),

    const Self = @This();

    pub fn init(name: []const u8) !Column {
        var col = Column{
            .name = std.ArrayList(u8).init(croc),
            .rows = std.ArrayList(Value).init(croc),
        };
        try col.name.appendSlice(name);
        return col;
    }

    pub fn add(self: *Self, v: Value) !void {
        try self.rows.append(v);
    }

    pub fn deleteRowAt(self: *Self, idx: usize) !void {
        if (idx >= self.rows.items.len) {
            return error.InvalidPosition;
        }
        self.rows.items[idx].deinit();
        _ = self.rows.orderedRemove(idx);
    }

    /// returns true if name identifies this column
    pub fn isName(self: Self, name: []const u8) bool {
        return std.mem.eql(u8, self.name.items, name);
    }

    /// Returns the max length of any column or the name of the column
    pub fn maxWidth(self: Self) !usize {
        var max = self.name.items.len;
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();
        for (self.rows.items) |row| {
            // Should be Value.fmt or something similar
            var len: usize = 0;
            switch (row) {
                .string => |str| len = str.items.len,
                else => {
                    _ = try row.write(line.writer());
                    len = line.items.len;
                    try line.resize(0);
                },
            }
            if (len > max) max = len;
        }
        return max;
    }

    pub fn compare(self: Self, other: Column) !Compare {
        var i: usize = 0;
        while (i < self.rows.items.len) : (i += 1) {
            if (other.rows.items.len <= i) {
                return Compare.greater;
            }
            const v = try self.rows.items[i].compare(other.rows.items[i]);
            if (v != Compare.equal) return v;
        }
        if (other.rows.items.len > i) {
            return Compare.lesser;
        }
        return Compare.equal;
    }

    pub fn deinit(self: Self) void {
        for (self.rows.items) |_, idx| {
            self.rows.items[idx].deinit();
        }
        self.rows.deinit();
        self.name.deinit();
    }
};
