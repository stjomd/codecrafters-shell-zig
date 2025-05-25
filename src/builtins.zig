const std = @import("std");
const externals = @import("externals.zig");

const all_builtins = [_]Builtin{
    .exit,
    .echo,
    .type,
    .pwd,
    .cd,
};

pub const Builtin = enum {
    exit,
    echo,
    type,
    pwd,
    cd,

    /// Returns the name of this builtin.
    pub fn name(self: Builtin) []const u8 {
        return switch (self) {
            .exit => "exit",
            .echo => "echo",
            .type => "type",
            .pwd => "pwd",
            .cd => "cd",
        };
    }
    /// Executes the builtin with the specified arguments.
    /// It is assumed that args includes the builtin name at index 0.
    pub fn run(self: Builtin, args: [][]const u8, stdout: anytype, stderr: anytype) !void {
        try switch (self) {
            .exit => exit(args),
            .echo => echo(args, stdout),
            .type => typeCommand(args, stdout, stderr),
            .pwd => pwd(stdout, stderr),
            .cd => cd(args, stderr),
        };
    }
    /// Returns an instance of this enum with the same name as specified.
    pub fn byName(_name: []const u8) ?Builtin {
        for (all_builtins) |builtin| {
            if (std.mem.eql(u8, _name, builtin.name())) {
                return builtin;
            }
        }
        return null;
    }
};

/// Exits the process with a specified exit code.
/// `args` should be the numeric exit code.
fn exit(args: [][]const u8) !void {
    const code = try std.fmt.parseInt(u8, args[1], 10);
    std.process.exit(code);
}

/// Prints the argument to stdout.
/// `args` should be the message to be printed.
fn echo(args: [][]const u8, stdout: anytype) !void {
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
fn typeCommand(args: [][]const u8, stdout: anytype, stderr: anytype) !void {
    const command = Builtin.byName(args[1]);
    if (command) |cmd| {
        try stdout.print("{s} is a shell builtin\n", .{cmd.name()});
        return;
    }

    const externalCommand = try externals.findExecutable(args[1], std.heap.page_allocator);
    if (externalCommand) |path| {
        defer std.heap.page_allocator.free(path);
        try stdout.print("{s} is {s}\n", .{ args[1], path });
        return;
    }

    try stderr.print("{s}: not found\n", .{args[1]});
}

/// Prints current working directory
fn pwd(stdout: anytype, stderr: anytype) !void {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.posix.getcwd(&buf) catch |err| {
        try stderr.print("pwd: {}\n", .{err});
        return;
    };
    try stdout.print("{s}\n", .{cwd});
}

/// Changes current working directory
fn cd(args: [][]const u8, stderr: anytype) !void {
    var path = args[1];

    if (std.mem.eql(u8, path, "~")) {
        const home = externals.getEnv("HOME") catch {
            try stderr.print("cd: $HOME is not set", .{});
            return;
        };
        if (home) |home_path| {
            path = home_path;
        }
    }

    std.posix.chdir(path) catch |err| switch (err) {
        std.posix.ChangeCurDirError.FileNotFound => try stderr.print("cd: {s}: No such file or directory\n", .{path}),
        else => try stderr.print("cd: {s}: {}\n", .{ path, err }),
    };
}
