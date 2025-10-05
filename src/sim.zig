const std = @import("std");
const t = @import("types.zig");
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

const SimError = error {
    NotImplemented,
    InvalidInstruction
};

fn simInstr(inst: t.Instruction) !void {
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
                },
                else => {
                    return SimError.NotImplemented;
                }
            }
            
            dest_ptr.* = src_val;
        },
        else => {
            return SimError.NotImplemented;
        }
    }
}

fn debugRegister(name: []const u8, ptr: *u16) void {
    std.log.debug("{s}: 0x{x:0>4} {d}", .{name, ptr.*, ptr.*});
}

pub fn simProgram(instructions: []t.Instruction) void {
    for(instructions) |inst| {
        simInstr(inst) catch |err| {
            std.log.err("{t}: An error occured when simulation an instruction", .{err});
        };
    }

    debugRegister("ax", register_pointers.ax);
    debugRegister("bx", register_pointers.bx);
    debugRegister("cx", register_pointers.cx);
    debugRegister("dx", register_pointers.dx);
    debugRegister("sp", register_pointers.sp);
    debugRegister("bp", register_pointers.bp);
    debugRegister("si", register_pointers.si);
    debugRegister("di", register_pointers.di);
}
