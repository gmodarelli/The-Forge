const std = @import("std");

pub fn buildExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "ze-forge-test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const abi = (std.zig.system.resolveTargetQuery(target.query) catch unreachable).abi;
    exe.linkLibC();
    if (abi != .msvc) {
        exe.linkLibCpp();
    }

    // zglfw
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    // zgltf
    const zgltf = b.dependency("zgltf", .{});
    exe.root_module.addImport("zgltf", zgltf.module("zgltf"));

    // zmath
    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

    // ze-forge
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

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/D3D12Core.pdb"), test_exe_bin_path ++ "D3D12Core.pdb");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/d3d12SDKLayers.dll"), test_exe_bin_path ++ "d3d12SDKLayers.dll");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/d3d12SDKLayers.pdb"), test_exe_bin_path ++ "d3d12SDKLayers.pdb");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(ze_forge_base_path ++ "Common_3/OS/Windows/pc_gpu.data"), test_exe_bin_path ++ "gpu.data");
    exe.step.dependOn(&install_file.step);

    install_file = b.addInstallFile(b.path(ze_forge_base_path ++ "tides/gpu.cfg"), test_exe_bin_path ++ "gpu.cfg");
    exe.step.dependOn(&install_file.step);

    var install_models_directory = b.addInstallDirectory(.{ .source_dir = b.path("content/models"), .install_dir = .{ .prefix = {} }, .install_subdir = "bin/content/models" });
    exe.step.dependOn(&install_models_directory.step);

    var install_textures_directory = b.addInstallDirectory(.{ .source_dir = b.path("content/textures"), .install_dir = .{ .prefix = {} }, .install_subdir = "bin/content/textures" });
    exe.step.dependOn(&install_textures_directory.step);

    var install_fonts_directory = b.addInstallDirectory(.{ .source_dir = b.path("content/fonts"), .install_dir = .{ .prefix = {} }, .install_subdir = "bin/content/fonts" });
    exe.step.dependOn(&install_fonts_directory.step);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    compileShaders(&exe.step, allocator);

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

