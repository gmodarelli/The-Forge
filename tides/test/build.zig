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

    install_file = b.addInstallFile(b.path(the_forge_open_source_path ++ "Direct3d12Agility/bin/x64/d3d12SDKLayers.dll"), test_exe_bin_path ++ "d3d12SDKLayers.dll");
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
    compileShader(step, "shaders/GraphicsRootSignature.hlsl", graphics_root_signature_output_path, "DefaultRootSignature", "", .root_signature);
    compileShader(step, "shaders/ComputeRootSignature.hlsl", compute_root_signature_output_path, "ComputeRootSignature", "", .root_signature);

    const blit_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Blit.vert" }) catch unreachable;
    defer allocator.free(blit_vertex_output_path);
    const blit_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Blit.frag" }) catch unreachable;
    defer allocator.free(blit_pixel_output_path);
    compileShader(step, "shaders/Blit.hlsl", blit_vertex_output_path, "FullscreenVertex", "", .vertex);
    compileShader(step, "shaders/Blit.hlsl", blit_pixel_output_path, "BlitFragment", "", .pixel);

    const gbuffer_object_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ObjectGBuffer.vert" }) catch unreachable;
    defer allocator.free(gbuffer_object_vertex_output_path);
    const gbuffer_object_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ObjectGBuffer.frag" }) catch unreachable;
    defer allocator.free(gbuffer_object_pixel_output_path);
    compileShader(step, "shaders/Object.hlsl", gbuffer_object_vertex_output_path, "GBufferVS", "", .vertex);
    compileShader(step, "shaders/Object.hlsl", gbuffer_object_pixel_output_path, "GBufferPS", "", .pixel);

    const shadow_caster_object_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ObjectShadowCaster.vert" }) catch unreachable;
    defer allocator.free(shadow_caster_object_vertex_output_path);
    const shadow_caster_object_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ObjectShadowCaster.frag" }) catch unreachable;
    defer allocator.free(shadow_caster_object_pixel_output_path);
    compileShader(step, "shaders/Object.hlsl", shadow_caster_object_vertex_output_path, "ShadowCasterVS", "SHADOW_CASTER", .vertex);
    compileShader(step, "shaders/Object.hlsl", shadow_caster_object_pixel_output_path, "ShadowCasterPS", "SHADOW_CASTER", .pixel);

    const sprite_vertex_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Sprite.vert" }) catch unreachable;
    defer allocator.free(sprite_vertex_output_path);
    const sprite_pixel_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "Sprite.frag" }) catch unreachable;
    defer allocator.free(sprite_pixel_output_path);
    compileShader(step, "shaders/Sprite.hlsl", sprite_vertex_output_path, "SpriteVS", "", .vertex);
    compileShader(step, "shaders/Sprite.hlsl", sprite_pixel_output_path, "SpritePS", "", .pixel);

    const clear_screen_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ClearScreen.comp" }) catch unreachable;
    defer allocator.free(clear_screen_output_path);
    compileShader(step, "shaders/ClearScreenCS.hlsl", clear_screen_output_path, "main", "", .compute);

    const gauss_blur_horizontal_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "GaussBlurH.comp" }) catch unreachable;
    defer allocator.free(gauss_blur_horizontal_output_path);
    compileShader(step, "shaders/GaussBlurCS.hlsl", gauss_blur_horizontal_output_path, "main", "BLUR_HORIZONTAL", .compute);
    const gauss_blur_vertical_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "GaussBlurV.comp" }) catch unreachable;
    defer allocator.free(gauss_blur_vertical_output_path);
    compileShader(step, "shaders/GaussBlurCS.hlsl", gauss_blur_vertical_output_path, "main", "BLUR_VERTICAL", .compute);

    const clear_buffer_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "ClearBuffer.comp" }) catch unreachable;
    defer allocator.free(clear_buffer_output_path);
    compileShader(step, "shaders/ClearBufferCS.hlsl", clear_buffer_output_path, "main", "", .compute);

    const deferred_shading_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "DeferredShading.comp" }) catch unreachable;
    defer allocator.free(deferred_shading_output_path);
    compileShader(step, "shaders/DeferredShadingCS.hlsl", deferred_shading_output_path, "main", "", .compute);

    const debug_text_output_path = std.fs.path.join(allocator, &[_][]const u8{ output_shaders_path, "DebugText.comp" }) catch unreachable;
    defer allocator.free(debug_text_output_path);
    compileShader(step, "shaders/DebugTextCS.hlsl", debug_text_output_path, "main", "", .compute);
}

const ShaderType = enum {
    vertex,
    pixel,
    compute,
    root_signature,
};

fn compileShader(step: *std.Build.Step, input: []const u8, output: []const u8, entry: []const u8, define: []const u8, shader_type: ShaderType) void {
    const profile = switch (shader_type) {
        .vertex => "vs_6_8",
        .pixel => "ps_6_8",
        .compute => "cs_6_8",
        .root_signature => "rootsig_1_1",
    };

    const qstrip_root_signature = switch (shader_type) {
        .vertex, .pixel, .compute => "-Qstrip_rootsignature",
        .root_signature => "",
    };

    const b = step.owner;
    const dxc_command = [_][]const u8{
        "../../Common_3/Graphics/ThirdParty/OpenSource/DirectXShaderCompiler/bin/x64/dxc.exe",
        input,
        b.fmt("-Fo {s}", .{output}),
        b.fmt("-E {s}", .{entry}),
        b.fmt("-T {s}", .{profile}),
        if (define.len == 0) "" else b.fmt("/D {s}", .{define}),
        qstrip_root_signature,
        "-Qembed_debug",
        "-HV 2021",
        "-all-resources-bound",
        "-WX",
        "-Od",
        "-Zi",
    };

    const cmd_step = b.addSystemCommand(&dxc_command);
    step.dependOn(&cmd_step.step);
}
