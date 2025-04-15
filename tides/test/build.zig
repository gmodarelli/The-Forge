const std = @import("std");

pub fn buildExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "ze-forge-test",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const abi = (std.zig.system.resolveTargetQuery(target.query) catch unreachable).abi;
    exe.linkLibC();
    if (abi != .msvc) {
        exe.linkLibCpp();
    }

    const ze_forge = b.dependency("ze_forge", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ze_forge", ze_forge.module("ze_forge"));
    exe.linkLibrary(ze_forge.artifact("ze_forge_c_cpp"));

    exe.addLibraryPath(b.path("../../Common_3/Graphics/ThirdParty/OpenSource/nvapi/amd64/"));
    exe.addLibraryPath(b.path("../../Common_3/Graphics/ThirdParty/OpenSource/ags/ags_lib/lib"));
    exe.addLibraryPath(b.path("../../Common_3/Graphics/ThirdParty/OpenSource/winpixeventruntime/bin"));

    exe.addObjectFile(b.path("../../Common_3/Graphics/ThirdParty/OpenSource/ags/ags_lib/lib/amd_ags_x64.lib"));
    exe.addObjectFile(b.path("../../Common_3/Graphics/ThirdParty/OpenSource/winpixeventruntime/bin/WinPixEventRuntime.lib"));
    // exe.linkSystemLibrary("amd_ags_x64");
    // exe.linkSystemLibrary("WinPixEventRuntime");
    exe.linkSystemLibrary("dxcompiler");
    exe.linkSystemLibrary("nvapi64");
    exe.linkSystemLibrary("kernel32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("winspool");
    exe.linkSystemLibrary("comdlg32");
    exe.linkSystemLibrary("advapi32");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("oleaut32");
    exe.linkSystemLibrary("uuid");
    exe.linkSystemLibrary("odbc32");
    exe.linkSystemLibrary("odbccp32");
    exe.linkSystemLibrary("dxguid");
    exe.linkSystemLibrary("d3d12");
    exe.linkSystemLibrary("legacy_stdio_definitions");

    exe.rdynamic = true;

    b.installArtifact(exe);

    const ze_forge_base_path = "../../";
    const the_forge_open_source_path = ze_forge_base_path ++ "Common_3/Graphics/ThirdParty/OpenSource/";
    const test_exe_bin_path = "bin/";

    var install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "ags/ags_lib/lib/amd_ags_x64.dll"), test_exe_bin_path ++ "amd_ags_x64.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "DirectXShaderCompiler/bin/x64/dxcompiler.dll"), test_exe_bin_path ++ "dxcompiler.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "winpixeventruntime/bin/WinPixEventRuntime.dll"), test_exe_bin_path ++ "WinPixEventRuntime.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/D3D12Core.dll"), test_exe_bin_path ++ "D3D12Core.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/d3d12SDKLayers.dll"), test_exe_bin_path ++ "d3d12SDKLayers.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(ze_forge_base_path ++ "Common_3/OS/Windows/pc_gpu.data"), test_exe_bin_path ++ "gpu.data");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(ze_forge_base_path ++ "tides/gpu.cfg"), test_exe_bin_path ++ "gpu.cfg");
    exe.step.dependOn(&install_file.step);

    {
        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    buildExe(b, target, optimize);
}
