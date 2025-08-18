const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_glfw.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});

pub const StepType = enum {
    authentication,
    curl,
    unknown,
};

pub const Step = union(StepType) {
    authentication: AuthenticationStep,
    curl: CurlStep,
    unknown: UnknownStep,

    pub fn draw(self: Step) void {
        switch (self) {
            inline else => |step| step.draw(),
        }
    }
};

pub const Command = struct {
    command: [:0]u8,
    steps: []const Step,
};

pub const CurlStep = struct {
    command: [:0]u8,

    pub fn draw(self: CurlStep) void {
        _ = c.ImGui_InputTextMultiline("command", self.command.ptr, self.command.len);
    }
};

pub const AuthenticationStep = struct {
    pub fn draw(self: AuthenticationStep) void {
        _ = self;
    }
};

pub const UnknownStep = struct {
    pub fn draw(_: UnknownStep) void {}
};
