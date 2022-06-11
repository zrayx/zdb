const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const Compare = common.Compare;
const value = @import("value.zig");
const Value = value.Value;
const column = @import("column.zig");
const Column = column.Column;
const table = @import("table.zig");
const Table = table.Table;
const croc = common.allocator;

// Tests that are not included next to the implementation

test "Column.max_width()" {
    {
        const tab1 = try Table.fromCSV("test1");
        defer tab1.deinit();
        const max_len = tab1.columns.items[0].max_width();
        try testing.expectEqual(max_len, 3);
    }

    {
        const tab2 = try Table.fromCSV("test2");
        defer tab2.deinit();
        const max_len = tab2.columns.items[0].max_width();
        try testing.expectEqual(max_len, 23);
    }
}

test "Column.compare" {
    //const writer = std.io.getStdErr().writer();

    var table_a = try Table.fromCSV("test1");
    defer table_a.deinit();
    try table_a.rename("table_a");
    const col_a = table_a.columns.items[0];

    var table_b = try Table.fromCSV("test1");
    defer table_b.deinit();
    try table_b.rename("table_b");
    var col_b = table_b.columns.items[0];

    try testing.expectEqual(col_a.compare(col_b), Compare.equal);

    //try table_b.print(writer);
    col_b.rows.items[2] = Value{ .float = 5 };
    //try table_b.print(writer);
    try testing.expectEqual(col_a.compare(col_b), Compare.lesser);
    try testing.expectEqual(col_b.compare(col_a), Compare.greater);

    var table_c = try Table.fromCSV("test1");
    defer table_c.deinit();
    try table_c.append_at(0, Value{ .float = 1 });
    const col_c = table_c.columns.items[0];

    try testing.expectEqual(col_a.compare(col_c), Compare.lesser);
    try testing.expectEqual(col_c.compare(col_a), Compare.greater);
}
