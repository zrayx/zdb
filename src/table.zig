const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const Compare = common.Compare;
const croc = common.allocator;
const value = @import("value.zig");
const Value = value.Value;
const column = @import("column.zig");
const Column = column.Column;

pub const Table = struct {
    name: std.ArrayList(u8),
    columns: std.ArrayList(Column),

    const Self = @This();

    pub fn init(name: []const u8) !Table {
        var table = Table{
            .name = std.ArrayList(u8).init(croc),
            .columns = std.ArrayList(Column).init(croc),
        };
        try table.name.appendSlice(name);
        return table;
    }

    pub fn rename(self: *Self, name: []const u8) !void {
        try self.name.resize(0);
        try self.name.appendSlice(name);
    }

    pub fn add_column(self: *Self, name: []const u8) !void {
        var col = try Column.init(name);
        try self.columns.append(col);
    }

    pub fn append_column(self: *Self, colname: []const u8, v: Value) !void {
        for (self.columns.items) |col, idx| {
            if (col.is_name(colname)) {
                try self.columns.items[idx].rows.append(v);
            }
        }
    }

    pub fn append_at(self: *Self, col_idx: usize, v: Value) !void {
        try self.columns.items[col_idx].rows.append(v);
    }

    pub fn compare(self: Self, other: Table) Compare {
        var i: usize = 0;
        while (i < self.columns.items.len) : (i += 1) {
            if (other.columns.items.len <= i) {
                return Compare.greater;
            }
            const v = self.columns.items[i].compare(other.columns.items[i]);
            if (v != Compare.equal) return v;
        }
        if (other.columns.items.len > i) {
            return Compare.lesser;
        }
        return Compare.equal;
    }

    test "Table.compare" {
        var table_a = try Table.fromCSV("test3");
        defer table_a.deinit();
        try table_a.rename("table_a");

        var table_b = try Table.fromCSV("test3");
        defer table_b.deinit();
        try table_b.rename("table_b");

        try testing.expectEqual(table_a.compare(table_b), Compare.equal);

        //try table_b.debug();
        table_b.columns.items[1].rows.items[1] = Value{ .float = 5 };
        //try table_b.debug();
        try testing.expectEqual(table_a.compare(table_b), Compare.lesser);
        try testing.expectEqual(table_b.compare(table_a), Compare.greater);

        var table_c = try Table.fromCSV("test3");
        defer table_c.deinit();
        try table_c.rename("table_c");
        try table_c.append_at(0, Value{ .float = 1 });

        try testing.expectEqual(table_a.compare(table_c), Compare.lesser);
        try testing.expectEqual(table_c.compare(table_a), Compare.greater);
    }

    pub fn debug(self: Self) !void {
        try self.print(std.io.getStdErr().writer());
    }

    pub fn print(self: Self, writer: anytype) !void {
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();

        // print table name
        const table_name_width = 1 + 5 + 1 + self.name.items.len + 1;
        try line.append('\n');
        try line.appendNTimes('-', table_name_width);
        try line.append('\n');
        try line.writer().print("|Table {s}|", .{self.name.items});
        try line.append('\n');

        // get the width of all columns
        var widths = std.ArrayList(usize).init(croc);
        defer widths.deinit();
        var col_total_width: usize = 1;
        for (self.columns.items) |col| {
            const col_width = try col.max_width();
            try widths.append(col_width);
            col_total_width += col_width + 1;
        }

        // print dashed line between table name and table content
        try line.appendNTimes('-', if (table_name_width > col_total_width) table_name_width else col_total_width);
        try line.append('\n');

        // print column names
        try line.append('|');
        for (self.columns.items) |col, idx| {
            try line.appendSlice(col.name.items);
            const extra_width = widths.items[idx] - col.name.items.len;
            try line.appendNTimes(' ', extra_width);
            try line.append('|');
        }
        try line.append('\n');
        try line.appendNTimes('-', col_total_width);
        try line.append('\n');
        try writer.print("{s}", .{line.items});

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
            try writer.print("{s}\n", .{line.items});
        }
        const len = line.items.len;
        try line.resize(0); // reusing the line from above
        try line.appendNTimes('-', len);
        try writer.print("{s}\n", .{line.items});
    }

    pub fn fromCSV(name: []const u8) !Table {
        const filename = try std.fmt.allocPrint(croc, "db/{s}.csv", .{name});
        defer croc.free(filename);
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var table = try Table.init(name);

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        // TODO: Remove constant size buffer
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
                    const val = try Value.parse(content);
                    try table.append_at(col_idx, val);
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

    pub fn deinit(self: Self) void {
        for (self.columns.items) |_, idx| {
            self.columns.items[idx].deinit();
        }
        self.columns.deinit();
        self.name.deinit();
    }
};

test "read csv with 1 column of floats" {
    var line = std.ArrayList(u8).init(croc);
    defer line.deinit();
    var line2 = std.ArrayList(u8).init(croc);
    defer line2.deinit();
    const tab1 = try Table.fromCSV("test1");
    defer tab1.deinit();
    try tab1.print(line.writer());
    //std.debug.print("{s}", .{line.items});
    _ = try line2.writer().write(
        \\
        \\-------------
        \\|Table test1|
        \\-------------
        \\|num|
        \\-----
        \\|1  |
        \\|2  |
        \\|3  |
        \\|4  |
        \\-----
        \\
    );
    //std.debug.print("{s}", .{line2.items});
    try testing.expectEqualStrings(line.items, line2.items);
}

test "read csv with 1 column of strings" {
    var line = std.ArrayList(u8).init(croc);
    defer line.deinit();
    var line2 = std.ArrayList(u8).init(croc);
    defer line2.deinit();
    const tab2 = try Table.fromCSV("test2");
    defer tab2.deinit();
    try tab2.print(line.writer());
    //std.debug.print("{s}", .{line.items});
    _ = try line2.writer().write(
        \\
        \\-------------
        \\|Table test2|
        \\-------------------------
        \\|text                   |
        \\-------------------------
        \\|txt1                   |
        \\|Text 2                 |
        \\|And this is text three!|
        \\-------------------------
        \\
    );
    //std.debug.print("{s}", .{line2.items});
    try testing.expectEqualStrings(line.items, line2.items);
}

test "read csv with 3 columns" {
    var line = std.ArrayList(u8).init(croc);
    defer line.deinit();
    var line2 = std.ArrayList(u8).init(croc);
    defer line2.deinit();
    const tab3 = try Table.fromCSV("test3");
    defer tab3.deinit();
    try tab3.print(line.writer());
    //std.debug.print("{s}", .{line.items});
    _ = try line2.writer().write(
        \\
        \\-------------
        \\|Table test3|
        \\--------------------
        \\|text |num|one_more|
        \\--------------------
        \\|text1|1  |1       |
        \\|text2|2  |two     |
        \\|text3|3  |你好  |
        \\--------------------
        \\
    );
    //std.debug.print("{s}", .{line2.items});
    try testing.expectEqualStrings(line.items, line2.items);
}