pub fn compileShaders(step: *std.Build.Step, allocator: std.mem.Allocator) void {
    const b = step.owner;
    const output_shaders_path = std.fs.path.join(allocator, &[_][]const u8{ b.install_path, "bin", "shaders" }) catch unreachable;
    defer allocator.free(output_shaders_path);

    const graphics_root_signature_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "GraphicsRootSignature.rs" }) catch unreachable;
    defer allocator.free(graphics_root_signature_output_path);
    const compute_root_signature_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ComputeRootSignature.rs" }) catch unreachable;
    defer allocator.free(compute_root_signature_output_path);
    compileShader(step, "shaders/GraphicsRootSignature.hlsl", graphics_root_signature_output_path, "DefaultRootSignature", &[_][]const u8{}, .root_signature);
    compileShader(step, "shaders/ComputeRootSignature.hlsl", compute_root_signature_output_path, "ComputeRootSignature", &[_][]const u8{}, .root_signature);

    const compositor_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Compositor.vert" }) catch unreachable;
    defer allocator.free(compositor_vertex_output_path);
    const compositor_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Compositor.frag" }) catch unreachable;
    defer allocator.free(compositor_pixel_output_path);
    compileShader(step, "shaders/Compositor.hlsl", compositor_vertex_output_path, "FullscreenTriangleVS", &[_][]const u8{}, .vertex);
    compileShader(step, "shaders/Compositor.hlsl", compositor_pixel_output_path, "CompositorPS", &[_][]const u8{}, .pixel);

    const sprite_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Sprite.vert" }) catch unreachable;
    defer allocator.free(sprite_vertex_output_path);
    const sprite_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Sprite.frag" }) catch unreachable;
    defer allocator.free(sprite_pixel_output_path);
    compileShader(step, "shaders/Sprite.hlsl", sprite_vertex_output_path, "SpriteVS", &[_][]const u8{}, .vertex);
    compileShader(step, "shaders/Sprite.hlsl", sprite_pixel_output_path, "SpritePS", &[_][]const u8{}, .pixel);

    const meshlet_clear_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletClearCounters.comp" }) catch unreachable;
    defer allocator.free(meshlet_clear_output_path);
    compileShader(step, "shaders/MeshletCullCS.hlsl", meshlet_clear_output_path, "ClearCountersCS", &[_][]const u8{ "/D CLEAR_COUNTERS" }, .compute);

    const meshlet_cull_instances_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletCullInstances.comp" }) catch unreachable;
    defer allocator.free(meshlet_cull_instances_output_path);
    compileShader(step, "shaders/MeshletCullCS.hlsl", meshlet_cull_instances_output_path, "CullInstancesCS", &[_][]const u8{ "/D CULL_INSTANCES" }, .compute);

    const meshlet_build_indirect_cull_args_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletBuildCullIndirectArgs.comp" }) catch unreachable;
    defer allocator.free(meshlet_build_indirect_cull_args_output_path);
    compileShader(step, "shaders/MeshletCullCS.hlsl", meshlet_build_indirect_cull_args_output_path, "BuildMeshletCullIndirectArgsCS", &[_][]const u8{ "/D MESHLET_CULL_ARGUMENTS" }, .compute);

    const meshlet_cull_meshlets_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletCullMeshlets.comp" }) catch unreachable;
    defer allocator.free(meshlet_cull_meshlets_output_path);
    compileShader(step, "shaders/MeshletCullCS.hlsl", meshlet_cull_meshlets_output_path, "CullMeshletsCS", &[_][]const u8{ "/D CULL_MESHLETS" }, .compute);

    const meshlet_bin_prepare_args_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletBinPrepareArgs.comp" }) catch unreachable;
    defer allocator.free(meshlet_bin_prepare_args_output_path);
    compileShader(step, "shaders/MeshletBinningCS.hlsl", meshlet_bin_prepare_args_output_path, "PrepareArgsCS", &[_][]const u8{ "/D PREPARE_ARGS" }, .compute);

    const meshlet_bin_classify_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletBinClassifyMeshlets.comp" }) catch unreachable;
    defer allocator.free(meshlet_bin_classify_output_path);
    compileShader(step, "shaders/MeshletBinningCS.hlsl", meshlet_bin_classify_output_path, "ClassifyMeshletsCS", &[_][]const u8{ "/D CLASSIFY_MESHLETS" }, .compute);

    const meshlet_bin_allocate_bin_ranges_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletBinAllocateBins.comp" }) catch unreachable;
    defer allocator.free(meshlet_bin_allocate_bin_ranges_output_path);
    compileShader(step, "shaders/MeshletBinningCS.hlsl", meshlet_bin_allocate_bin_ranges_output_path, "AllocateBinRangesCS", &[_][]const u8{ "/D ALLOCATE_BIN_RANGES" }, .compute);

    const meshlet_bin_write_bins_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletBinWriteBins.comp" }) catch unreachable;
    defer allocator.free(meshlet_bin_write_bins_output_path);
    compileShader(step, "shaders/MeshletBinningCS.hlsl", meshlet_bin_write_bins_output_path, "WriteBinsCS", &[_][]const u8{ "/D WRITE_BINS" }, .compute);

    const meshlet_rasterizer_mesh_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletRasterizer.comp" }) catch unreachable;
    defer allocator.free(meshlet_rasterizer_mesh_output_path);
    compileShader(step, "shaders/MeshletRasterizerMS.hlsl", meshlet_rasterizer_mesh_output_path, "main", &[_][]const u8{ "/D MESH_SHADER" }, .mesh);

    const meshlet_rasterizer_pixel_opaque_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletRasterizerOpaque.frag" }) catch unreachable;
    defer allocator.free(meshlet_rasterizer_pixel_opaque_output_path);
    compileShader(step, "shaders/MeshletRasterizerMS.hlsl", meshlet_rasterizer_pixel_opaque_output_path, "pixel", &[_][]const u8{ "/D PIXEL_SHADER" }, .pixel);

    const meshlet_rasterizer_pixel_masked_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "MeshletRasterizerMasked.frag" }) catch unreachable;
    defer allocator.free(meshlet_rasterizer_pixel_masked_output_path);
    compileShader(step, "shaders/MeshletRasterizerMS.hlsl", meshlet_rasterizer_pixel_masked_output_path, "pixel", &[_][]const u8{ "/D PIXEL_SHADER", "/D ALPHA_TEST" }, .pixel);

    const visibility_debug_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "VisibilityDebug.comp" }) catch unreachable;
    defer allocator.free(visibility_debug_output_path);
    compileShader(step, "shaders/VisibilityDebugCS.hlsl", visibility_debug_output_path, "VisibilityDebugCS", &[_][]const u8{}, .compute);
}

const ShaderType = enum {
    vertex,
    pixel,
    compute,
    amplification,
    mesh,
    root_signature,
};

fn compileShader(step: *std.Build.Step, input: []const u8, output: []const u8, entry: []const u8, defines: []const []const u8, shader_type: ShaderType) void {
    const profile = switch (shader_type) {
        .vertex => "vs_6_8",
        .pixel => "ps_6_8",
        .compute => "cs_6_8",
        .amplification => "as_6_8",
        .mesh => "ms_6_8",
        .root_signature => "rootsig_1_1",
    };

    const qstrip_root_signature = switch (shader_type) {
        .vertex, .pixel, .compute, .amplification, .mesh => "-Qstrip_rootsignature",
        .root_signature => "",
    };

    const b = step.owner;
    var dxc_command: [16][]const u8 = undefined;
    var dxc_command_length: u64 = 12;

    dxc_command[0] = "../../Common_3/Graphics/ThirdParty/OpenSource/DirectXShaderCompiler/bin/x64/dxc.exe";
    dxc_command[1] = input;
    dxc_command[2] = b.fmt("-Fo {s}", .{output});
    dxc_command[3] = b.fmt("-E {s}", .{entry});
    dxc_command[4] = b.fmt("-T {s}", .{profile});
    dxc_command[5] = qstrip_root_signature;
    dxc_command[6] = "-Qembed_debug";
    dxc_command[7] = "-HV 2021";
    dxc_command[8] = "-all-resources-bound";
    dxc_command[9] = "-WX";
    dxc_command[10] = "-Od";
    dxc_command[11] = "-Zi";

    for (defines) |define| {
        std.debug.assert(dxc_command_length < dxc_command.len);
        dxc_command[dxc_command_length] = define;
        dxc_command_length += 1;
    }

    const cmd_step = b.addSystemCommand(dxc_command[0..dxc_command_length]);
    step.dependOn(&cmd_step.step);
}
