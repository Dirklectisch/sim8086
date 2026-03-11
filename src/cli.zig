const std = @import("std");
const decode = @import("decode.zig");
const print = @import("print.zig");
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

pub fn parseArgs() ArgumentError!Arguments {
    var parsedArguments: Arguments = undefined;
    const length: usize = std.os.argv.len;
    if (length < 3) {
        return ArgumentError.MissingArgument;
    }
    
    parsedArguments = Arguments{
        .command = undefined,
        .path = undefined
    };

    for (std.os.argv, 0..) |arg, idx| {
        if (idx == 1) {
            const str: []const u8 = std.mem.span(arg);
            parsedArguments.command = std.meta.stringToEnum(Commands, str) orelse {
                return ArgumentError.UnknownCommand; 
            };
        }
        
        if (idx == 2) {
            parsedArguments.path = std.mem.span(arg); 
        }
    }

    return parsedArguments;
}

var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout_writer_ptr  = &stdout_writer.interface;

pub fn main() u8 {
    const args: Arguments = parseArgs() catch |err| {
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
            print.printInstrXs(stdout_writer_ptr,instructions, args.path) catch |err| {
                std.log.err("{t}: Printing instruction failed", .{ err });
                return 1;
            };
        },
        Commands.exec => {
            sim.simProgram(stdout_writer_ptr, instructions) catch |err| {
                std.log.err("{t}: Simulating istructions failed", .{ err });
                return 1;
            };
        }
    }
    
    return 0;
}
