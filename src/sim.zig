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

const TaggedPointer = union(enum){
    u8_ptr: *u8,
    u16_ptr: *u16,
    
    pub fn size(self: TaggedPointer) usize {
        return switch (self) {
            .u8_ptr => @sizeOf(u8),
            .u16_ptr => @sizeOf(u16),
        };
    }
};

fn ptrForReg(name: t.RegisterName) TaggedPointer {
    return switch (name) {
        t.RegisterName.AX => TaggedPointer{.u16_ptr = register_pointers.ax},
        t.RegisterName.BX => TaggedPointer{.u16_ptr = register_pointers.bx},
        t.RegisterName.CX => TaggedPointer{.u16_ptr = register_pointers.cx},
        t.RegisterName.DX => TaggedPointer{.u16_ptr = register_pointers.dx},
        t.RegisterName.SP => TaggedPointer{.u16_ptr = register_pointers.sp},
        t.RegisterName.BP => TaggedPointer{.u16_ptr = register_pointers.bp},
        t.RegisterName.SI => TaggedPointer{.u16_ptr = register_pointers.si},
        t.RegisterName.DI => TaggedPointer{.u16_ptr = register_pointers.di},
        t.RegisterName.AH => TaggedPointer{.u8_ptr = register_pointers.ah},
        t.RegisterName.AL => TaggedPointer{.u8_ptr = register_pointers.al},
        t.RegisterName.BH => TaggedPointer{.u8_ptr = register_pointers.bh},
        t.RegisterName.BL => TaggedPointer{.u8_ptr = register_pointers.bl},
        t.RegisterName.CH => TaggedPointer{.u8_ptr = register_pointers.ch},
        t.RegisterName.CL => TaggedPointer{.u8_ptr = register_pointers.cl},
        t.RegisterName.DH => TaggedPointer{.u8_ptr = register_pointers.dh},
        t.RegisterName.DL => TaggedPointer{.u8_ptr = register_pointers.dl},
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

fn simInstr(inst: t.Instruction) !void {
    var mutation_result: MutationResult = undefined;
    
    switch (inst.name) {
        t.OperationName.MOV => {
            if(inst.source == null) {
                return SimError.InvalidInstruction;
            }

            var dest_ptr: TaggedPointer = undefined;
            switch (inst.dest) {
                .REGISTER => |register_op| {
                    dest_ptr = ptrForReg(register_op.target);
                    mutation_result.register_name = register_op.target;
                },
                else => {
                    return SimError.NotImplemented;
                }
            }

            var src_ptr: TaggedPointer = undefined;
            switch (inst.source.?) {
                .IMMEDIATE => |immediate_op| {
                    if (immediate_op.value < 255) {
                        var one_byte: u8 = @intCast(immediate_op.value);
                        src_ptr = TaggedPointer{
                            .u8_ptr = &one_byte
                        };
                    } else {
                        var two_bytes: u16 = @intCast(immediate_op.value);
                        src_ptr = TaggedPointer {
                            .u16_ptr = &two_bytes
                        };
                    }
                },
                .REGISTER => |register_op| {
                      src_ptr = ptrForReg(register_op.target);
                },
                else => {
                    return SimError.NotImplemented;
                }
            }
            
            switch (dest_ptr) {
                .u8_ptr => |d_ptr| {
                    switch (src_ptr) {
                        .u8_ptr => |s_ptr| {
                            mutation_result.original_value = d_ptr.*;
                            d_ptr.* = s_ptr.*;
                        },
                        .u16_ptr => {
                            std.log.err("invalid instruction, moving sixteen bit value to eight bit register", .{});
                            return SimError.InvalidInstruction;
                        }
                    }
                    mutation_result.updated_value = d_ptr.*;
                },
                .u16_ptr => |d_ptr| {
                    switch (src_ptr) {
                        .u8_ptr => |s_ptr| {
                            mutation_result.original_value = d_ptr.*;
                            d_ptr.* = s_ptr.*;
                        },
                        .u16_ptr => |s_ptr| {
                            mutation_result.original_value = d_ptr.*;
                            d_ptr.* = s_ptr.*;
                        }
                    }
                    mutation_result.updated_value = d_ptr.*;
                },
            }
            
        },
        else => {
            return SimError.NotImplemented;
        }
    }
    
    printMutation( inst, mutation_result);
}

pub fn simProgram(instructions: []t.Instruction) !void {
    for(instructions) |inst| {
        simInstr(inst) catch |err| {
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
    
    p.print("Final registers:\n", .{});
    printRegister("ax", register_pointers.ax);
    printRegister("bx", register_pointers.bx);
    printRegister("cx", register_pointers.cx);
    printRegister("dx", register_pointers.dx);
    printRegister("sp", register_pointers.sp);
    printRegister("bp", register_pointers.bp);
    printRegister("si", register_pointers.si);
    printRegister("di", register_pointers.di);
}

fn printRegister(name: []const u8, ptr: *u16) void {
    p.print("      {s}: 0x{x:0>4} ({d})\n", .{name, ptr.*, ptr.*});
}

fn printMutation(instr: t.Instruction, result: MutationResult) void {
    // Example: "mov ax, 1 ; ax:0x0->0x1"
    p.printInstr(instr);
    p.print(" ; ax:0x{x}->0x{x}", .{result.original_value, result.updated_value});
    p.print("\n", .{});
}