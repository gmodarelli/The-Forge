const std = @import("std");
const Camera = @import("camera.zig").Camera;
const dds = @import("dds.zig");
const geometry = @import("geometry.zig");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");
const zmath = @import("zmath");

pub const Gfx = struct {
    // Static samplers
    linear_repeat_static_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,
    linear_clamp_static_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,

    // Bindless samplers
    linear_repeat_sampler: zf.SamplerHandle = zf.StaticSamplerHandle.nil,
    linear_clamp_sampler: zf.SamplerHandle = zf.StaticSamplerHandle.nil,

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
    geometry_buffer_mutex: std.Thread.Mutex,

    // GPU-Scene buffers
    instance_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    transform_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    material_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    // Materials
    blit_material_1: GfxMaterial = undefined,
    blit_material_2: GfxMaterial = undefined,
    object_material: GfxMaterial = undefined,
    clear_screen_material: GfxMaterial = undefined,
    gauss_blur_horizontal_material: GfxMaterial = undefined,
    gauss_blur_vertical_material: GfxMaterial = undefined,

    // CPU Geometry data
    birch_1_mesh: geometry.Mesh = undefined,
    birch_2_mesh: geometry.Mesh = undefined,
    bush_large_mesh: geometry.Mesh = undefined,

    // Textures
    bark_birch_albedo: zf.TextureHandle = zf.TextureHandle.nil,
    bark_birch_normal: zf.TextureHandle = zf.TextureHandle.nil,
    leaves_birch_albedo: zf.TextureHandle = zf.TextureHandle.nil,
    leaves_giant_pine_albedo: zf.TextureHandle = zf.TextureHandle.nil,
};

pub const Frame = struct {
    view_matrix: [16]f32,
    projection_matrix: [16]f32,
    view_projection_matrix: [16]f32,
    linear_repeat_sampler_index: u32,
    linear_clamp_sampler_index: u32,
    _padding: [2]u32,
    time: f32,
    vertex_buffer_index: u32,
    transform_buffer_index: u32,
    material_buffer_index: u32,
    instance_buffer_index: u32,
};

pub const Transform = struct {
    world_matrix: [16]f32,
};

pub const MaterialData = struct {
    albedo_texture_id: u32 = std.math.maxInt(u32),
    albedo_sampler_id: u32 = std.math.maxInt(u32),
    normal_texture_id: u32 = std.math.maxInt(u32),
    normal_sampler_id: u32 = std.math.maxInt(u32),
};

pub const InstanceData = struct {
    transform_index: u32,
    material_index: u32,
    _padding: [2]u32 = .{ 42, 42 },
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

    pub fn bindPipeline(self: *GfxMaterialPass) void {
        zf.cmdBindPipeline(self.pso);
    }

    pub fn bindDescriptorSets(self: *GfxMaterialPass, frame_index: u32) void {
        bindDescriptorSet(self.per_draw_descriptor_set, frame_index);
        bindDescriptorSet(self.per_batch_descriptor_set, frame_index);
        bindDescriptorSet(self.per_frame_descriptor_set, frame_index);
        bindDescriptorSet(self.persistent_descriptor_set, 0);
        bindDescriptorSet(self.persistent_samplers_descriptor_set, 0);
    }

    fn bindDescriptorSet(handle: zf.DescriptorSetHandle, frame_index: u32) void {
        if (handle.id != zf.DescriptorSetHandle.nil.id) {
            zf.cmdBindDescriptorSet(frame_index, handle);
        }
    }
};

const material_passes_max_count: u32 = 8;

pub const GfxMaterial = struct {
    passes: [material_passes_max_count]GfxMaterialPass,
    passes_count: u32,

    pub fn bindMaterialPass(self: *GfxMaterial, pass: Pass, frame_index: u32) void {
        const pass_index: usize = @intFromEnum(pass);
        self.passes[pass_index].bindPipeline();
        self.passes[pass_index].bindDescriptorSets(frame_index);
    }
};

var gfx_allocator: std.mem.Allocator = undefined;
var gfx: *Gfx = undefined;

