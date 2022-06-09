const std = @import("std");
const expect = std.testing.expect;

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

    fn deinit(self: Self) void {
        for (self.rows.items) |_, idx| {
            self.rows.items[idx].deinit();
        }
        self.rows.deinit();
        self.name.deinit();
    }
};

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
        // print table name
        const string = try std.fmt.allocPrint(croc, "\nTable {s}", .{self.name.items});
        defer croc.free(string);
        common.print_with_line(string);

        // print column names
        var line = std.ArrayList(u8).init(croc);
        defer line.deinit();
        for (self.columns.items) |col, idx| {
            try line.appendSlice(col.name.items);
            if (idx + 1 < self.columns.items.len) {
                try line.appendSlice(",");
            }
        }
        common.print_with_line(line.items);

        // print column contents
        var row_idx: usize = 0;
        var has_more: bool = true;
        const p = line.writer().print;
        while (has_more) : (row_idx += 1) {
            try line.resize(0); // reusing the line from above

            has_more = false;
            for (self.columns.items) |col, idx| {
                if (col.rows.items.len > row_idx + 1) {
                    has_more = true;
                }
                const row = col.rows.items[row_idx];
                switch (row) {
                    .string => |s| try p("{s}", .{s.items}),
                    .float => |d| try p("{d}", .{d}),
                    .empty => {},
                }

                if (idx + 1 < self.columns.items.len) {
                    try line.appendSlice(",");
                }
            }
            std.debug.print("{s}\n", .{line.items});
        }
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

test "split" {
    var it = std.mem.split(u8, "abc|def||ghi", "|");
    try expect(std.mem.eql(u8, it.next().?, "abc"));
    try expect(std.mem.eql(u8, it.next().?, "def"));
    try expect(std.mem.eql(u8, it.next().?, ""));
    try expect(std.mem.eql(u8, it.next().?, "ghi"));
    try expect(it.next() == null);
}

test "read csv with 1 column of floats" {
    const table = try readTableFromCSV("test1");
    defer table.deinit();
    try table.print();
    //try expect(true);
}

test "read csv with 1 column of strings" {
    const table = try readTableFromCSV("test2");
    defer table.deinit();
    try table.print();
    //try expect(true);
}

test "read csv with 3 columns" {
    const table = try readTableFromCSV("test3");
    defer table.deinit();
    try table.print();
    //try expect(true);
}

test "concat" {
    var list = std.ArrayList(u8).init(croc);
    defer list.deinit();
    try list.appendSlice("hello ");
    try list.appendSlice("world");
    try expect(std.mem.eql(u8, list.items, "hello world"));
}

test "ArrayList" {
    var list = std.ArrayList(u8).init(croc);
    defer list.deinit();
    try list.append(47);
    try list.append(11);
    //print("{d} {d}\n", .{ list.items[0], list.items[1] });
}

test "gpa" {
    var slice = try croc.alloc(i32, 2);
    defer croc.free(slice);

    slice[0] = 47;
    slice[1] = 11;
    //print("{d} {d}\n", .{ slice[0], slice[1] });
}
