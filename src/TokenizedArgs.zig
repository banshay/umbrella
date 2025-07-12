const std = @import("std");
const t = std.testing;

const Allocator = std.mem.Allocator;
const Self = @This();

alloc: Allocator,
tokens: [][]const u8,
wildcards_flag: u64 = 0,
wildcards: std.StringHashMap([]const u8),

pub fn fromArgs(alloc: Allocator, args: std.process.ArgIterator) !Self {
    var tokens = std.ArrayList([]const u8).init(alloc);
    var wc = std.StringHashMap([]const u8).init(alloc);
    var wc_flag: u64 = 0;

    var i: usize = 0;
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, ":{") and std.mem.endsWith(u8, arg, "}")) {
            wc_flag = wc_flag | 0b1 << i;
            try wc.put(arg[2..-1], i);
        }
        try tokens.append(arg);

        i += 1;
    }
    return .{
        .alloc = alloc,
        .tokens = try tokens.toOwnedSlice(),
        .wildcard_flag = wc_flag,
        .wildcards = wc,
    };
}

pub fn fromStr(alloc: Allocator, arg_str: []const u8) !Self {
    var split = std.mem.splitAny(u8, arg_str, " ");
    var tokens = std.ArrayList([]const u8).init(alloc);
    while (split.next()) |arg| {
        try tokens.append(arg);
    }
    return .{
        .alloc = alloc,
        .tokens = try tokens.toOwnedSlice(),
    };
}

pub fn deinit(self: *const Self) void {
    self.alloc.free(self.tokens);
}

pub fn matches(self: *const Self, other: *const Self, wildcards: u64) bool {
    var match: bool = true;
    for (other.tokens, 0..) |o, i| {
        if (!match) return match;
        // std.log.warn("checking flag {b} is {}", .{ wildcards >> @intCast(i), wildcards >> @intCast(i) & 0b1 == 0 });
        if (wildcards >> @intCast(i) & 0b1 == 0) {
            const left = if (self.tokens.len >= i) self.tokens[i] else return false;
            match = std.mem.eql(u8, left, o);
        }
    }
    return match;
}

test matches {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const a1 = try Self.fromStr(alloc, "sync TESY 4733526");
    const b1 = try Self.fromStr(alloc, "synct :{pms_property_id} :{pms_reservation_id}");
    const f1: u64 = 0b1 << 2 | 0b1 << 1;
    try t.expectEqual(false, a1.matches(&b1, f1));

    const a2 = try Self.fromStr(alloc, "sync TESY 4733526");
    const b2 = try Self.fromStr(alloc, "sync :{pms_property_id} :{pms_reservation_id}");
    const f2: u64 = 0b1 << 2 | 0b1 << 1;
    try t.expectEqual(true, a2.matches(&b2, f2));
}

