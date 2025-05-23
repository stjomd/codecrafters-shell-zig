const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const input = try stdin.readUntilDelimiter(&buffer, '\n');
        try command(input);
    }
}

fn command(input: []u8) !void {
    if (std.mem.startsWith(u8, input, "exit")) {
        try exit(input[4..]);
    } else {
        try stdout.print("{s}: command not found\n", .{input});
    }
}

fn exit(args: []u8) !void {
    const code = try std.fmt.parseInt(u8, args[1..], 10);
    std.process.exit(code);
}
