const std = @import("std");

// Declarative reader specifications

const FieldName = enum {
    D,
    W,
    MOD,
    REG,
    RM,
};

const FieldSpec = struct { name: FieldName, length: u8 };

pub fn fieldBitSize(comptime name: FieldName) comptime_int {
    return switch (name) {
        FieldName.D => 1,
        FieldName.W => 1,
        FieldName.MOD => 2,
        FieldName.REG => 3,
        FieldName.RM => 3,
    };
}

pub fn FieldType(comptime name: FieldName) type {
    return switch (fieldBitSize(name)) {
        1 => u1,
        2 => u2,
        3 => u3,
        else => u8
    };
}

const LiteralSpec = struct { value: u8, length: u8 };

const specTable = .{
    @as(u6, 0b100010),
    FieldName.D,
    FieldName.W,
    FieldName.MOD,
    FieldName.REG,
    FieldName.RM,
};

// In memory representations of decoded bits

const CapturedBits = struct {
    D: ?FieldType(FieldName.D),
    W: ?FieldType(FieldName.W),
    MOD: ?FieldType(FieldName.MOD),
    REG: ?FieldType(FieldName.REG),
    RM: ?FieldType(FieldName.RM),
    
    pub fn init() CapturedBits {
        return CapturedBits{
            .D = null, 
            .W = null, 
            .MOD = null,
            .REG = null,
            .RM = null,
        };
    }

    pub fn setBitsField(this: *CapturedBits, field: FieldName, value: u8) void {
        switch (field) {
            FieldName.D => this.D = @intCast(value),
            FieldName.W => this.W = @intCast(value),
            FieldName.MOD => this.MOD = @intCast(value),
            FieldName.REG => this.REG = @intCast(value),
            FieldName.RM => this.RM = @intCast(value),
        }
    }
};

// Decoding logic

const DecodeBytesError = error{ NotEnoughBytes, SpecDoesNotMatch };

pub fn decodeBytes(comptime spec: anytype, bytes: []u8) !CapturedBits {
    var captured = CapturedBits.init();
    var bitCursor: u32 = 0;

    inline for (spec, 0..) |s, i| {
        const bitSize = switch (@TypeOf(s)) {
            FieldName => fieldBitSize(s),
            else => @bitSizeOf(@TypeOf(s)),
        };

        const byteOffset: u8 = @intCast(bitCursor / 8);
        if (bytes.len < byteOffset) {
            return DecodeBytesError.NotEnoughBytes;
        }

        const bitOffset: u8 = @truncate(bitCursor % 8);
        const bitShift: u3 = @truncate(8 - bitOffset - bitSize);
        const bitMaskSize: u8 = 8 - bitSize;
        const bitMask: u8 = switch (bitMaskSize) {
            0 => 0b11111111,
            1 => 0b01111111,
            2 => 0b00111111,
            3 => 0b00011111,
            4 => 0b00001111,
            5 => 0b00000111,
            6 => 0b00000011,
            7 => 0b00000001,
            8 => 0b00000000,
            else => unreachable,
        };

        const byte = bytes[byteOffset];
        const bits: u8 = (byte >> bitShift) & bitMask;

        switch (@TypeOf(s)) {
            FieldName => captured.setBitsField(s, bits),
            else => {
                const bitsInt: u8 = @intCast(s); 
                if (bitsInt != bits) {
                    return DecodeBytesError.SpecDoesNotMatch;
                }
            },
        }

        std.log.info("captured i:{d} boff:{d} size:{d} shift:{d} mask:{d} bits:{b:0>8}", .{ i, byteOffset, bitSize, bitShift, bitMaskSize, bits });

        bitCursor += bitSize;
    }

    return captured;
}

// In memory representation of intstuctions

const OperationName = enum {
    MOV,
};

const Register = enum {
    AX,
    AL,
    AH,
    BX,
    BL,
    BH,
    CX,
    CL,
    CH,
    DX,
    DL,
    DH,
    SP,
    BP,
    SI,
    DI,
};

fn findRegister(wide: u1, reg: u3) Register {
    return switch (wide) {
        0b0 => switch (reg) {
            0b000 => Register.AL,
            0b001 => Register.CL,
            0b010 => Register.DL,
            0b011 => Register.BL,
            0b100 => Register.AH,
            0b101 => Register.CH,
            0b110 => Register.DH,
            0b111 => Register.BH,
        },
        0b1 => switch (reg) {
            0b000 => Register.AX,
            0b001 => Register.CX,
            0b010 => Register.DX,
            0b011 => Register.BX,
            0b100 => Register.SP,
            0b101 => Register.BP,
            0b110 => Register.SI,
            0b111 => Register.DI,
        },
    };
} 
const OperandType = enum {
    REGISTER,
};

const OperandRegister = struct {
    target: Register
};

const Operand = union(OperandType) {
    REGISTER: OperandRegister
};

const Instruction = struct {
    name: OperationName,
    destination: Operand,
    source: Operand
};

const DecodeInstructionError = error{ UnrecognizedBits };

fn decodeInstruction(bits: CapturedBits) !Instruction {
    const bitsW  = bits.W orelse return DecodeInstructionError.UnrecognizedBits;
    const bitsREG  = bits.REG orelse return DecodeInstructionError.UnrecognizedBits;
    
    const regOperand = OperandRegister{
        .target = findRegister(bitsW, bitsREG),
    };
    
    const bitsD  = bits.D orelse return DecodeInstructionError.UnrecognizedBits;
    var inst = Instruction {
        .name = OperationName.MOV,
        .destination = undefined,
        .source = undefined
    }; 
    
    switch (bitsD) {
        0b0 => inst.source.REGISTER = regOperand,
        0b1 => inst.destination.REGISTER = regOperand,
    }

    const bitsRM  = bits.RM orelse return DecodeInstructionError.UnrecognizedBits;
    const rmOperand = OperandRegister{
        .target = findRegister(bitsW, bitsRM),
    };

    switch (bitsD) {
        0b0 => inst.destination.REGISTER = rmOperand,
        0b1 => inst.source.REGISTER = rmOperand,
    }
    
    return inst;
}

pub fn main() !void {
    var exampleBytes = [_]u8{ 0b10001010, 0b10101100 };
    const bits = try decodeBytes(specTable, &exampleBytes);
    const inst = try decodeInstruction(bits);
    std.log.info("{any}", .{bits});
    std.log.info("{any}", .{inst});
}
