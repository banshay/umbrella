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

fn errorCallback(errn: c_int, str: [*c]const u8) callconv(.C) void {
    std.log.err("GLFW Error '{}'': {s}", .{ errn, str });
}

pub fn window() !void {
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

    // --- Main Loop ---
    var open: bool = true;
    while (open) {
        c.glfwPollEvents();

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplGlfw_NewFrame();
        c.ImGui_NewFrame();

        // An ImGui window that will be visible
        // c.ImGui_ShowDemoWindow(&open);

        //main commander contend window
        content(&open, win_pos);

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

fn content(open: [*c]bool, win_pos: c.ImVec2) void {
    const label_width_base = c.ImGui_GetFontSize() * 12;
    const label_width_max = c.ImGui_GetContentRegionAvail().x * 0.40;
    const label_width = @min(label_width_base, label_width_max);
    c.ImGui_PushItemWidth(-label_width);

    if (!c.ImGui_Begin("Comms", open, 0)) {
        c.ImGui_End();
        return;
    }

    c.ImGui_Text("Hello world in the ui aswell %s", "from the code I guess");

    const size = c.ImGui_GetWindowSize();
    c.ImGui_SetWindowPos(.{ .x = win_pos.x - (size.x / 2), .y = win_pos.y - (size.y / 2) }, c.ImGuiCond_Once);
    c.ImGui_End();
}

const data: Command = &[_]Command{
    .{ .step = &[_]Step{CurlStep{ .command = "curl -X GET http://localhost:8090/api/swagger" }} },
};
