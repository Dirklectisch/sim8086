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

pub fn FieldBitSize(comptime name: FieldName) comptime_int {
    return switch (name) {
        FieldName.D => 1,
        FieldName.W => 1,
        FieldName.MOD => 2,
        FieldName.REG => 3,
        FieldName.RM => 3,
    };
}

pub fn FieldType(comptime name: FieldName) type {
    return switch (FieldBitSize(name)) {
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

// In memory representations of decoded instruction

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
};

fn setBitsField(s: *CapturedBits, field: FieldName, value: u8) void {
    switch (field) {
        FieldName.D => s.D = @intCast(value),
        FieldName.W => s.W = @intCast(value),
        FieldName.MOD => s.MOD = @intCast(value),
        FieldName.REG => s.REG = @intCast(value),
        FieldName.RM => s.RM = @intCast(value),
    }
}

const Instruction = struct {
    opName: []const u8,
};

// Decoding logic and utilities

const DecodeBytesError = error{ NotEnoughBytes, SpecDoesNotMatch };

pub fn DecodeBytes(comptime spec: anytype, bytes: []u8) !CapturedBits {
    var captured = CapturedBits.init();
    var bitCursor: u32 = 0;

    inline for (spec, 0..) |s, i| {
        const bitSize = switch (@TypeOf(s)) {
            FieldName => FieldBitSize(s),
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
            FieldName => setBitsField(&captured, s, bits),
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

pub fn main() !void {
    var exampleBytes = [_]u8{ 0b10001010, 0b10101100 };
    const bits = try DecodeBytes(specTable, &exampleBytes);
    std.log.info("{any}", .{bits});
}
