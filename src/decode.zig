const std = @import("std");
const t = @import("types.zig");
const expect = std.testing.expect;

// Declarative reader specifications

const FieldName = enum { D, W, S, MOD, REG, RM, DATA, DISP, IPINC8 };

const FieldSpec = struct { name: FieldName };
const LiteralSpec = struct { value: u8, bitSize: u8 };
const TokenSpec = union(enum) { literal: LiteralSpec, field: FieldSpec };

const Spec = struct { opName: t.OperationName, tokenSpec: []const TokenSpec };

pub fn maxFieldBitSize(name: FieldName) u8 {
    return switch (name) {
        FieldName.D => 1,
        FieldName.W => 1,
        FieldName.S => 1,
        FieldName.MOD => 2,
        FieldName.REG => 3,
        FieldName.RM => 3,
        FieldName.DATA => 16,
        FieldName.DISP => 16,
        FieldName.IPINC8 => 8,
    };
}

fn makeSpec(comptime name: t.OperationName, comptime fields: anytype) Spec {
    var tokens: [fields.len]TokenSpec = undefined;
    inline for (fields, 0..) |f, i| {
        const to = @TypeOf(f);
        switch (to) {
            FieldName => {
                tokens[i] = TokenSpec{ .field = FieldSpec{ .name = f } };
            },
            u1, u2, u3, u4, u5, u6, u7, u8 => {
                tokens[i] = TokenSpec{ .literal = LiteralSpec{ .value = f, .bitSize = @bitSizeOf(to) } };
            },
            else => unreachable,
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
    makeSpec(t.OperationName.ADD, .{
        @as(u6, 0b000000),
        FieldName.D,
        FieldName.W,
        FieldName.MOD,
        FieldName.REG,
        FieldName.RM,
        FieldName.DISP
    }),
    makeSpec(t.OperationName.ADD, .{
        @as(u6, 0b100000),
        FieldName.S,
        FieldName.W,
        FieldName.MOD,
        @as(u3, 0b000),
        FieldName.RM,
        FieldName.DISP,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.ADD, .{
        @as(u7, 0b0000010),
        FieldName.W,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.SUB, .{
        @as(u6, 0b001010),
        FieldName.D,
        FieldName.W,
        FieldName.MOD,
        FieldName.REG,
        FieldName.RM,
        FieldName.DISP
    }),
    makeSpec(t.OperationName.SUB, .{
        @as(u6, 0b100000),
        FieldName.S,
        FieldName.W,
        FieldName.MOD,
        @as(u3, 0b101),
        FieldName.RM,
        FieldName.DISP,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.SUB, .{
        @as(u7, 0b0010110),
        FieldName.W,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.CMP, .{
        @as(u6, 0b001110),
        FieldName.D,
        FieldName.W,
        FieldName.MOD,
        FieldName.REG,
        FieldName.RM,
        FieldName.DISP
    }),
    makeSpec(t.OperationName.CMP, .{
        @as(u6, 0b100000),
        FieldName.S,
        FieldName.W,
        FieldName.MOD,
        @as(u3, 0b111),
        FieldName.RM,
        FieldName.DISP,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.CMP, .{
        @as(u7, 0b0011110),
        FieldName.W,
        FieldName.DATA
    }),
    makeSpec(t.OperationName.JNZ, .{
        @as(u8, 0b01110101),
        FieldName.IPINC8
    }),
    makeSpec(t.OperationName.JE, .{ @as(u8, 0b1110100), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JL, .{ @as(u8, 0b1111100), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JLE, .{ @as(u8, 0b01111110), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JB, .{ @as(u8, 0b01110010), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JBE, .{ @as(u8, 0b01110110), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JP, .{ @as(u8, 0b01111010), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JO, .{ @as(u8, 0b01110000), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JS, .{ @as(u8, 0b01111000), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNE, .{ @as(u8, 0b011110101), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNL, .{ @as(u8, 0b011111101), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JG, .{ @as(u8, 0b011111111), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNB, .{ @as(u8, 0b01110011), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JA, .{ @as(u8, 0b01110111), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNP, .{ @as(u8, 0b1111011), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNO, .{ @as(u8, 0b1110001), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JNS, .{ @as(u8, 0b1111001), FieldName.IPINC8 }),
    makeSpec(t.OperationName.LOOP, .{ @as(u8, 0b11100010), FieldName.IPINC8 }),
    makeSpec(t.OperationName.LOOPZ, .{ @as(u8, 0b11100001), FieldName.IPINC8 }),
    makeSpec(t.OperationName.LOOPNZ, .{ @as(u8, 0b11100000), FieldName.IPINC8 }),
    makeSpec(t.OperationName.JCXZ, .{ @as(u8, 0b11100011), FieldName.IPINC8 }),
};

// In memory representations of decoded bits

const CapturedBits = struct {
    D: ?u1,
    W: ?u1,
    S: ?u1,
    MOD: ?u2,
    REG: ?u3,
    RM: ?u3,
    DATA: ?[]const u8,
    DISP: ?[]const u8,
    IPINC8: ?[]const u8,

    opName: t.OperationName,
    bytesRead: usize,

    pub fn init(opName: t.OperationName) CapturedBits {
        return CapturedBits{
            .D = null,
            .W = null,
            .S = null,
            .MOD = null,
            .REG = null,
            .RM = null,
            .DATA = null,
            .DISP = null,
            .IPINC8 = null,
            .opName = opName,
            .bytesRead = 0,
        };
    }

    pub fn setBitsField(this: *CapturedBits, field: FieldName, value: u16) void {
        switch (field) {
            FieldName.D => this.D = @intCast(value),
            FieldName.W => this.W = @intCast(value),
            FieldName.S => this.S = @intCast(value),
            FieldName.MOD => this.MOD = @intCast(value),
            FieldName.REG => this.REG = @intCast(value),
            FieldName.RM => this.RM = @intCast(value),
            else => {
                std.log.err("Can not set field, maybe it is undefined or multi byte.", .{});
                unreachable;
            },
        }
    }

    pub fn setBytesField(this: *CapturedBits, field: FieldName, value: []const u8) void {
        switch (field) {
            FieldName.DATA => this.DATA = value,
            FieldName.DISP => this.DISP = value,
            FieldName.IPINC8 => this.IPINC8 = value,
            else => {
                std.log.err("Can not set bit field, use setBitsField instead.", .{});
                unreachable;
            },
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
                FieldName.DATA => b: {
                    if (captured.W == null) return AttemptDecodeError.InvalidSpec;
                    if (captured.S != null) {
                        if (captured.S == 0b0 and captured.W == 0b1) {
                            break :b 16;
                        } else {
                            break :b 8;
                        }
                    } else {
                        break :b switch (captured.W.?) {
                            0b0 => 8,
                            0b1 => 16,
                        };
                    }
                },
                FieldName.DISP => switch (captured.MOD orelse return AttemptDecodeError.InvalidSpec) {
                    0b00 => b: {
                        // Special case in table for direct address
                        if (captured.RM == 0b110) {
                            break :b 16;
                        }
                        break :b 0;
                    },
                    0b01 => 8,
                    0b10 => 16,
                    0b11 => 0,
                },
                else => maxFieldBitSize(f.name),
            },
        };

        const noBytes = bitSize == 0;
        if (noBytes) {
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

            switch (ts) {
                .field => |f| captured.setBytesField(f.name, byteSlice),
                .literal => |l| {
                    // Only supporting max 8bit literals until we need longer ones
                    if (l.value != byteSlice[0]) {
                        return AttemptDecodeError.SpecDoesNotMatch;
                    }
                },
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
    try expect(std.mem.readInt(u16, &[_]u8{ 0b00000000, 0b00000001 }, .big) == 1);
    try expect(std.mem.readInt(u16, &[_]u8{ 0b00000000, 0b00000001 }, .little) != 1);
}

// Transform captured bits into instructions

fn findRegister(wide: u1, reg: u3) t.RegisterName {
    return switch (wide) {
        0b0 => switch (reg) {
            0b000 => t.RegisterName.AL,
            0b001 => t.RegisterName.CL,
            0b010 => t.RegisterName.DL,
            0b011 => t.RegisterName.BL,
            0b100 => t.RegisterName.AH,
            0b101 => t.RegisterName.CH,
            0b110 => t.RegisterName.DH,
            0b111 => t.RegisterName.BH,
        },
        0b1 => switch (reg) {
            0b000 => t.RegisterName.AX,
            0b001 => t.RegisterName.CX,
            0b010 => t.RegisterName.DX,
            0b011 => t.RegisterName.BX,
            0b100 => t.RegisterName.SP,
            0b101 => t.RegisterName.BP,
            0b110 => t.RegisterName.SI,
            0b111 => t.RegisterName.DI,
        },
    };
}

const DecodeCapturedBitsError = error{UnrecognizedBits};

fn makeRegOperand(wide: ?u1, reg: u3) !t.Operand {
    const sureWide = wide orelse return DecodeCapturedBitsError.UnrecognizedBits;
    const register = findRegister(sureWide, reg);
    const operandRegister = t.OperandRegister{ .target = register };
    return t.Operand{ .REGISTER = operandRegister };
}

fn makeAddressOperand(rm: u3, mod: u2, disp: ?i16) t.Operand {
    var addressOperand = t.OperandAddress{
        .registers = .{ null, null },
        .value = null,
    };

    const registers: [2]?t.RegisterName = switch (rm) {
        0b000 => [2]?t.RegisterName{ t.RegisterName.BX, t.RegisterName.SI },
        0b001 => [2]?t.RegisterName{ t.RegisterName.BX, t.RegisterName.DI },
        0b010 => [2]?t.RegisterName{ t.RegisterName.BP, t.RegisterName.SI },
        0b011 => [2]?t.RegisterName{ t.RegisterName.BP, t.RegisterName.DI },
        0b100 => [2]?t.RegisterName{ t.RegisterName.SI, null },
        0b101 => [2]?t.RegisterName{ t.RegisterName.DI, null },
        0b110 => b: {
            if (mod == 0b00) {
                break :b [2]?t.RegisterName{ null, null };
            } else {
                break :b [2]?t.RegisterName{ t.RegisterName.BP, null };
            }
        },
        0b111 => [2]?t.RegisterName{ t.RegisterName.BX, null },
    };
    addressOperand.registers = registers;

    const hasDispValue = disp != null and disp.? > 0;
    if (hasDispValue) {
        addressOperand.value = disp;
    }

    return t.Operand{ .ADDRESS = addressOperand };
}

fn makeDecimal(bytes: []const u8) !i16 {
    var data: i16 = undefined;
    switch (bytes.len) {
        1 => {
            data = std.mem.readInt(i8, bytes[0..1], .little);
        },
        2 => {
            data = std.mem.readInt(i16, bytes[0..2], .little);
        },
        else => {
            return DecodeCapturedBitsError.UnrecognizedBits;
        },
    }
    return data;
}

fn decodeCapturedBits(bits: CapturedBits) !t.Instruction {
    var inst = t.Instruction{ .name = bits.opName, .dest = undefined, .source = null, .size = t.Size.UNKNOWN };

    const isCondJump = switch (bits.opName) {
        t.OperationName.JNZ => true,
        t.OperationName.JE => true,
        t.OperationName.JL => true,
        t.OperationName.JLE => true,
        t.OperationName.JB => true,
        t.OperationName.JBE => true,
        t.OperationName.JP => true,
        t.OperationName.JO => true,
        t.OperationName.JS => true,
        t.OperationName.JNE => true,
        t.OperationName.JNL => true,
        t.OperationName.JG => true,
        t.OperationName.JNB => true,
        t.OperationName.JA => true,
        t.OperationName.JNP => true,
        t.OperationName.JNO => true,
        t.OperationName.JNS => true,
        t.OperationName.LOOP => true,
        t.OperationName.LOOPZ => true,
        t.OperationName.LOOPNZ => true,
        t.OperationName.JCXZ => true,
        else => false,
    };

    if (isCondJump and bits.IPINC8 != null) {
        const val: i8 = @bitCast(bits.IPINC8.?[0]);
        const target = t.OperandTarget{ .value = val };
        inst.dest = t.Operand{ .TARGET = target };
    }

    const hasReg = bits.REG != null;
    var regOperand: t.Operand = undefined;
    if (hasReg) {
        regOperand = try makeRegOperand(bits.W, bits.REG.?);
    }

    const hasDisp = bits.DISP != null;
    var disp: ?i16 = null;
    if (hasDisp) {
        disp = try makeDecimal(bits.DISP.?);
    }

    const hasRM = bits.RM != null;
    var rmOperand: t.Operand = undefined;
    if (hasRM) {
        const bitsMOD = bits.MOD orelse return DecodeCapturedBitsError.UnrecognizedBits;
        switch (bitsMOD) {
            0b00, 0b01, 0b10 => {
                rmOperand = makeAddressOperand(bits.RM.?, bits.MOD.?, disp);
            },
            0b11 => {
                rmOperand = try makeRegOperand(bits.W, bits.RM.?);
            },
        }
    }

    const hasD = bits.D != null;
    if (hasD) {
        if (!hasReg or !hasRM) return DecodeCapturedBitsError.UnrecognizedBits;
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
    } else if (hasReg) {
        inst.dest = regOperand;
    } else if (hasRM) {
        inst.dest = rmOperand;
    }

    const hasData = bits.DATA != null;
    if (hasData) {
        const data: i16 = try makeDecimal(bits.DATA.?);
        inst.source = t.Operand{ .IMMEDIATE = t.OperandImmediate{ .value = data } };
    }

    // No obvious destination, check if "immediate to accumulator"
    const noDest = !hasD and !hasReg and !hasRM;
    if (noDest and hasData) {
        const reg: t.RegisterName = switch (bits.W orelse return DecodeCapturedBitsError.UnrecognizedBits) {
            0b0 => t.RegisterName.AL,
            0b1 => t.RegisterName.AX,
        };
        inst.dest = t.Operand{ .REGISTER = t.OperandRegister{ .target = reg } };
    }

    const hasW = bits.W != null;
    if (hasW) {
        inst.size = switch (bits.W.?) {
            0b0 => t.Size.BYTE,
            0b1 => t.Size.WORD,
        };
    }

    return inst;
}

const decodeStreamError = error{ExtraBytesFound};

pub fn decodeStream(memory: []u8, allocator: std.mem.Allocator) ![]t.Instruction {
    var bytesRead: usize = 0;
    var endOfStream = false;
    var captured: ?CapturedBits = null;
    var inst: ?t.Instruction = null;
    var result = std.ArrayList(t.Instruction).empty;

    while (!endOfStream) {
        for (specs) |spec| {
            captured = attemptDecode(spec, memory[bytesRead..]) catch {
                // If are unable to decode the next few bytes using this spec ..
                // .. continue with the next
                continue;
            };
            // If we found a match break out of the loop
            break;
        }

        if (captured == null) {
            std.log.err("{t}: Unexpected bytes found, spec table invalid or incomplete", .{decodeStreamError.ExtraBytesFound});
            std.log.debug("Next several bytes in stream (max 8) =>", .{});
            for (memory[bytesRead..], 0..) |byte, idx| {
                if (idx > 7) break;
                std.log.debug("{b:0>8}", .{byte});
            }
            break;
        }
        const sureCapture = captured.?;

        inst = decodeCapturedBits(sureCapture) catch null;
        if (inst != null) {
            try result.append(allocator, inst.?);
        } else {
            std.log.err("Decoded bit tokens but failed to translate into instruction", .{});
        }

        bytesRead += sureCapture.bytesRead;
        endOfStream = memory.len <= bytesRead;
        captured = null;
    }

    return result.toOwnedSlice(allocator);
}
