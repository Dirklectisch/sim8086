const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "sim8086",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    b.installArtifact(exe);
}