pub fn init(hwnd: std.os.windows.HWND, window_width: u32, window_height: u32) void {
    const gpu_desc = zf.GpuDesc{
        .graphics_root_signature_path = "shaders/GraphicsRootSignature.rs",
        .compute_root_signature_path = "shaders/ComputeRootSignature.rs",
        .hwnd = hwnd,
    };

    gfx_allocator = std.heap.page_allocator;

    zf.initializeGpu(gpu_desc, gfx_allocator) catch unreachable;

    gfx = gfx_allocator.create(Gfx) catch unreachable;

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
        gfx.linear_repeat_static_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_static_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;
    }

    // Bindless Samplers
    {
        var sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        sampler_desc.mMinFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMagFilter = zf.FilterType.FILTER_LINEAR;
        sampler_desc.mMipMapMode = zf.MipMapMode.MIPMAP_MODE_LINEAR;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_REPEAT;
        gfx.linear_repeat_sampler = zf.createBindlessSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = zf.AddressMode.ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_sampler = zf.createBindlessSampler(sampler_desc) catch unreachable;
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
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_NONE;
        rasterizer_state_desc.mFillMode = zf.FillMode.FILL_MODE_SOLID;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
        depth_state_desc.mDepthWrite = true;
        depth_state_desc.mDepthTest = true;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_GEQUAL;
        graphics_desc.pDepthState = @ptrCast(&depth_state_desc);
        graphics_desc.mDepthStencilFormat = .D32_SFLOAT;

        // var blend_state_desc = std.mem.zeroes(zf.BlendStateDesc);
        // blend_state_desc.mSrcFactors[0] = .BC_SRC_ALPHA;
        // blend_state_desc.mDstFactors[0] = .BC_ONE_MINUS_SRC_ALPHA;
        // blend_state_desc.mBlendModes[0] = .BM_ADD;
        // blend_state_desc.mSrcAlphaFactors[0] = .BC_ONE;
        // blend_state_desc.mDstAlphaFactors[0] = .BC_ZERO;
        // blend_state_desc.mBlendAlphaModes[0] = .BM_ADD;
        // blend_state_desc.mColorWriteMasks[0] = .COLOR_MASK_ALL;
        // blend_state_desc.mRenderTargetMask = .BLEND_STATE_TARGET_0;
        // blend_state_desc.mAlphaToCoverage = true;
        // graphics_desc.pBlendState = @ptrCast(&blend_state_desc);

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
        gfx.vertex_buffer = zf.createRawBuffer(8 * 1024 * 1024, geometry.Vertex, true, "Vertex Buffer");
        gfx.vertex_buffer_offset = 0;
        gfx.index_buffer = zf.createIndexBuffer(8 * 1024 * 1024, zf.IndexType.INDEX_TYPE_UINT32, "Index Buffer");
        gfx.index_buffer_offset = 0;
        gfx.geometry_buffer_mutex = std.Thread.Mutex{};
    }

    loadMeshes();
    loadTextures();

    // GPU-Scene buffers
    {
        // Materials buffers
        // =================
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.material_buffers[frame_index] = zf.createRawBuffer(8 * 1024, MaterialData, true, "Material Buffer");
        }

        var materials = [_]MaterialData{
            .{
                .albedo_texture_id = zf.getTextureBindlessIndex(gfx.bark_birch_albedo),
                .normal_texture_id = zf.getTextureBindlessIndex(gfx.bark_birch_normal),
            },
            .{
                .albedo_texture_id = zf.getTextureBindlessIndex(gfx.leaves_birch_albedo),
            },
            .{
                .albedo_texture_id = zf.getTextureBindlessIndex(gfx.leaves_giant_pine_albedo),
            },
        };

        const material_data = zf.DataSlice{
            .data = @ptrCast(&materials),
            .size = @sizeOf(MaterialData) * materials.len,
        };
        for (0..zf.frames_in_flight_count) |frame_index| {
            zf.updateBuffer(material_data, 0, gfx.material_buffers[frame_index]);
        }

        // Transforms buffers
        // ==================
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.transform_buffers[frame_index] = zf.createRawBuffer(8 * 1024 * 1024, Transform, true, "Transform Buffer");
        }

        var transforms: [3]Transform = undefined;
        {
            var z_trans = zmath.translation(-6.0, -7.0, 0.0);
            zmath.storeMat(&transforms[0].world_matrix, z_trans);
            z_trans = zmath.translation(0.0, -7.0, 0.0);
            zmath.storeMat(&transforms[1].world_matrix, z_trans);
            z_trans = zmath.translation(6.0, -7.0, 0.0);
            zmath.storeMat(&transforms[2].world_matrix, z_trans);
        }

        const transform_data = zf.DataSlice{
            .data = @ptrCast(&transforms),
            .size = @sizeOf(Transform) * transforms.len,
        };
        for (0..zf.frames_in_flight_count) |frame_index| {
            zf.updateBuffer(transform_data, 0, gfx.transform_buffers[frame_index]);
        }

        // Instances buffers
        // =================
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.instance_buffers[frame_index] = zf.createRawBuffer(8 * 1024, InstanceData, true, "Instance Buffer");
        }

        const instances = [_]InstanceData{
            .{ .transform_index = 0, .material_index = 0, ._padding = .{ 42, 42 } },
            .{ .transform_index = 0, .material_index = 1, ._padding = .{ 42, 42 } },
            .{ .transform_index = 1, .material_index = 0, ._padding = .{ 42, 42 } },
            .{ .transform_index = 1, .material_index = 1, ._padding = .{ 42, 42 } },
            .{ .transform_index = 2, .material_index = 2, ._padding = .{ 42, 42 } },
        };

        const instance_data = zf.DataSlice{
            .data = @ptrCast(&instances),
            .size = @sizeOf(InstanceData) * instances.len,
        };
        for (0..zf.frames_in_flight_count) |frame_index| {
            zf.updateBuffer(instance_data, 0, gfx.instance_buffers[frame_index]);
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
}

