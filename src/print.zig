const std = @import("std");
const t = @import("types.zig");

pub fn printOperationName(name: t.OperationName, w: anytype) !void {
    try w.print("{s}", .{@tagName(name)});
}

pub fn printOperand(operand: t.Operand, w: anytype) !void {
    try w.print("{s}", .{@tagName(operand.REGISTER.target)});
}

pub fn printInstr(inst: t.Instruction, w: anytype) !void { 
    try printOperationName(inst.name, w);
    try w.print(" ", .{});
    try printOperand(inst.destination, w);
    try w.print(", ", .{});
    try printOperand(inst.source, w);
    try w.print("\n", .{});
}

pub fn printInstrXs(instructions: []t.Instruction) !void {
    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());
    const w = buf.writer();

    for (instructions) |i| {
        try printInstr(i, w);
    }

    try buf.flush();
}

