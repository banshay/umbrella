const std = @import("std");
const capy = @import("capy");
pub usingnamespace capy.cross_platform;

var counter: isize = 0;

pub fn main() !void {
    try capy.init();

    var window = try capy.Window.init();
    window.setPreferredSize(800, 600);
    try window.set(capy.navigationSidebar(.{}));
    window.show();
    capy.runEventLoop();
}