pub fn shutdown() void {
    zf.shutdownGpu();
    gfx_allocator.destroy(gfx);
}

pub fn resize() void {
    zf.requestResize();
}

pub fn draw(camera: *Camera, window_width: u32, window_height: u32) void {
    const frame_index = zf.frameStart();

    const z_view = camera.view;

    const z_proj = zmath.perspectiveFovLh(
        std.math.degreesToRadians(45.0),
        @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(window_height)),
        100.0,
        0.01);

    var frame = Frame{
        .view_matrix = undefined,
        .projection_matrix = undefined,
        .view_projection_matrix = undefined,
        .linear_repeat_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_repeat_sampler),
        .linear_clamp_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_clamp_sampler),
        ._padding = .{ std.math.maxInt(u32), std.math.maxInt(u32) },
        .time = @floatCast(zglfw.getTime()),
        .vertex_buffer_index = zf.getBufferBindlessIndex(gfx.vertex_buffer),
        .transform_buffer_index = zf.getBufferBindlessIndex(gfx.transform_buffers[frame_index]),
        .material_buffer_index = zf.getBufferBindlessIndex(gfx.material_buffers[frame_index]),
        .instance_buffer_index = zf.getBufferBindlessIndex(gfx.instance_buffers[frame_index]),
    };
    zmath.storeMat(&frame.view_matrix, zmath.transpose(z_view));
    zmath.storeMat(&frame.projection_matrix, zmath.transpose(z_proj));
    zmath.storeMat(&frame.view_projection_matrix, zmath.mul(z_view, z_proj));

    const frame_data = zf.DataSlice{
        .data = @ptrCast(&frame),
        .size = @sizeOf(Frame),
    };
    zf.updateUniformBuffer(frame_data, gfx.global_frame_constant_buffers[frame_index]);

    // // Clear screen: Scene Color
    // {
    //     var texture_barriers = [_]zf.TextureBarrier{
    //         .{
    //             .render_texture_handle = gfx.scene_color,
    //             .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
    //             .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
    //         },
    //     };

    //     zf.cmdResourceBarrier(null, &texture_barriers, null);
    //     gfx.clear_screen_material.bindMaterialPass(.default, frame_index);
    //     zf.cmdDispacth(@intCast(@divTrunc(frame_buffer_size[0], 8) + 1), @intCast(@divTrunc(frame_buffer_size[1], 8) + 1), 1);

    //     texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
    //     texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

    //     zf.cmdResourceBarrier(null, &texture_barriers, null);
    // }

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

        zf.cmdSetDefaultViewportAndScissor(window_width, window_height);

        // gfx.blit_material_1.bindMaterialPass(.default, frame_index);
        // zf.cmdDraw(3, 0);

        gfx.object_material.bindMaterialPass(.default, frame_index);
        zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);

        for (0..gfx.birch_1_mesh.sub_meshes_count) |sub_mesh_index| {
            const sub_mesh = gfx.birch_1_mesh.sub_meshes[sub_mesh_index];
            zf.cmdDrawIndexedInstanced(
                sub_mesh.index_count,
                sub_mesh.first_index,
                1,
                sub_mesh.first_vertex,
                0 + @as(u32, @intCast(sub_mesh_index)));
        }

        for (0..gfx.birch_2_mesh.sub_meshes_count) |sub_mesh_index| {
            const sub_mesh = gfx.birch_2_mesh.sub_meshes[sub_mesh_index];
            zf.cmdDrawIndexedInstanced(
                sub_mesh.index_count,
                sub_mesh.first_index,
                1,
                sub_mesh.first_vertex,
                2 + @as(u32, @intCast(sub_mesh_index)));
        }

        for (0..gfx.bush_large_mesh.sub_meshes_count) |sub_mesh_index| {
            const sub_mesh = gfx.bush_large_mesh.sub_meshes[sub_mesh_index];
            zf.cmdDrawIndexedInstanced(
                sub_mesh.index_count,
                sub_mesh.first_index,
                1,
                sub_mesh.first_vertex,
                4);
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
            .sigma = 0.0,
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

            gfx.gauss_blur_horizontal_material.bindMaterialPass(.default, frame_index);
            zf.cmdDispacth(@intCast(@divTrunc(window_width, 8) + 1), @intCast(@divTrunc(window_height, 8) + 1), 1);

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

            gfx.gauss_blur_vertical_material.bindMaterialPass(.default, frame_index);
            zf.cmdDispacth(@intCast(@divTrunc(window_width, 8) + 1), @intCast(@divTrunc(window_height, 8) + 1), 1);

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

        zf.cmdSetDefaultViewportAndScissor(window_width, window_height);

        gfx.blit_material_2.bindMaterialPass(.default, frame_index);
        zf.cmdDraw(3, 0);

        rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
        rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_PRESENT;
        zf.cmdResourceBarrier(null, null, &rt_barriers);
    }

    zf.frameSubmit();
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

