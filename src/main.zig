const std = @import("std");

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

/// A type that represents an executable command.
const Command = struct {
    name: []const u8,
    run: *const fn ([][]const u8) anyerror!void,
};

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const input = try stdin.readUntilDelimiter(&buffer, '\n');

        var argv: [255][]const u8 = undefined;
        const argc = try parseArgs(input, &argv);

        const builtin = findBuiltin(argv[0]);
        if (builtin) |cmd| {
            try cmd.run(argv[0..argc]);
            continue;
        }

        const exe_path = try findExecutable(argv[0], std.heap.page_allocator);
        if (exe_path) |path| {
            defer std.heap.page_allocator.free(path);
            try runExternal(argv[0..argc], std.heap.page_allocator);
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

/// Runs an executable.
fn runExternal(argv: [][]const u8, allocator: std.mem.Allocator) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    var stdout_buf = try std.ArrayListAlignedUnmanaged(u8, null).initCapacity(allocator, 1024);
    var stderr_buf = try std.ArrayListAlignedUnmanaged(u8, null).initCapacity(allocator, 1024);

    try child.spawn();
    try child.collectOutput(allocator, &stdout_buf, &stderr_buf, 2048);
    _ = try child.wait();

    _ = try stderr.write(stderr_buf.items);
    _ = try stdout.write(stdout_buf.items);
}

/// Retrieves the name of the command from the user input, i.e. the substring until the first whitespace.
fn parseName(input: []u8) []const u8 {
    var iter = std.mem.splitScalar(u8, input, ' ');
    const name = iter.next();
    return name orelse unreachable;
}

/// Retrieves a command by its name.
fn findBuiltin(name: []const u8) ?Command {
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
fn exit(args: [][]const u8) !void {
    const code = try std.fmt.parseInt(u8, args[1], 10);
    std.process.exit(code);
}

/// Prints the argument to stdout.
/// `args` should be the message to be printed.
fn echo(args: [][]const u8) !void {
    for (args[1..], 1..) |arg, i| {
        try stdout.print("{s}", .{arg});
        if (i != args[1..].len) {
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

    const externalCommand = try findExecutable(args[1], std.heap.page_allocator);
    if (externalCommand) |path| {
        defer std.heap.page_allocator.free(path);
        try stdout.print("{s} is {s}\n", .{ args[1], path });
        return;
    }
    try stdout.print("{s}: not found\n", .{args[1]});
}

/// Returns the path to the executable with the specified name.
/// The path is search for via the `PATH` environment variable.
fn findExecutable(name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
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
                    const qualp = try allocator.alloc(u8, location.len + 1 + entry.name.len);
                    std.mem.copyForwards(u8, qualp, location);
                    qualp[location.len] = '/';
                    std.mem.copyForwards(u8, qualp[(location.len + 1)..], entry.name);
                    return qualp;
                }
            }
        }
    }
    return null;
}

/// Returns the value of the environment variable with the specified key.
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
