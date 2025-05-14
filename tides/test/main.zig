const std = @import("std");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");
const zgltf = @import("zgltf");
const zmath = @import("zmath");

pub const Gfx = struct {
    // Static samplers
    linear_repeat_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,
    linear_clamp_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,

    // Shaders
    blit_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    object_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    clear_screen_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    gauss_blur_horizontal_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    gauss_blur_vertical_shader: zf.ShaderHandle = zf.ShaderHandle.nil,

    // PSOs
    blit_pso: zf.PsoHandle = zf.PsoHandle.nil,
    blit_swapchain_pso: zf.PsoHandle = zf.PsoHandle.nil,
    object_pso: zf.PsoHandle = zf.PsoHandle.nil,
    clear_screen_pso: zf.PsoHandle = zf.PsoHandle.nil,
    gauss_horizontal_pso: zf.PsoHandle = zf.PsoHandle.nil,
    gauss_vertical_pso: zf.PsoHandle = zf.PsoHandle.nil,

    // Render Targets and Render Textures
    gbuffer0: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    // TODO: Figure out if we need double-buffering for render textures
    scene_color: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
    gauss_blur_a: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
    gauss_blur_b: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,

    // Uniform buffers
    global_frame_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },
    gauss_blur_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },

    // Geometry buffers
    // TODO: Figure out if we need double-buffering here to be able to stream in meshes
    vertex_buffer: zf.BufferHandle = undefined,
    index_buffer: zf.BufferHandle = undefined,
    vertex_buffer_offset: u64 = 0,
    index_buffer_offset: u64 = 0,

    // GPU-Scene buffers
    transform_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    // Materials
    blit_material_1: GfxMaterial = undefined,
    blit_material_2: GfxMaterial = undefined,
    object_material: GfxMaterial = undefined,
    clear_screen_material: GfxMaterial = undefined,
    gauss_blur_horizontal_material: GfxMaterial = undefined,
    gauss_blur_vertical_material: GfxMaterial = undefined,

    // CPU Geometry data
    birch_1_mesh: Mesh = undefined,
};

pub const Frame = struct {
    view_matrix: [16]f32,
    projection_matrix: [16]f32,
    view_projection_matrix: [16]f32,
    time: f32,
    transform_buffer_index: u32,
    vertex_buffer_index: u32,
};

pub const Mesh = struct {
    sub_meshes: [8]SubMesh = undefined,
    sub_meshes_count: u32 = 0,
};

pub const SubMesh = struct {
    index_count: u32,
    first_index: u32,
    vertex_count: u32,
    first_vertex: u32,
};

pub const Vertex = struct {
    position: [3]f32,
    uv: [2]f32,
    normal: [3]f32,
};

pub const Transform = struct {
    world_matrix: [16]f32,
};

pub const BlurData = struct {
    sigma: f32,
    support: f32,
    sRGB: f32,
    padding: f32,
};

// TODO: List all possible passes (eg. default, shadow_caster, gbuffer, etc.)
pub const Pass = enum {
    default,
    gbuffer,
    shadow_caster,
};

pub const GfxMaterialPass = struct {
    pso: zf.PsoHandle,

    per_draw_descriptor_set: zf.DescriptorSetHandle,
    per_batch_descriptor_set: zf.DescriptorSetHandle,
    per_frame_descriptor_set: zf.DescriptorSetHandle,
    persistent_descriptor_set: zf.DescriptorSetHandle,
    persistent_samplers_descriptor_set: zf.DescriptorSetHandle,

    pass: Pass,
};

const material_passes_max_count: u32 = 8;

pub const GfxMaterial = struct {
    passes: [material_passes_max_count]GfxMaterialPass,
    passes_count: u32,
};

