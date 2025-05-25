const std = @import("std");

pub fn printInstruct() !void {
    try std.io.getStdOut().writer();
}
