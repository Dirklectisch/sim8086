const std = @import("std");
const t = @import("types.zig");

// Global standard out buffer, don't forget to flush!
var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout_writer_ptr  = &stdout_writer.interface;

pub fn print(comptime fmt: []const u8, args: anytype) void {
    stdout_writer_ptr.print(fmt, args) catch |err| {
        std.log.err("{t}: Failed to print to stdout", .{ err });
    };
}

pub fn flush() void {
    stdout_writer_ptr.flush() catch |err| {
        std.log.err("{t}: Failed to flush stdout buffer", .{err});
    };
}

pub fn formatRegisterName(reg: t.RegisterName) [2]u8 {
    var lower: [2]u8 = undefined;
    _ = std.ascii.lowerString(&lower, @tagName(reg));
    return lower;
}

pub fn printOperationName(name: t.OperationName) void {
    const tagName = @tagName(name);
    var buf: [3]u8 = undefined;
    const lowerTagName = std.ascii.lowerString(&buf, tagName);
    
    print("{s}", .{lowerTagName});
}

pub fn printRegisterOperand(operand: t.OperandRegister) void {
    var lower: [2]u8 = undefined;
    _ = std.ascii.lowerString(&lower, @tagName(operand.target));
    
    print("{s}", .{lower});
}

pub fn printImmediateOperand(operand: t.OperandImmediate) void {
    print("{d}", .{operand.value});
}

pub fn printAddressOperand(operand: t.OperandAddress) void {
    print("[", .{});
    
    var hasRegister = false;
    
    if(operand.registers[0] != null) {
        hasRegister = true;
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[0].?));
        print("{s}", .{lower});
    }

    if(operand.registers[1] != null) {
        hasRegister = true;
        var lower: [2]u8 = undefined;
        _ = std.ascii.lowerString(&lower, @tagName(operand.registers[1].?));
        print(" + {s}", .{lower});
    }

    if(operand.value != null) {
        if(hasRegister) {
            print(" + ", .{});
        }
        print("{d}", .{operand.value.?});
    }

    print("]", .{});
}

pub fn printTargetOperand(operand: t.OperandTarget) void {
    print("; {d}", .{operand.value});
}

pub fn printOperand(operand: t.Operand) void {
    switch (operand) {
        .REGISTER => printRegisterOperand(operand.REGISTER),
        .IMMEDIATE => printImmediateOperand(operand.IMMEDIATE),
        .ADDRESS => printAddressOperand(operand.ADDRESS),
        .TARGET => printTargetOperand(operand.TARGET)
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


pub fn printSize(size: t.Size) void {
    const str = switch (size) {
        t.Size.BYTE => "byte",
        t.Size.WORD => "word",
        t.Size.UNKNOWN => "",
    };

    print("{s}", .{str});
} 

pub fn printInstr(inst: t.Instruction) void {
    printOperationName(inst.name);
    if (explicitSize(inst)) {
        print(" ", .{});
        printSize(inst.size);
    }
    print(" ", .{});
    printOperand(inst.dest);
    if (inst.source != null) {
        print(", ", .{});
        printOperand(inst.source.?);
    }
}

pub fn printInstrXs(instructions: []t.Instruction, path: []const u8) void {
    print("; {s}\n", .{path});
    print("bits 16\n", .{});

    for (instructions) |i| {
        printInstr(i);
        print("\n", .{});
    }
}