var gfx: *Gfx = undefined;
var gltf: *zgltf = undefined;

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

    gfx = std.heap.page_allocator.create(Gfx) catch unreachable;
    defer std.heap.page_allocator.destroy(gfx);

    zf.registerUpdateDescriptorSetFn(updateDescriptorSets);

    // Static Samplers
    {
        var sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        sampler_desc.mMinFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMagFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMipMapMode = zf.MipMapMode.MIPMAP_MODE_LINEAR;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_REPEAT;
        gfx.linear_repeat_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;
    }

    // Shaders
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
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Object.vert",
                .entry = "ObjectVS",
            },
            .pixel = .{
                .path = "shaders/Object.frag",
                .entry = "ObjectPS",
            },
            .compute = null,
        };
        gfx.object_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{ .compute = .{
            .path = "shaders/ClearScreen.comp",
            .entry = "main",
        }, .vertex = null, .pixel = null };
        gfx.clear_screen_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{ .compute = .{
            .path = "shaders/GaussBlurH.comp",
            .entry = "main",
        }, .vertex = null, .pixel = null };
        gfx.gauss_blur_horizontal_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{ .compute = .{
            .path = "shaders/GaussBlurV.comp",
            .entry = "main",
        }, .vertex = null, .pixel = null };
        gfx.gauss_blur_vertical_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    // PSOs
    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.clear_screen_pso = zf.createPso(pipeline_desc, gfx.clear_screen_shader) catch unreachable;
    }

    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.gauss_horizontal_pso = zf.createPso(pipeline_desc, gfx.gauss_blur_horizontal_shader) catch unreachable;
    }

    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.gauss_vertical_pso = zf.createPso(pipeline_desc, gfx.gauss_blur_vertical_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{.R8G8B8A8_SRGB};
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mRenderTargetCount = render_targets.len;
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;

        var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_NONE;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        gfx.blit_pso = zf.createPso(pipeline_desc, gfx.blit_shader) catch unreachable;

        render_targets[0] = zf.getSwapChainFormat();
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        gfx.blit_swapchain_pso = zf.createPso(pipeline_desc, gfx.blit_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{.R8G8B8A8_SRGB};
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mRenderTargetCount = render_targets.len;
        graphics_desc.pColorFormats = @ptrCast(&render_targets);
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;

        var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_BACK;
        rasterizer_state_desc.mFillMode = zf.FillMode.FILL_MODE_SOLID;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
        depth_state_desc.mDepthWrite = true;
        depth_state_desc.mDepthTest = true;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_GEQUAL;
        graphics_desc.pDepthState = @ptrCast(&depth_state_desc);
        graphics_desc.mDepthStencilFormat = .D32_SFLOAT;

        gfx.object_pso = zf.createPso(pipeline_desc, gfx.object_shader) catch unreachable;
    }

    // Render Targets
    {
        var gbuffer0_desc = std.mem.zeroes(zf.RenderTargetDesc);
        gbuffer0_desc.pName = "GBuffer 0";
        gbuffer0_desc.mArraySize = 1;
        gbuffer0_desc.mDepth = 1;
        gbuffer0_desc.mFormat = .R8G8B8A8_SRGB;
        gbuffer0_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        gbuffer0_desc.mWidth = @intCast(window_width);
        gbuffer0_desc.mHeight = @intCast(window_height);
        gbuffer0_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        gbuffer0_desc.mSampleQuality = 0;
        gbuffer0_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.gbuffer0 = zf.createRenderTarget(gbuffer0_desc) catch unreachable;
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

    // Render Textures
    {
        var rt_desc = std.mem.zeroes(zf.TextureDesc);
        rt_desc.mWidth = @intCast(window_width);
        rt_desc.mHeight = @intCast(window_height);
        rt_desc.mDepth = 1;
        rt_desc.mArraySize = 1;
        rt_desc.mMipLevels = 1;
        rt_desc.mClearValue.__struct_field1.r = 0.0;
        rt_desc.mClearValue.__struct_field1.g = 0.0;
        rt_desc.mClearValue.__struct_field1.b = 0.0;
        rt_desc.mClearValue.__struct_field1.a = 0.0;
        rt_desc.mFormat = .R8G8B8A8_SRGB;
        rt_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        rt_desc.mDescriptors.bits = zf.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits | zf.DescriptorType.DESCRIPTOR_TYPE_RW_TEXTURE.bits;
        rt_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        rt_desc.mSampleQuality = 0;
        rt_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;

        rt_desc.pName = "Scene Color";
        gfx.scene_color = zf.createRenderTexture(rt_desc) catch unreachable;

        rt_desc.pName = "Gaussian Blur A";
        gfx.gauss_blur_a = zf.createRenderTexture(rt_desc) catch unreachable;

        rt_desc.pName = "Gaussian Blur B";
        gfx.gauss_blur_b = zf.createRenderTexture(rt_desc) catch unreachable;
    }

    // Uniform Buffers
    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.global_frame_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(Frame), "Global Frame Constant Buffer");
        }
    }

    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.gauss_blur_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(BlurData), "Gaussian Blur Constant Buffer");
        }
    }

    // Geometry Buffers
    {
        gfx.vertex_buffer = zf.createRawBuffer(8 * 1024 * 1024, Vertex, true, "Vertex Buffer");
        gfx.vertex_buffer_offset = 0;
        gfx.index_buffer = zf.createIndexBuffer(8 * 1024 * 1024, zf.IndexType.INDEX_TYPE_UINT32, "Index Buffer");
        gfx.index_buffer_offset = 0;
    }

    // GPU-Scene buffers
    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.transform_buffers[frame_index] = zf.createRawBuffer(8 * 1024 * 1024, Transform, true, "Transform Buffer");
        }

        const objects_per_side = 9;
        var transforms: [objects_per_side * objects_per_side]Transform = undefined;
        for (0..objects_per_side) |y| {
            for (0..objects_per_side) |x| {
                const z_trans = zmath.translation(-6.0 + @as(f32, @floatFromInt(x)) * 1.0, -5.0 + @as(f32, @floatFromInt(y)) * 1.25, 0.0);
                const z_rot = zmath.rotationY(@floatFromInt(x));
                const z_scale = zmath.scaling(0.07, 0.07, 0.07);
                const z_world = zmath.mul(z_scale, zmath.mul(z_rot, z_trans));
                zmath.storeMat(&transforms[y + x * objects_per_side].world_matrix, z_world);
            }
        }

        // TODO: Test appending while frame is running
        const transform_data = zf.DataSlice{
            .data = @ptrCast(&transforms),
            .size = @sizeOf(Transform) * transforms.len,
        };
        for (0..zf.frames_in_flight_count) |frame_index| {
            zf.updateBuffer(transform_data, 0, gfx.transform_buffers[frame_index]);
        }
    }

    // Clear Screen material
    {
        gfx.clear_screen_material.passes_count = 1;
        gfx.clear_screen_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.clear_screen_material.passes[0].pass = .default;
        gfx.clear_screen_material.passes[0].pso = gfx.clear_screen_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.clear_screen_shader) catch unreachable;
        gfx.clear_screen_material.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.clear_screen_material.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.clear_screen_material.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.clear_screen_material.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.clear_screen_material.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    // Gauss Blur Horizontal material
    {
        gfx.gauss_blur_horizontal_material.passes_count = 1;
        gfx.gauss_blur_horizontal_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.gauss_blur_horizontal_material.passes[0].pass = .default;
        gfx.gauss_blur_horizontal_material.passes[0].pso = gfx.gauss_horizontal_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.gauss_blur_horizontal_shader) catch unreachable;
        gfx.gauss_blur_horizontal_material.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.gauss_blur_horizontal_material.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.gauss_blur_horizontal_material.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.gauss_blur_horizontal_material.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.gauss_blur_horizontal_material.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    // Gauss Blur Vertical material
    {
        gfx.gauss_blur_vertical_material.passes_count = 1;
        gfx.gauss_blur_vertical_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.gauss_blur_vertical_material.passes[0].pass = .default;
        gfx.gauss_blur_vertical_material.passes[0].pso = gfx.gauss_vertical_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.gauss_blur_vertical_shader) catch unreachable;
        gfx.gauss_blur_vertical_material.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.gauss_blur_vertical_material.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.gauss_blur_vertical_material.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.gauss_blur_vertical_material.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.gauss_blur_vertical_material.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    // Blit material 1
    {
        gfx.blit_material_1.passes_count = 1;
        gfx.blit_material_1.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.blit_material_1.passes[0].pass = .default;
        gfx.blit_material_1.passes[0].pso = gfx.blit_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.blit_shader) catch unreachable;
        gfx.blit_material_1.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.blit_material_1.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.blit_material_1.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.blit_material_1.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.blit_material_1.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    // Blit material 2
    {
        gfx.blit_material_2.passes_count = 1;
        gfx.blit_material_2.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.blit_material_2.passes[0].pass = .default;
        gfx.blit_material_2.passes[0].pso = gfx.blit_swapchain_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.blit_shader) catch unreachable;
        gfx.blit_material_2.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.blit_material_2.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.blit_material_2.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.blit_material_2.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.blit_material_2.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    // Object material
    {
        gfx.object_material.passes_count = 1;
        gfx.object_material.passes[0] = std.mem.zeroes(GfxMaterialPass);
        gfx.object_material.passes[0].pass = .default;
        gfx.object_material.passes[0].pso = gfx.object_pso;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.object_shader) catch unreachable;
        gfx.object_material.passes[0].per_draw_descriptor_set = descriptor_set_handles.per_draw;
        gfx.object_material.passes[0].per_batch_descriptor_set = descriptor_set_handles.per_batch;
        gfx.object_material.passes[0].per_frame_descriptor_set = descriptor_set_handles.per_frame;
        gfx.object_material.passes[0].persistent_descriptor_set = descriptor_set_handles.persistent;
        gfx.object_material.passes[0].persistent_samplers_descriptor_set = descriptor_set_handles.persistent_samplers;
    }

    updateDescriptorSets();

    // TODO: There must me a better way.
    gltf = @constCast(&(zgltf.init(std.heap.page_allocator)));
    defer gltf.deinit();

    var temp_allocator = std.heap.page_allocator;
    {
        const base_path = std.fs.path.join(temp_allocator, &[_][]const u8{ "content", "models", "stylized_nature" }) catch unreachable;
        defer temp_allocator.free(base_path);
        loadGltfMesh(base_path, "Birch_1.gltf", temp_allocator, &gfx.birch_1_mesh);
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

        const frame_index = zf.frameStart();

        const z_view = zmath.lookAtLh(
            zmath.f32x4(0.0, 0.0, -10.0, 1.0),
            zmath.f32x4(0.0, 0.0, 0.0, 1.0),
            zmath.f32x4(0.0, 1.0, 0.0, 0.0));

        const z_proj = zmath.perspectiveFovLh(
            std.math.degreesToRadians(45.0),
            @as(f32, @floatFromInt(frame_buffer_size[0])) / @as(f32, @floatFromInt(frame_buffer_size[1])),
            100.0,
            0.01);

        var frame = Frame{
            .view_matrix = undefined,
            .projection_matrix = undefined,
            .view_projection_matrix = undefined,
            .time = @floatCast(zglfw.getTime()),
            .transform_buffer_index = zf.getBufferBindlessIndex(gfx.transform_buffers[frame_index]),
            .vertex_buffer_index = zf.getBufferBindlessIndex(gfx.vertex_buffer),
        };
        zmath.storeMat(&frame.view_matrix, zmath.transpose(z_view));
        zmath.storeMat(&frame.projection_matrix, zmath.transpose(z_proj));
        zmath.storeMat(&frame.view_projection_matrix, zmath.mul(z_view, z_proj));

        const frame_data = zf.DataSlice{
            .data = @ptrCast(&frame),
            .size = @sizeOf(Frame),
        };
        zf.updateUniformBuffer(frame_data, gfx.global_frame_constant_buffers[frame_index]);

        // Clear screen: Scene Color
        {
            var texture_barriers = [_]zf.TextureBarrier{
                .{
                    .render_texture_handle = gfx.scene_color,
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(null, &texture_barriers, null);
            zf.cmdBindPipeline(gfx.clear_screen_pso);
            zf.cmdBindDescriptorSet(frame_index, gfx.clear_screen_material.passes[0].per_frame_descriptor_set);
            zf.cmdDispacth(@intCast(@divTrunc(frame_buffer_size[0], 8) + 1), @intCast(@divTrunc(frame_buffer_size[1], 8) + 1), 1);

            texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(null, &texture_barriers, null);
        }

        // Blit: Scene Color -> GBuffer0
        {
            var rt_barriers = [_]zf.RenderTargetBarrier{
                .{
                    .render_target_handle = gfx.gbuffer0,
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET,
                },
                .{
                    .render_target_handle = gfx.depth_buffer,
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE,
                },
            };
            zf.cmdResourceBarrier(null, null, &rt_barriers);

            var bind_render_targets = [_]zf.BindRenderTarget{
                .{
                    .render_target_handle = gfx.gbuffer0,
                    .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
                },
                .{
                    .render_target_handle = gfx.depth_buffer,
                    .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
                },
            };
            zf.cmdBindRenderTargets(&bind_render_targets);

            zf.cmdSetDefaultViewportAndScissor(@intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]));

            zf.cmdBindPipeline(gfx.blit_pso);
            zf.cmdBindDescriptorSet(0, gfx.blit_material_1.passes[0].persistent_samplers_descriptor_set);
            zf.cmdBindDescriptorSet(frame_index, gfx.blit_material_1.passes[0].per_frame_descriptor_set);
            zf.cmdDraw(3, 0);

            zf.cmdBindPipeline(gfx.object_pso);
            zf.cmdBindDescriptorSet(frame_index, gfx.object_material.passes[0].per_frame_descriptor_set);
            zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);
            for (0..gfx.birch_1_mesh.sub_meshes_count) |sub_mesh_index| {
                const sub_mesh = gfx.birch_1_mesh.sub_meshes[sub_mesh_index];
                zf.cmdDrawIndexedInstanced(
                    sub_mesh.index_count,
                    sub_mesh.first_index,
                    81,
                    sub_mesh.first_vertex,
                    0);
            }

            rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
            rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            rt_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE;
            rt_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            zf.cmdResourceBarrier(null, null, &rt_barriers);
        }

        // Blur
        {
            var blur = BlurData{
                .sigma = 8.0,
                .support = 0.995,
                .sRGB = 1.0,
                .padding = 42.0,
            };

            const blur_data = zf.DataSlice{
                .data = @ptrCast(&blur),
                .size = @sizeOf(BlurData),
            };
            zf.updateUniformBuffer(blur_data, gfx.gauss_blur_constant_buffers[frame_index]);

            // Horizontal Blur
            {
                var texture_barriers = [_]zf.TextureBarrier{
                    .{
                        .render_texture_handle = gfx.gauss_blur_a,
                        .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                        .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                    },
                };
                zf.cmdResourceBarrier(null, &texture_barriers, null);

                zf.cmdBindPipeline(gfx.gauss_horizontal_pso);
                zf.cmdBindDescriptorSet(0, gfx.gauss_blur_horizontal_material.passes[0].persistent_descriptor_set);
                zf.cmdBindDescriptorSet(frame_index, gfx.gauss_blur_horizontal_material.passes[0].per_frame_descriptor_set);
                zf.cmdDispacth(@intCast(@divTrunc(frame_buffer_size[0], 8) + 1), @intCast(@divTrunc(frame_buffer_size[1], 8) + 1), 1);

                texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
                texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

                zf.cmdResourceBarrier(null, &texture_barriers, null);
            }

            // Vertical Blur
            {
                var texture_barriers = [_]zf.TextureBarrier{
                    .{
                        .render_texture_handle = gfx.gauss_blur_b,
                        .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                        .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                    },
                };
                zf.cmdResourceBarrier(null, &texture_barriers, null);

                zf.cmdBindPipeline(gfx.gauss_vertical_pso);
                zf.cmdBindDescriptorSet(0, gfx.gauss_blur_vertical_material.passes[0].persistent_descriptor_set);
                zf.cmdBindDescriptorSet(frame_index, gfx.gauss_blur_vertical_material.passes[0].per_frame_descriptor_set);
                zf.cmdDispacth(@intCast(@divTrunc(frame_buffer_size[0], 8) + 1), @intCast(@divTrunc(frame_buffer_size[1], 8) + 1), 1);

                texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
                texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

                zf.cmdResourceBarrier(null, &texture_barriers, null);
            }
        }

        // Blit to swapchain
        {
            const swap_chain_buffer_handle = zf.getSwapChainBufferHandle();

            var rt_barriers = [_]zf.RenderTargetBarrier{
                .{
                    .render_target_handle = swap_chain_buffer_handle,
                    .current_state = zf.ResourceState.RESOURCE_STATE_PRESENT,
                    .new_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET,
                },
            };
            zf.cmdResourceBarrier(null, null, &rt_barriers);

            var bind_render_targets = [_]zf.BindRenderTarget{
                .{
                    .render_target_handle = swap_chain_buffer_handle,
                    .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
                },
            };
            zf.cmdBindRenderTargets(&bind_render_targets);

            zf.cmdSetDefaultViewportAndScissor(@intCast(frame_buffer_size[0]), @intCast(frame_buffer_size[1]));

            zf.cmdBindPipeline(gfx.blit_swapchain_pso);
            zf.cmdBindDescriptorSet(0, gfx.blit_material_2.passes[0].persistent_samplers_descriptor_set);
            zf.cmdBindDescriptorSet(frame_index, gfx.blit_material_2.passes[0].per_frame_descriptor_set);
            zf.cmdDraw(3, 0);

            rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
            rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_PRESENT;
            zf.cmdResourceBarrier(null, null, &rt_barriers);
        }

        zf.frameSubmit();
    }
}