// ███╗   ███╗███████╗███████╗██╗  ██╗███████╗███████╗
// ████╗ ████║██╔════╝██╔════╝██║  ██║██╔════╝██╔════╝
// ██╔████╔██║█████╗  ███████╗███████║█████╗  ███████╗
// ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║██╔══╝  ╚════██║
// ██║ ╚═╝ ██║███████╗███████║██║  ██║███████╗███████║
// ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝
//


fn loadMeshes() void {
    var temp_allocator = std.heap.page_allocator;

    const base_path = std.fs.path.join(temp_allocator, &[_][]const u8{ "content", "models" }) catch unreachable;
    defer temp_allocator.free(base_path);

    var mesh_vertices = std.ArrayList(geometry.Vertex).init(temp_allocator);
    defer mesh_vertices.deinit();
    var mesh_indices = std.ArrayList(u32).init(temp_allocator);
    defer mesh_indices.deinit();

    var load_desc = geometry.GltfLoadDesc{
        .base_path = base_path,
        .file_name = "Birch_1.gltf",
        .allocator = temp_allocator,
        .mesh = &gfx.birch_1_mesh,
        .mesh_vertices = &mesh_vertices,
        .mesh_indices = &mesh_indices,
    };

    geometry.loadGltfMesh(&load_desc);
    uploadMesh(&mesh_vertices, &mesh_indices, &gfx.birch_1_mesh);

    mesh_vertices.clearRetainingCapacity();
    mesh_indices.clearRetainingCapacity();
    load_desc.file_name = "Birch_2.gltf";
    load_desc.mesh = &gfx.birch_2_mesh;
    geometry.loadGltfMesh(&load_desc);
    uploadMesh(&mesh_vertices, &mesh_indices, &gfx.birch_2_mesh);

    mesh_vertices.clearRetainingCapacity();
    mesh_indices.clearRetainingCapacity();
    load_desc.file_name = "Bush_Large.gltf";
    load_desc.mesh = &gfx.bush_large_mesh;
    geometry.loadGltfMesh(&load_desc);
    uploadMesh(&mesh_vertices, &mesh_indices, &gfx.bush_large_mesh);
}

