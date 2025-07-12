const std = @import("std");

pub export fn run_command(command_str: [*c]const u8) callconv(.C) i32 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        if (gpa.deinit() == std.heap.Check.leak) {
            std.log.err("Leaked", .{});
        }
    }

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();
    _ = alloc;

    std.debug.print("Hello World from run_command with arg \"{s}\"", .{command_str});

    return 0;
}
