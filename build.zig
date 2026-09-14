const std = @import("std");

const sdl_sources = [_]struct { dir: []const u8, files: []const []const u8 }{
    .{ .dir = "src", .files = &.{
        "SDL.c",
        "SDL_assert.c",
        "SDL_error.c",
        "SDL_guid.c",
        "SDL_hashtable.c",
        "SDL_hints.c",
        "SDL_list.c",
        "SDL_log.c",
        "SDL_properties.c",
        "SDL_utils.c",
    } },
    .{ .dir = "src/dynapi", .files = &.{"SDL_dynapi.c"} },
    .{ .dir = "src/core", .files = &.{"SDL_core_unsupported.c"} },
    .{ .dir = "src/core/windows", .files = &.{
        "SDL_hid.c",
        "SDL_immdevice.c",
        "SDL_windows.c",
        "SDL_xinput.c",
    } },
    .{ .dir = "src/events", .files = &.{
        "SDL_categories.c",
        "SDL_clipboardevents.c",
        "SDL_displayevents.c",
        "SDL_dropevents.c",
        "SDL_events.c",
        "SDL_eventwatch.c",
        "SDL_keyboard.c",
        "SDL_keymap.c",
        "SDL_keysym_to_keycode.c",
        "SDL_keysym_to_scancode.c",
        "SDL_mouse.c",
        "SDL_pen.c",
        "SDL_quit.c",
        "SDL_scancode_tables.c",
        "SDL_touch.c",
        "SDL_windowevents.c",
        "imKStoUCS.c",
    } },
    .{ .dir = "src/video", .files = &.{
        "SDL_RLEaccel.c",
        "SDL_blit.c",
        "SDL_blit_0.c",
        "SDL_blit_1.c",
        "SDL_blit_A.c",
        "SDL_blit_N.c",
        "SDL_blit_auto.c",
        "SDL_blit_copy.c",
        "SDL_blit_slow.c",
        "SDL_bmp.c",
        "SDL_clipboard.c",
        "SDL_egl.c",
        "SDL_fillrect.c",
        "SDL_pixels.c",
        "SDL_rect.c",
        "SDL_rotate.c",
        "SDL_stb.c",
        "SDL_stretch.c",
        "SDL_surface.c",
        "SDL_video.c",
        "SDL_video_unsupported.c",
        "SDL_vulkan_utils.c",
        "SDL_yuv.c",
    } },
    .{ .dir = "src/video/windows", .files = &.{
        "SDL_windowsclipboard.c",
        "SDL_windowsevents.c",
        "SDL_windowsframebuffer.c",
        "SDL_windowskeyboard.c",
        "SDL_windowsmessagebox.c",
        "SDL_windowsmodes.c",
        "SDL_windowsmouse.c",
        "SDL_windowsopengl.c",
        "SDL_windowsopengles.c",
        "SDL_windowsrawinput.c",
        "SDL_windowsshape.c",
        "SDL_windowsvideo.c",
        "SDL_windowsvulkan.c",
        "SDL_windowswindow.c",
    } },
    .{ .dir = "src/video/yuv2rgb", .files = &.{
        "yuv_rgb_std.c",
        "yuv_rgb_sse.c",
        "yuv_rgb_lsx.c",
    } },
    .{ .dir = "src/thread", .files = &.{"SDL_thread.c"} },
    .{ .dir = "src/thread/windows", .files = &.{
        "SDL_syscond_cv.c",
        "SDL_sysmutex.c",
        "SDL_sysrwlock_srw.c",
        "SDL_syssem.c",
        "SDL_systhread.c",
        "SDL_systls.c",
    } },
    .{ .dir = "src/thread/generic", .files = &.{
        "SDL_syscond.c",
        "SDL_sysrwlock.c",
    } },
    .{ .dir = "src/timer", .files = &.{"SDL_timer.c"} },
    .{ .dir = "src/timer/windows", .files = &.{"SDL_systimer.c"} },
    .{ .dir = "src/time", .files = &.{"SDL_time.c"} },
    .{ .dir = "src/time/windows", .files = &.{"SDL_systime.c"} },
    .{ .dir = "src/filesystem", .files = &.{"SDL_filesystem.c"} },
    .{ .dir = "src/filesystem/windows", .files = &.{
        "SDL_sysfilesystem.c",
        "SDL_sysfsops.c",
    } },
    .{ .dir = "src/render", .files = &.{
        "SDL_render.c",
        "SDL_render_unsupported.c",
        "SDL_yuv_sw.c",
    } },
    .{ .dir = "src/render/software", .files = &.{
        "SDL_blendfillrect.c",
        "SDL_blendline.c",
        "SDL_blendpoint.c",
        "SDL_drawline.c",
        "SDL_drawpoint.c",
        "SDL_render_sw.c",
        "SDL_triangle.c",
    } },
    .{ .dir = "src/tray/dummy", .files = &.{"SDL_tray.c"} },
    .{ .dir = "src/tray", .files = &.{"SDL_tray_utils.c"} },
    .{ .dir = "src/main", .files = &.{"SDL_main_callbacks.c"} },
    .{ .dir = "src/joystick", .files = &.{
        "SDL_gamepad.c",
        "SDL_joystick.c",
        "SDL_steam_virtual_gamepad.c",
        "controller_type.c",
    } },
    .{ .dir = "src/joystick/windows", .files = &.{
        "SDL_dinputjoystick.c",
        "SDL_rawinputjoystick.c",
        "SDL_windows_gaming_input.c",
        "SDL_windowsjoystick.c",
        "SDL_xinputjoystick.c",
    } },
    .{ .dir = "src/joystick/virtual", .files = &.{"SDL_virtualjoystick.c"} },
    .{ .dir = "src/sensor", .files = &.{"SDL_sensor.c"} },
    .{ .dir = "src/sensor/dummy", .files = &.{"SDL_dummysensor.c"} },
    .{ .dir = "src/loadso/windows", .files = &.{"SDL_sysloadso.c"} },
    .{ .dir = "src/stdlib", .files = &.{
        "SDL_crc16.c",
        "SDL_crc32.c",
        "SDL_getenv.c",
        "SDL_iconv.c",
        "SDL_malloc.c",
        "SDL_memcpy.c",
        "SDL_memmove.c",
        "SDL_memset.c",
        "SDL_mslibc.c",
        "SDL_murmur3.c",
        "SDL_qsort.c",
        "SDL_random.c",
        "SDL_stdlib.c",
        "SDL_string.c",
        "SDL_strtokr.c",
    } },
    .{ .dir = "src/libm", .files = &.{
        "e_atan2.c",
        "e_exp.c",
        "e_fmod.c",
        "e_log.c",
        "e_log10.c",
        "e_pow.c",
        "e_rem_pio2.c",
        "e_sqrt.c",
        "k_cos.c",
        "k_rem_pio2.c",
        "k_sin.c",
        "k_tan.c",
        "s_atan.c",
        "s_copysign.c",
        "s_cos.c",
        "s_fabs.c",
        "s_floor.c",
        "s_isinf.c",
        "s_isinff.c",
        "s_isnan.c",
        "s_isnanf.c",
        "s_modf.c",
        "s_scalbn.c",
        "s_sin.c",
        "s_tan.c",
    } },
    .{ .dir = "src/io", .files = &.{
        "SDL_asyncio.c",
        "SDL_iostream.c",
    } },
    .{ .dir = "src/io/generic", .files = &.{"SDL_asyncio_generic.c"} },
    .{ .dir = "src/locale", .files = &.{"SDL_locale.c"} },
    .{ .dir = "src/locale/windows", .files = &.{"SDL_syslocale.c"} },
    .{ .dir = "src/misc", .files = &.{"SDL_url.c"} },
    .{ .dir = "src/misc/windows", .files = &.{"SDL_sysurl.c"} },
    .{ .dir = "src/atomic", .files = &.{
        "SDL_atomic.c",
        "SDL_spinlock.c",
    } },
    .{ .dir = "src/cpuinfo", .files = &.{"SDL_cpuinfo.c"} },
};

