const std = @import("std");
const externals = @import("externals.zig");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

/// A type that represents an executable command.
const Command = struct {
    name: []const u8,
    run: *const fn ([][]const u8) anyerror!void,
};

/// Shell builtin commands.
const builtins = [_]Command{
    Command{ .name = "exit", .run = exit },
    Command{ .name = "echo", .run = echo },
    Command{ .name = "type", .run = typeCommand },
};

/// Retrieves a command by its name.
pub fn findBuiltin(name: []const u8) ?Command {
    for (builtins) |command| {
        if (std.mem.eql(u8, name, command.name)) {
            return command;
        }
    }
    return null;
}

/// Exits the process with a specified exit code.
/// `args` should be the numeric exit code.
fn exit(args: [][]const u8) !void {
    const code = try std.fmt.parseInt(u8, args[1], 10);
    std.process.exit(code);
}

/// Prints the argument to stdout.
/// `args` should be the message to be printed.
fn echo(args: [][]const u8) !void {
    const arguments = args[1..];
    for (arguments, 1..) |arg, i| {
        try stdout.print("{s}", .{arg});
        if (i != arguments.len) {
            try stdout.print(" ", .{});
        }
    }
    try stdout.print("\n", .{});
}

/// Prints the type of the symbol.
/// `name` should be the symbol, as a string.
fn typeCommand(args: [][]const u8) !void {
    const command = findBuiltin(args[1]);
    if (command) |cmd| {
        try stdout.print("{s} is a shell builtin\n", .{cmd.name});
        return;
    }

    const externalCommand = try externals.findExecutable(args[1], std.heap.page_allocator);
    if (externalCommand) |path| {
        defer std.heap.page_allocator.free(path);
        try stdout.print("{s} is {s}\n", .{ args[1], path });
        return;
    }

    try stdout.print("{s}: not found\n", .{args[1]});
}
