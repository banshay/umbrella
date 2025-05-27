const std = @import("std");

pub fn main() !void {
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
}
