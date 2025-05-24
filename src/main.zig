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
/// `name` should be the symbol, as a string.
fn typeCommand(name: []u8) !void {
    const command = findCommand(name);
    if (command) |cmd| {
        try stdout.print("{s} is a shell builtin\n", .{cmd.name});
        return;
    }

    const path = try getEnv("PATH");
    if (path) |path_val| {
        var path_iter = std.mem.splitScalar(u8, path_val, ':');
        while (path_iter.next()) |location| {
            var dir = std.fs.cwd().openDir(location, .{ .iterate = true }) catch {
                continue;
            };
            defer dir.close();

            var dir_iter = dir.iterate();
            while (try dir_iter.next()) |entry| {
                if (std.mem.eql(u8, entry.name, name)) {
                    try stdout.print("{s} is {s}/{s}\n", .{ name, location, entry.name });
                    return;
                }
            }
        }
    }
    try stdout.print("{s}: not found\n", .{name});
}

fn getEnv(key: []const u8) !?[]const u8 {
    const allocator = std.heap.page_allocator;

    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    var iter = env.iterator();
    while (iter.next()) |pair| {
        const current_key = pair.key_ptr.*;
        if (std.mem.eql(u8, current_key, key)) {
            const value = pair.value_ptr.*;
            const buf = try allocator.alloc(u8, value.len);
            std.mem.copyForwards(u8, buf, value);
            return buf;
        }
    }
    return null;
}
