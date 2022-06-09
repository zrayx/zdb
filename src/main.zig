const std = @import("std");
//const GPA = std.heap.GeneralPurposeAllocator(.{});
const testing = std.testing;

//var gpa = GPA{};
//const allocator = gpa.allocator();
const allocator = std.testing.allocator;

const Compare = enum {
    lesser,
    equal,
    greater,
};

fn strcat(s1: []const u8, s2: []const u8) !std.ArrayList(u8) {
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
    try testing.expect(strcmp(r1.items, "abc") == Compare.equal);
    try testing.expect(strcmp(r2.items, "abc") == Compare.equal);
    try testing.expect(strcmp(r3.items, "abc") == Compare.equal);
}

/// strcmp("a", "b") returns Compare.lesser
/// strcmp("a", "") returns Compare.greater
/// strcmp("", "") returns Compare.equal
fn strcmp(s1: []const u8, s2: []const u8) Compare {
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
    try testing.expect(strcmp("", "") == Compare.equal);
    try testing.expect(strcmp("abc", "") == Compare.greater);
    try testing.expect(strcmp("", "abc") == Compare.lesser);
    try testing.expect(strcmp("abc", "bca") == Compare.lesser);
    try testing.expect(strcmp("bca", "abc") == Compare.greater);
    try testing.expect(strcmp("ab", "abc") == Compare.lesser);
    try testing.expect(strcmp("abc", "ab") == Compare.greater);
}

fn print_with_line(s: []const u8) void {
    std.debug.print("{s}\n", .{s});
    for (s) |_| {
        std.debug.print("-", .{});
    }
    std.debug.print("\n", .{});
}

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
            var v = Value{ .string = std.ArrayList(u8).init(allocator) };
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
            .name = std.ArrayList(u8).init(allocator),
            .rows = std.ArrayList(Value).init(allocator),
        };
        try col.name.appendSlice(name);
        return col;
    }

    fn add(self: *Self, v: Value) !void {
        try self.rows.append(v);
    }

    /// returns true if name identifies this column
    fn is_name(self: Self, name: []const u8) bool {
        return if (strcmp(self.name.items, name) == Compare.equal) true else false;
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
            .name = std.ArrayList(u8).init(allocator),
            .columns = std.ArrayList(Column).init(allocator),
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
        const string = try std.fmt.allocPrint(allocator, "\nTable {s}", .{self.name.items});
        defer allocator.free(string);
        print_with_line(string);

        for (self.columns.items) |col| {
            print_with_line(col.name.items);
            std.debug.print("column has {d} items.\n", .{col.rows.items.len});
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
        allocator,
        "db/{s}.csv",
        .{name},
    );
    defer allocator.free(filename);
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var table = try Table.init(name);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    if (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |cn| {
        const colname = try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{cn},
        );
        defer allocator.free(colname);
        try table.add_column(colname);
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            const value = try Value.parse(line);
            try table.add_single(colname, value);
        }
    }
    return table;
}

test "read csv 1 column floats" {
    const table = readFile("test1") catch @panic("error reading numbers");
    defer table.deinit();
    try table.print();
    //try testing.expect(true);
}

test "read csv 1 column strings" {
    const table = readFile("test2") catch @panic("error reading strings");
    defer table.deinit();
    try table.print();
    //try testing.expect(true);
}

test "concat" {
    const a: []const u8 = "hi ";
    const b: []const u8 = "world";
    try testing.expect(strcmp(a ++ b, "hi world") == Compare.equal);

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.appendSlice("hello ");
    try list.appendSlice("world");
    try testing.expect(strcmp(list.items, "hello world") == Compare.equal);
}

test "ArrayList" {
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try list.append(47);
    try list.append(11);
    //print("{d} {d}\n", .{ list.items[0], list.items[1] });
}

test "gpa" {
    var slice = try allocator.alloc(i32, 2);
    defer allocator.free(slice);

    slice[0] = 47;
    slice[1] = 11;
    //print("{d} {d}\n", .{ slice[0], slice[1] });
}
