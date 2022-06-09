const std = @import("std");
const expect = std.testing.expect;

const common = @import("common.zig");

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
            var v = Value{ .string = std.ArrayList(u8).init(common.allocator) };
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
            .name = std.ArrayList(u8).init(common.allocator),
            .rows = std.ArrayList(Value).init(common.allocator),
        };
        try col.name.appendSlice(name);
        return col;
    }

    fn add(self: *Self, v: Value) !void {
        try self.rows.append(v);
    }

    /// returns true if name identifies this column
    fn is_name(self: Self, name: []const u8) bool {
        return if (common.strcmp(self.name.items, name) == common.Compare.equal) true else false;
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
            .name = std.ArrayList(u8).init(common.allocator),
            .columns = std.ArrayList(Column).init(common.allocator),
        };
        try table.name.appendSlice(name);
        return table;
    }

    fn add_column(self: *Self, name: []const u8) !void {
        var col = try Column.init(name);
        try self.columns.append(col);
    }

    fn add_single(self: *Self, colname: []const u8, v: Value) !void {
        for (self.columns.items) |col, idx| {
            if (col.is_name(colname)) {
                try self.columns.items[idx].rows.append(v);
            }
        }
    }

    fn print(self: Self) !void {
        const string = try std.fmt.allocPrint(common.allocator, "\nTable {s}", .{self.name.items});
        defer common.allocator.free(string);
        common.print_with_line(string);

        for (self.columns.items) |col| {
            common.print_with_line(col.name.items);
            for (col.rows.items) |row, idx| {
                std.debug.print("row {d}: ", .{idx});
                switch (row) {
                    .string => |s| std.debug.print("{s}\n", .{s.items}),
                    .float => |d| std.debug.print("{d}\n", .{d}),
                    .empty => std.debug.print("\n", .{}),
                }
            }
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

fn readFile(name: []const u8) !Table {
    const filename = try std.fmt.allocPrint(
        common.allocator,
        "db/{s}.csv",
        .{name},
    );
    defer common.allocator.free(filename);
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var table = try Table.init(name);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    if (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |cn| {
        const colname = try std.fmt.allocPrint(
            common.allocator,
            "{s}",
            .{cn},
        );
        defer common.allocator.free(colname);
        try table.add_column(colname);
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const value = try Value.parse(line);
            try table.add_single(colname, value);
        }
    }
    return table;
}

test "read csv with 1 column of floats" {
    const table = readFile("test1") catch @panic("error reading numbers");
    defer table.deinit();
    try table.print();
    //try expect(true);
}

test "read csv with 1 column of strings" {
    const table = readFile("test2") catch @panic("error reading strings");
    defer table.deinit();
    try table.print();
    //try expect(true);
}

test "concat" {
    const a: []const u8 = "hi ";
    const b: []const u8 = "world";
    try expect(common.strcmp(a ++ b, "hi world") == common.Compare.equal);

    var list = std.ArrayList(u8).init(common.allocator);
    defer list.deinit();
    try list.appendSlice("hello ");
    try list.appendSlice("world");
    try expect(common.strcmp(list.items, "hello world") == common.Compare.equal);
}

test "ArrayList" {
    var list = std.ArrayList(u8).init(common.allocator);
    defer list.deinit();
    try list.append(47);
    try list.append(11);
    //print("{d} {d}\n", .{ list.items[0], list.items[1] });
}

test "gpa" {
    var slice = try common.allocator.alloc(i32, 2);
    defer common.allocator.free(slice);

    slice[0] = 47;
    slice[1] = 11;
    //print("{d} {d}\n", .{ slice[0], slice[1] });
}
