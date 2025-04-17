const std = @import("std");

fn addMSVCIncludePaths(compile: *std.Build.Step.Compile, allocator: std.mem.Allocator) void {
    const vctools_install_dir = std.process.getEnvVarOwned(allocator, "VCToolsInstallDir") catch unreachable;
    const sdk_path = std.process.getEnvVarOwned(allocator, "WindowsSdkDir") catch unreachable;
    const sdk_version = std.process.getEnvVarOwned(allocator, "WindowsSDKLibVersion") catch unreachable;
    defer allocator.free(vctools_install_dir);
    defer allocator.free(sdk_path);
    defer allocator.free(sdk_version);

    const vctools_include_path = std.fs.path.join(allocator, &[_][]const u8{ vctools_install_dir, "include" }) catch unreachable;
    const shared_include_path = std.fs.path.join(allocator, &[_][]const u8{ sdk_path, "Include", sdk_version, "shared" }) catch unreachable;
    const ucrt_include_path = std.fs.path.join(allocator, &[_][]const u8{ sdk_path, "Include", sdk_version, "ucrt" }) catch unreachable;
    const um_include_path = std.fs.path.join(allocator, &[_][]const u8{ sdk_path, "Include", sdk_version, "um" }) catch unreachable;
    defer allocator.free(vctools_include_path);
    defer allocator.free(shared_include_path);
    defer allocator.free(ucrt_include_path);
    defer allocator.free(um_include_path);

    compile.addSystemIncludePath(.{ .cwd_relative = vctools_include_path });
    compile.addSystemIncludePath(.{ .cwd_relative = shared_include_path });
    compile.addSystemIncludePath(.{ .cwd_relative = ucrt_include_path });
    compile.addSystemIncludePath(.{ .cwd_relative = um_include_path });
}

pub fn buildLib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const ze_forge_c_cpp = b.addStaticLibrary(.{
        .name = "ze_forge_c_cpp",
        .target = target,
        .optimize = optimize,
    });

    std.debug.assert(target.result.abi == .msvc);

    const cflags = &.{
        "-DTIDES",
        "-DD3D12_AGILITY_SDK=1",
        "-DD3D12_AGILITY_SDK_VERSION=715",
        "-msse2",
        "-fms-extensions",
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    addMSVCIncludePaths(ze_forge_c_cpp, allocator);

    const ze_forge_base_path = "../";
    const the_forge_base_path = ze_forge_base_path ++ "./";

    ze_forge_c_cpp.addCSourceFiles(.{
        .files = &.{
            // Single header libraries
            "src/single_header_wrapper.cpp",

            // The-forge graphics
            the_forge_base_path ++ "Common_3/Graphics/GraphicsConfig.cpp",
            the_forge_base_path ++ "Common_3/Graphics/Direct3D12/Direct3D12_cxx.cpp",
            the_forge_base_path ++ "Common_3/Graphics/Direct3D12/Direct3D12.c",
            the_forge_base_path ++ "Common_3/Graphics/Direct3D12/Direct3D12Hooks.c",
            the_forge_base_path ++ "Common_3/Graphics/Direct3D12/Direct3D12Raytracing.c",
            the_forge_base_path ++ "Common_3/Utilities/ThirdParty/OpenSource/bstrlib/bstrlib.c",

            // Glue
            the_forge_base_path ++ "Common_3/Graphics/Interfaces/IGraphics_glue.cpp",
            the_forge_base_path ++ "Common_3/Graphics/Interfaces/IRay_glue.cpp",

            // TIDES Graphics
            the_forge_base_path ++ "Common_3/Graphics/GraphicsTides.c",
            the_forge_base_path ++ "Common_3/Graphics/Interfaces/IGraphicsTides_glue.cpp",

            // TIDES
            the_forge_base_path ++ "Common_3/Tides/WindowsFileSystem.c",
            the_forge_base_path ++ "Common_3/Tides/WindowsLog.c",
            the_forge_base_path ++ "Common_3/Tides/WindowsMemory.c",
            the_forge_base_path ++ "Common_3/Tides/WindowsThread.c",
        },
        .flags = cflags,
    });

    b.installArtifact(ze_forge_c_cpp);

    var ze_forge = b.addModule("ze_forge", .{
        .root_source_file = b.path("../root.zig"),
        .target = target,
        .optimize = optimize,
    });

    ze_forge.linkLibrary(ze_forge_c_cpp);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    buildLib(b, target, optimize);
}
