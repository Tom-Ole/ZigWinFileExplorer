const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});
    const optimize = std.builtin.Mode.Debug;

    const exe = b.addExecutable(.{
        .name = "file_explorer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "C:/raylib/include" });
    exe.addObjectFile(.{ .cwd_relative = "C:/raylib/lib/libraylib.a" });

    exe.linkSystemLibrary("mingw32");
    exe.linkSystemLibrary("mingwex");
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("winmm");
    exe.linkSystemLibrary("opengl32");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    b.step("run", "Run the app").dependOn(&run_cmd.step);
}
