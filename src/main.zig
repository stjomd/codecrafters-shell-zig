const std = @import("std");

const builtins = @import("builtins.zig");
const externals = @import("externals.zig");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const input = try stdin.readUntilDelimiter(&buffer, '\n');

        var argv: [255][]const u8 = undefined;
        const argc = try parseArgs(input, &argv);

        const builtin = builtins.Builtin.byName(argv[0]);
        if (builtin) |cmd| {
            try cmd.run(argv[0..argc]);
            continue;
        }

        const exe_path = try externals.findExecutable(argv[0], std.heap.page_allocator);
        if (exe_path) |path| {
            defer std.heap.page_allocator.free(path);
            try externals.runExternal(argv[0..argc], std.heap.page_allocator);
            continue;
        }

        try stdout.print("{s}: command not found\n", .{argv[0]});
    }
}

/// Parses an input string and fills the `dest` slice with the parsed arguments.
fn parseArgs(input: []const u8, dest: [][]const u8) !u8 {
    var iter = std.mem.splitScalar(u8, input, ' ');
    var counter: u8 = 0;
    while (iter.next()) |arg| {
        dest[counter] = arg;
        counter += 1;
    }
    return counter;
}
