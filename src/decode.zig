const std = @import("std");
const t = @import("types.zig");
const expect = std.testing.expect;

// Declarative reader specifications

const FieldName = enum {
    D,
    W,
    MOD,
    REG,
    RM,
    DATA,
    DISP
};

const FieldSpec = struct { name: FieldName };
const LiteralSpec = struct { value: u8, bitSize: u8};
const TokenSpec = union(enum) { literal: LiteralSpec, field: FieldSpec};

const Spec = struct {
    opName: t.OperationName,
    tokenSpec: []const TokenSpec
};

pub fn maxFieldBitSize(name: FieldName) u8 {
    return switch (name) {
        FieldName.D => 1,
        FieldName.W => 1,
        FieldName.MOD => 2,
        FieldName.REG => 3,
        FieldName.RM => 3,
        FieldName.DATA => 16,
        FieldName.DISP => 16,
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
        FieldName.DISP
    }),
    makeSpec(t.OperationName.MOV, .{
        @as(u7, 0b1100011),
        FieldName.W,
        FieldName.MOD,
        @as(u3, 0b000),
        FieldName.RM,
        FieldName.DISP,
        FieldName.DATA,
    }),
    makeSpec(t.OperationName.MOV, .{
        @as(u4, 0b1011),
        FieldName.W,
        FieldName.REG,
        FieldName.DATA,
    }),
};

// In memory representations of decoded bits

const MultiByte = union (enum) { one: u8, two: u16 };

const CapturedBits = struct {
    D: ?u1,
    W: ?u1,
    MOD: ?u2,
    REG: ?u3,
    RM: ?u3,
    DATA: ?MultiByte,
    DISP: ?MultiByte,
    
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
            .DISP = null,
            .opName = opName,
            .bytesRead = 0,
        };
    }

    pub fn setBitsField(this: *CapturedBits, field: FieldName, value: u16) void {
        switch (field) {
            FieldName.D => this.D = @intCast(value),
            FieldName.W => this.W = @intCast(value),
            FieldName.MOD => this.MOD = @intCast(value),
            FieldName.REG => this.REG = @intCast(value),
            FieldName.RM => this.RM = @intCast(value),
            else => {
                std.log.err("Can not set multi byte field, use setBytesField instead.", .{});
                unreachable;
            }
        }
    }
    
    pub fn setBytesField(this: *CapturedBits, field: FieldName, value: MultiByte) void {
        switch (field) {
            FieldName.DATA => this.DATA = value,
            FieldName.DISP => this.DISP = value,
            else => {
                std.log.err("Can not set bit field, use setBitsField instead.", .{});
                unreachable;
            }
        }
    }
};

// Decoding logic

const AttemptDecodeError = error{ NotEnoughBytes, SpecDoesNotMatch, InvalidSpec };

pub fn attemptDecode(spec: Spec, bytes: []const u8) !CapturedBits {
    var captured = CapturedBits.init(spec.opName);
    var bitCursor: usize = 0;

    for (spec.tokenSpec) |ts| {
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
                    FieldName.DISP =>
                        switch (captured.MOD orelse return AttemptDecodeError.InvalidSpec) {
                            0b00 => 0,
                            0b01 => 8,
                            0b10 => 16,
                            0b11 => 0,
                        },
                    else => maxFieldBitSize(f.name),
                },
        };
        
        const noBytes = bitSize == 0;
        if(noBytes) {
            continue;
        }
        
        const isWholeBytes = (bitSize % 8) == 0;
        if (isWholeBytes) {
            // Tokens of a full byte or larger are always whole bytes..
            // .. and also start on the first bit of a byte
            // .. and also are always one or two bytes long
            const amountOfBytes = bitSize / 8;
            const upTo = byteOffset + amountOfBytes;
            const byteSlice = bytes[byteOffset..upTo];
            switch (amountOfBytes) {
                1 => {
                    const oneByte: u8 = std.mem.readInt(u8, byteSlice[0..1], .big);
                    captured.setBytesField(ts.field.name, MultiByte{ .one = oneByte });
                },
                2 => {
                    const twoBytes = std.mem.readInt(u16, byteSlice[0..2], .big);
                    captured.setBytesField(ts.field.name, MultiByte{ .two = twoBytes });
                },
                else => {
                    std.log.err(
                        "{!}: Invalid bitsize in spec {d}",
                        .{AttemptDecodeError.InvalidSpec, bitSize}
                    );
                    return AttemptDecodeError.InvalidSpec;
                }
            }

            bitCursor += bitSize;
            continue;
        }

        const isPartialByte = bitSize < 8;
        if (isPartialByte) {
            var bits: u8 = undefined;
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
            bits = (byte >> bitShift) & bitMask;

            switch (ts) {
            // if we are currently evaluation a field token, capture the bits
            .field => |f| captured.setBitsField(f.name, bits),
                // if we are currently evaluation a literal token, check bits against spec
            .literal => |l| {
                    if (l.value != bits) {
                        return AttemptDecodeError.SpecDoesNotMatch;
                    }
                },
            }

            bitCursor += bitSize;
        }
    }
    
    const bitCursorFloat: f16 = @floatFromInt(bitCursor);
    captured.bytesRead = @intFromFloat(@ceil(bitCursorFloat / 8)); 

    return captured;
}

