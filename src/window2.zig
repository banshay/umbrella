const std = @import("std");
const types = @import("types.zig");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_glfw.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});

const Command = types.Command;
const Step = types.Step;
const CurlStep = types.CurlStep;

const AppData = struct {
    selected_i: ?usize,
    show_demo: bool,
};

fn errorCallback(errn: c_int, str: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error '{}'': {s}", .{ errn, str });
}

pub fn window(alloc: std.mem.Allocator) !void {
    // --- GLFW/SDL Initialization ---
    _ = c.glfwSetErrorCallback(errorCallback);
    if (c.glfwInit() == 0) {
        std.log.err("Failed to initialize GLFW", .{});
        return;
    }
    defer c.glfwTerminate();

    // --- Window Creation (Hidden) ---
    // This is the key part for hiding the main window
    c.glfwWindowHint(c.GLFW_VISIBLE, c.GLFW_FALSE);

    const win = c.glfwCreateWindow(1, 1, "Hidden Main Window", null, null);
    if (win == null) {
        std.log.err("Failed to create GLFW window", .{});
        return;
    }
    defer c.glfwDestroyWindow(win);

    c.glfwMakeContextCurrent(win);
    c.glfwSwapInterval(1); // Enable vsync

    // --- ImGui Initialization ---
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const io = c.ImGui_GetIO();
    // Enable Docking and Viewports
    io.*.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;
    io.*.ConfigFlags |= c.ImGuiConfigFlags_ViewportsEnable;

    c.ImGui_StyleColorsDark(null);

    // When viewports are enabled, we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
    const style = c.ImGui_GetStyle();
    if ((io.*.ConfigFlags & c.ImGuiConfigFlags_ViewportsEnable) != 0) {
        style.*.WindowRounding = 0.0;
        style.*.Colors[c.ImGuiCol_WindowBg].w = 1.0;
    }

    // --- Backend Initialization ---
    _ = c.cImGui_ImplGlfw_InitForOpenGL(win, true);
    defer c.cImGui_ImplGlfw_Shutdown();
    _ = c.cImGui_ImplOpenGL3_Init();
    defer c.cImGui_ImplOpenGL3_Shutdown();

    //initial position
    var win_pos: c.ImVec2 = undefined;
    if (c.glfwGetPrimaryMonitor()) |monitor| {
        const videoMode = c.glfwGetVideoMode(monitor);
        const x: f32 = @floatFromInt(videoMode.*.width);
        const y: f32 = @floatFromInt(videoMode.*.height);
        win_pos = .{
            .x = x * 0.5,
            .y = y * 0.3,
        };
    } else {
        win_pos = .{ .x = 2540, .y = 0 };
    }
    std.log.debug("displaysize (x = {d}, y = {d})", .{ win_pos.x, win_pos.y });

    var app_data = AppData{
        .selected_i = null,
        .show_demo = false,
    };

    // --- Main Loop ---
    var open: bool = true;
    while (open) {
        c.glfwPollEvents();

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplGlfw_NewFrame();
        c.ImGui_NewFrame();

        // An ImGui window that will be visible
        // c.ImGui_ShowDemoWindow(&open);

        if (c.ImGui_Shortcut(c.ImGuiKey_Escape, c.ImGuiInputFlags_RouteGlobal)) open = false;

        // if (app_data.show_demo) {
        //     c.ImGui_ShowDemoWindow(&app_data.show_demo);
        // }

        //main commander contend window
        content(&open, win_pos, &app_data, try testData(alloc));

        c.ImGui_Render();
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());

        // Update and Render additional Platform Windows
        if ((io.*.ConfigFlags & c.ImGuiConfigFlags_ViewportsEnable) != 0) {
            const backup_current_context = c.glfwGetCurrentContext();
            c.ImGui_UpdatePlatformWindows();
            c.ImGui_RenderPlatformWindowsDefault();
            c.glfwMakeContextCurrent(backup_current_context);
        }

        c.glfwSwapBuffers(win);

        //FOR DEBUG ONLY
        // open = false;
    }
}

