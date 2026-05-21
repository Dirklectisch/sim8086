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

fn valueFromOperand(operand: t.Operand) u16 {
    switch (operand) {
        .ADDRESS => unreachable,
        .IMMEDIATE => |io| {
            const pos_int: u16 = @bitCast(io.value);
            return @intCast(pos_int);
        },
        .REGISTER => |ro| {
            switch (ptrForReg(ro.target)) {
                .u8_ptr => |eight| {
                    return @intCast(eight.*);
                },
                .u16_ptr => |sixteen| {
                    return @intCast(sixteen.*);
                } 
            }
        },
        .TARGET => unreachable,
    }
}

const MutationResult = struct {
    register_name: t.RegisterName,
    original_value: u64,
    updated_value: u64,
};

fn writeToOperand(op: t.Operand, value: u16) !MutationResult {
    var result: MutationResult = undefined;
    var ptr: TaggedPointer = undefined;
    switch (op) {
        .ADDRESS => return SimError.NotImplemented,
        .REGISTER => |ro| {
            result.register_name = ro.target;
            result.original_value = valueFromOperand(op);
            ptr = ptrForReg(ro.target);
        },
        else => return SimError.InvalidInstruction,
    }
    
    switch (ptr) {
        .u8_ptr => |eight_ptr| {
            eight_ptr.* = @intCast(value);
        },
        .u16_ptr => |sixteen_ptr| {
            sixteen_ptr.* = @intCast(value);
        }
    }
    result.updated_value = valueFromOperand(op);
    return result;
}

const Flags = struct {
    zero: bool,
    sign: bool
};

var flags = Flags {
    .zero = false,
    .sign = false
};

const SimError = error {
    NotImplemented,
    InvalidInstruction
};

fn simInstr(inst: t.Instruction) !void {
    var mutation_result: MutationResult = undefined;
    
    const dest_val = valueFromOperand(inst.dest);
    var src_val: u16 = 0;
    if (inst.source != null) {
        src_val = valueFromOperand(inst.source.?);
    }
    
    switch (inst.name) {
        t.OperationName.MOV => {
            mutation_result = try writeToOperand(inst.dest, src_val);
        },
        t.OperationName.ADD => {
            const res_val = dest_val + src_val;
            mutation_result = try writeToOperand(inst.dest, res_val);
        },
        t.OperationName.SUB => {
            const res_val = dest_val - src_val;
            mutation_result = try writeToOperand(inst.dest, res_val);
        },
        t.OperationName.CMP => {
            // cmp is just sub but cmp doesn’t write the result.
            // const res_val = src_val - dest_val;
            // write flags
        },
        else => {
            return SimError.NotImplemented;
        }
    }
    
    switch (inst.name) {
        t.OperationName.MOV, t.OperationName.ADD, t.OperationName.SUB => {
            printInstruction(inst);
            printMutation(mutation_result);            
        },
        t.OperationName.CMP => {
            printInstruction(inst);
        },
        else => {}
    }
    p.print("\n", .{});
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

fn printInstruction(instr: t.Instruction) void {
    p.printInstr(instr);
    p.print(" ;", .{});
}

fn printMutation(result: MutationResult) void {
    // Example: " ax:0x0->0x1"
    p.print(" {s}:0x{x}->0x{x}", .{p.formatRegisterName(result.register_name), result.original_value, result.updated_value});
}