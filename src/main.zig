const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const croc = common.allocator;

const Type = enum {
    float,
    string,
    empty,
};

const Value = union(Type) {
    float: f64,
    string: std.ArrayList(u8),
    empty,

    const Self = @This();

    fn parse(s: []const u8) !Value {
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

    fn deinit(self: Self) void {
        _ = switch (self) {
            .string => |s| s.deinit(),
            else => .{},
        };
        return {};
    }
};

const Column = struct {
    name: std.ArrayList(u8),
    rows: std.ArrayList(Value),

    const Self = @This();

    fn init(name: []const u8) !Column {
        var col = Column{
            .name = std.ArrayList(u8).init(croc),
            .rows = std.ArrayList(Value).init(croc),
        };
        try col.name.appendSlice(name);
        return col;
    }

    fn add(self: *Self, v: Value) !void {
        try self.rows.append(v);
    }

    /// returns true if name identifies this column
    fn is_name(self: Self, name: []const u8) bool {
        return std.mem.eql(u8, self.name.items, name);
    }

    /// Returns the max length of any column or the name of the column
    fn max_width(self: Self) !usize {
        var max = self.name.items.len;
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();
        for (self.rows.items) |row| {
            // Should be Value.fmt or something similar
            var len: usize = 0;
            switch (row) {
                .string => |str| len = str.items.len,
                .float => |num| {
                    try line.writer().print("{d}", .{num});
                    len = line.items.len;
                    try line.resize(0);
                },
                .empty => len = 0,
            }
            if (len > max) max = len;
        }
        return max;
    }

    fn deinit(self: Self) void {
        for (self.rows.items) |_, idx| {
            self.rows.items[idx].deinit();
        }
        self.rows.deinit();
        self.name.deinit();
    }
};

test "Column.max_width()" {
    {
        const table = try readTableFromCSV("test1");
        defer table.deinit();
        const max_len = table.columns.items[0].max_width();
        try testing.expectEqual(max_len, 3);
    }

    {
        const table = try readTableFromCSV("test2");
        defer table.deinit();
        const max_len = table.columns.items[0].max_width();
        try testing.expectEqual(max_len, 23);
    }
}

const Table = struct {
    name: std.ArrayList(u8),
    columns: std.ArrayList(Column),

    const Self = @This();

    fn init(name: []const u8) !Table {
        var table = Table{
            .name = std.ArrayList(u8).init(croc),
            .columns = std.ArrayList(Column).init(croc),
        };
        try table.name.appendSlice(name);
        return table;
    }

    fn add_column(self: *Self, name: []const u8) !void {
        var col = try Column.init(name);
        try self.columns.append(col);
    }

    fn append_column(self: *Self, colname: []const u8, v: Value) !void {
        for (self.columns.items) |col, idx| {
            if (col.is_name(colname)) {
                try self.columns.items[idx].rows.append(v);
            }
        }
    }

    fn append_at(self: *Self, col_idx: usize, v: Value) !void {
        try self.columns.items[col_idx].rows.append(v);
    }

    fn print(self: Self) !void {
        var line = std.ArrayList(u8).init(croc);

        {
            // print table name
            const len = 1 + 5 + 1 + self.name.items.len + 1;
            try line.append('\n');
            try line.appendNTimes('-', len);
            try line.append('\n');
            try line.writer().print("|Table {s}|", .{self.name.items});
            try line.append('\n');
            std.debug.print("{s}", .{line.items});
        }
        // get the width of all columns
        var widths = std.ArrayList(usize).init(croc);
        defer widths.deinit();
        for (self.columns.items) |col| {
            try widths.append(try col.max_width());
        }

        // print column names
        try line.resize(0); // reusing the line from above
        defer line.deinit();
        try line.appendSlice("|");
        for (self.columns.items) |col, idx| {
            try line.appendSlice(col.name.items);
            const extra_width = widths.items[idx] - col.name.items.len;
            try line.appendNTimes(' ', extra_width);
            try line.appendSlice("|");
        }
        common.print_with_lines_around(line.items);

        // print column contents
        var row_idx: usize = 0;
        var has_more: bool = true;
        while (has_more) : (row_idx += 1) {
            try line.resize(0); // reusing the line from above

            try line.appendSlice("|");
            has_more = false;
            for (self.columns.items) |col, idx| {
                if (col.rows.items.len > row_idx + 1) {
                    has_more = true;
                }
                const row = col.rows.items[row_idx];
                const len_before = line.items.len;
                switch (row) {
                    .string => |s| try line.writer().print("{s}", .{s.items}),
                    .float => |d| try line.writer().print("{d}", .{d}),
                    .empty => {},
                }
                const len_after = line.items.len;

                const extra_width = widths.items[idx] - (len_after - len_before);
                try line.appendNTimes(' ', extra_width);
                try line.appendSlice("|");
                //if (idx + 1 < self.columns.items.len) {
                //try line.appendSlice(",");
                //}
            }
            std.debug.print("{s}\n", .{line.items});
        }
        const len = line.items.len;
        try line.resize(0); // reusing the line from above
        try line.appendNTimes('-', len);
        std.debug.print("{s}\n", .{line.items});
    }

    fn deinit(self: Self) void {
        for (self.columns.items) |_, idx| {
            self.columns.items[idx].deinit();
        }
        self.columns.deinit();
        self.name.deinit();
    }
};

export fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn readTableFromCSV(name: []const u8) !Table {
    const filename = try std.fmt.allocPrint(croc, "db/{s}.csv", .{name});
    defer croc.free(filename);
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var table = try Table.init(name);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [65536]u8 = undefined;
    if (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line_title| {
        // read headers
        var it_title = std.mem.split(u8, line_title, ",");
        var num_columns: usize = 0;
        while (it_title.next()) |colname| {
            try table.add_column(colname);
            num_columns += 1;
        }

        // read column contents
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var it = std.mem.split(u8, line, ",");
            var col_idx: usize = 0;
            while (it.next()) |content| {
                const value = try Value.parse(content);
                try table.append_at(col_idx, value);
                col_idx += 1;
            }
            while (col_idx < num_columns) : (col_idx += 1) {
                try table.append_at(col_idx, Value.empty);
                col_idx += 1;
            }
        }
    }
    return table;
}

test "read csv with 1 column of floats" {
    const table = try readTableFromCSV("test1");
    defer table.deinit();
    try table.print();
    //try testing.expect(true);
}

test "read csv with 1 column of strings" {
    const table = try readTableFromCSV("test2");
    defer table.deinit();
    try table.print();
    //try testing.expect(true);
}

test "read csv with 3 columns" {
    const table = try readTableFromCSV("test3");
    defer table.deinit();
    try table.print();
    //try testing.expect(true);
}
//var line = std.ArrayList(u8).init(croc);
//defer line.deinit();
//try line.resize(0); // reusing the line from above
//const p = line.writer().print;
//.float => |d| try p("{d}", .{d}),
