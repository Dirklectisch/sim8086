const std = @import("std");
const t = @import("types.zig");

pub fn printOperationName(name: t.OperationName, w: anytype) !void {
    const tagName = @tagName(name);
    var buf: [3]u8 = undefined;
    const lowerTagName = std.ascii.lowerString(&buf, tagName);
    
    try w.print("{s}", .{lowerTagName});
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
    
    var hasRegister = false;
    
    if(operand.registers[0] != null) {
        hasRegister = true;
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[0].?));
        try w.print("{s}", .{lower});
    }

    if(operand.registers[1] != null) {
        hasRegister = true;
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[1].?));
        try w.print(" + {s}", .{lower});
    }

    if(operand.value != null) {
        if(hasRegister) {
            try w.print(" + ", .{});
        }
        try w.print("{d}", .{operand.value.?});
    }

    try w.print("]", .{});
}

pub fn printTargetOperand(operand: t.OperandTarget, w: anytype) !void {
    try w.print("; {d}", .{operand.value});
}

pub fn printOperand(operand: t.Operand, w: anytype) !void {
    switch (operand) {
        .REGISTER => try printRegisterOperand(operand.REGISTER, w),
        .IMMEDIATE => try printImmediateOperand(operand.IMMEDIATE, w),
        .ADDRESS => try printAddressOperand(operand.ADDRESS, w),
        .TARGET => try printTargetOperand(operand.TARGET, w)
    }
}

fn explicitSize(inst: t.Instruction) bool {
    if (inst.source == null) {
        return false;
    }
    
    const hasAddresDest = switch (inst.dest) {
        .ADDRESS => true,
        else => false,
    };
    
    const hasImmediateSrc = switch (inst.source.?) {
        .IMMEDIATE => true,
        else => false
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

pub fn printInstr(w: *std.Io.Writer, inst: t.Instruction) !void {
    try printOperationName(inst.name, w);
    if (explicitSize(inst)) {
        try w.print(" ", .{});
        try printSize(inst.size, w);
    }
    try w.print(" ", .{});
    try printOperand(inst.dest,  w);
    if (inst.source != null) {
        try w.print(", ", .{});
        try printOperand(inst.source.?, w);
    }
}

pub fn printInstrXs(w: *std.Io.Writer, instructions: []t.Instruction, path: []const u8) !void {
    try w.print("; {s}\n", .{path});
    try w.print("bits 16\n", .{});

    for (instructions) |i| {
        try printInstr(w, i);
        try w.print("\n", .{});
    }

    try w.flush();
}
