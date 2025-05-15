const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const is_windows = target.result.os.tag == .windows;

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "umbrella",
        .root_module = exe_mod,
    });

    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const qt6zig = b.dependency("libqt6zig", .{
        .target = target,
        .optimize = .ReleaseFast,
    });

    // After defining the executable, add the module from the library
    exe.root_module.addImport("libqt6zig", qt6zig.module("libqt6zig"));

    // Qt system libraries to link
    var qt_libs: std.ArrayListUnmanaged([]const u8) = .empty;

    try qt_libs.appendSlice(alloc, &[_][]const u8{
        "Qt6Core",
        "Qt6Gui",
        "Qt6Widgets",
        "Qt6Multimedia",
        "Qt6MultimediaWidgets",
        "Qt6PdfWidgets",
        "Qt6PrintSupport",
        "Qt6SvgWidgets",
        "Qt6WebEngineCore",
        "Qt6WebEngineWidgets",
    });

    var qt_win_paths: std.ArrayListUnmanaged([]const u8) = .empty;

    if (is_windows) {
        const win_compilers = &.{
            "mingw_64",
            "llvm-mingw_64",
            "msvc2022_64",
        };

        inline for (win_compilers) |wc| {
            try qt_win_paths.append(alloc, "/mnt/d/qt/bin/6.9.0" ++ wc ++ "/lib");
        }
    }

    if (is_windows) {
        for (qt_win_paths.items) |path| {
            exe.root_module.addLibraryPath(std.Build.LazyPath{ .cwd_relative = path });
        }
    }

    for (qt_libs.items) |lib| {
        exe.root_module.linkSystemLibrary(lib, .{});
    }

    // Link the compiled libqt6zig libraries to the executable
    // qt_lib_name is the name of the target library without prefix and suffix, e.g. qapplication, qwidget, etc.
    var qlibs: std.ArrayListUnmanaged([]const u8) = .empty;
    try qlibs.appendSlice(alloc, &[_][]const u8{
        "qabstractbutton",
        "qapplication",
        "qcoreapplication",
        "qcoreevent",
        "qguiapplication",
        "qobject",
        "qpaintdevice",
        "qpushbutton",
        "qwidget",
    });

    for (qlibs.items) |lib| {
        exe.root_module.linkLibrary(qt6zig.artifact(lib));
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
