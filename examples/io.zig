const std = @import("std");
const testing = std.testing;
const Table = @import("table").Table;
const Value = @import("value").Value;

fn streq(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}

// need to select inputs
// * manual input
// * automated input for testing
//
// commands
// --------
// new table io
// set table io
// drop table io
// rename column name new_name
// add row The answer, 42
pub fn main() !void {
    var t1 = try Table.init("io");
    defer t1.deinit();

    try parse(&t1, "new col date");
    try parse(&t1, "new col time");
    try parse(&t1, "new col name");
    try parse(&t1, "new col value");

    try parse(&t1, "append date 1.1.1900");
    try parse(&t1, "append time 4:20");
    try parse(&t1, "append name Love");
    try parse(&t1, "append value The answer");

    try parse(&t1, "append date 31.4.2099");
    try parse(&t1, "append time 0:00");
    try parse(&t1, "append name The answer");
    try parse(&t1, "append value 42");

    try t1.print(std.io.getStdOut().writer());
    try t1.save();
}

fn parse(table: *Table, input: []const u8) !void {
    var it = std.mem.split(u8, input, " ");
    const Args = enum {
        new,
        new_col,
        set,
        add,
        append,
        none,
    };
    var command = Args.none;
    var idx: usize = 0;
    while (it.next()) |arg| : (idx += 1) {
        if (idx == 0) {
            if (streq(arg, "new")) {
                command = Args.new;
            } else if (streq(arg, "append")) {
                command = Args.append;
            } else {
                std.debug.panic("unknown command {s}", .{input});
            }
        } else if (idx == 1) {
            if (command == Args.new and streq(arg, "col")) {
                command = Args.new_col;
            } else if (command == Args.append) {
                const colname = arg;
                const content = it.rest();
                try table.append_column(colname, try Value.parse(content));
            } else {
                std.debug.panic("unknown command {s}", .{input});
            }
        } else if (idx == 2) {
            if (command == Args.new_col) {
                try table.add_column(arg);
            }
        }
    }
}
