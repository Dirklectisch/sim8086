const std = @import("std");
const decode = @import("decode.zig");
const p = @import("print.zig");
const sim = @import("sim.zig");

// Command line argument parsing

const Commands = enum {
    exec,
    decode
};

const Arguments = struct {
    command: Commands, 
    path: []const u8,
};

const ArgumentError = error{
    MissingArgument,
    UnknownCommand
};

pub fn parseArgs(args: std.process.Args) ArgumentError!Arguments {
    // Note argument parsing changed in Zig 0.16
    // Link: https://codeberg.org/ziglang/zig/pulls/30644
    var parsedArguments = Arguments{
        .command = undefined,
        .path = undefined
    };

    var idx: u8 = 0;
    var iterate = args.iterate();
    while (iterate.next()) |arg| {
        if (idx == 1) {
            parsedArguments.command = std.meta.stringToEnum(Commands, arg) orelse {
                return ArgumentError.UnknownCommand; 
            };
        }
        
        if (idx == 2) {
            parsedArguments.path = arg; 
        }
        idx = idx + 1;
    }
    
    if (idx < 2) {
        return ArgumentError.MissingArgument;
    }

    return parsedArguments;
}

pub fn main(init: std.process.Init) u8 {
    const args: Arguments = parseArgs(init.minimal.args) catch |err| {
        std.log.err("{t}: Invalid command line arguments", .{err});
        return 1;
    };

    const file = std.fs.cwd().openFile(args.path, .{ .mode = .read_only }) catch |err| {
        std.log.err("{t}: Opening file at path {s} failed", .{ err, args.path });
        return 1;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const megabyte: usize = 1000000;
    const memory = file.readToEndAlloc(allocator, megabyte) catch |err| {
        std.log.err("{t}: Reading file at path {s} failed", .{ err, args.path });
        return 1;
    };

    const instructions = decode.decodeStream(memory, allocator) catch |err| {
        std.log.err("{t}: Decoding instructions in file {s} failed", .{ err, args.path });
        return 1;
    };
    
    switch (args.command) {
        Commands.decode => {
            p.printInstrXs(instructions, args.path);
        },
        Commands.exec => {
            sim.simProgram(instructions) catch |err| {
                std.log.err("{t}: Simulating Instructions failed", .{ err });
                return 1;
            };
        }
    }
    
    p.flush();
    return 0;
}