const sdl_c_flags = [_][]const u8{
    "-std=gnu11",
    "-DSDL_BUILD_MAJOR_VERSION=3",
    "-DSDL_BUILD_MINOR_VERSION=4",
    "-DSDL_BUILD_MICRO_VERSION=14",
    "-DDYNAPI_NEEDS_DLOPEN=1",
};

fn unsupportedTarget(t: std.Target) noreturn {
    std.process.fatal(
        "NumericDream has no prebuilt wgpu-native for {s}-{s}. " ++
            "Supported targets: x86_64-windows, x86_64-linux, aarch64-linux.",
        .{ @tagName(t.cpu.arch), @tagName(t.os.tag) },
    );
}

fn addPkgConfigIncludes(b: *std.Build, tc: *std.Build.Step.TranslateC, pkg: []const u8) void {
    var exit_code: u8 = undefined;
    const stdout = b.runAllowFail(
        &.{ "pkg-config", "--cflags-only-I", pkg },
        &exit_code,
        .ignore,
    ) catch return;

    var it = std.mem.tokenizeAny(u8, stdout, " \t\r\n");
    while (it.next()) |tok| {
        if (std.mem.startsWith(u8, tok, "-I") and tok.len > 2) {
            tc.addIncludePath(.{ .cwd_relative = tok[2..] });
        }
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const t = target.result;

    const sdl_prefix_opt = b.option(
        []const u8,
        "sdl-prefix",
        "Root of a Linux SDL3 install, holding <prefix>/include/SDL3 and " ++
            "<prefix>/lib/libSDL3.so. Overrides the sysroot vendored at " ++
            "vendor/sdl3_linux that a cross-build uses by default; a native " ++
            "Linux build finds SDL3 through pkg-config instead.",
    );

    const cross_to_linux = t.os.tag == .linux and
        t.cpu.arch == .x86_64 and
        b.graph.host.result.os.tag != .linux;

    const sdl_inc: ?std.Build.LazyPath, const sdl_lib: ?std.Build.LazyPath =
        if (sdl_prefix_opt) |p| .{
            .{ .cwd_relative = b.pathJoin(&.{ p, "include" }) },
            .{ .cwd_relative = b.pathJoin(&.{ p, "lib" }) },
        } else if (cross_to_linux) .{
            b.path("vendor/sdl3_linux/include"),
            b.path("vendor/sdl3_linux/lib"),
        } else .{ null, null };

    const wgpu_pkg: []const u8 = switch (t.os.tag) {
        .windows => switch (t.cpu.arch) {
            .x86_64 => "wgpu_native_windows_x86_64",
            else => unsupportedTarget(t),
        },
        .linux => switch (t.cpu.arch) {
            .x86_64 => "wgpu_native_linux_x86_64",
            .aarch64 => "wgpu_native_linux_aarch64",
            else => unsupportedTarget(t),
        },
        else => unsupportedTarget(t),
    };
    const wgpu_dep = b.lazyDependency(wgpu_pkg, .{}) orelse return;

    const sdl3_dep: ?*std.Build.Dependency = if (t.os.tag == .windows)
        (b.lazyDependency("sdl3", .{}) orelse return)
    else
        null;

    const exe = b.addExecutable(.{
        .name = "NumericDream",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    const mod = exe.root_module;

    // --- SDL3 ---
    switch (t.os.tag) {
        .windows => {
            const sdl3 = sdl3_dep.?;
            mod.addIncludePath(sdl3.path("include"));
            mod.addIncludePath(sdl3.path("src"));
            mod.addIncludePath(b.path("vendor/sdl_config"));
            for (sdl_sources) |group| {
                mod.addCSourceFiles(.{
                    .root = sdl3.path(group.dir),
                    .files = group.files,
                    .flags = &sdl_c_flags,
                });
            }
            const cpp_flags = [_][]const u8{
                "-std=gnu++17",
                "-DSDL_BUILD_MAJOR_VERSION=3",
                "-DSDL_BUILD_MINOR_VERSION=4",
                "-DSDL_BUILD_MICRO_VERSION=14",
                "-DDYNAPI_NEEDS_DLOPEN=1",
            };
            mod.addCSourceFiles(.{
                .root = sdl3.path(""),
                .files = &.{
                    "src/core/windows/SDL_gameinput.cpp",
                    "src/video/windows/SDL_windowsgameinput.cpp",
                },
                .flags = &cpp_flags,
            });

            for ([_][]const u8{
                "user32",   "gdi32",    "shell32", "advapi32", "ole32",
                "oleaut32", "imm32",    "version", "setupapi", "winmm",
                "shlwapi",  "comdlg32",
            }) |lib| mod.linkSystemLibrary(lib, .{ .use_pkg_config = .no });
        },
        .linux => {
            if (sdl_inc) |inc| {
                mod.addIncludePath(inc);
                mod.addLibraryPath(sdl_lib.?);
                mod.linkSystemLibrary("SDL3", .{ .use_pkg_config = .no });
            } else {
                mod.linkSystemLibrary("SDL3", .{ .use_pkg_config = .yes });
            }
        },
        else => unsupportedTarget(t),
    }

    mod.addIncludePath(b.path("vendor/nuklear"));
    mod.addCSourceFile(.{
        .file = b.path("src/bindings/nuklear_impl.c"),
        .flags = &.{"-std=gnu11"},
    });

    mod.addIncludePath(b.path("vendor/stb"));
    mod.addCSourceFile(.{
        .file = b.path("src/bindings/stb_image_write_impl.c"),
        .flags = &.{ "-std=gnu11", "-fno-sanitize=undefined" },
    });

    mod.addCSourceFile(.{
        .file = b.path("src/bindings/stb_image_impl.c"),
        .flags = &.{ "-std=gnu11", "-fno-sanitize=undefined" },
    });

    mod.addIncludePath(wgpu_dep.path("include"));
    mod.addLibraryPath(wgpu_dep.path("lib"));
    mod.linkSystemLibrary("wgpu_native", .{ .use_pkg_config = .no });
    switch (t.os.tag) {
        .windows => {
            for ([_][]const u8{ "ws2_32", "userenv", "ntdll", "bcrypt" }) |lib| {
                mod.linkSystemLibrary(lib, .{ .use_pkg_config = .no });
            }
        },
        .linux => {
            mod.addRPathSpecial("$ORIGIN");
        },
        else => unsupportedTarget(t),
    }

    const sdl3_tc = b.addTranslateC(.{
        .root_source_file = b.path("src/bindings/sdl3_shim.h"),
        .target = target,
        .optimize = optimize,
    });
    if (sdl3_dep) |sdl3| {
        sdl3_tc.addIncludePath(b.path("src/bindings/translate_c_shims"));
        sdl3_tc.addIncludePath(sdl3.path("include"));
    } else if (sdl_inc) |inc| {
        sdl3_tc.addIncludePath(inc);
    } else {
        addPkgConfigIncludes(b, sdl3_tc, "sdl3");
    }
    mod.addImport("sdl3_c", sdl3_tc.createModule());

    const webgpu_tc = b.addTranslateC(.{
        .root_source_file = b.path("src/bindings/webgpu_shim.h"),
        .target = target,
        .optimize = optimize,
    });
    webgpu_tc.addIncludePath(wgpu_dep.path("include"));
    mod.addImport("webgpu_c", webgpu_tc.createModule());

    const nuklear_tc = b.addTranslateC(.{
        .root_source_file = b.path("src/bindings/nuklear_shim.h"),
        .target = target,
        .optimize = optimize,
    });
    nuklear_tc.addIncludePath(b.path("vendor/nuklear"));
    mod.addImport("nuklear_c", nuklear_tc.createModule());

    const stb_image_write_tc = b.addTranslateC(.{
        .root_source_file = b.path("src/bindings/stb_image_write_shim.h"),
        .target = target,
        .optimize = optimize,
    });
    stb_image_write_tc.addIncludePath(b.path("vendor/stb"));
    mod.addImport("stb_image_write_c", stb_image_write_tc.createModule());

    const stb_image_tc = b.addTranslateC(.{
        .root_source_file = b.path("src/bindings/stb_image_shim.h"),
        .target = target,
        .optimize = optimize,
    });
    stb_image_tc.addIncludePath(b.path("vendor/stb"));
    mod.addImport("stb_image_c", stb_image_tc.createModule());

    b.installArtifact(exe);

    const wgpu_lib_name = switch (t.os.tag) {
        .windows => "wgpu_native.dll",
        .linux => "libwgpu_native.so",
        else => unsupportedTarget(t),
    };
    const install_lib = b.addInstallFileWithDir(
        wgpu_dep.path(b.fmt("lib/{s}", .{wgpu_lib_name})),
        .bin,
        wgpu_lib_name,
    );
    b.getInstallStep().dependOn(&install_lib.step);

    const install_formulas = b.addInstallDirectory(.{
        .source_dir = b.path("formulas"),
        .install_dir = .bin,
        .install_subdir = "formulas",
        .include_extensions = &.{".wgsl"},
    });
    b.getInstallStep().dependOn(&install_formulas.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
}
