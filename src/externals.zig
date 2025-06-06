const std = @import("std");

/// Runs an executable.
pub fn runExternal(argv: [][]const u8, allocator: std.mem.Allocator, stdout: anytype, stderr: anytype) !void {
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

/// Returns the path to the executable with the specified name.
/// The path is search for via the `PATH` environment variable.
pub fn findExecutable(name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    const path = try getEnv("PATH");
    if (path) |path_val| {
        var path_iter = std.mem.splitScalar(u8, path_val, ':');
        while (path_iter.next()) |location| {
            return try findInDir(location, name, allocator) orelse {
                continue;
            };
        }
    }
    return null;
}

/// Looks for the executable with the specified name in the specified directory.
/// Returns the path to the executable if found, and `null` otherwise.
fn findInDir(location: []const u8, name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
    var dir = std.fs.cwd().openDir(location, .{ .iterate = true }) catch {
        return null;
    };
    defer dir.close();

    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            const qual_path = try allocator.alloc(u8, location.len + 1 + entry.name.len);
            std.mem.copyForwards(u8, qual_path, location);
            qual_path[location.len] = '/';
            std.mem.copyForwards(u8, qual_path[(location.len + 1)..], entry.name);
            return qual_path;
        }
    }
    return null;
}

/// Returns the value of the environment variable with the specified key.
pub fn getEnv(key: []const u8) !?[]const u8 {
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