fn updateDescriptorSets() void {
    // Blit Material 1: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_source",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.scene_color,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.blit_shader,
            gfx.blit_material_1.passes[0].per_frame_descriptor_set
        );
    }

    // Blit Material 1: Persistent Sampler
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_linear_repeat_sampler",
                .binding_type = .sampler,
                .static_sampler_handle = gfx.linear_repeat_sampler,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .persistent_sampler,
            0,
            gfx.blit_shader,
            gfx.blit_material_1.passes[0].persistent_samplers_descriptor_set
        );
    }

    // Blit Material 2: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_source",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.gauss_blur_b,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.blit_shader,
            gfx.blit_material_2.passes[0].per_frame_descriptor_set
        );
    }

    // Blit Material 2: Persistent Sampler
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_linear_repeat_sampler",
                .binding_type = .sampler,
                .static_sampler_handle = gfx.linear_repeat_sampler,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .persistent_sampler,
            0,
            gfx.blit_shader,
            gfx.blit_material_2.passes[0].persistent_samplers_descriptor_set
        );
    }

    // Object Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.object_shader,
            gfx.object_material.passes[0].per_frame_descriptor_set
        );
    }

    // Clear Screen Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.scene_color,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.clear_screen_shader,
            gfx.clear_screen_material.passes[0].per_frame_descriptor_set
        );
    }

    // Blur Horizontal Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.gauss_blur_constant_buffers[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.gauss_blur_horizontal_shader,
            gfx.gauss_blur_horizontal_material.passes[0].per_frame_descriptor_set
        );
    }

    // Blur Vertical Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.gauss_blur_constant_buffers[frame_index],
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .per_frame,
            @intCast(frame_index),
            gfx.gauss_blur_vertical_shader,
            gfx.gauss_blur_vertical_material.passes[0].per_frame_descriptor_set
        );
    }

    // Blur Horizontal Material: Persistent
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_input",
                .binding_type = .render_target,
                .render_target_handle = gfx.gbuffer0,
            },
            .{
                .name = "g_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.gauss_blur_a,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .persistent,
            0,
            gfx.gauss_blur_horizontal_shader,
            gfx.gauss_blur_horizontal_material.passes[0].persistent_descriptor_set
        );
    }

    // Blur Vertical Material: Persistent
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_input",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.gauss_blur_a,
            },
            .{
                .name = "g_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.gauss_blur_b,
            },
        };

        zf.updateDescriptorSet(
            &resource_binding_descs,
            .persistent,
            0,
            gfx.gauss_blur_vertical_shader,
            gfx.gauss_blur_vertical_material.passes[0].persistent_descriptor_set
        );
    }
}

