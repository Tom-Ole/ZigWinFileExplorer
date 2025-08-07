const std = @import("std");

const c = @cImport({
    @cInclude("raylib.h");
});

const explorer = struct {
    alloc: std.mem.Allocator,
    window_width: c_int,
    window_height: c_int,
    title: [*c]const u8,
    root_dir: []const u8 = "C:/Users/Tom-o/Desktop",
    current_path: []const u8 = "C:/",
    current_dir: ?std.fs.Dir = null,
    dir_entries: std.ArrayList(DirEntry),

    const DirEntry = struct {
        name: []u8,
        kind: std.fs.File.Kind,
        path: []u8,
        size: u64,
    };

    pub fn init(self: *explorer) !void {
        c.InitWindow(self.window_width, self.window_height, self.title);
        c.SetTargetFPS(60);
        c.SetWindowState(c.FLAG_WINDOW_RESIZABLE);

        // TODO: Change default font,

        self.dir_entries = std.ArrayList(DirEntry).init(self.alloc);

        try self.getDirContent(self.root_dir);

        for (self.dir_entries.items) |entry| {
            const type_str = switch (entry.kind) {
                .file => "FILE",
                .directory => "DIR ",
                .sym_link => "LINK",
                else => "????",
            };
            if (entry.kind == .file) {
                std.debug.print("{s}: {s} ({} bytes) - {s}\n", .{ type_str, entry.name, entry.size, entry.path });
            } else {
                std.debug.print("{s}: {s} - {s}\n", .{ type_str, entry.name, entry.path });
            }
        }
    }

    pub fn draw(self: *explorer) void {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);

        const title_text = "File Explorer";
        const title_size: c_int = 30;
        const title_width = c.MeasureText(title_text, title_size);
        c.DrawText(title_text, @divFloor(self.window_width - title_width, 2), 20, title_size, c.DARKGRAY);

        var current_path_buf: [512]u8 = undefined;
        const current_path_text = std.fmt.bufPrintZ(&current_path_buf, "Current: {s}", .{self.current_path}) catch "Current: Error";
        c.DrawText(current_path_text, 10, 60, 20, c.GRAY);

        var y_offset: c_int = 100;
        const line_height: c_int = 25;

        for (self.dir_entries.items) |entry| {
            if (y_offset > self.window_height - 50) break;

            const color = if (entry.kind == .directory) c.BLUE else c.BLACK;
            const prefix = if (entry.kind == .directory) "[DIR]  " else "[FILE] ";

            var display_text_buf: [512]u8 = undefined;
            const display_text = if (entry.kind == .file and entry.size > 0)
                std.fmt.bufPrintZ(&display_text_buf, "{s}{s} ({s})", .{ prefix, entry.name, formatFileSize(entry.size) }) catch "Error"
            else
                std.fmt.bufPrintZ(&display_text_buf, "{s}{s}", .{ prefix, entry.name }) catch "Error";

            c.DrawText(display_text, 20, y_offset, 16, color);
            y_offset += line_height;
        }

        //c.DrawText("Press ESC to exit", 10, self.window_height - 30, 16, c.DARKGRAY);

        c.EndDrawing();
    }

    pub fn close(self: *explorer) void {
        self.deinit();
        c.CloseWindow();
    }

    pub fn deinit(self: *explorer) void {
        for (self.dir_entries.items) |entry| {
            self.alloc.free(entry.name);
            self.alloc.free(entry.path);
        }
        self.dir_entries.deinit();

        if (self.current_dir) |*dir| {
            dir.close();
        }
    }

    pub fn getDirContent(self: *explorer, path: []const u8) !void {
        if (self.current_dir) |*dir| {
            dir.close();
        }

        for (self.dir_entries.items) |entry| {
            self.alloc.free(entry.name);
            self.alloc.free(entry.path);
        }
        self.dir_entries.clearAndFree();

        self.current_dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
            std.debug.print("Failed to open directory {s}: {}\n", .{ path, err });
            return err;
        };

        var iterator = self.current_dir.?.iterate();
        while (try iterator.next()) |entry| {
            const name = try self.alloc.dupe(u8, entry.name);
            const full_path = try std.fs.path.join(self.alloc, &[_][]const u8{ path, entry.name });
            var size: u64 = 0;

            // TODO: Handle size for directories not just files
            if (entry.kind == .file) {
                if (self.current_dir.?.openFile(entry.name, .{})) |file| {
                    defer file.close();
                    if (file.stat()) |stat| {
                        size = stat.size;
                    } else |err| {
                        std.debug.print("Warning: Could not stat file {s}: {}\n", .{ entry.name, err });
                    }
                } else |err| {
                    std.debug.print("Warning: Could not open file {s}: {}\n", .{ entry.name, err });
                }
            }

            const dir_entry = DirEntry{
                .name = name,
                .kind = entry.kind,
                .path = full_path,
                .size = size,
            };

            try self.dir_entries.append(dir_entry);
        }

        std.sort.pdq(DirEntry, self.dir_entries.items, {}, compareEntries);
    }

    fn compareEntries(ctx: void, a: DirEntry, b: DirEntry) bool {
        _ = ctx;
        if (a.kind == .directory and b.kind != .directory) return true;
        if (a.kind != .directory and b.kind == .directory) return false;

        return std.mem.lessThan(u8, a.name, b.name);
    }

    // TODO: get right format size output like "1.2 MB", "3.4 GB", etc.
    // Currently, it just returns "< 1KB", "< 1MB", "<
    fn formatFileSize(size: u64) []const u8 {
        if (size < 1024) return "< 1KB";
        if (size < 1024 * 1024) return "< 1MB";
        if (size < 1024 * 1024 * 1024) return "< 1GB";
        return "> 1GB";
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var exp: explorer = .{
        .alloc = gpa.allocator(),
        .window_width = 1280,
        .window_height = 720,
        .title = "File Explorer",
        .dir_entries = undefined,
    };

    try exp.init();

    while (!c.WindowShouldClose()) {
        exp.draw();
    }

    exp.close();
}
