const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

/// A type that represents an executable command.
const Command = struct {
    name: []const u8,
    run: *const fn ([]u8) anyerror!void,
};

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const input = try stdin.readUntilDelimiter(&buffer, '\n');

        const name = parseName(input);
        const command = findCommand(name);
        if (command) |cmd| {
            try cmd.run(input[(name.len + 1)..]);
        } else {
            try stdout.print("{s}: command not found\n", .{name});
        }
    }
}

/// Retrieves the name of the command from the user input, i.e. the substring until the first whitespace.
fn parseName(input: []u8) []const u8 {
    var iter = std.mem.splitScalar(u8, input, ' ');
    const name = iter.next();
    return name orelse unreachable;
}

/// Retrieves a command by its name.
fn findCommand(name: []const u8) ?Command {
    for (builtins) |command| {
        if (std.mem.eql(u8, name, command.name)) {
            return command;
        }
    }
    return null;
}

// MARK: - Builtins

/// Shell builtin commands.
const builtins = [_]Command{
    Command{ .name = "exit", .run = exit },
    Command{ .name = "echo", .run = echo },
    Command{ .name = "type", .run = typeCommand },
};

/// Exits the process with a specified exit code.
/// `args` should be the numeric exit code.
fn exit(args: []u8) !void {
    const code = try std.fmt.parseInt(u8, args[0..], 10);
    std.process.exit(code);
}

/// Prints the argument to stdout.
/// `args` should be the message to be printed.
fn echo(args: []u8) !void {
    try stdout.print("{s}\n", .{args[0..]});
}

/// Prints the type of the symbol.
/// `args` should be the symbol, as a string.
fn typeCommand(args: []u8) !void {
    const command = findCommand(args);
    if (command) |cmd| {
        try stdout.print("{s} is a shell builtin\n", .{cmd.name});
    } else {
        try stdout.print("{s}: not found\n", .{args});
    }
}
