const std = @import("std");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");

pub const Gfx = struct {
    // Shaders
    blit_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    clear_screen_shader: zf.ShaderHandle = zf.ShaderHandle.nil,

    // Render Targets and Render Textures
    depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    scene_color: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
};

pub fn main() !void {
    // Create a window
    zglfw.init() catch unreachable;
    defer zglfw.terminate();

    var window_width: c_int = 1920;
    var window_height: c_int = 1080;

    zglfw.windowHint(.client_api, .no_api);
    const window = zglfw.Window.create(window_width, window_height, "Ze-Forge Test", null) catch unreachable;
    defer zglfw.Window.destroy(window);

    const gpu_desc = zf.GpuDesc{
        .graphics_root_signature_path = "shaders/GraphicsRootSignature.rs",
        .compute_root_signature_path = "shaders/ComputeRootSignature.rs",
        .hwnd = zglfw.getWin32Window(window).?,
    };
    zf.initializeGpu(gpu_desc, std.heap.page_allocator) catch unreachable;
    defer zf.shutdownGpu();

    var gfx = Gfx{};

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Blit.vert",
                .entry = "FullscreenVertex",
            },
            .pixel = .{
                .path = "shaders/Blit.frag",
                .entry = "BlitFragment",
            },
            .compute = null,
        };
        gfx.blit_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{ .compute = .{
            .path = "shaders/ClearScreen.comp",
            .entry = "main",
        }, .vertex = null, .pixel = null };
        gfx.clear_screen_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        var depth_buffer_desc = std.mem.zeroes(zf.IGraphics.RenderTargetDesc);
        depth_buffer_desc.pName = "Depth Buffer";
        depth_buffer_desc.mArraySize = 1;
        depth_buffer_desc.mClearValue.__struct_field3.depth = 0.0;
        depth_buffer_desc.mClearValue.__struct_field3.stencil = 0;
        depth_buffer_desc.mDepth = 1;
        depth_buffer_desc.mFormat = .D32_SFLOAT;
        depth_buffer_desc.mStartState = zf.IGraphics.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        depth_buffer_desc.mWidth = @intCast(window_width);
        depth_buffer_desc.mHeight = @intCast(window_height);
        depth_buffer_desc.mSampleCount = zf.IGraphics.SampleCount.SAMPLE_COUNT_1;
        depth_buffer_desc.mSampleQuality = 0;
        depth_buffer_desc.mFlags = zf.IGraphics.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.depth_buffer = zf.createRenderTarget(depth_buffer_desc) catch unreachable;
    }

    {
        var scene_color_desc = std.mem.zeroes(zf.IGraphics.TextureDesc);
        scene_color_desc.mWidth = @intCast(window_width);
        scene_color_desc.mHeight = @intCast(window_height);
        scene_color_desc.mDepth = 1;
        scene_color_desc.mArraySize = 1;
        scene_color_desc.mMipLevels = 1;
        scene_color_desc.mClearValue.__struct_field1.r = 0.0;
        scene_color_desc.mClearValue.__struct_field1.g = 0.0;
        scene_color_desc.mClearValue.__struct_field1.b = 0.0;
        scene_color_desc.mClearValue.__struct_field1.a = 0.0;
        scene_color_desc.mFormat = .R8G8B8A8_SRGB;
        scene_color_desc.mStartState = zf.IGraphics.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        scene_color_desc.mDescriptors.bits = zf.IGraphics.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits | zf.IGraphics.DescriptorType.DESCRIPTOR_TYPE_RW_TEXTURE.bits;
        scene_color_desc.mSampleCount = zf.IGraphics.SampleCount.SAMPLE_COUNT_1;
        scene_color_desc.mSampleQuality = 0;
        scene_color_desc.mFlags = zf.IGraphics.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        scene_color_desc.pName = "Scene Color";
        gfx.scene_color = zf.createRenderTexture(scene_color_desc) catch unreachable;
    }

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const frame_buffer_size = window.getFramebufferSize();
        if (frame_buffer_size[0] != window_width or frame_buffer_size[1] != window_height) {
            window_width = frame_buffer_size[0];
            window_height = frame_buffer_size[1];

            std.log.info(
                "Window resized to {d}x{d}",
                .{ window_width, window_height },
            );

            zf.requestResize();
        }

        _ = zf.frameStart();
        zf.frameSubmit();
    }
}
