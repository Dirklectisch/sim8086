const std = @import("std");
const t = @import("types.zig");

pub fn printOperationName(name: t.OperationName, w: anytype) !void {
    var lower: [3]u8 = undefined; 
    _ = std.ascii.lowerString(&lower, @tagName(name));
    
    try w.print("{s}", .{lower});
}

pub fn printOperand(operand: t.Operand, w: anytype) !void {
    var lower: [2]u8 = undefined;
    _ = std.ascii.lowerString(&lower, @tagName(operand.REGISTER.target));
    
    try w.print("{s}", .{lower});
}

pub fn printInstr(inst: t.Instruction, w: anytype) !void { 
    try printOperationName(inst.name, w);
    try w.print(" ", .{});
    try printOperand(inst.destination, w);
    try w.print(", ", .{});
    try printOperand(inst.source, w);
    try w.print("\n", .{});
}

pub fn printInstrXs(instructions: []t.Instruction, path: []const u8) !void {
    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());
    const w = buf.writer();
    
    try w.print("; {s}\n", .{path});
    try w.print("bits 16\n", .{});

    for (instructions) |i| {
        try printInstr(i, w);
    }

    try buf.flush();
}