fn uploadMesh(vertices: *std.ArrayList(geometry.Vertex), indices: *std.ArrayList(u32), mesh: *geometry.Mesh) void {
    gfx.geometry_buffer_mutex.lock();
    defer gfx.geometry_buffer_mutex.unlock();

    for (0..mesh.sub_meshes_count) |sub_mesh_index| {
        mesh.sub_meshes[sub_mesh_index].first_vertex += @intCast(@divExact(gfx.vertex_buffer_offset, @sizeOf(geometry.Vertex)));
        mesh.sub_meshes[sub_mesh_index].first_index += @intCast(@divExact(gfx.index_buffer_offset, @sizeOf(u32)));
    }

    const vertex_data = zf.DataSlice{
        .data = @ptrCast(vertices.items),
        .size = @sizeOf(geometry.Vertex) * vertices.items.len,
    };
    zf.updateBuffer(vertex_data, gfx.vertex_buffer_offset, gfx.vertex_buffer);

    const index_data = zf.DataSlice{
        .data = @ptrCast(indices.items),
        .size = @sizeOf(u32) * indices.items.len,
    };
    zf.updateBuffer(index_data, gfx.index_buffer_offset, gfx.index_buffer);

    gfx.vertex_buffer_offset += vertex_data.size;
    gfx.index_buffer_offset += index_data.size;
}

// ████████╗███████╗██╗  ██╗████████╗██╗   ██╗██████╗ ███████╗███████╗
// ╚══██╔══╝██╔════╝╚██╗██╔╝╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔════╝
//    ██║   █████╗   ╚███╔╝    ██║   ██║   ██║██████╔╝█████╗  ███████╗
//    ██║   ██╔══╝   ██╔██╗    ██║   ██║   ██║██╔══██╗██╔══╝  ╚════██║
//    ██║   ███████╗██╔╝ ██╗   ██║   ╚██████╔╝██║  ██║███████╗███████║
//    ╚═╝   ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝
//

fn loadTextures() void {
    const temp_allocator = std.heap.page_allocator;
    gfx.bark_birch_albedo = loadDdsTexture("content/textures/Bark_BirchTree.dds", true, temp_allocator) catch unreachable;
    gfx.bark_birch_normal = loadDdsTexture("content/textures/Bark_BirchTree_Normal.dds", true, temp_allocator) catch unreachable;
    gfx.leaves_birch_albedo = loadDdsTexture("content/textures/Leaves_Birch_C.dds", true, temp_allocator) catch unreachable;
    gfx.leaves_giant_pine_albedo = loadDdsTexture("content/textures/Leaves_GiantPine_C.dds", true, temp_allocator) catch unreachable;
}

fn loadDdsTexture(file_path: []const u8, bindless: bool, allocator: std.mem.Allocator) !zf.TextureHandle {
    const dds_image = dds.loadDdsImage(file_path, allocator) catch unreachable;

    // Create texture
    var texture_desc = std.mem.zeroes(zf.TextureDesc);
    texture_desc.mWidth = dds_image.width;
    texture_desc.mHeight = dds_image.height;
    texture_desc.mDepth = dds_image.depth;
    texture_desc.mArraySize = dds_image.array_size;
    texture_desc.mMipLevels = dds_image.mip_levels;
    texture_desc.mFormat = dds_image.format;
    texture_desc.mStartState = zf.ResourceState.RESOURCE_STATE_COMMON;
    texture_desc.mDescriptors.bits = zf.DescriptorType.DESCRIPTOR_TYPE_TEXTURE.bits;
    texture_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
    texture_desc.mSampleQuality = 0;
    const texture_handle = zf.createTexture(texture_desc, bindless) catch unreachable;

    // Update texture
    zf.updateTexture(texture_handle, texture_desc, dds_image.data);

    return texture_handle;
}