const std = @import("std");
const t = @import("types.zig");

// Declarative reader specifications

const FieldName = enum {
    D,
    W,
    MOD,
    REG,
    RM,
    DATA,
};

const FieldSpec = struct { name: FieldName };
const LiteralSpec = struct { value: u8, bitSize: u8};
const TokenSpec = union(enum) { literal: LiteralSpec, field: FieldSpec};

const Spec = struct {
    opName: t.OperationName,
    tokenSpec: []const TokenSpec
};

pub fn maxFieldBitSize(comptime name: FieldName) comptime_int {
    return switch (name) {
        FieldName.D => 1,
        FieldName.W => 1,
        FieldName.MOD => 2,
        FieldName.REG => 3,
        FieldName.RM => 3,
        FieldName.DATA => 16,
    };
}

pub fn FieldType(comptime name: FieldName) type {
    return switch (maxFieldBitSize(name)) {
        1 => u1,
        2 => u2,
        3 => u3,
        else => u8
    };
}

const specTable = makeSpec(t.OperationName.MOV, .{
    @as(u6, 0b100010),
    FieldName.D,
    FieldName.W,
    FieldName.MOD,
    FieldName.REG,
    FieldName.RM,
});

fn makeSpec(comptime name: t.OperationName, comptime fields: anytype) Spec {
    var tokens: [fields.len]TokenSpec = undefined;
    inline for (fields, 0..) |f, i| {
        const to = @TypeOf(f);
        switch (to) {
            FieldName => {
                tokens[i] = TokenSpec{.field = FieldSpec{ .name = f }};
            },
            u1, u2, u3, u4, u5, u6, u7, u8 => {
                tokens[i] = TokenSpec{.literal = LiteralSpec{ .value = f, .bitSize = @bitSizeOf(to)}};
            },
            else => unreachable
        }
    }
    
    const finalTokens = tokens;
    
    return Spec{
        .opName = name,
        .tokenSpec = finalTokens[0..],
    };
}

const specs = [_]Spec{
    makeSpec(t.OperationName.MOV, .{
        @as(u6, 0b100010),
        FieldName.D,
        FieldName.W,
        FieldName.MOD,
        FieldName.REG,
        FieldName.RM,
    }),
    makeSpec(t.OperationName.MOV, .{
        @as(u6, 0b100010),
        FieldName.D,
        FieldName.W,
        FieldName.MOD,
        FieldName.REG,
        FieldName.RM,
        FieldName.DATA,
    })
};

// In memory representations of decoded bits

const CapturedBits = struct {
    D: ?FieldType(FieldName.D),
    W: ?FieldType(FieldName.W),
    MOD: ?FieldType(FieldName.MOD),
    REG: ?FieldType(FieldName.REG),
    RM: ?FieldType(FieldName.RM),
    DATA: ?FieldType(FieldName.DATA),
    
    opName: t.OperationName,
    bytesRead: usize,
    
    pub fn init(opName: t.OperationName) CapturedBits {
        return CapturedBits{
            .D = null, 
            .W = null, 
            .MOD = null,
            .REG = null,
            .RM = null,
            .DATA = null,
            .opName = opName,
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
            FieldName.DATA => this.DATA = @intCast(value),
        }
    }
};

// Decoding logic

const AttemptDecodeError = error{ NotEnoughBytes, SpecDoesNotMatch, InvalidSpec };

pub fn attemptDecode(comptime spec: Spec, bytes: []u8) !CapturedBits {
    var captured = CapturedBits.init(spec.opName);
    var bitCursor: usize = 0;

    inline for (spec.tokenSpec) |ts| {
        const byteOffset: u8 = @intCast(bitCursor / 8);
        if (bytes.len < byteOffset) {
            return AttemptDecodeError.NotEnoughBytes;
        }
        
        const bitSize: u8 = switch (ts) {
            .literal => |l| l.bitSize,
            .field => |f| 
                // Some fields have a conditional size based on what was captured..
                // .. for these fields we determine the length here at runtime.
                switch (f.name) {
                    FieldName.DATA =>
                        switch (captured.W orelse return AttemptDecodeError.InvalidSpec) {
                            0b0 => 8,
                            0b1 => 16,
                        },
                    else => maxFieldBitSize(f.name),
                },
        };

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

        switch (ts) {
        // if we are currently evaluation a field token, capture the bits
            .field => |f| captured.setBitsField(f.name, bits),
        // if we are currently evaluation a literal token, check bits against spec
            .literal => |l| {
                if (l.value != bits) {
                    std.log.err(
                        "{!}: Unexpected bits, did not encounter pattern {b}",
                        .{AttemptDecodeError.SpecDoesNotMatch, l.value}
                    );
                    return AttemptDecodeError.SpecDoesNotMatch;
                }
            },
        }

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
            0b000 => t.Register.AL,
            0b001 => t.Register.CL,
            0b010 => t.Register.DL,
            0b011 => t.Register.BL,
            0b100 => t.Register.AH,
            0b101 => t.Register.CH,
            0b110 => t.Register.DH,
            0b111 => t.Register.BH,
        },
        0b1 => switch (reg) {
            0b000 => t.Register.AX,
            0b001 => t.Register.CX,
            0b010 => t.Register.DX,
            0b011 => t.Register.BX,
            0b100 => t.Register.SP,
            0b101 => t.Register.BP,
            0b110 => t.Register.SI,
            0b111 => t.Register.DI,
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
        .name = t.OperationName.MOV,
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

const decodeStreamError = error { ExtraBytesFound };

pub fn decodeStream(memory: []u8, allocator: std.mem.Allocator) ![]t.Instruction {
    var bytesRead: usize = 0;
    var endOfStream = false;
    var captured: ?CapturedBits = null;
    var inst: t.Instruction = undefined;
    var result = std.ArrayList(t.Instruction).init(allocator);
    
    while(!endOfStream) {
        // Some dirty code here because of comptime stuff..
        // .. have another go at this later  
        inline for (specs) |spec|{
            if(captured != null) break;
            captured = attemptDecode(spec, memory[bytesRead..]) catch null;
        }
        
        if(captured == null) {
            std.log.err(
                "{!}: Unexpected bytes found, spec table invalid or incomplete",
                .{decodeStreamError.ExtraBytesFound}
            );
            break;
        }
        const sureCapture = captured orelse unreachable;
        inst = try decodeCapturedBits(sureCapture);
        try result.append(inst);
        
        bytesRead += sureCapture.bytesRead;
        endOfStream = memory.len <= bytesRead;
        captured = null;
    }
    
    return result.toOwnedSlice();
}
