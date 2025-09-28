const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "sim8086",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cli.zig"),
            .target = b.graph.host,
        }),
    });
    b.installArtifact(exe);
}
