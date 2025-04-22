const std = @import("std");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");

pub const Gfx = struct {
    // Shaders
    blit_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    clear_screen_shader: zf.ShaderHandle = zf.ShaderHandle.nil,

    // PSOs
    clear_screen_pso: zf.PsoHandle = zf.PsoHandle.nil,
    blit_pso: zf.PsoHandle = zf.PsoHandle.nil,

    // Render Targets and Render Textures
    depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    scene_color: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,

    // Uniform buffers
    global_frame_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    // Materials
    blit_material: GfxMaterial = undefined,
};

pub const Frame = struct {
    time: f32,
};

// TODO: List all possible passes (eg. default, shadow_caster, gbuffer, etc.)
pub const Pass = enum {
    default,
    gbuffer,
    shadow_caster,
};

pub const GfxMaterialPass = struct {
    pso: zf.PsoHandle,

    per_draw_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    per_batch_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    per_frame_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    persistent_descriptor_set: [*c]zf.IGraphics.DescriptorSet,
    persistent_samplers_descriptor_set: [*c]zf.IGraphics.DescriptorSet,

    pass: Pass,
};

const material_passes_max_count: u32 = 8;

pub const GfxMaterial = struct {
    passes: [material_passes_max_count]GfxMaterialPass,
    passes_count: u32,
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
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.clear_screen_pso = zf.createPso(pipeline_desc, gfx.clear_screen_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{ zf.getSwapChainFormat() };
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mRenderTargetCount = render_targets.len;
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;
        gfx.blit_pso = zf.createPso(pipeline_desc, gfx.blit_shader) catch unreachable;
    }

    {
        var depth_buffer_desc = std.mem.zeroes(zf.RenderTargetDesc);
        depth_buffer_desc.pName = "Depth Buffer";
        depth_buffer_desc.mArraySize = 1;
        depth_buffer_desc.mClearValue.__struct_field3.depth = 0.0;
        depth_buffer_desc.mClearValue.__struct_field3.stencil = 0;
        depth_buffer_desc.mDepth = 1;
        depth_buffer_desc.mFormat = .D32_SFLOAT;
        depth_buffer_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        depth_buffer_desc.mWidth = @intCast(window_width);
        depth_buffer_desc.mHeight = @intCast(window_height);
        depth_buffer_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        depth_buffer_desc.mSampleQuality = 0;
        depth_buffer_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.depth_buffer = zf.createRenderTarget(depth_buffer_desc) catch unreachable;
    }

    {
        var scene_color_desc = std.mem.zeroes(zf.TextureDesc);
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
        scene_color_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        scene_color_desc.mDescriptors.bits = zf.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits | zf.DescriptorType.DESCRIPTOR_TYPE_RW_TEXTURE.bits;
        scene_color_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        scene_color_desc.mSampleQuality = 0;
        scene_color_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        scene_color_desc.pName = "Scene Color";
        gfx.scene_color = zf.createRenderTexture(scene_color_desc) catch unreachable;
    }

    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.global_frame_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(Frame), "Global Frame Constant Buffer");
        }
    }

    // Blit material example
    {
        gfx.blit_material.passes_count = 1;
        gfx.blit_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.blit_material.passes[0].pass = .default;
        gfx.blit_material.passes[0].pso = gfx.blit_pso;

        const descriptor_sets = zf.createDescriptorSets(gfx.blit_shader) catch unreachable;
        gfx.blit_material.passes[0].per_draw_descriptor_set = descriptor_sets.per_draw;
        gfx.blit_material.passes[0].per_batch_descriptor_set = descriptor_sets.per_batch;
        gfx.blit_material.passes[0].per_frame_descriptor_set = descriptor_sets.per_frame;
        gfx.blit_material.passes[0].persistent_descriptor_set = descriptor_sets.persistent;
        gfx.blit_material.passes[0].persistent_samplers_descriptor_set = descriptor_sets.persistent_samplers;
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
