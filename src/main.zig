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

const Opcode = enum(u6) {
    mov = 0b100010,
};

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

const Instruction = packed struct {
    rm: u3,
    reg: u3,
    mod: Mode,
    wide: Wide,
    dest: Destination,
    opcode: Opcode,

    fn formatRegister(inst: Instruction, field: enum {rm, reg}) []const u8 {
        const bits: u3 = switch (field) {
            .rm => inst.rm,
            .reg => inst.reg
        };

        return switch (inst.wide) {
            Wide.eight => switch (bits) {
                0b000 => "al",
                0b001 => "cl",
                0b010 => "dl",
                0b011 => "bl",
                0b100 => "ah",
                0b101 => "ch",
                0b110 => "dh",
                0b111 => "bh",
            },
            Wide.sixteen => switch (bits) {
                0b000 => "ax",
                0b001 => "cx",
                0b010 => "dx",
                0b011 => "bx",
                0b100 => "sp",
                0b101 => "bp",
                0b110 => "si",
                0b111 => "di",
            },
        };
    }

    pub fn format(value: Instruction, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const mnemonic = std.enums.tagName(Opcode, value.opcode) orelse unreachable;
        const leftOperand = switch (value.dest) {
            .reg => value.formatRegister(.reg),
            .rm => value.formatRegister(.rm),
        };
        const rightOperand = switch (value.dest) {
            .reg => value.formatRegister(.rm),
            .rm => value.formatRegister(.reg),
        };

        try writer.print("{s} {s},{s}", .{mnemonic, leftOperand, rightOperand});
    }
};

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

    const bytes = file.reader().readInt(u16, std.builtin.Endian.big) catch |err| {
        std.log.err("{!}: Failed to read 16 bits", .{ err });
        return 0;
    };

    const inst: Instruction = @bitCast(bytes);

    const writer = std.io.getStdOut().writer();
    std.fmt.format(writer, "bits 16\n{any}\n", .{inst}) catch |err| {
        std.log.err("{!}: Failed to write to standard out", .{ err });
        return 0;
    };

    return 0;
}

