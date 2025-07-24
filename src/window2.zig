const std = @import("std");

const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_glfw.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});

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
    // c.glfwWindowHint(c.GLFW_VISIBLE, c.GLFW_FALSE);

    const win = c.glfwCreateWindow(1280, 720, "Hidden Main Window", null, null);
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

    // --- Main Loop ---
    var open: bool = true;
    while (open) {
        c.glfwPollEvents();

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplGlfw_NewFrame();
        c.ImGui_NewFrame();

        // An ImGui window that will be visible
        // c.ImGui_ShowDemoWindow(&open);
        // content(&open);
        // _ = c.ImGui_DockSpaceOverViewport();
        //
        _ = c.ImGui_Begin("Comms", &open, 0);
        c.ImGui_Text("Hello world from me too");
        c.ImGui_Spacing();
        c.ImGui_End();

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
    }
}

fn content(open: [*c]bool) void {

    // const main_viewport: *c.ImGuiViewport = c.ImGui_GetMainViewport();
    // c.ImGui_SetNextWindowPos(.{
    //     .x = main_viewport.Pos.x + 650,
    //     .y = main_viewport.Pos.y + 20,
    // }, c.ImGuiCond_FirstUseEver);
    // c.ImGui_SetNextWindowSize(.{ .x = 550, .y = 680 }, c.ImGuiCond_FirstUseEver);
    // c.ImGui_SetNextWindowViewport(main_viewport.ID);

    if (!c.ImGui_Begin("Commander", open, c.ImGuiWindowFlags_MenuBar)) {
        c.ImGui_End();
        return;
    }

    const label_width_base = c.ImGui_GetFontSize() * 12;
    const label_width_max = c.ImGui_GetContentRegionAvail().x * 0.40;
    const label_width = @min(label_width_base, label_width_max);
    c.ImGui_PushItemWidth(-label_width);

    // const io = c.ImGui_GetIO();
    // if (io.*.ConfigFlags & c.ImGuiConfigFlags_DockingEnable == 1) {
    //     const dockspace_id = c.ImGui_GetID("MyDockspace");
    //     _ = c.ImGui_DockSpace(dockspace_id);
    // }

    c.ImGui_Text("Hello world in the ui aswell %s", "from the code I guess");

    c.ImGui_End();
}
