const std = @import("std");
const Table = @import("table").Table;
const Value = @import("value").Value;

pub fn main() !void {
    var t1 = try Table.init("io");
    try t1.add_column("name");
    try t1.append_column("name", try Value.parse("Hello world!"));
    try t1.append_column("name", try Value.parse("1.2e1"));
    try t1.print(std.io.getStdErr().writer());
    try t1.write();
}
