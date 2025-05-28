const std = @import("std");
const t = @import("types.zig");

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
    
    bytesRead: usize,
    
    pub fn init() CapturedBits {
        return CapturedBits{
            .D = null, 
            .W = null, 
            .MOD = null,
            .REG = null,
            .RM = null,
            .bytesRead = 0,
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
    var bitCursor: usize = 0;

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
                    std.log.err(
                        "{!}: Unexpected bits, did not encounter pattern {b}",
                        .{DecodeBytesError.SpecDoesNotMatch, s}
                    );
                    return DecodeBytesError.SpecDoesNotMatch;
                }
            },
        }

        std.log.info("captured i:{d} boff:{d} size:{d} shift:{d} mask:{d} bits:{b:0>8}", .{ i, byteOffset, bitSize, bitShift, bitMaskSize, bits });

        bitCursor += bitSize;
    }
    
    const bitCursorFloat: f16 = @floatFromInt(bitCursor);
    captured.bytesRead = @intFromFloat(@ceil(bitCursorFloat / 8)); 

    return captured;
}

// Transform captured bits into structions

fn findRegister(wide: u1, reg: u3) t.Register {
    return switch (wide) {
        0b0 => switch (reg) {
            0b000 => t.Register.al,
            0b001 => t.Register.cl,
            0b010 => t.Register.dl,
            0b011 => t.Register.bl,
            0b100 => t.Register.ah,
            0b101 => t.Register.ch,
            0b110 => t.Register.dh,
            0b111 => t.Register.bh,
        },
        0b1 => switch (reg) {
            0b000 => t.Register.ax,
            0b001 => t.Register.cx,
            0b010 => t.Register.dx,
            0b011 => t.Register.bx,
            0b100 => t.Register.sp,
            0b101 => t.Register.bp,
            0b110 => t.Register.si,
            0b111 => t.Register.di,
        },
    };
}

const DecodeCapturedBitsError = error{ UnrecognizedBits };

fn decodeCapturedBits(bits: CapturedBits) !t.Instruction {
    const bitsW  = bits.W orelse return DecodeCapturedBitsError.UnrecognizedBits;
    const bitsREG  = bits.REG orelse return DecodeCapturedBitsError.UnrecognizedBits;
    
    const regOperand = t.OperandRegister{
        .target = findRegister(bitsW, bitsREG),
    };
    
    const bitsD  = bits.D orelse return DecodeCapturedBitsError.UnrecognizedBits;
    var inst = t.Instruction {
        .name = t.OperationName.mov,
        .destination = undefined,
        .source = undefined
    }; 
    
    switch (bitsD) {
        0b0 => inst.source.REGISTER = regOperand,
        0b1 => inst.destination.REGISTER = regOperand,
    }

    const bitsRM  = bits.RM orelse return DecodeCapturedBitsError.UnrecognizedBits;
    const rmOperand = t.OperandRegister{
        .target = findRegister(bitsW, bitsRM),
    };

    switch (bitsD) {
        0b0 => inst.destination.REGISTER = rmOperand,
        0b1 => inst.source.REGISTER = rmOperand,
    }
    
    return inst;
}

pub fn decodeStream(memory: []u8, allocator: std.mem.Allocator) ![]t.Instruction {
    
    var bytesRead: usize = 0;
    var endOfStream = false;
    var captured: CapturedBits = undefined;
    var inst: t.Instruction = undefined;
    var result = std.ArrayList(t.Instruction).init(allocator);
    
    while(!endOfStream) {
        captured = try decodeBytes(specTable, memory);
        inst = try decodeCapturedBits(captured);
        try result.append(inst);
        
        bytesRead += captured.bytesRead;
        endOfStream = memory.len >= bytesRead;
    }
    
    return result.toOwnedSlice();
}
