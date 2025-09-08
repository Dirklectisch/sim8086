const std = @import("std");
const t = @import("types.zig");

pub fn printOperationName(name: t.OperationName, w: anytype) !void {
    var lower: [3]u8 = undefined; 
    _ = std.ascii.lowerString(&lower, @tagName(name));
    
    try w.print("{s}", .{lower});
}

pub fn printRegisterOperand(operand: t.OperandRegister, w: anytype) !void {
    var lower: [2]u8 = undefined;
    _ = std.ascii.lowerString(&lower, @tagName(operand.target));
    
    try w.print("{s}", .{lower});
}

pub fn printImmediateOperand(operand: t.OperandImmediate, w: anytype) !void {
    try w.print("{d}", .{operand.value});
}

pub fn printAddressOperand(operand: t.OperandAddress, w: anytype) !void {
    try w.print("[", .{});
    
    if(operand.registers[0] != null) {
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[0].?));
        try w.print("{s}", .{lower});
    }

    if(operand.registers[1] != null) {
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[1].?));
        try w.print(" + {s}", .{lower});
    }

    if(operand.value != null) {
        try w.print(" + {d}", .{operand.value.?});
    }

    try w.print("]", .{});
}

pub fn printOperand(operand: t.Operand, w: anytype) !void {
    switch (operand) {
        .REGISTER => try printRegisterOperand(operand.REGISTER, w),
        .IMMEDIATE => try printImmediateOperand(operand.IMMEDIATE, w),
        .ADDRESS => try printAddressOperand(operand.ADDRESS, w),
    }
}

fn explicitSize(inst: t.Instruction) bool {
    const hasAddresDest = switch (inst.dest) {
        .ADDRESS => true,
        .IMMEDIATE => false,
        .REGISTER => false
    };
    
    const hasImmediateSrc = switch (inst.source) {
        .ADDRESS =>  false,
        .IMMEDIATE => true,
        .REGISTER => false,
    };
    
    return hasAddresDest and hasImmediateSrc;
}


pub fn printSize(size: t.Size, w: anytype) !void {
    const str = switch (size) {
        t.Size.BYTE => "byte",
        t.Size.WORD => "word",
        t.Size.UNKNOWN => "",
    };

    try w.print("{s}", .{str});
} 

pub fn printInstr(inst: t.Instruction, w: anytype) !void {
    try printOperationName(inst.name, w);
    if (explicitSize(inst)) {
        try w.print(" ", .{});
        try printSize(inst.size, w);
    }
    try w.print(" ", .{});
    try printOperand(inst.dest,  w);
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
