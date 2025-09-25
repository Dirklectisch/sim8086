const std = @import("std");
const decode = @import("decode.zig");
const print = @import("print.zig");

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

// Main entry point

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
        std.log.err("{t}: Reading file at path {s} failed", .{ err, args.path });
        return 1;
    };
    
    print.printInstrXs(instructions, args.path) catch |err| {
        std.log.err("{t}: Printing instruction failed", .{ err });
        return 1;
    };
    
    return 0;
}