fn content(open: [*c]bool, win_pos: c.ImVec2, app_data: *AppData, data: []const Command) void {
    const label_width_base = c.ImGui_GetFontSize() * 12;
    const label_width_max = c.ImGui_GetContentRegionAvail().x * 0.40;
    const label_width = @min(label_width_base, label_width_max);
    c.ImGui_PushItemWidth(-label_width);

    var window_flags: c_int = 0;
    window_flags |= c.ImGuiWindowFlags_MenuBar;

    if (!c.ImGui_Begin("Comms", open, window_flags)) {
        c.ImGui_End();
        return;
    }

    if (c.ImGui_BeginMenuBar()) {
        if (c.ImGui_BeginMenu("Tools")) {
            if (c.ImGui_MenuItem("Demo")) {
                app_data.show_demo = true;
            }
        }
        c.ImGui_EndMenu();
    }
    c.ImGui_EndMenuBar();

    for (data, 0..) |command, i| {
        const selected = c.ImGui_SelectableEx(
            @ptrCast(command.command),
            app_data.selected_i != null and app_data.selected_i.? == i,
            c.ImGuiWindowFlags_None,
            .{ .x = 0, .y = 0 },
        );
        if (selected) app_data.selected_i = i;
    }

    const size = c.ImGui_GetWindowSize();
    c.ImGui_SetWindowPos(.{ .x = win_pos.x - (size.x / 2), .y = win_pos.y - (size.y / 2) }, c.ImGuiCond_Once);
    c.ImGui_End();

    if (app_data.selected_i) |i| {
        const command = data[i];
        var command_open = true;

        command_window(command, &command_open, c.ImGui_GetWindowPos());

        if (!command_open) app_data.selected_i = null;
    }
}

fn command_window(command: Command, open: *bool, win_pos: c.ImVec2) void {
    c.ImGui_SetNextWindowPos(
        .{ .x = win_pos.x - 300, .y = win_pos.y - 300 },
        c.ImGuiCond_Once,
    );
    _ = c.ImGui_Begin(command.command.ptr, open, c.ImGuiWindowFlags_None);
    const label_width_base = c.ImGui_GetFontSize() * 12;
    const label_width_max = c.ImGui_GetContentRegionAvail().x * 0.40;
    const label_width = @min(label_width_base, label_width_max);
    c.ImGui_PushItemWidth(-label_width);

    for (command.steps) |step| {
        if (c.ImGui_TreeNode(stepToName(step).ptr)) {
            //have content of step

            step.draw();

            c.ImGui_TreePop();
        }
    }

    c.ImGui_End();
}

fn stepToName(step: Step) []const u8 {
    return switch (step) {
        .curl => "Curl Step",
        .authentication => "Authentication Step",
        .unknown => "Not set",
    };
}

fn testData(alloc: std.mem.Allocator) ![]Command {
    var l = std.ArrayList(Command).init(alloc);
    defer l.deinit();

    var s = std.ArrayList(Step).init(alloc);
    defer s.deinit();

    try s.append(.{ .curl = .{
        .command = try std.fmt.allocPrintZ(alloc, "curl -X POST http://lukas-tfe:8090/api/swagger", .{}),
    } });

    try l.append(.{
        .command = try std.fmt.allocPrintZ(alloc, "sync {{pmsPropertyId}} {{pmsReservationId}}", .{}),
        .steps = try s.toOwnedSlice(),
    });

    return try l.toOwnedSlice();
}

const test_data = &[_]Command{
    Command{
        .command = @constCast(@as([:0]const u8, "sync {pmsPropertyId} {pmsReservationId}")),
        .steps = &[_]Step{
            .{ .curl = CurlStep{ .command = @constCast(@as([:0]const u8, "curl -X POST http://lukas-tfe:8090/api/swagger")) } },
        },
    },
    Command{
        .command = @constCast(@as([:0]const u8, "do something else")),
        .steps = &[_]Step{
            .{ .curl = CurlStep{ .command = @constCast(@as([:0]const u8, "curl -X GET https://api.example.com/data")) } },
        },
    },
};
