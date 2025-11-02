const std = @import("std");

pub const Package = struct {
    zforge: *std.Build.Module,
    zforge_cpp: *std.Build.Step.Compile,

    pub fn link(pkg: Package, b: *std.Build, exe: *std.Build.Step.Compile) void {
        exe.root_module.addImport("zforge", pkg.zforge);
        exe.linkLibrary(pkg.zforge_cpp);

        const tides_renderer_base_path = "external/The-Forge/Examples_3/TidesRenderer";
        const tides_renderer_output_path = tides_renderer_base_path ++ "/PC Visual Studio 2019/x64/DebugNoValidation";
        exe.linkLibC();
        exe.addLibraryPath(b.path(tides_renderer_output_path));
    }
};

pub fn package(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    _: struct {},
) Package {
    const zforge = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("external/The-Forge/main.zig"),
    });

    const zforge_cpp = b.addStaticLibrary(.{
        .name = "zforge",
        .target = target,
        .optimize = optimize,
    });

    zforge_cpp.linkLibC();
    // zforge_cpp.linkLibCpp();
    zforge_cpp.addIncludePath(b.path("external/The-Forge/Common_3/Application/Interfaces"));
    zforge_cpp.addIncludePath(b.path("external/The-Forge/Common_3/Graphics/Interfaces"));
    zforge_cpp.addIncludePath(b.path("external/The-Forge/Common_3/Resources/ResourceLoader/Interfaces"));
    zforge_cpp.addIncludePath(b.path("external/The-Forge/Common_3/Utilities/Interfaces"));
    zforge_cpp.addIncludePath(b.path("Common_3/Utilities/Log"));
    zforge_cpp.addCSourceFiles(.{
        .files = &.{
            "external/The-Forge/Common_3/Application/Interfaces/IFont_glue.cpp",
            "external/The-Forge/Common_3/Graphics/Interfaces/IGraphics_glue.cpp",
            "external/The-Forge/Common_3/Resources/ResourceLoader/Interfaces/IResourceLoader_glue.cpp",
            "external/The-Forge/Common_3/Utilities/Interfaces/IFileSystem_glue.cpp",
            "external/The-Forge/Common_3/Utilities/Interfaces/IMemory_glue.cpp",
            "external/The-Forge/Common_3/Utilities/Log/Log_glue.cpp",
        },
        .flags = &.{
            "-DTIDES",
            "-DNO_TIDES_FORGE_DEBUG",
        },
    });

    const tides_renderer_build_step = buildTheForgeRenderer(b);
    const tides_renderer_base_path = "external/The-Forge/Examples_3/TidesRenderer";
    const tides_the_forge_base_path = "external/The-Forge";
    const d3d_agility_sdk_path = tides_the_forge_base_path ++ "/Common_3/Graphics/ThirdParty/OpenSource/Direct3d12Agility/bin/x64";
    // TODO(gmodarelli): Check if OS is windows and if target is debug
    const tides_renderer_output_path = tides_renderer_base_path ++ "/PC Visual Studio 2019/x64/DebugNoValidation";
    zforge_cpp.addLibraryPath(b.path(tides_renderer_base_path));
    zforge_cpp.addLibraryPath(b.path(tides_renderer_output_path));
    zforge_cpp.linkSystemLibrary("dxguid");
    zforge_cpp.linkSystemLibrary("ole32");
    zforge_cpp.linkSystemLibrary("oleaut32");
    zforge_cpp.linkSystemLibrary("OS");
    zforge_cpp.linkSystemLibrary("Renderer");
    zforge_cpp.linkSystemLibrary("ws2_32");
    zforge_cpp.linkSystemLibrary("Xinput9_1_0");
    zforge_cpp.step.dependOn(tides_renderer_build_step);

    // Install DLLs
    var install_file = b.addInstallFile(b.path(tides_renderer_output_path ++ "/WinPixEventRunTime.dll"), "bin/WinPixEventRunTime.dll");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(tides_renderer_output_path ++ "/amd_ags_x64.dll"), "bin/amd_ags_x64.dll");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(tides_renderer_output_path ++ "/dxcompiler.dll"), "bin/dxcompiler.dll");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(d3d_agility_sdk_path ++ "/D3D12Core.dll"), "bin/d3d12/D3D12Core.dll");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(d3d_agility_sdk_path ++ "/D3D12SDKLayers.dll"), "bin/d3d12/D3D12SDKLayers.dll");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(d3d_agility_sdk_path ++ "/D3D12Core.pdb"), "bin/d3d12/D3D12Core.pdb");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(d3d_agility_sdk_path ++ "/D3D12SDKLayers.pdb"), "bin/d3d12/D3D12SDKLayers.pdb");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);

    // Install Configuration Files
    install_file = b.addInstallFile(b.path(tides_renderer_base_path ++ "/src/GPUCfg/gpu.cfg"), "bin/GPUCfg/gpu.cfg");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);
    install_file = b.addInstallFile(b.path(tides_the_forge_base_path ++ "/Common_3/OS/Windows/pc_gpu.data"), "bin/gpu.data");
    install_file.step.dependOn(tides_renderer_build_step);
    zforge_cpp.step.dependOn(&install_file.step);

    return .{
        .zforge = zforge,
        .zforge_cpp = zforge_cpp,
    };
}

pub fn build(_: *std.Build) void {}

fn buildTheForgeRenderer(b: *std.Build) *std.Build.Step {
    const build_step = b.step(
        "the-forge-tides-renderer",
        "Build The-Forge renderer",
    );

    const solution_path = thisDir() ++ "/Examples_3/TidesRenderer/PC Visual Studio 2019/TidesRenderer.sln";
    const command = [_][]const u8{
        "./tools/external/msvc_BuildTools/MSBuild/Current/Bin/amd64/MSBuild",
        "/p:Configuration=DebugNoValidation",
        solution_path,
    };

    build_step.dependOn(&b.addSystemCommand(&command).step);
    return build_step;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