test "Endianess in standard library readInt function" {
    // This test is just here for clarifying how reading ints from the byte streams works
    // Leaving it here in case my future self needs a refresher
    
    try expect(std.mem.readInt(u8, &[_]u8{0b00000001}, .little) == 1);
    try expect(std.mem.readInt(u8, &[_]u8{0b00000001}, .big) == 1);
    try expect(std.mem.readInt(u16, &[_]u8{0b00000000, 0b00000001}, .big) == 1);
    try expect(std.mem.readInt(u16, &[_]u8{0b00000000, 0b00000001}, .little) != 1);
}

test "Test handling of multiple bytes capture" {
    const oneByteDataSpec = makeSpec(t.OperationName.MOV, .{
        @as(u7, 0b1111111),
        FieldName.W,
        FieldName.DATA,
    });

    const example = [2]u8{0b11111110, 0b10101010};
    const capture = try attemptDecode(oneByteDataSpec, example[0..]);
    try expect(capture.DATA == @as(u16, 0b00000000_10101010));

    const twoByteSpec = makeSpec(t.OperationName.MOV, .{
        @as(u7, 0b0000000),
        FieldName.W,
        FieldName.DATA,
    });

    const exampleTwo = [3]u8{0b00000001, 0b10101010, 0b11111111};
    const captureTwo = try attemptDecode(twoByteSpec, exampleTwo[0..]);
    try expect(captureTwo.DATA == @as(u16, 0b10101010_11111111));
}

// Transform captured bits into instructions

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

fn makeRegOperand(wide: ?u1, reg: u3) !t.Operand {
    const sureWide = wide orelse return DecodeCapturedBitsError.UnrecognizedBits;
    const register = findRegister(sureWide, reg);
    const operandRegister = t.OperandRegister{.target = register};
    return t.Operand{ .REGISTER = operandRegister };
}

fn decodeCapturedBits(bits: CapturedBits) !t.Instruction {
    std.log.debug("start to decode captured bits {any}", .{bits});
    
    var inst = t.Instruction {
        .name = t.OperationName.MOV,
        .dest = undefined,
        .source = undefined
    };
    
    const hasReg = bits.REG != null;
    var regOperand: t.Operand = undefined;
    if (hasReg) {
        regOperand = try makeRegOperand(bits.W, bits.REG.?);
    }
    
    const hasRM = bits.RM != null;
    var rmOperand: t.Operand = undefined;
    if (hasRM) {
        const bitsMOD = bits.MOD orelse return DecodeCapturedBitsError.UnrecognizedBits;
        switch (bitsMOD) {
            0b00 => return DecodeCapturedBitsError.UnrecognizedBits,
            0b01 => return DecodeCapturedBitsError.UnrecognizedBits,
            0b10 => return DecodeCapturedBitsError.UnrecognizedBits,
            0b11 => {
                rmOperand = try makeRegOperand(bits.W, bits.RM.?);
            },
        }
    }
    
    const hasD = bits.D != null;
    if (hasD) {
        if(!hasReg or !hasRM) return DecodeCapturedBitsError.UnrecognizedBits;
        switch (bits.D.?) {
            0b0 => {
                inst.source = regOperand;
                inst.dest = rmOperand;
            },
            0b1 => {
                inst.dest = regOperand;
                inst.source = rmOperand;
            },
        }
    }
    
    const hasData = bits.DATA != null;
    var immediateOperand: t.Operand = undefined;
    if (hasData) {
        var data: i16 = undefined;
        switch (bits.DATA.?) {
            .one => |byte| {
                const signed: i8 = @bitCast(byte);
                data = signed;
            },
            .two => |bytes| {
                data = @bitCast(bytes);
            }
        }
        immediateOperand = t.Operand{ .IMMEDIATE = t.OperandImmediate{ .value = data }};
    }
    
    if(hasReg and hasData) {
        inst.dest = regOperand;
        inst.source = immediateOperand;
    }
    
    return inst;
}

const decodeStreamError = error { ExtraBytesFound };

pub fn decodeStream(memory: []u8, allocator: std.mem.Allocator) ![]t.Instruction {
    var bytesRead: usize = 0;
    var endOfStream = false;
    var captured: ?CapturedBits = null;
    var inst: ?t.Instruction = null;
    var result = std.ArrayList(t.Instruction).init(allocator);
    
    while(!endOfStream) {
        for (specs) |spec|{
            captured = attemptDecode(spec, memory[bytesRead..]) catch {
                // If are unable to decode the next few bytes using this spec ..
                // .. continue with the next
                continue;
            };
            // If we found a match break out of the loop
            break;
        }
        
        if(captured == null) {
            std.log.err(
                "{!}: Unexpected bytes found, spec table invalid or incomplete",
                .{decodeStreamError.ExtraBytesFound}
            );
            break;
        }
        const sureCapture = captured.?;
        
        inst = decodeCapturedBits(sureCapture) catch null;
        if (inst != null) {
            try result.append(inst.?);
        } else {
            std.log.err(
                "Decoded bit tokens but failed to traslate into instruction",
                .{}
            );
        }
        
        bytesRead += sureCapture.bytesRead;
        endOfStream = memory.len <= bytesRead;
        captured = null;
    }
    
    return result.toOwnedSlice();
}