fn loadGltfMesh(base_path: []const u8, file_name: []const u8, allocator: std.mem.Allocator, out_mesh: *Mesh) void {
    const gltf_path = std.fs.path.join(allocator, &[_][]const u8{ base_path, file_name }) catch unreachable;
    defer allocator.free(gltf_path);

    const json = std.fs.cwd().readFileAllocOptions(
        allocator,
        gltf_path,
        512_000,
        null,
        4,
        null
    ) catch unreachable;
    defer allocator.free(json);
    gltf.parse(json) catch unreachable;

    std.debug.assert(gltf.data.buffers.items.len == 1);
    const bin_path = std.fs.path.join(allocator, &[_][]const u8{ base_path, gltf.data.buffers.items[0].uri.? }) catch unreachable;
    defer allocator.free(bin_path);

    const bin = std.fs.cwd().readFileAllocOptions(
        allocator,
        bin_path,
        5_000_000,
        null,
        4,
        null
    ) catch unreachable;
    defer allocator.free(bin);

    var mesh_vertices = std.ArrayList(Vertex).init(allocator);
    defer mesh_vertices.deinit();
    var mesh_indices = std.ArrayList(u32).init(allocator);
    defer mesh_indices.deinit();

    var positions = std.ArrayList(f32).init(allocator);
    defer positions.deinit();
    var uvs = std.ArrayList(f32).init(allocator);
    defer uvs.deinit();
    var normals = std.ArrayList(f32).init(allocator);
    defer normals.deinit();
    var indices = std.ArrayList(u32).init(allocator);
    defer indices.deinit();

    const mesh = gltf.data.meshes.items[0];
    std.debug.assert(mesh.primitives.items.len < 8);
    out_mesh.sub_meshes_count = 0;

    for (mesh.primitives.items) |primitive| {
        positions.clearRetainingCapacity();
        uvs.clearRetainingCapacity();
        normals.clearRetainingCapacity();
        indices.clearRetainingCapacity();

        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec3);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &positions, accessor, bin);
                },
                .texcoord => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec2);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &uvs, accessor, bin);
                },
                .normal => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    std.debug.assert(accessor.type == .vec3);
                    std.debug.assert(accessor.component_type == .float);
                    gltf.getDataFromBufferView(f32, &normals, accessor, bin);
                },
                else => {}
            }
        }

        std.debug.assert(primitive.indices != null);
        const accessor = gltf.data.accessors.items[primitive.indices.?];
        if (accessor.component_type == .unsigned_short) {
            var indices16 = std.ArrayList(u16).init(allocator);
            defer indices16.deinit();
            gltf.getDataFromBufferView(u16, &indices16, accessor, bin);

            for (indices16.items) |index_16| {
                indices.append(@intCast(index_16)) catch unreachable;
            }
        } else {
            gltf.getDataFromBufferView(u32, &indices, accessor, bin);
        }

        const positions_count = @divExact(positions.items.len, 3);

        out_mesh.sub_meshes[out_mesh.sub_meshes_count].index_count = @intCast(indices.items.len);
        out_mesh.sub_meshes[out_mesh.sub_meshes_count].first_index = @intCast(mesh_indices.items.len);
        out_mesh.sub_meshes[out_mesh.sub_meshes_count].vertex_count = @intCast(positions_count);
        out_mesh.sub_meshes[out_mesh.sub_meshes_count].first_vertex = @intCast(mesh_vertices.items.len);
        out_mesh.sub_meshes_count += 1;

        for (0..positions_count) |vertex_index| {
            const vertex = Vertex{
                .position = .{ positions.items[vertex_index * 3 + 0] * -1.0, positions.items[vertex_index * 3 + 1], positions.items[vertex_index * 3 + 2] },
                .normal = .{ normals.items[vertex_index * 3 + 0] * -1.0, normals.items[vertex_index * 3 + 1], normals.items[vertex_index * 3 + 2] },
                .uv = .{ uvs.items[vertex_index * 2 + 0], uvs.items[vertex_index * 2 + 1] },
            };
            mesh_vertices.append(vertex) catch unreachable;
        }

        for (indices.items) |index| {
            mesh_indices.append(index) catch unreachable;
        }

    }

    const vertex_data = zf.DataSlice{
        .data = @ptrCast(mesh_vertices.items),
        .size = @sizeOf(Vertex) * mesh_vertices.items.len,
    };
    zf.updateBuffer(vertex_data, gfx.vertex_buffer_offset, gfx.vertex_buffer);

    const index_data = zf.DataSlice{
        .data = @ptrCast(mesh_indices.items),
        .size = @sizeOf(u32) * mesh_indices.items.len,
    };
    zf.updateBuffer(index_data, gfx.index_buffer_offset, gfx.index_buffer);

    // TODO: Lock-guard when multithreading
    gfx.vertex_buffer_offset += vertex_data.size;
    gfx.index_buffer_offset += index_data.size;
}
