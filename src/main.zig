const std = @import("std");

// Command line argument parsing

const Arguments = struct {
    path: []const u8,
};

const ArgumentError = error{
    MissingPath,
};

pub fn parseArgs() ArgumentError!Arguments {
    var parsedArguments: Arguments = undefined;
    const length: usize = std.os.argv.len;
    if (length < 2) {
        return ArgumentError.MissingPath;
    }

    for (std.os.argv, 0..) |arg, idx| {
        if (idx == 1) {
            parsedArguments = Arguments{
                .path = std.mem.span(arg),
            };
        }
    }

    return parsedArguments;
}

// Instruction decoding

const Destination = enum(u1) {
    rm = 0b0,
    reg = 0b1,
};

const Wide = enum(u1) {
    eight = 0, // Byte
    sixteen = 1, // Word
};

const Mode = enum(u2) {
    MemNo = 0b00, // Memory Mode, no displacement
    MemEight = 0b01, // Memory Mode, eight bit displacement
    MemSixt = 0b10, // Memory Mode, sixteen bit displacement
    RegNo = 0b11, // Register Mode, no displacement
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
    pub fn format(val: Register, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var tag: [2]u8 = undefined;
        _ = std.ascii.lowerString(&tag, @tagName(val));
        try writer.print("{s}", .{tag});
    }
};

fn findRegister(wide: Wide, bits: u3) Register {
    return switch (wide) {
        Wide.eight => switch (bits) {
            0b000 => Register.AL,
            0b001 => Register.CL,
            0b010 => Register.DL,
            0b011 => Register.BL,
            0b100 => Register.AH,
            0b101 => Register.CH,
            0b110 => Register.DH,
            0b111 => Register.BH,
        },
        Wide.sixteen => switch (bits) {
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

pub fn takeFourBits(byte: u8) u4 {
    const DividedByte4 = packed struct { right: u4, left: u4 };
    const parts: DividedByte4 = @bitCast(byte);
    return parts.left;
}

pub fn takeSixBits(byte: u8) u6 {
    const DividedByte6 = packed struct { right: u2, left: u6 };
    const parts: DividedByte6 = @bitCast(byte);
    return parts.left;
}

pub fn takeSevenBits(byte: u8) u7 {
    const DividedByte7 = packed struct { right: u2, left: u7 };
    const parts: DividedByte7 = @bitCast(byte);
    return parts.left;
}

const InstMovImToReg = struct {
    opcode: u4,
    w: Wide,
    reg: Register,
    data: i16,

    pub fn format(value: InstMovImToReg, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const mnemonic = "mov";
        try writer.print("{s} {s}, {d}", .{ mnemonic, value.reg, value.data });
    }
};

const DisplLength = enum { eight, sixteen, none };

const EffAddrCalc = struct {
    regs: []const Register,
    dispLength: DisplLength,

    pub fn format(val: EffAddrCalc, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (val.regs, 0..) |reg, idx| {
            if (idx > 0) {
                try writer.print(" + ", .{});
            }
            try writer.print("{s}", .{reg});
        }
    }
};

fn findCalc(mod: Mode, rmbits: u3) EffAddrCalc {
    const notFound = EffAddrCalc{
        .regs = &[_]Register{},
        .dispLength = DisplLength.none,
    };

    return switch (mod) {
        Mode.MemNo => switch (rmbits) {
            0b000 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.SI }, .dispLength = DisplLength.none },
            0b001 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.DI }, .dispLength = DisplLength.none },
            0b010 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.SI }, .dispLength = DisplLength.none },
            0b011 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.DI }, .dispLength = DisplLength.none },
            0b100 => EffAddrCalc{ .regs = &[_]Register{Register.SI}, .dispLength = DisplLength.none },
            0b101 => EffAddrCalc{ .regs = &[_]Register{Register.DI}, .dispLength = DisplLength.none },
            0b111 => EffAddrCalc{ .regs = &[_]Register{Register.BX}, .dispLength = DisplLength.none },
            else => notFound,
        },
        Mode.MemEight => switch (rmbits) {
            0b000 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.SI }, .dispLength = DisplLength.eight },
            0b001 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.DI }, .dispLength = DisplLength.eight },
            0b010 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.SI }, .dispLength = DisplLength.eight },
            0b011 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.DI }, .dispLength = DisplLength.eight },
            0b100 => EffAddrCalc{ .regs = &[_]Register{Register.SI}, .dispLength = DisplLength.eight },
            0b101 => EffAddrCalc{ .regs = &[_]Register{Register.DI}, .dispLength = DisplLength.eight },
            0b110 => EffAddrCalc{ .regs = &[_]Register{Register.BP}, .dispLength = DisplLength.eight },
            0b111 => EffAddrCalc{ .regs = &[_]Register{Register.BX}, .dispLength = DisplLength.eight },
        },
        Mode.MemSixt => switch (rmbits) {
            0b000 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.SI }, .dispLength = DisplLength.sixteen },
            0b001 => EffAddrCalc{ .regs = &[_]Register{ Register.BX, Register.DI }, .dispLength = DisplLength.sixteen },
            0b010 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.SI }, .dispLength = DisplLength.sixteen },
            0b011 => EffAddrCalc{ .regs = &[_]Register{ Register.BP, Register.DI }, .dispLength = DisplLength.sixteen },
            0b100 => EffAddrCalc{ .regs = &[_]Register{Register.SI}, .dispLength = DisplLength.sixteen },
            0b101 => EffAddrCalc{ .regs = &[_]Register{Register.DI}, .dispLength = DisplLength.sixteen },
            0b110 => EffAddrCalc{ .regs = &[_]Register{Register.BP}, .dispLength = DisplLength.sixteen },
            0b111 => EffAddrCalc{ .regs = &[_]Register{Register.BX}, .dispLength = DisplLength.sixteen },
        },
        else => notFound,
    };
}

