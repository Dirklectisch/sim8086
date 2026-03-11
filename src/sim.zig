const std = @import("std");
const t = @import("types.zig");
const p = @import("print.zig");
const expect = std.testing.expect;

// Note that because it's most natural to work with little endian data..
// .. these registers will have the high byte in position 1 and the low byte in position 0 
const RegisterData = struct {
    ax: [2]u8,
    bx: [2]u8,
    cx: [2]u8,
    dx: [2]u8,
    sp: [2]u8,
    bp: [2]u8,
    si: [2]u8,
    di: [2]u8,
};

var register_data = RegisterData{
    .ax = [2]u8{0x0, 0x0},
    .bx = [2]u8{0x0, 0x0},
    .cx = [2]u8{0x0, 0x0},
    .dx = [2]u8{0x0, 0x0},
    .sp = [2]u8{0x0, 0x0},
    .bp = [2]u8{0x0, 0x0},
    .si = [2]u8{0x0, 0x0},
    .di = [2]u8{0x0, 0x0},
};

const RegisterPointers = struct {
    ax: *u16,
    ah: *u8,
    al: *u8,
    bx: *u16,
    bh: *u8,
    bl: *u8,
    cx: *u16,
    ch: *u8,
    cl: *u8,
    dx: *u16,
    dh: *u8,
    dl: *u8,
    sp: *u16,
    bp: *u16,
    si: *u16,
    di: *u16
};

fn toFullPtr(register: *[2]u8) *u16 {
    const full_ptr: *u16 = @ptrCast(@alignCast(register));
    return full_ptr;
}

fn toHighPtr(register: *[2]u8) *u8 {
    const high_ptr: *u8 = @ptrCast(&register[1]);
    return high_ptr;
}

fn toLowPtr(register: *[2]u8) *u8 {
    const low_ptr: *u8 = @ptrCast(&register[0]);
    return low_ptr;
}

test "pointers to registers" {
    var ax = [2]u8{0x0, 0x0};
    const full_ptr = toFullPtr(&ax);
    full_ptr.* = 0x1234;
    try expect(full_ptr.* == 0x1234);
    
    const ah = toHighPtr(&ax);
    try expect(ah.* == 0x12);

    const al = toLowPtr(&ax);
    try expect(al.* == 0x34);
}

const register_pointers = RegisterPointers{
    .ax = toFullPtr(&register_data.ax),
    .ah = toHighPtr(&register_data.ax),
    .al = toLowPtr(&register_data.ax),
    .bx = toFullPtr(&register_data.bx),
    .bh = toHighPtr(&register_data.bx),
    .bl = toLowPtr(&register_data.bx),
    .cx = toFullPtr(&register_data.cx),
    .ch = toHighPtr(&register_data.cx),
    .cl = toLowPtr(&register_data.cx),
    .dx = toFullPtr(&register_data.dx),
    .dh = toHighPtr(&register_data.dx),
    .dl = toLowPtr(&register_data.dx),
    .sp = toFullPtr(&register_data.sp),
    .bp = toFullPtr(&register_data.bp),
    .si = toFullPtr(&register_data.si),
    .di = toFullPtr(&register_data.di),
};

fn ptrForReg(name: t.RegisterName) *u16 {
    return switch (name) {
        t.RegisterName.AX => register_pointers.ax,
        t.RegisterName.BX => register_pointers.bx,
        t.RegisterName.CX => register_pointers.cx,
        t.RegisterName.DX => register_pointers.dx,
        t.RegisterName.SP => register_pointers.sp,
        t.RegisterName.BP => register_pointers.bp,
        t.RegisterName.SI => register_pointers.si,
        t.RegisterName.DI => register_pointers.di,
        else => unreachable
    };
}

const MutationResult = struct {
    register_name: t.RegisterName,
    original_value: u16,
    updated_value: u16,
};

const SimError = error {
    NotImplemented,
    InvalidInstruction
};

fn simInstr(w: *std.Io.Writer, inst: t.Instruction) !void {
    var mutation_result: MutationResult = undefined;
    
    switch (inst.name) {
        t.OperationName.MOV => {
            if(inst.source == null) {
                return SimError.InvalidInstruction;
            }
            var src_val: u16 = undefined;
            switch (inst.source.?) {
                .IMMEDIATE => |immediate_op| {
                    src_val = @bitCast(immediate_op.value);
                },
                else => {
                    return SimError.NotImplemented;
                }
            }

            var dest_ptr: *u16 = undefined;
            switch (inst.dest) {
                .REGISTER => |register_op| {
                    dest_ptr = ptrForReg(register_op.target);
                    mutation_result.register_name = register_op.target;
                },
                else => {
                    return SimError.NotImplemented;
                }
            }

            mutation_result.original_value = dest_ptr.*;
            dest_ptr.* = src_val;
            mutation_result.updated_value = dest_ptr.*;
            
        },
        else => {
            return SimError.NotImplemented;
        }
    }
    
    try printMutation(w, inst, mutation_result);
}

pub fn simProgram(w: *std.Io.Writer, instructions: []t.Instruction) !void {
    for(instructions) |inst| {
        simInstr(w, inst) catch |err| {
            std.log.err("{t}: An error occured when simulation an instruction", .{err});
        };
    }
    
    // Print final overview of register state
    // 
    // Example:
    // 
    // Final registers:
    // ax: 0x0001 (1)
    // bx: 0x0002 (2)
    // cx: 0x0003 (3)
    // dx: 0x0004 (4)
    // sp: 0x0005 (5)
    // bp: 0x0006 (6)
    // si: 0x0007 (7)
    // di: 0x0008 (8)
    
    try w.print("Final registers:\n", .{});
    try printRegister(w,"ax", register_pointers.ax);
    try printRegister(w,"bx", register_pointers.bx);
    try printRegister(w,"cx", register_pointers.cx);
    try printRegister(w,"dx", register_pointers.dx);
    try printRegister(w,"sp", register_pointers.sp);
    try printRegister(w,"bp", register_pointers.bp);
    try printRegister(w,"si", register_pointers.si);
    try printRegister(w,"di", register_pointers.di);
    try w.flush();
}

fn printRegister(w: *std.Io.Writer, name: []const u8, ptr: *u16) !void {
    try w.print("      {s}: 0x{x:0>4} ({d})\n", .{name, ptr.*, ptr.*});
}

fn printMutation(w: *std.Io.Writer, instr: t.Instruction, result: MutationResult) !void {
    // Example: "mov ax, 1 ; ax:0x0->0x1"
    try p.printInstr(w, instr);
    try w.print(" ; ax:0x{x}->0x{x}", .{result.original_value, result.updated_value});
    try w.print("\n", .{});
}