const RmType = enum { r, m };

const Rm = union(RmType) {
    r: Register,
    m: EffAddrCalc,
    pub fn format(value: Rm, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .r => |*r| try writer.print("{s}", .{r.*}),
            .m => |*m| try writer.print("{s}", .{m.*}),
        }
    }
};

const InstMovRegToMem = struct {
    opcode: u6,
    dest: Destination,
    wide: Wide,
    mod: Mode,
    reg: Register,
    rm: Rm,
    disp: ?i16,
    pub fn format(val: InstMovRegToMem, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {

        const minDisp = val.disp orelse 0;
        const hasDispl = minDisp > 0;
        // mnemonic
        try writer.print("{s} ", .{"mov"});

        // left operand
        if (val.dest == Destination.rm and !hasDispl) {
            try writer.print("[{s}], ", .{val.rm});
        }

        if (val.dest == Destination.rm and hasDispl) {
            try writer.print("[{s} + {?d}], ", .{val.rm, val.disp});
        }

        if (val.dest == Destination.reg) {
            try writer.print("{s}, ", .{val.reg});
        }

        // right operand
        if (val.dest == Destination.rm) {
            try writer.print("{s} ", .{val.reg});
        }

        if (val.dest == Destination.reg and !hasDispl) {
            try writer.print("[{s}]", .{val.rm});
        }

        if (val.dest == Destination.reg and hasDispl) {
            try writer.print("[{s} + {?d}]", .{val.rm, val.disp});
        }
    }
};

const DEBUG = false;

pub fn main() u8 {
    const args: Arguments = parseArgs() catch |err| {
        std.log.err("{!}: Invalid command line arguments", .{err});
        return 1;
    };

    const file = std.fs.cwd().openFile(args.path, .{ .mode = .read_only }) catch |err| {
        std.log.err("{!}: Opening file at path {s} failed", .{ err, args.path });
        return 1;
    };
    defer file.close();

    var eof = false;
    var reader = file.reader();
    const writer = std.io.getStdOut().writer();

    std.fmt.format(writer, "\n\nbits 16\n\n", .{}) catch |err| {
        std.log.err("{!}: Failed to write to standard out", .{err});
        return 1;
    };

    while (eof == false) {
        const firstByte: u8 = reader.readByte() catch {
            eof = true;
            break;
        };

        // immediate to register
        const firstFour: u4 = takeFourBits(firstByte);
        if (firstFour == 0b1011) {
            const ByteOne = packed struct {
                reg: u3,
                w: u1,
                opcode: u4,
            };

            const byteOne: ByteOne = @bitCast(firstByte);
            const wide: Wide = @enumFromInt(byteOne.w);

            const rawByteTwo = reader.readByte() catch {
                eof = true;
                break;
            };

            var data: i16 = undefined;
            if (wide == Wide.eight) {
                data = std.mem.readInt(i8, &[_]u8{ rawByteTwo }, .little);
            }

            var rawByteThree: ?u8 = null;
            if (wide == Wide.sixteen) {
                rawByteThree = reader.readByte() catch {
                    eof = true;
                    break;
                };
                const highBits = rawByteThree orelse unreachable;
                data = std.mem.readInt(i16, &[_]u8{ rawByteTwo, highBits }, .little);
            }

            const inst = InstMovImToReg{
                .opcode = byteOne.opcode,
                .w = wide,
                .reg = findRegister(wide, byteOne.reg),
                .data = data,
            };

            if (DEBUG) {
                if (wide == Wide.sixteen) {
                    std.log.debug("{b:0>8} {b:0>8} {?b:0>8}", .{ firstByte, rawByteTwo, rawByteThree });
                } else {
                    std.log.debug("{b:0>8} {b:0>8}", .{ firstByte, rawByteTwo });
                }
            }

            std.fmt.format(writer, "{any}\n", .{inst}) catch |err| {
                std.log.err("{!}: Failed to write to standard out", .{err});
                return 1;
            };

            continue;
        }

        // Register /memory to/from register
        const firstSix: u6 = takeSixBits(firstByte);
        if (firstSix == 0b100010) {
            const ByteOne = packed struct { w: u1, d: u1, opcode: u6 };
            const byteOne: ByteOne = @bitCast(firstByte);

            const ByteTwo = packed struct { rm: u3, reg: u3, mod: u2 };
            const rawByteTwo: u8 = reader.readByte() catch {
                eof = true;
                break;
            };
            const byteTwo: ByteTwo = @bitCast(rawByteTwo);

            const wide: Wide = @enumFromInt(byteOne.w);
            const mod: Mode = @enumFromInt(byteTwo.mod);
            const rm: Rm = switch (mod) {
                Mode.MemNo => Rm{ .m = findCalc(mod, byteTwo.rm) },
                Mode.MemEight => Rm{ .m = findCalc(mod, byteTwo.rm) },
                Mode.MemSixt => Rm{ .m = findCalc(mod, byteTwo.rm) },
                Mode.RegNo => Rm{ .r = findRegister(wide, byteTwo.rm) },
            };

            var disp: ?i16 = null;
            var rawByteThree: ?u8 = null;
            if (mod == Mode.MemEight or mod == Mode.MemSixt) {
                rawByteThree = reader.readByte() catch {
                    eof = true;
                    break;
                };
                disp = rawByteThree orelse null;
            }

            var rawByteFour: ?u8 = null;
            if (mod == Mode.MemSixt) {
                rawByteFour = reader.readByte() catch {
                    eof = true;
                    break;
                };
                disp = std.mem.readInt(i16, &[_]u8{ rawByteThree orelse unreachable, rawByteFour orelse unreachable }, .little);
            }

            const inst = InstMovRegToMem{
                .opcode = byteOne.opcode,
                .dest = @enumFromInt(byteOne.d),
                .wide = wide,
                .mod = mod,
                .reg = findRegister(wide, byteTwo.reg),
                .rm = rm,
                .disp = disp,
            };

            if (DEBUG) {
                switch (mod) {
                    Mode.RegNo => std.log.debug("{b:0>8} {b:0>8}", .{ firstByte, rawByteTwo }),
                    Mode.MemNo => std.log.debug("{b:0>8} {b:0>8}", .{ firstByte, rawByteTwo }),
                    Mode.MemEight => std.log.debug("{b:0>8} {b:0>8} {?b:0>8}", .{ firstByte, rawByteTwo, rawByteThree }),
                    Mode.MemSixt => std.log.debug("{b:0>8} {b:0>8} {?b:0>8} {?b:0>8}", .{ firstByte, rawByteTwo, rawByteThree, rawByteFour }),
                }
            }

            std.fmt.format(writer, "{any}\n", .{inst}) catch |err| {
                std.log.err("{!}: Failed to write to standard out", .{err});
                return 1;
            };

            continue;
        }

        std.log.warn("Byte skipped: {b:0>8}", .{firstByte});
    }

    return 0;
}
