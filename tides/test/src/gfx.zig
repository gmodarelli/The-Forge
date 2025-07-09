const std = @import("std");
const Camera = @import("camera.zig").Camera;
const dds = @import("dds.zig");
const font = @import("font.zig");
const geometry = @import("geometry.zig");
const zf = @import("ze_forge");
const zglfw = @import("zglfw");
const zmath = @import("zmath");

pub const HashKey = zf.HashKey;

const MeshHashMap = std.AutoHashMap(u64, usize);
const ClusteredMeshHashMap = std.AutoHashMap(u64, struct { index: u32, count: u32 });
const TextureHashMap = std.AutoHashMap(u64, zf.TextureHandle);
const MaterialHashMap = std.AutoHashMap(u64, usize);
const RenderableHashMap = std.AutoHashMap(u64, Renderable);

pub const MeshletClearCountersParams = struct {
    counters_buffer_index: u32,
    visible_counters_buffer_index: u32,
};

pub const MeshletCullInstancesParams = struct {
    counters_buffer_index: u32,
    candidate_meshlets_buffer_index: u32,
};

pub const MeshletCullArgsParams = struct {
    counters_buffer_index: u32,
    dispatch_args_buffer_index: u32,
};

pub const MeshletCullMeshletsParams = struct {
    counters_buffer_index: u32,
    candidate_meshlets_buffer_index: u32,
    visible_counters_buffer_index: u32,
    visible_meshlets_buffer_index: u32,
};

pub const MeshletDispatchArgsParams = struct {
    visible_counters_buffer_index: u32,
    dispatch_args_buffer_index: u32,
};

pub const Mesh = struct {
    data_buffer: zf.BufferHandle = zf.BufferHandle.nil,
    position_stream_location: zf.VertexBufferView = undefined,
    normal_stream_location: zf.VertexBufferView = undefined,
    texcoord_stream_location: zf.VertexBufferView = undefined,
    indices_location: zf.IndexBufferView = undefined,
    bounds: geometry.BoundingBox = undefined,

    meshlets_location: u32 = std.math.maxInt(u32),
    meshlet_vertices_location: u32 = std.math.maxInt(u32),
    meshlet_triangles_location: u32 = std.math.maxInt(u32),
    meshlet_bounds_location: u32 = std.math.maxInt(u32),
    meshlet_count: u32 = 0,
};

const GPUMesh = struct {
    data_buffer: u32,
    positions_offset: u32,
    normals_offset: u32,
    texcoords_offset: u32,
    indices_offset: u32,
    index_byte_size: u32,
    meshlet_offset: u32,
    meshlet_vertex_offset: u32,
    meshlet_triangle_offset: u32,
    meshlet_bounds_offset: u32,
    meshlet_count: u32,
};

const GPUMeshletCandidate = struct {
    instance_id: u32,
    meshlet_index: u32,
};

const GPUInstance = struct {
    world: [16]f32,
    local_bounds_origin: [3]f32,
    _pad0: u32,
    local_bounds_extents: [3]f32,
    id: u32,
    mesh_index: u32,
    material_index: u32,
    _pad1: [2]u32,
};

pub const Instance = struct {
    world_mat: [16]f32,
    renderable: HashKey,
};

pub const Renderable = struct {
    mesh_key: HashKey,
    materials: [8]HashKey,
    material_count: u32,
};

pub const CSMSettings = struct {
    pub const cascades_max_count: u32 = 4;

    cascades_count: u32 = 4,
    cascades_distances: [cascades_max_count]f32 = .{ 0.05, 0.15, 0.5, 1.0 },
    resolution: u32 = 2048,
    stabilize_cascades: bool = true,
    filter_across_cascades: bool = true,
};

pub const Gfx = struct {
    // Static samplers
    linear_repeat_static_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,
    linear_clamp_static_sampler: zf.StaticSamplerHandle = zf.StaticSamplerHandle.nil,

    // Bindless samplers
    linear_repeat_sampler: zf.SamplerHandle = zf.SamplerHandle.nil,
    linear_clamp_sampler: zf.SamplerHandle = zf.SamplerHandle.nil,
    shadow_sampler: zf.SamplerHandle = zf.SamplerHandle.nil,
    shadow_pcf_sampler: zf.SamplerHandle = zf.SamplerHandle.nil,

    // Shaders
    blit_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    object_gbuffer_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    object_shadow_caster_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    gauss_blur_horizontal_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    gauss_blur_vertical_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    clear_buffer_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    deferred_shading_shader: zf.ShaderHandle = zf.ShaderHandle.nil,

    // PSOs
    object_gbuffer_pso: zf.PsoHandle = zf.PsoHandle.nil,
    object_shadow_caster_pso: zf.PsoHandle = zf.PsoHandle.nil,
    gauss_horizontal_pso: zf.PsoHandle = zf.PsoHandle.nil,
    gauss_vertical_pso: zf.PsoHandle = zf.PsoHandle.nil,
    clear_buffer_pso: zf.PsoHandle = zf.PsoHandle.nil,
    deferred_shading_pso: zf.PsoHandle = zf.PsoHandle.nil,

    // Render Targets and Render Textures
    gbuffer0: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    gbuffer1: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    shadow_depth_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    scene_color: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
    debug_buffer: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
    gauss_blur_a: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,
    gauss_blur_b: zf.RenderTextureHandle = zf.RenderTextureHandle.nil,

    // Uniform buffers
    global_frame_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },
    shadow_caster_constant_buffers: [zf.frames_in_flight_count][CSMSettings.cascades_max_count]zf.BufferHandle = undefined,
    gauss_blur_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },
    clear_buffer_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },
    timings_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },
    sprite_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = .{ zf.BufferHandle.nil, zf.BufferHandle.nil },

    // CSM Settings
    cms_settings: CSMSettings,
    shadow_frame_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    // Renderables
    renderables: RenderableHashMap,

    // Geometry buffers
    // TODO: Figure out if we need double-buffering here to be able to stream in meshes
    vertex_buffer: zf.BufferHandle = undefined,
    index_buffer: zf.BufferHandle = undefined,
    vertex_buffer_offset: u64 = 0,
    index_buffer_offset: u64 = 0,
    geometry_buffer_mutex: std.Thread.Mutex,

    // Meshlet Renderer
    // ================
    meshlet_clear_counters_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_clear_counters_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_clear_counters_material: GfxMaterial = undefined,
    meshlet_cull_instances_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_cull_instances_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_cull_instances_material: GfxMaterial = undefined,
    meshlet_cull_args_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_cull_args_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_cull_args_material: GfxMaterial = undefined,
    meshlet_cull_meshlets_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_cull_meshlets_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_cull_meshlets_material: GfxMaterial = undefined,
    meshlet_dispatch_args_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_dispatch_args_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_dispatch_args_material: GfxMaterial = undefined,
    meshlet_rasterizer_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    meshlet_rasterizer_pso: zf.PsoHandle = zf.PsoHandle.nil,
    meshlet_rasterizer_material: GfxMaterial = undefined,
    clustered_mesh_map: ClusteredMeshHashMap,
    clustered_meshes: std.ArrayList(Mesh) = undefined,
    mesh_buffer: zf.BufferHandle = undefined,
    mesh_buffer_offset: u64 = 0,
    mesh_buffer_mutex: std.Thread.Mutex,
    clear_counters_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_cull_args_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_cull_instances_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_cull_meshlets_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_dispatch_args_constant_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_cull_args_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    meshlet_dispatch_args_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    candidate_meshlet_counters_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    candidate_meshlets_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    visible_meshlet_counters_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    visible_meshlets_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    instance_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    registered_instances_count: u32 = 0,
    visibility_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,

    // Sprite Renderer
    // ===============
    roboto: *font.FontDesc = undefined,
    overlay_buffer: zf.RenderTargetHandle = zf.RenderTargetHandle.nil,
    sprite_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    sprite_pso: zf.PsoHandle = zf.PsoHandle.nil,
    sprite_instance_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    sprite_material: GfxMaterial = undefined,
    sprite_instances: std.ArrayList(SpriteInstance) = undefined,

    // Compositor Renderer
    // ===================
    compositor_shader: zf.ShaderHandle = zf.ShaderHandle.nil,
    compositor_pso: zf.PsoHandle = zf.PsoHandle.nil,
    compositor_material: GfxMaterial = undefined,

    // // GPU-Scene buffers
    // visible_instance_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,
    // visible_instance_buffers_element_count: u32,
    // indirect_args_buffers: [zf.frames_in_flight_count]zf.BufferHandle = undefined,

    material_buffer: zf.BufferHandle = undefined,
    material_buffer_offset: u64 = 0,
    material_buffer_mutex: std.Thread.Mutex,

    // NOTE: Material is not the best name here
    // Materials
    object_material: GfxMaterial = undefined,
    gauss_blur_horizontal_material: GfxMaterial = undefined,
    gauss_blur_vertical_material: GfxMaterial = undefined,
    clear_buffer_material: GfxMaterial = undefined,
    deferred_shading_material: GfxMaterial = undefined,
    timings_material: GfxMaterial = undefined,

    // CPU Geometry data
    mesh_map: MeshHashMap,
    meshes: std.ArrayList(geometry.Mesh) = undefined,

    // Textures
    texture_map: TextureHashMap,

    // Material data
    material_data: std.ArrayList(GpuMaterialData) = undefined,
    material_map: MaterialHashMap,

    // Profiler indices
    shadows_profile_index: usize = 0,
    gbuffer_profile_index: usize = 0,
    deferred_shading_profile_index: usize = 0,
    ui_profile_index: usize = 0,
    compositor_profile_index: usize = 0,
};

pub const Frame = struct {
    view_matrix: [16]f32,
    projection_matrix: [16]f32,
    view_projection_matrix: [16]f32,
    inv_view_projection_matrix: [16]f32,
    cascade_view_projections: [CSMSettings.cascades_max_count][16]f32,
    camera_position: [4]f32,
    camera_near_plane: f32,
    camera_far_plane: f32,
    time: f32,
    _padding0: f32,
    linear_repeat_sampler_index: u32,
    linear_clamp_sampler_index: u32,
    shadow_sampler_index: u32,
    shadow_pcf_sampler_index: u32,
    vertex_buffer_index: u32,
    material_buffer_index: u32,
    instance_buffer_index: u32,
    meshes_buffer_index: u32,
    instances_count: u32,
    _padding1: [3]u32,
};

pub const ShadowFrame = struct {
    shadow_matrix: [16]f32,
    cascade_offsets: [CSMSettings.cascades_max_count][4]f32,
    cascade_scales: [CSMSettings.cascades_max_count][4]f32,
    cascade_splits: [CSMSettings.cascades_max_count]f32,
};

pub const ShadowCasterFrame = struct {
    cascade_index: u32,
    _padding: [3]u32,
};

pub const Transform = struct {
    world_matrix: [16]f32,
};

pub const MaterialDataDesc = struct {
    albedo_texture: ?zf.HashKey = null,
    normal_texture: ?zf.HashKey = null,
    base_color: [4]f32 = .{ 0.5, 0.5, 0.5, 1.0 },
};

pub const GpuMaterialData = struct {
    albedo_texture_id: u32 = std.math.maxInt(u32),
    albedo_sampler_id: u32 = std.math.maxInt(u32),
    normal_texture_id: u32 = std.math.maxInt(u32),
    normal_sampler_id: u32 = std.math.maxInt(u32),
    base_color: [4]f32 = .{ 0.5, 0.5, 0.5, 1.0 },
};

pub const InstanceData = struct {
    transform_index: u32,
    material_index: u32,
    mesh_index: u32,
    sub_mesh_index: u32 = 42,
};

pub const SpriteConstantBuffer = struct {
    viewport_size: [2]f32,
    _padding: [2]f32,
    vertex_buffer_index: u32,
    instance_buffer_index: u32,
    linear_clamp_sampler_index: u32,
    linear_repeat_sampler_index: u32,
};

pub const SpriteInstance = struct {
    transform: [16]f32,
    color: [4]f32,
    source_rect: [4]f32,
    sprite_resolution: [2]f32,
    sprite_atlas_index: u32,
    font_distance_range: f32,
};

pub const BlurData = struct {
    sigma: f32,
    support: f32,
    sRGB: f32,
    padding: f32,
};

pub const ClearBufferInput = struct {
    element_count: u32,
    buffer_index: u32,
};

// TODO: List all possible passes (eg. default, shadow_caster, gbuffer, etc.)
pub const Pass = enum {
    default,
    gbuffer,
    shadow_caster,
    _count,
};

pub const GfxMaterialPass = struct {
    pass: Pass,
    pso: zf.PsoHandle,
    shader: zf.ShaderHandle,

    per_draw_descriptor_sets: [CSMSettings.cascades_max_count]zf.DescriptorSetHandle,
    per_batch_descriptor_sets: [CSMSettings.cascades_max_count]zf.DescriptorSetHandle,
    per_frame_descriptor_sets: [CSMSettings.cascades_max_count]zf.DescriptorSetHandle,
    persistent_descriptor_sets: [CSMSettings.cascades_max_count]zf.DescriptorSetHandle,
    persistent_samplers_descriptor_sets: [CSMSettings.cascades_max_count]zf.DescriptorSetHandle,

    pub fn bindPipeline(self: *GfxMaterialPass) void {
        zf.cmdBindPipeline(self.pso);
    }

    pub fn bindDescriptorSets(self: *GfxMaterialPass, frame_index: u32, descriptor_set_index: u32) void {
        bindDescriptorSet(self.per_draw_descriptor_sets[descriptor_set_index], frame_index);
        bindDescriptorSet(self.per_batch_descriptor_sets[descriptor_set_index], frame_index);
        bindDescriptorSet(self.per_frame_descriptor_sets[descriptor_set_index], frame_index);
        bindDescriptorSet(self.persistent_descriptor_sets[descriptor_set_index], 0);
        bindDescriptorSet(self.persistent_samplers_descriptor_sets[descriptor_set_index], 0);
    }

    pub fn updateDescriptorSet(self: *GfxMaterialPass, descs: []const zf.ResourceBindingDesc, space: zf.DescriptorSpace, frame_index: u32, descriptor_set_index: u32) void {
        _ = switch (space) {
            .per_draw => zf.updateDescriptorSet(descs, space, frame_index, self.shader, self.per_draw_descriptor_sets[descriptor_set_index]),
            .per_batch => zf.updateDescriptorSet(descs, space, frame_index, self.shader, self.per_batch_descriptor_sets[descriptor_set_index]),
            .per_frame => zf.updateDescriptorSet(descs, space, frame_index, self.shader, self.per_frame_descriptor_sets[descriptor_set_index]),
            .persistent => zf.updateDescriptorSet(descs, space, frame_index, self.shader, self.persistent_descriptor_sets[descriptor_set_index]),
            .persistent_sampler => zf.updateDescriptorSet(descs, space, frame_index, self.shader, self.persistent_samplers_descriptor_sets[descriptor_set_index]),
        };
    }

    fn bindDescriptorSet(handle: zf.DescriptorSetHandle, frame_index: u32) void {
        if (handle.id != zf.DescriptorSetHandle.nil.id) {
            zf.cmdBindDescriptorSet(frame_index, handle);
        }
    }
};

const material_passes_max_count: u32 = @intFromEnum(Pass._count);

pub const GfxMaterial = struct {
    passes: [material_passes_max_count]GfxMaterialPass,

    pub fn bindMaterialPass(self: *GfxMaterial, pass: Pass, frame_index: u32, descriptor_set_index: u32) void {
        const pass_index: usize = @intFromEnum(pass);
        self.passes[pass_index].bindPipeline();
        self.passes[pass_index].bindDescriptorSets(frame_index, descriptor_set_index);
    }

    pub fn updateDescriptorSet(self: *GfxMaterial, pass: Pass, descs: []const zf.ResourceBindingDesc, space: zf.DescriptorSpace, frame_index: u32, descriptor_set_index: u32) void {
        const pass_index: usize = @intFromEnum(pass);
        self.passes[pass_index].updateDescriptorSet(descs, space, frame_index, descriptor_set_index);
    }

    pub fn getPassShaderHandle(self: *GfxMaterial, pass: Pass) zf.ShaderHandle {
        const pass_index: usize = @intFromEnum(pass);
        return self.passes[pass_index].shader;
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
    gfx.shadows_profile_index = 0;
    gfx.gbuffer_profile_index = 0;
    gfx.deferred_shading_profile_index = 0;
    gfx.ui_profile_index = 0;
    gfx.compositor_profile_index = 0;

    zf.registerUpdateDescriptorSetFn(updateDescriptorSets);

    // Static Samplers
    {
        var sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        sampler_desc.mMinFilter = .FILTER_LINEAR;
        sampler_desc.mMagFilter = .FILTER_LINEAR;
        sampler_desc.mMipMapMode = .MIPMAP_MODE_LINEAR;
        sampler_desc.mAddressU = .ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressV = .ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressW = .ADDRESS_MODE_REPEAT;
        gfx.linear_repeat_static_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = .ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = .ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = .ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_static_sampler = zf.createStaticSampler(sampler_desc) catch unreachable;
    }

    // Bindless Samplers
    {
        var sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        sampler_desc.mMinFilter = .FILTER_LINEAR;
        sampler_desc.mMagFilter = .FILTER_LINEAR;
        sampler_desc.mMipMapMode = .MIPMAP_MODE_LINEAR;
        sampler_desc.mAddressU = .ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressV = .ADDRESS_MODE_REPEAT;
        sampler_desc.mAddressW = .ADDRESS_MODE_REPEAT;
        gfx.linear_repeat_sampler = zf.createBindlessSampler(sampler_desc) catch unreachable;

        sampler_desc.mAddressW = .ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = .ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressU = .ADDRESS_MODE_CLAMP_TO_EDGE;
        gfx.linear_clamp_sampler = zf.createBindlessSampler(sampler_desc) catch unreachable;

        var shadow_sampler_desc = std.mem.zeroes(zf.SamplerDesc);
        shadow_sampler_desc.mMinFilter = .FILTER_NEAREST;
        shadow_sampler_desc.mMagFilter = .FILTER_NEAREST;
        shadow_sampler_desc.mMipMapMode = .MIPMAP_MODE_NEAREST;
        shadow_sampler_desc.mAddressW = .ADDRESS_MODE_CLAMP_TO_EDGE;
        shadow_sampler_desc.mAddressV = .ADDRESS_MODE_CLAMP_TO_EDGE;
        shadow_sampler_desc.mAddressU = .ADDRESS_MODE_CLAMP_TO_EDGE;
        shadow_sampler_desc.mCompareFunc = .CMP_LEQUAL;
        shadow_sampler_desc.mMipLodBias = 0.0;
        shadow_sampler_desc.mMaxAnisotropy = 1.0;
        shadow_sampler_desc.mMinLod = 0.0;
        shadow_sampler_desc.mMaxLod = std.math.floatMax(f32);
        gfx.shadow_sampler = zf.createBindlessSampler(shadow_sampler_desc) catch unreachable;

        shadow_sampler_desc.mMinFilter = .FILTER_LINEAR;
        shadow_sampler_desc.mMagFilter = .FILTER_LINEAR;
        shadow_sampler_desc.mMipMapMode = .MIPMAP_MODE_LINEAR;
        gfx.shadow_pcf_sampler = zf.createBindlessSampler(shadow_sampler_desc) catch unreachable;
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
            .mesh = null,
            .amplification = null,
        };
        gfx.blit_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Compositor.vert",
                .entry = "FullscreenTriangleVS",
            },
            .pixel = .{
                .path = "shaders/Compositor.frag",
                .entry = "CompositorPS",
            },
            .compute = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.compositor_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/Sprite.vert",
                .entry = "SpriteVS",
            },
            .pixel = .{
                .path = "shaders/Sprite.frag",
                .entry = "SpritePS",
            },
            .compute = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.sprite_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/ObjectGBuffer.vert",
                .entry = "GBufferVS",
            },
            .pixel = .{
                .path = "shaders/ObjectGBuffer.frag",
                .entry = "GBufferPS",
            },
            .compute = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.object_gbuffer_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .vertex = .{
                .path = "shaders/ObjectShadowCaster.vert",
                .entry = "ShadowCasterVS",
            },
            .pixel = .{
                .path = "shaders/ObjectShadowCaster.frag",
                .entry = "ShadowCasterPS",
            },
            .compute = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.object_shadow_caster_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .compute = .{
                .path = "shaders/GaussBlurH.comp",
                .entry = "main",
            },
            .vertex = null,
            .pixel = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.gauss_blur_horizontal_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .compute = .{
                .path = "shaders/GaussBlurV.comp",
                .entry = "main",
            },
            .vertex = null,
            .pixel = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.gauss_blur_vertical_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .compute = .{
                .path = "shaders/ClearBuffer.comp",
                .entry = "main",
            },
            .vertex = null,
            .pixel = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.clear_buffer_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    {
        const shader_load_desc = zf.ShaderLoadDesc{
            .compute = .{
                .path = "shaders/DeferredShading.comp",
                .entry = "main",
            },
            .vertex = null,
            .pixel = null,
            .mesh = null,
            .amplification = null,
        };
        gfx.deferred_shading_shader = zf.compileShader(shader_load_desc) catch unreachable;
    }

    // PSOs
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
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.deferred_shading_pso = zf.createPso(pipeline_desc, gfx.deferred_shading_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{zf.getSwapChainFormat()};
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

        gfx.compositor_pso = zf.createPso(pipeline_desc, gfx.compositor_shader) catch unreachable;
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
        rasterizer_state_desc.mFrontFace = zf.FrontFace.FRONT_FACE_CW;
        rasterizer_state_desc.mDepthClampEnable = true;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
        depth_state_desc.mDepthWrite = false;
        depth_state_desc.mDepthTest = false;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_ALWAYS;
        graphics_desc.pDepthState = @ptrCast(&depth_state_desc);

        gfx.sprite_pso = zf.createPso(pipeline_desc, gfx.sprite_shader) catch unreachable;
    }

    {
        var render_targets = [_]zf.IGraphics.TinyImageFormat{
            .R8G8B8A8_SRGB, // TODO: Read from gbuffer0 format
            .R8G8B8A8_UNORM, // TODO: Read from gbuffer1 format
        };
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
        // depth_state_desc.mDepthFunc = zf.CompareMode.CMP_GEQUAL;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_LEQUAL;
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

        gfx.object_gbuffer_pso = zf.createPso(pipeline_desc, gfx.object_gbuffer_shader) catch unreachable;
    }

    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_GRAPHICS;
        var graphics_desc = &pipeline_desc.__union_field1.mGraphicsDesc;
        graphics_desc.* = std.mem.zeroes(zf.GraphicsPipelineDesc);
        graphics_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
        graphics_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        graphics_desc.mSampleQuality = 0;

        var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
        rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_NONE;
        rasterizer_state_desc.mFillMode = zf.FillMode.FILL_MODE_SOLID;
        rasterizer_state_desc.mDepthClampEnable = true;
        graphics_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

        var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
        depth_state_desc.mDepthWrite = true;
        depth_state_desc.mDepthTest = true;
        depth_state_desc.mDepthFunc = zf.CompareMode.CMP_LEQUAL;
        graphics_desc.pDepthState = @ptrCast(&depth_state_desc);
        graphics_desc.mDepthStencilFormat = .D32_SFLOAT;

        gfx.object_shadow_caster_pso = zf.createPso(pipeline_desc, gfx.object_shadow_caster_shader) catch unreachable;
    }

    {
        var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
        pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
        gfx.clear_buffer_pso = zf.createPso(pipeline_desc, gfx.clear_buffer_shader) catch unreachable;
    }

    // Render Targets
    {
        var overlay_buffer_desc = std.mem.zeroes(zf.RenderTargetDesc);
        overlay_buffer_desc.pName = "Overlay Buffer";
        overlay_buffer_desc.mArraySize = 1;
        overlay_buffer_desc.mDepth = 1;
        overlay_buffer_desc.mFormat = .R8G8B8A8_SRGB;
        overlay_buffer_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        overlay_buffer_desc.mWidth = @intCast(window_width);
        overlay_buffer_desc.mHeight = @intCast(window_height);
        overlay_buffer_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        overlay_buffer_desc.mSampleQuality = 0;
        overlay_buffer_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.overlay_buffer = zf.createRenderTarget(overlay_buffer_desc) catch unreachable;

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

        var gbuffer1_desc = std.mem.zeroes(zf.RenderTargetDesc);
        gbuffer1_desc.pName = "GBuffer 1";
        gbuffer1_desc.mArraySize = 1;
        gbuffer1_desc.mDepth = 1;
        gbuffer1_desc.mFormat = .R8G8B8A8_UNORM; // TODO: Use a better format for normals
        gbuffer1_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        gbuffer1_desc.mWidth = @intCast(window_width);
        gbuffer1_desc.mHeight = @intCast(window_height);
        gbuffer1_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        gbuffer1_desc.mSampleQuality = 0;
        gbuffer1_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        gfx.gbuffer1 = zf.createRenderTarget(gbuffer1_desc) catch unreachable;
    }

    {
        var depth_buffer_desc = std.mem.zeroes(zf.RenderTargetDesc);
        depth_buffer_desc.pName = "Depth Buffer";
        depth_buffer_desc.mArraySize = 1;
        depth_buffer_desc.mClearValue.__struct_field3.depth = 1.0;
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

    // NOTE: These settings should come from the app side I think
    gfx.cms_settings.cascades_count = 4;
    gfx.cms_settings.resolution = 2048;
    gfx.cms_settings.cascades_distances[0] = 0.05;
    gfx.cms_settings.cascades_distances[1] = 0.15;
    gfx.cms_settings.cascades_distances[2] = 0.5;
    gfx.cms_settings.cascades_distances[3] = 1.0;
    gfx.cms_settings.filter_across_cascades = true;
    gfx.cms_settings.stabilize_cascades = true;

    {
        var shadow_buffer_desc = std.mem.zeroes(zf.RenderTargetDesc);
        shadow_buffer_desc.pName = "Shadow Depth Buffer";
        shadow_buffer_desc.mArraySize = gfx.cms_settings.cascades_count;
        shadow_buffer_desc.mMipLevels = 1;
        shadow_buffer_desc.mClearValue.__struct_field3.depth = 1.0;
        shadow_buffer_desc.mClearValue.__struct_field3.stencil = 0;
        shadow_buffer_desc.mDepth = 1;
        shadow_buffer_desc.mFormat = .D32_SFLOAT;
        shadow_buffer_desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        shadow_buffer_desc.mWidth = gfx.cms_settings.resolution;
        shadow_buffer_desc.mHeight = gfx.cms_settings.resolution;
        shadow_buffer_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
        shadow_buffer_desc.mSampleQuality = 0;
        shadow_buffer_desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
        shadow_buffer_desc.mDescriptors = .DESCRIPTOR_TYPE_RENDER_TARGET_DEPTH_SLICES;
        gfx.shadow_depth_buffer = zf.createRenderTarget(shadow_buffer_desc) catch unreachable;
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

        rt_desc.pName = "Debug Buffer";
        gfx.debug_buffer = zf.createRenderTexture(rt_desc) catch unreachable;

        rt_desc.pName = "Gaussian Blur A";
        gfx.gauss_blur_a = zf.createRenderTexture(rt_desc) catch unreachable;

        rt_desc.pName = "Gaussian Blur B";
        gfx.gauss_blur_b = zf.createRenderTexture(rt_desc) catch unreachable;
    }

    // Uniform Buffers
    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.global_frame_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(Frame), "Global Frame Constant Buffer");
            gfx.shadow_frame_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(ShadowFrame), "Shadow Frame Constant Buffer");
            gfx.gauss_blur_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(BlurData), "Gaussian Blur Constant Buffer");
            gfx.clear_buffer_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(ClearBufferInput), "Clear Buffer Constant Buffer");
            gfx.sprite_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(SpriteConstantBuffer), "Sprite Constant Buffer");

            for (0..CSMSettings.cascades_max_count) |cascade_index| {
                gfx.shadow_caster_constant_buffers[frame_index][cascade_index] = zf.createUniformBuffer(@sizeOf(ShadowCasterFrame), "Shadow Caster Constant Buffer");
            }
        }
    }

    // Geometry Buffers
    {
        gfx.vertex_buffer = zf.createRawBuffer(8 * 1024 * 1024, geometry.Vertex, true, false, "Vertex Buffer");
        gfx.vertex_buffer_offset = 0;
        gfx.index_buffer = zf.createIndexBuffer(8 * 1024 * 1024, zf.IndexType.INDEX_TYPE_UINT32, "Index Buffer");
        gfx.index_buffer_offset = 0;
        gfx.geometry_buffer_mutex = std.Thread.Mutex{};
    }

    // Sprite Instances buffers
    for (0..zf.frames_in_flight_count) |frame_index| {
        gfx.sprite_instance_buffers[frame_index] = zf.createRawBuffer(8 * 1024 * 1024, SpriteInstance, true, false, "Sprite Instance Buffer");
    }

    // Materials buffers
    // =================
    gfx.material_buffer = zf.createRawBuffer(8 * 1024, GpuMaterialData, true, false, "Material Buffer");
    gfx.material_buffer_offset = 0;
    gfx.material_buffer_mutex = std.Thread.Mutex{};

    // Meshlet Renderer Initialization
    // ===============================
    {
        // Shaders
        // =======
        {
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .compute = .{
                        .path = "shaders/MeshletClearCounters.comp",
                        .entry = "ClearCountersCS",
                    },
                    .vertex = null,
                    .pixel = null,
                    .mesh = null,
                    .amplification = null,
                };
                gfx.meshlet_clear_counters_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .compute = .{
                        .path = "shaders/MeshletCullInstances.comp",
                        .entry = "CullInstancesCS",
                    },
                    .vertex = null,
                    .pixel = null,
                    .mesh = null,
                    .amplification = null,
                };
                gfx.meshlet_cull_instances_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .compute = .{
                        .path = "shaders/MeshletBuildCullIndirectArgs.comp",
                        .entry = "BuildMeshletCullIndirectArgsCS",
                    },
                    .vertex = null,
                    .pixel = null,
                    .mesh = null,
                    .amplification = null,
                };
                gfx.meshlet_cull_args_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .compute = .{
                        .path = "shaders/MeshletCullMeshlets.comp",
                        .entry = "CullMeshletsCS",
                    },
                    .vertex = null,
                    .pixel = null,
                    .mesh = null,
                    .amplification = null,
                };
                gfx.meshlet_cull_meshlets_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .compute = .{
                        .path = "shaders/MeshletBuildDispatchIndirectArgs.comp",
                        .entry = "BuildMeshletDispatchIndirectArgsCS",
                    },
                    .vertex = null,
                    .pixel = null,
                    .mesh = null,
                    .amplification = null,
                };
                gfx.meshlet_dispatch_args_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
            {
                const shader_load_desc = zf.ShaderLoadDesc{
                    .mesh = .{
                        .path = "shaders/MeshletRasterizer.comp",
                        .entry = "main",
                    },
                    .pixel = .{
                        .path = "shaders/MeshletRasterizer.frag",
                        .entry = "pixel",
                    },
                    .vertex = null,
                    .compute = null,
                    .amplification = null,
                };
                gfx.meshlet_rasterizer_shader = zf.compileShader(shader_load_desc) catch unreachable;
            }
        }
        // PSOs
        // ====
        {
            {
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
                gfx.meshlet_clear_counters_pso = zf.createPso(pipeline_desc, gfx.meshlet_clear_counters_shader) catch unreachable;
            }
            {
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
                gfx.meshlet_cull_instances_pso = zf.createPso(pipeline_desc, gfx.meshlet_cull_instances_shader) catch unreachable;
            }
            {
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
                gfx.meshlet_cull_args_pso = zf.createPso(pipeline_desc, gfx.meshlet_cull_args_shader) catch unreachable;
            }
            {
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
                gfx.meshlet_cull_meshlets_pso = zf.createPso(pipeline_desc, gfx.meshlet_cull_meshlets_shader) catch unreachable;
            }
            {
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_COMPUTE;
                gfx.meshlet_dispatch_args_pso = zf.createPso(pipeline_desc, gfx.meshlet_dispatch_args_shader) catch unreachable;
            }

            {
                var render_targets = [_]zf.IGraphics.TinyImageFormat{
                    .R32_UINT, // TODO: Read from visibility buffer format
                };
                var pipeline_desc = std.mem.zeroes(zf.PipelineDesc);
                pipeline_desc.mType = zf.PipelineType.PIPELINE_TYPE_MESH;
                var mesh_desc = &pipeline_desc.__union_field1.mMeshDesc;
                mesh_desc.* = std.mem.zeroes(zf.MeshPipelineDesc);
                mesh_desc.mPrimitiveTopo = zf.PrimitiveTopology.PRIMITIVE_TOPO_TRI_LIST;
                mesh_desc.mRenderTargetCount = render_targets.len;
                mesh_desc.pColorFormats = @ptrCast(&render_targets);
                mesh_desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
                mesh_desc.mSampleQuality = 0;

                var rasterizer_state_desc = std.mem.zeroes(zf.RasterizerStateDesc);
                rasterizer_state_desc.mCullMode = zf.CullMode.CULL_MODE_NONE;
                rasterizer_state_desc.mFillMode = zf.FillMode.FILL_MODE_SOLID;
                mesh_desc.pRasterizerState = @ptrCast(&rasterizer_state_desc);

                var depth_state_desc = std.mem.zeroes(zf.DepthStateDesc);
                depth_state_desc.mDepthWrite = true;
                depth_state_desc.mDepthTest = true;
                depth_state_desc.mDepthFunc = zf.CompareMode.CMP_LEQUAL;
                mesh_desc.pDepthState = @ptrCast(&depth_state_desc);
                mesh_desc.mDepthStencilFormat = .D32_SFLOAT;

                gfx.meshlet_rasterizer_pso = zf.createPso(pipeline_desc, gfx.meshlet_rasterizer_shader) catch unreachable;
            }
        }
        // Materials
        // =========
        {
            {
                gfx.meshlet_clear_counters_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_clear_counters_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_clear_counters_pso;
                pass.shader = gfx.meshlet_clear_counters_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_clear_counters_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
            {
                gfx.meshlet_cull_instances_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_cull_instances_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_cull_instances_pso;
                pass.shader = gfx.meshlet_cull_instances_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_cull_instances_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
            {
                gfx.meshlet_cull_args_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_cull_args_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_cull_args_pso;
                pass.shader = gfx.meshlet_cull_args_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_cull_args_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
            {
                gfx.meshlet_cull_meshlets_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_cull_meshlets_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_cull_meshlets_pso;
                pass.shader = gfx.meshlet_cull_meshlets_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_cull_meshlets_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
            {
                gfx.meshlet_dispatch_args_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_dispatch_args_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_dispatch_args_pso;
                pass.shader = gfx.meshlet_dispatch_args_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_dispatch_args_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
            {
                gfx.meshlet_rasterizer_material = std.mem.zeroes(GfxMaterial);
                const pass_type = Pass.default;

                const pass_index: usize = @intFromEnum(pass_type);
                var pass = &gfx.meshlet_rasterizer_material.passes[pass_index];

                pass.pass = pass_type;
                pass.pso = gfx.meshlet_rasterizer_pso;
                pass.shader = gfx.meshlet_rasterizer_shader;

                const descriptor_set_handles = zf.createDescriptorSets(gfx.meshlet_rasterizer_shader) catch unreachable;
                pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
            }
        }
        // Buffers
        // =======
        for (0..zf.frames_in_flight_count) |frame_index| {
            gfx.instance_buffers[frame_index] = zf.createRawBuffer(8 * 1024 * 1024, GPUInstance, true, false, "Instance Buffer");
            gfx.candidate_meshlet_counters_buffers[frame_index] = zf.createRawBuffer(16, u32, true, true, "Candidate Meshlet Counters");
            gfx.candidate_meshlets_buffers[frame_index] = zf.createRawBuffer(@intCast(1 << 20), GPUMeshletCandidate, true, true, "Candidate Meshlets");
            gfx.visible_meshlet_counters_buffers[frame_index] = zf.createRawBuffer(16, u32, true, true, "Visible Meshlet Counters");
            gfx.visible_meshlets_buffers[frame_index] = zf.createRawBuffer(@intCast(1 << 20), GPUMeshletCandidate, true, true, "Visible Meshlets");
            gfx.meshlet_cull_args_buffers[frame_index] = zf.createRawBuffer(16, u32, true, true, "Meshlets Cull Args");
            gfx.meshlet_dispatch_args_buffers[frame_index] = zf.createRawBuffer(16, u32, true, true, "Meshlets Dispatch Args");
            gfx.clear_counters_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(MeshletClearCountersParams), "Clear Counters");
            gfx.meshlet_cull_instances_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(MeshletCullInstancesParams), "Meshlet Cull Instances Params");
            gfx.meshlet_cull_args_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(MeshletCullArgsParams), "Meshlet Cull Args Params");
            gfx.meshlet_cull_meshlets_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(MeshletCullMeshletsParams), "Meshlet Cull Meshlets Params");
            gfx.meshlet_dispatch_args_constant_buffers[frame_index] = zf.createUniformBuffer(@sizeOf(MeshletDispatchArgsParams), "Meshlet Dispatch Args Params");
        }
        // Render Targets
        // ==============
        {
            var desc = std.mem.zeroes(zf.RenderTargetDesc);
            desc.pName = "Visibility Buffer";
            desc.mArraySize = 1;
            desc.mDepth = 1;
            desc.mFormat = .R32_UINT;
            desc.mStartState = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            desc.mWidth = @intCast(window_width);
            desc.mHeight = @intCast(window_height);
            desc.mSampleCount = zf.SampleCount.SAMPLE_COUNT_1;
            desc.mSampleQuality = 0;
            desc.mFlags = zf.TextureCreationFlags.TEXTURE_CREATION_FLAG_ON_TILE;
            gfx.visibility_buffer = zf.createRenderTarget(desc) catch unreachable;
        }
        // CPU Data
        // ========
        gfx.mesh_map = MeshHashMap.init(gfx_allocator);
        gfx.meshes = std.ArrayList(geometry.Mesh).init(gfx_allocator);
        gfx.clustered_mesh_map = ClusteredMeshHashMap.init(gfx_allocator);
        gfx.clustered_meshes = std.ArrayList(Mesh).init(gfx_allocator);
        gfx.texture_map = TextureHashMap.init(gfx_allocator);
        gfx.material_data = std.ArrayList(GpuMaterialData).init(gfx_allocator);
        gfx.material_map = MaterialHashMap.init(gfx_allocator);
        gfx.renderables = RenderableHashMap.init(gfx_allocator);
        gfx.mesh_buffer = zf.createRawBuffer(1024, GPUMesh, true, false, "Meshes");
        gfx.mesh_buffer_offset = 0;
        gfx.mesh_buffer_mutex = std.Thread.Mutex{};
    }

    // Sprite material
    {
        gfx.sprite_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.sprite_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.sprite_pso;
        pass.shader = gfx.sprite_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.sprite_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Deferred Shading material
    {
        gfx.deferred_shading_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.deferred_shading_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.deferred_shading_pso;
        pass.shader = gfx.deferred_shading_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.deferred_shading_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Clear Buffer material
    {
        gfx.clear_buffer_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.clear_buffer_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.clear_buffer_pso;
        pass.shader = gfx.clear_buffer_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.clear_buffer_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Gauss Blur Horizontal material
    {
        gfx.gauss_blur_horizontal_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.gauss_blur_horizontal_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.gauss_horizontal_pso;
        pass.shader = gfx.gauss_blur_horizontal_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.gauss_blur_horizontal_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Gauss Blur Vertical material
    {
        gfx.gauss_blur_vertical_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.gauss_blur_vertical_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.gauss_vertical_pso;
        pass.shader = gfx.gauss_blur_vertical_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.gauss_blur_vertical_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Compositor material
    {
        gfx.compositor_material = std.mem.zeroes(GfxMaterial);
        const pass_type = Pass.default;

        const pass_index: usize = @intFromEnum(pass_type);
        var pass = &gfx.compositor_material.passes[pass_index];

        pass.pass = pass_type;
        pass.pso = gfx.compositor_pso;
        pass.shader = gfx.compositor_shader;

        const descriptor_set_handles = zf.createDescriptorSets(gfx.compositor_shader) catch unreachable;
        pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
        pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
        pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
        pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
        pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
    }

    // Object material
    {
        gfx.object_material = std.mem.zeroes(GfxMaterial);

        // GBuffer Pass
        {
            const pass_type = Pass.gbuffer;

            const pass_index: usize = @intFromEnum(pass_type);
            var pass = &gfx.object_material.passes[pass_index];

            pass.pass = pass_type;
            pass.pso = gfx.object_gbuffer_pso;
            pass.shader = gfx.object_gbuffer_shader;

            const descriptor_set_handles = zf.createDescriptorSets(gfx.object_gbuffer_shader) catch unreachable;
            pass.per_draw_descriptor_sets[0] = descriptor_set_handles.per_draw;
            pass.per_batch_descriptor_sets[0] = descriptor_set_handles.per_batch;
            pass.per_frame_descriptor_sets[0] = descriptor_set_handles.per_frame;
            pass.persistent_descriptor_sets[0] = descriptor_set_handles.persistent;
            pass.persistent_samplers_descriptor_sets[0] = descriptor_set_handles.persistent_samplers;
        }

        // Shadow Caster Pass
        {
            const pass_type = Pass.shadow_caster;

            const pass_index: usize = @intFromEnum(pass_type);
            var pass = &gfx.object_material.passes[pass_index];

            pass.pass = pass_type;
            pass.pso = gfx.object_shadow_caster_pso;
            pass.shader = gfx.object_shadow_caster_shader;

            for (0..CSMSettings.cascades_max_count) |cascade_index| {
                const descriptor_set_handles = zf.createDescriptorSets(gfx.object_shadow_caster_shader) catch unreachable;
                pass.per_draw_descriptor_sets[cascade_index] = descriptor_set_handles.per_draw;
                pass.per_batch_descriptor_sets[cascade_index] = descriptor_set_handles.per_batch;
                pass.per_frame_descriptor_sets[cascade_index] = descriptor_set_handles.per_frame;
                pass.persistent_descriptor_sets[cascade_index] = descriptor_set_handles.persistent;
                pass.persistent_samplers_descriptor_sets[cascade_index] = descriptor_set_handles.persistent_samplers;
            }
        }
    }

    updateDescriptorSets();

    // Load quad
    loadGltfMesh(HashKey.generate("quad"), "content/models", "Quad.gltf");

    // Testing custom mesh loading
    {
        var mesh_data = std.ArrayList(geometry.MeshData).init(gfx_allocator);

        var load_desc: geometry.MeshLoadDesc = undefined;
        load_desc.base_path = "content/models";
        load_desc.file_name = "Birch_1.mesh";
        load_desc.allocator = gfx_allocator;
        load_desc.mesh_data = &mesh_data;
        geometry.loadMesh(&load_desc);
    }

    // Load fonts
    {
        const handle = loadDdsTexture("content/fonts/T_RobotoMono_Regular.dds", true, gfx_allocator) catch unreachable;
        gfx.roboto = font.FontDesc.create("content/fonts/RobotoMono_Regular.json", handle, gfx_allocator) catch unreachable;
    }

    gfx.sprite_instances = std.ArrayList(SpriteInstance).init(gfx_allocator);
}

pub fn shutdown() void {
    zf.shutdownGpu();
    gfx.renderables.deinit();
    gfx.texture_map.deinit();
    gfx.mesh_map.deinit();
    gfx.meshes.deinit();
    gfx.clustered_mesh_map.deinit();
    gfx.clustered_meshes.deinit();
    gfx.roboto.destroy();
    gfx.sprite_instances.deinit();
    gfx_allocator.destroy(gfx.roboto);
    gfx_allocator.destroy(gfx);
}

pub fn resize() void {
    zf.requestResize();
}

pub fn draw(camera: *Camera, window_width: u32, window_height: u32, delta_time: f32) void {
    _ = delta_time;
    const frame_index = zf.frameStart();

    spriteRenderer_Begin(frame_index);

    var frame = Frame{
        .view_matrix = undefined,
        .projection_matrix = undefined,
        .view_projection_matrix = undefined,
        .inv_view_projection_matrix = undefined,
        .cascade_view_projections = undefined,
        .camera_position = undefined,
        .camera_near_plane = camera.near_plane,
        .camera_far_plane = camera.far_plane,
        .time = @floatCast(zglfw.getTime()),
        ._padding0 = 42,
        .linear_repeat_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_repeat_sampler),
        .linear_clamp_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_clamp_sampler),
        .shadow_sampler_index = zf.getSamplerBindlessIndex(gfx.shadow_sampler),
        .shadow_pcf_sampler_index = zf.getSamplerBindlessIndex(gfx.shadow_pcf_sampler),
        .vertex_buffer_index = zf.getBufferBindlessIndex(gfx.vertex_buffer),
        .material_buffer_index = zf.getBufferBindlessIndex(gfx.material_buffer),
        .instance_buffer_index = zf.getBufferBindlessIndex(gfx.instance_buffers[frame_index]),
        .meshes_buffer_index = zf.getBufferBindlessIndex(gfx.mesh_buffer),
        .instances_count = gfx.registered_instances_count,
        ._padding1 = [3]u32 { 42, 42, 42 }
    };
    zmath.storeMat(&frame.view_matrix, zmath.transpose(camera.view));
    zmath.storeMat(&frame.projection_matrix, zmath.transpose(camera.proj));
    zmath.storeMat(&frame.view_projection_matrix, zmath.transpose(camera.view_proj));
    zmath.storeMat(&frame.inv_view_projection_matrix, zmath.transpose(zmath.inverse(camera.view_proj)));
    zmath.storeArr4(&frame.camera_position, camera.position);

    var shadow_frame = ShadowFrame{
        .shadow_matrix = undefined,
        .cascade_offsets = undefined,
        .cascade_scales = undefined,
        .cascade_splits = undefined,
    };

    prepareCascadeShadowData(camera, &frame, &shadow_frame);

    const frame_data = zf.DataSlice{
        .data = @ptrCast(&frame),
        .size = @sizeOf(Frame),
    };
    zf.updateUniformBuffer(frame_data, gfx.global_frame_constant_buffers[frame_index]);

    const shadow_frame_data = zf.DataSlice{
        .data = @ptrCast(&shadow_frame),
        .size = @sizeOf(ShadowFrame),
    };
    zf.updateUniformBuffer(shadow_frame_data, gfx.shadow_frame_constant_buffers[frame_index]);

    for (0..CSMSettings.cascades_max_count) |cascade_index| {
        var shadow_caster_frame = ShadowCasterFrame{
            .cascade_index = @intCast(cascade_index),
            ._padding = .{ 42, 42, 42 },
        };
        const shadow_caster_data = zf.DataSlice{
            .data = @ptrCast(&shadow_caster_frame),
            .size = @sizeOf(ShadowCasterFrame),
        };
        zf.updateUniformBuffer(shadow_caster_data, gfx.shadow_caster_constant_buffers[frame_index][cascade_index]);
    }

    // Meshlet Pass
    // ============
    {
        const profile_index = zf.startGpuProfile("Meshlet Rendering");
        defer zf.endGpuProfile(profile_index);

        // Clear counters
        {
            const inner_profile_index = zf.startGpuProfile("Clear Counters");
            defer zf.endGpuProfile(inner_profile_index);

            var clear_params = MeshletClearCountersParams{
                .counters_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlet_counters_buffers[frame_index]),
                .visible_counters_buffer_index = zf.getBufferBindlessIndex(gfx.visible_meshlet_counters_buffers[frame_index]),
            };
            const data_slice = zf.DataSlice{
                .data = @ptrCast(&clear_params),
                .size = @sizeOf(MeshletClearCountersParams),
            };
            zf.updateUniformBuffer(data_slice, gfx.clear_counters_constant_buffers[frame_index]);

            var buffer_barriers = [_]zf.BufferBarrier{
                .{
                    .buffer_handle = gfx.candidate_meshlet_counters_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.visible_meshlet_counters_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
            gfx.meshlet_clear_counters_material.bindMaterialPass(.default, frame_index, 0);
            zf.cmdDispatch(1, 1, 1);

            buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
        }

        // Cull instances
        {
            const inner_profile_index = zf.startGpuProfile("Cull Instances");
            defer zf.endGpuProfile(inner_profile_index);

            var cull_instances_params = MeshletCullInstancesParams{
                .counters_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlet_counters_buffers[frame_index]),
                .candidate_meshlets_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlets_buffers[frame_index]),
            };
            const data_slice = zf.DataSlice{
                .data = @ptrCast(&cull_instances_params),
                .size = @sizeOf(MeshletCullInstancesParams),
            };
            zf.updateUniformBuffer(data_slice, gfx.meshlet_cull_instances_constant_buffers[frame_index]);

            var buffer_barriers = [_]zf.BufferBarrier{
                .{
                    .buffer_handle = gfx.candidate_meshlet_counters_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.candidate_meshlets_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
            gfx.meshlet_cull_instances_material.bindMaterialPass(.default, frame_index, 0);

            const thread_group_size = zf.getShaderThreadGroupSize(gfx.meshlet_cull_instances_material.getPassShaderHandle(.default));
            zf.cmdDispatch((gfx.registered_instances_count + thread_group_size.x - 1) / thread_group_size.x, 1, 1);

            buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
        }

        // Build meshlet cull indirect args
        {
            const inner_profile_index = zf.startGpuProfile("Build Meshlet Cull Indirect Args");
            defer zf.endGpuProfile(inner_profile_index);

            var cull_args_params = MeshletCullArgsParams{
                .counters_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlet_counters_buffers[frame_index]),
                .dispatch_args_buffer_index = zf.getBufferBindlessIndex(gfx.meshlet_cull_args_buffers[frame_index]),
            };
            const data_slice = zf.DataSlice{
                .data = @ptrCast(&cull_args_params),
                .size = @sizeOf(MeshletCullArgsParams),
            };
            zf.updateUniformBuffer(data_slice, gfx.meshlet_cull_args_constant_buffers[frame_index]);

            var buffer_barriers = [_]zf.BufferBarrier{
                .{
                    .buffer_handle = gfx.meshlet_cull_args_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
            gfx.meshlet_cull_args_material.bindMaterialPass(.default, frame_index, 0);
            zf.cmdDispatch(1, 1, 1);

            buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
        }

        // Cull meshlets
        {
            const inner_profile_index = zf.startGpuProfile("Cull Meshlets");
            defer zf.endGpuProfile(inner_profile_index);

            var cull_meshlets_params = MeshletCullMeshletsParams{
                .counters_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlet_counters_buffers[frame_index]),
                .candidate_meshlets_buffer_index = zf.getBufferBindlessIndex(gfx.candidate_meshlets_buffers[frame_index]),
                .visible_counters_buffer_index = zf.getBufferBindlessIndex(gfx.visible_meshlet_counters_buffers[frame_index]),
                .visible_meshlets_buffer_index = zf.getBufferBindlessIndex(gfx.visible_meshlets_buffers[frame_index]),
            };
            const data_slice = zf.DataSlice{
                .data = @ptrCast(&cull_meshlets_params),
                .size = @sizeOf(MeshletCullMeshletsParams),
            };
            zf.updateUniformBuffer(data_slice, gfx.meshlet_cull_meshlets_constant_buffers[frame_index]);

            var buffer_barriers = [_]zf.BufferBarrier{
                .{
                    .buffer_handle = gfx.candidate_meshlet_counters_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.candidate_meshlets_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.visible_meshlet_counters_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.visible_meshlets_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
                .{
                    .buffer_handle = gfx.meshlet_cull_args_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_INDIRECT_ARGUMENT,
                },
            };

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
            gfx.meshlet_cull_meshlets_material.bindMaterialPass(.default, frame_index, 0);

            zf.cmdExecuteIndirect(.INDIRECT_DISPATCH, 1, gfx.meshlet_cull_args_buffers[frame_index], 0, zf.BufferHandle.nil, 0);

            buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[2].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[2].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[3].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[3].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
            buffer_barriers[4].current_state = zf.ResourceState.RESOURCE_STATE_INDIRECT_ARGUMENT;
            buffer_barriers[4].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
        }

        // Build meshlet dispatch indirect args
        {
            const inner_profile_index = zf.startGpuProfile("Build Meshlet Dispatch Indirect Args");
            defer zf.endGpuProfile(inner_profile_index);

            var cull_args_params = MeshletDispatchArgsParams{
                .visible_counters_buffer_index = zf.getBufferBindlessIndex(gfx.visible_meshlet_counters_buffers[frame_index]),
                .dispatch_args_buffer_index = zf.getBufferBindlessIndex(gfx.meshlet_dispatch_args_buffers[frame_index]),
            };
            const data_slice = zf.DataSlice{
                .data = @ptrCast(&cull_args_params),
                .size = @sizeOf(MeshletDispatchArgsParams),
            };
            zf.updateUniformBuffer(data_slice, gfx.meshlet_dispatch_args_constant_buffers[frame_index]);

            var buffer_barriers = [_]zf.BufferBarrier{
                .{
                    .buffer_handle = gfx.meshlet_dispatch_args_buffers[frame_index],
                    .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                    .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
                },
            };

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
            gfx.meshlet_dispatch_args_material.bindMaterialPass(.default, frame_index, 0);
            zf.cmdDispatch(1, 1, 1);

            buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(&buffer_barriers, null, null);
        }
    }

    // // Clear Buffer: Visible Instances
    // {
    //     const profile_index = zf.startGpuProfile("Clear Visible Instances");
    //     defer zf.endGpuProfile(profile_index);

    //     var clear_buffer_input = ClearBufferInput{
    //         .buffer_index = zf.getBufferBindlessIndex(gfx.visible_instance_buffers[frame_index]),
    //         .element_count = gfx.visible_instance_buffers_element_count,
    //     };
    //     const clear_buffer_data = zf.DataSlice{
    //         .data = @ptrCast(&clear_buffer_input),
    //         .size = @sizeOf(ClearBufferInput),
    //     };
    //     zf.updateUniformBuffer(clear_buffer_data, gfx.clear_buffer_constant_buffers[frame_index]);

    //     var buffer_barriers = [_]zf.BufferBarrier{
    //         .{
    //             .buffer_handle = gfx.visible_instance_buffers[frame_index],
    //             .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
    //             .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
    //         },
    //     };

    //     zf.cmdResourceBarrier(&buffer_barriers, null, null);
    //     gfx.clear_buffer_material.bindMaterialPass(.default, frame_index, 0);

    //     const thread_group_size = zf.getShaderThreadGroupSize(gfx.clear_buffer_material.getPassShaderHandle(.default));
    //     zf.cmdDispatch((gfx.visible_instance_buffers_element_count + thread_group_size.x - 1) / thread_group_size.x, thread_group_size.y, thread_group_size.z);

    //     buffer_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
    //     buffer_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

    //     zf.cmdResourceBarrier(&buffer_barriers, null, null);
    // }

    // Shadow Caster Pass
    {
        gfx.shadows_profile_index = zf.startGpuProfile("Main Light Shadows");
        defer zf.endGpuProfile(gfx.shadows_profile_index);

        var rt_barriers = [_]zf.RenderTargetBarrier{
            .{
                .render_target_handle = gfx.shadow_depth_buffer,
                .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                .new_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE,
            },
        };

        zf.cmdResourceBarrier(null, null, &rt_barriers);

        // for (0..gfx.cms_settings.cascades_count) |cascade_index| {
        //     const profile_index_2 = switch (cascade_index) {
        //         0 => zf.startGpuProfile("Shadow Cascade 1"),
        //         1 => zf.startGpuProfile("Shadow Cascade 2"),
        //         2 => zf.startGpuProfile("Shadow Cascade 3"),
        //         3 => zf.startGpuProfile("Shadow Cascade 4"),
        //         else => @panic("Can only have a maximum of 4 cascades"),
        //     };
        //     defer zf.endGpuProfile(profile_index_2);

        //     var bind_render_targets = [_]zf.BindRenderTarget{
        //         .{
        //             .render_target_handle = gfx.shadow_depth_buffer,
        //             .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
        //             .use_array_slice = true,
        //             .array_slice = @intCast(cascade_index),
        //         },
        //     };
        //     zf.cmdBindRenderTargets(&bind_render_targets);
        //     zf.cmdSetDefaultViewportAndScissor(gfx.cms_settings.resolution, gfx.cms_settings.resolution);

        //     gfx.object_material.bindMaterialPass(.shadow_caster, frame_index, @intCast(cascade_index));
        //     zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);

        //     zf.cmdExecuteIndirect(.INDIRECT_DRAW_INDEX, 6, gfx.indirect_args_buffers[frame_index], 0, zf.BufferHandle.nil, 0);
        // }

        rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE;
        rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        zf.cmdResourceBarrier(null, null, &rt_barriers);
    }

    // GBuffer Pass
    {
        gfx.gbuffer_profile_index = zf.startGpuProfile("GBuffer Pass");
        defer zf.endGpuProfile(gfx.gbuffer_profile_index);

        var rt_barriers = [_]zf.RenderTargetBarrier{
            .{
                .render_target_handle = gfx.gbuffer0,
                .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                .new_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET,
            },
            .{
                .render_target_handle = gfx.gbuffer1,
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
                .render_target_handle = gfx.gbuffer1,
                .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
            },
            .{
                .render_target_handle = gfx.depth_buffer,
                .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
            },
        };
        zf.cmdBindRenderTargets(&bind_render_targets);
        zf.cmdSetDefaultViewportAndScissor(window_width, window_height);

        // gfx.object_material.bindMaterialPass(.gbuffer, frame_index, 0);
        // zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);

        // zf.cmdExecuteIndirect(.INDIRECT_DRAW_INDEX, 6, gfx.indirect_args_buffers[frame_index], 0, zf.BufferHandle.nil, 0);

        rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
        rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        rt_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
        rt_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        rt_barriers[2].current_state = zf.ResourceState.RESOURCE_STATE_DEPTH_WRITE;
        rt_barriers[2].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        zf.cmdResourceBarrier(null, null, &rt_barriers);
    }

    // Deferred Shading Pass
    {
        gfx.deferred_shading_profile_index = zf.startGpuProfile("Deferred Shading");
        defer zf.endGpuProfile(gfx.deferred_shading_profile_index);

        var texture_barriers = [_]zf.TextureBarrier{
            .{
                .render_texture_handle = gfx.scene_color,
                .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
            },
            .{
                .render_texture_handle = gfx.debug_buffer,
                .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                .new_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS,
            },
        };

        zf.cmdResourceBarrier(null, &texture_barriers, null);
        gfx.deferred_shading_material.bindMaterialPass(.default, frame_index, 0);
        const thread_group_size = zf.getShaderThreadGroupSize(gfx.deferred_shading_material.getPassShaderHandle(.default));
        zf.cmdDispatch((window_width + thread_group_size.x - 1) / thread_group_size.x, (window_height + thread_group_size.y - 1) / thread_group_size.y, thread_group_size.z);

        texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
        texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        texture_barriers[1].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
        texture_barriers[1].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

        zf.cmdResourceBarrier(null, &texture_barriers, null);
    }

    // Blur
    if (false) {
        const profile_index = zf.startGpuProfile("Gaussian Blur");
        defer zf.endGpuProfile(profile_index);

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

            gfx.gauss_blur_horizontal_material.bindMaterialPass(.default, frame_index, 0);
            const thread_group_size = zf.getShaderThreadGroupSize(gfx.gauss_blur_horizontal_material.getPassShaderHandle(.default));
            zf.cmdDispatch((window_width + thread_group_size.x - 1) / thread_group_size.x, (window_height + thread_group_size.y - 1) / thread_group_size.y, thread_group_size.z);

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

            gfx.gauss_blur_vertical_material.bindMaterialPass(.default, frame_index, 0);
            const thread_group_size = zf.getShaderThreadGroupSize(gfx.gauss_blur_vertical_material.getPassShaderHandle(.default));
            zf.cmdDispatch((window_width + thread_group_size.x - 1) / thread_group_size.x, (window_height + thread_group_size.y - 1) / thread_group_size.y, thread_group_size.z);

            texture_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_UNORDERED_ACCESS;
            texture_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;

            zf.cmdResourceBarrier(null, &texture_barriers, null);
        }
    }

    {
        gfx.ui_profile_index = zf.startGpuProfile("UI Renderer");
        defer zf.endGpuProfile(gfx.ui_profile_index);

        const text_x: f32 = 30.0;
        var text_y: f32 = 100.0;
        const text_line_height: f32 = 60.0;
        const text_scale: f32 = 18.0 / @as(f32, @floatFromInt(gfx.roboto.size));
        const text_color = [4]f32{ 1.0, 1.0, 0.0, 1.0 };

        {
            const gpu_time = zf.getFrameAvgTimeMs();
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "GPU: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        {
            text_y += text_line_height;
            const gpu_time = zf.getProfilerAvgTimeMs(gfx.shadows_profile_index);
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "Shadows: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        {
            text_y += text_line_height;
            const gpu_time = zf.getProfilerAvgTimeMs(gfx.gbuffer_profile_index);
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "GBuffer: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        {
            text_y += text_line_height;
            const gpu_time = zf.getProfilerAvgTimeMs(gfx.deferred_shading_profile_index);
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "Deferred Shading: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        {
            text_y += text_line_height;
            const gpu_time = zf.getProfilerAvgTimeMs(gfx.ui_profile_index);
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "UI: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        {
            text_y += text_line_height;
            const gpu_time = zf.getProfilerAvgTimeMs(gfx.compositor_profile_index);
            var text_buffer: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(
                text_buffer[0..],
                "Compositor: {d:.3}ms",
                .{ gpu_time },
            ) catch unreachable;

            const transform = zmath.mul(zmath.translation(text_x, text_y, 0.0), zmath.scaling(text_scale, text_scale, text_scale));
            spriteRenderer_RenderText(text, text_color, transform);
        }

        spriteRenderer_End(frame_index);

        var sprite_cb = SpriteConstantBuffer {
            .viewport_size = .{ @floatFromInt(window_width), @floatFromInt(window_height) },
            ._padding = .{ 42, 42 },
            .vertex_buffer_index = zf.getBufferBindlessIndex(gfx.vertex_buffer),
            .instance_buffer_index = zf.getBufferBindlessIndex(gfx.sprite_instance_buffers[frame_index]),
            .linear_repeat_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_repeat_sampler),
            .linear_clamp_sampler_index = zf.getSamplerBindlessIndex(gfx.linear_clamp_sampler),
        };

        const sprite_cb_slice = zf.DataSlice{
            .data = @ptrCast(&sprite_cb),
            .size = @sizeOf(SpriteConstantBuffer),
        };
        zf.updateUniformBuffer(sprite_cb_slice, gfx.sprite_constant_buffers[frame_index]);

         var rt_barriers = [_]zf.RenderTargetBarrier{
            .{
                .render_target_handle = gfx.overlay_buffer,
                .current_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE,
                .new_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET,
            },
        };

        zf.cmdResourceBarrier(null, null, &rt_barriers);

        var bind_render_targets = [_]zf.BindRenderTarget{
            .{
                .render_target_handle = gfx.overlay_buffer,
                .load_action = zf.LoadActionType.LOAD_ACTION_CLEAR,
            },
        };
        zf.cmdBindRenderTargets(&bind_render_targets);
        zf.cmdSetDefaultViewportAndScissor(window_width, window_height);

        gfx.sprite_material.bindMaterialPass(.default, frame_index, 0);
        zf.cmdBindIndexBuffer(gfx.index_buffer, zf.IndexType.INDEX_TYPE_UINT32);

        // TODO: Cache this mesh index
        const quad_mesh_index = gfx.mesh_map.get(HashKey.generate("quad").key).?;
        const quad = &gfx.meshes.items[quad_mesh_index];
        const quad_sub_mesh = quad.sub_meshes[0];
        zf.cmdDrawIndexedInstanced(quad_sub_mesh.index_count, quad_sub_mesh.first_index, @intCast(gfx.sprite_instances.items.len), quad_sub_mesh.first_vertex, 0);

        rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
        rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_SHADER_RESOURCE;
        zf.cmdResourceBarrier(null, null, &rt_barriers);
    }

    // Composite to swapchain
    {
        gfx.compositor_profile_index = zf.startGpuProfile("Composite");
        defer zf.endGpuProfile(gfx.compositor_profile_index);

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

        gfx.compositor_material.bindMaterialPass(.default, frame_index, 0);
        zf.cmdDraw(3, 0);

        rt_barriers[0].current_state = zf.ResourceState.RESOURCE_STATE_RENDER_TARGET;
        rt_barriers[0].new_state = zf.ResourceState.RESOURCE_STATE_PRESENT;
        zf.cmdResourceBarrier(null, null, &rt_barriers);
    }

    zf.frameSubmit();
}

fn prepareCascadeShadowData(camera: *Camera, frame: *Frame, shadow_frame: *ShadowFrame) void {
    const global_shadow_matrix = makeGlobalShadowMatrix(camera);
    zmath.storeMat(&shadow_frame.shadow_matrix, zmath.transpose(global_shadow_matrix));

    var cascade_splits: [CSMSettings.cascades_max_count]f32 = undefined;
    for (0..CSMSettings.cascades_max_count) |i| {
        // TODO: Change this if we want other partition modes other than the manual one
        cascade_splits[i] = gfx.cms_settings.cascades_distances[i];
    }

    // TODO: Change these if we want to use depth reduction to find the depth min/max values
    const min_distance: f32 = 0.0;
    // const max_distance: f32 = 1.0;

    for (0..gfx.cms_settings.cascades_count) |cascade_index| {
        const inv_view_proj = zmath.inverse(camera.view_proj);
        var frustum_corners = [8]zmath.Vec{
            .{ -1.0, 1.0, 0.0, 1.0 },
            .{ 1.0, 1.0, 0.0, 1.0 },
            .{ 1.0, -1.0, 0.0, 1.0 },
            .{ -1.0, -1.0, 0.0, 1.0 },
            .{ -1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, 1.0, 1.0, 1.0 },
            .{ 1.0, -1.0, 1.0, 1.0 },
            .{ -1.0, -1.0, 1.0, 1.0 },
        };

        for (0..8) |i| {
            frustum_corners[i] = transformVec3Coord(frustum_corners[i], inv_view_proj);
        }

        const previous_split_distance = if (cascade_index == 0) min_distance else cascade_splits[cascade_index - 1];
        const split_distance = cascade_splits[cascade_index];

        // Get the corners of the current cascade slice of the view frustum
        for (0..4) |i| {
            const corner_ray = frustum_corners[i + 4] - frustum_corners[i];
            const near_corner_ray = zmath.Vec{ corner_ray[0] * previous_split_distance, corner_ray[1] * previous_split_distance, corner_ray[2] * previous_split_distance, 1.0 };
            const far_corner_ray = zmath.Vec{ corner_ray[0] * split_distance, corner_ray[1] * split_distance, corner_ray[2] * split_distance, 1.0 };
            frustum_corners[i + 4] = frustum_corners[i] + far_corner_ray;
            frustum_corners[i] = frustum_corners[i] + near_corner_ray;
        }

        // Calculate the centroid of the view frustum slice
        var frustum_center = zmath.Vec{ 0.0, 0.0, 0.0, 1.0 };
        for (0..8) |i| {
            frustum_center = frustum_center + frustum_corners[i];
        }
        const weight: f32 = 1.0 / 8.0;
        frustum_center[0] *= weight;
        frustum_center[1] *= weight;
        frustum_center[2] *= weight;
        frustum_center[3] = 1.0;

        const up_dir = zmath.Vec{ 0.0, 1.0, 0.0, 0.0 };
        // Stabilize the cascade
        // Calculate the radius of a bounding sphere surrounding the frustum corner
        var sphere_radius: f32 = 0.0;
        for (0..8) |i| {
            const distance = zmath.length3(frustum_corners[i] - frustum_center);
            sphere_radius = @max(sphere_radius, distance[0]);
        }

        sphere_radius = @ceil(sphere_radius * 16.0) / 16.0;
        const max_extents = zmath.Vec{ sphere_radius, sphere_radius, sphere_radius, 0.0 };
        const min_extents = zmath.Vec{ -sphere_radius, -sphere_radius, -sphere_radius, 0.0 };
        const cascade_extents = max_extents - min_extents;

        // Get the position of the shadow camera
        // TODO: Get the actual sun light
        var light_direction = zmath.normalize3(zmath.Vec{ 1.0, 1.0, 1.0, 0.0 });
        light_direction[0] *= -min_extents[2];
        light_direction[1] *= -min_extents[2];
        light_direction[2] *= -min_extents[2];
        const shadow_camera_position = frustum_center + light_direction;

        var cascade_proj = zmath.orthographicOffCenterLh(min_extents[0], max_extents[0], max_extents[1], min_extents[1], 0.0, cascade_extents[2]);
        const cascade_view = zmath.lookAtLh(shadow_camera_position, frustum_center, up_dir);

        var cascade_view_proj = zmath.mul(cascade_view, cascade_proj);
        // Stabilize the cascade (once more)
        const cascade_resolution: f32 = @floatFromInt(gfx.cms_settings.resolution);
        var shadow_origin = transformVec3Coord(zmath.Vec{ 0.0, 0.0, 0.0, 1.0 }, cascade_view_proj);
        shadow_origin[0] *= cascade_resolution * 0.5;
        shadow_origin[1] *= cascade_resolution * 0.5;
        shadow_origin[2] *= cascade_resolution * 0.5;

        const rounded_origin = zmath.round(shadow_origin);
        var round_offset = rounded_origin - shadow_origin;
        round_offset[0] *= (2.0 / cascade_resolution);
        round_offset[1] *= (2.0 / cascade_resolution);
        round_offset[2] = 0.0;
        round_offset[3] = 0.0;

        cascade_proj[3] = cascade_proj[3] + round_offset;
        cascade_view_proj = zmath.mul(cascade_view, cascade_proj);

        zmath.storeMat(&frame.cascade_view_projections[cascade_index], zmath.transpose(cascade_view_proj));

        // Setting up shadow_frame data for this cascade
        var tex_scale_bias = zmath.identity();
        tex_scale_bias[0] = .{ 0.5, 0.0, 0.0, 0.0 };
        tex_scale_bias[1] = .{ 0.0, -0.5, 0.0, 0.0 };
        tex_scale_bias[2] = .{ 0.0, 0.0, 1.0, 0.0 };
        tex_scale_bias[3] = .{ 0.5, 0.5, 0.0, 1.0 };
        cascade_view_proj = zmath.mul(cascade_view_proj, tex_scale_bias);

        // Store the split distance in terms of view space depth
        const clip_distance = camera.far_plane - camera.near_plane;
        shadow_frame.cascade_splits[cascade_index] = camera.near_plane + split_distance * clip_distance;

        // Calculate the position of the lower corner of the cascade partition, in the UV space
        // of the first cascade partition
        const inv_cascade_view_proj = zmath.inverse(cascade_view_proj);
        var cascade_corner = transformVec3Coord(.{ 0.0, 0.0, 0.0, 1.0 }, inv_cascade_view_proj);
        cascade_corner = transformVec3Coord(cascade_corner, global_shadow_matrix);

        // Do the same for the upper corner
        var other_corner = transformVec3Coord(.{ 1.0, 1.0, 1.0, 1.0 }, inv_cascade_view_proj);
        other_corner = transformVec3Coord(other_corner, global_shadow_matrix);

        // Calculate the scale and offset
        const corner_diff = other_corner - cascade_corner;
        const cascade_scale = zmath.Vec{ 1.0 / corner_diff[0], 1.0 / corner_diff[1], 1.0 / corner_diff[2], 1.0 };
        shadow_frame.cascade_offsets[cascade_index] = .{ -cascade_corner[0], -cascade_corner[1], -cascade_corner[2], 0.0 };
        shadow_frame.cascade_scales[cascade_index] = .{ cascade_scale[0], cascade_scale[1], cascade_scale[2], 1.0 };
    }
}

// Makes the "global" shadow matrix used as reference point for the cascades
fn makeGlobalShadowMatrix(camera: *Camera) zmath.Mat {
    const inv_view_proj = zmath.inverse(camera.view_proj);
    var frustum_center = zmath.Vec{ 0.0, 0.0, 0.0, 1.0 };
    var frustum_corners = [8]zmath.Vec{
        .{ -1.0, 1.0, 0.0, 1.0 },
        .{ 1.0, 1.0, 0.0, 1.0 },
        .{ 1.0, -1.0, 0.0, 1.0 },
        .{ -1.0, -1.0, 0.0, 1.0 },
        .{ -1.0, 1.0, 1.0, 1.0 },
        .{ 1.0, 1.0, 1.0, 1.0 },
        .{ 1.0, -1.0, 1.0, 1.0 },
        .{ -1.0, -1.0, 1.0, 1.0 },
    };

    for (0..8) |i| {
        frustum_corners[i] = transformVec3Coord(frustum_corners[i], inv_view_proj);
        frustum_center = frustum_center + frustum_corners[i];
    }

    const weight: f32 = 1.0 / 8.0;
    frustum_center[0] *= weight;
    frustum_center[1] *= weight;
    frustum_center[2] *= weight;
    frustum_center[3] = 1.0;

    const up_dir = zmath.Vec{ 0.0, 1.0, 0.0, 0.0 };

    // Get the position of the shadow camera
    var light_direction = zmath.normalize3(zmath.Vec{ 1.0, 1.0, 1.0, 0.0 });
    light_direction[0] *= -0.5;
    light_direction[1] *= -0.5;
    light_direction[2] *= -0.5;
    const shadow_camera_position = frustum_center + light_direction;

    // Come up with a new orthographic camera for the shaodw caster
    const shadow_camera_proj = zmath.orthographicOffCenterLh(-0.5, 0.5, 0.5, -0.5, 0.0, 1.0);
    const shadow_camera_view = zmath.lookAtLh(shadow_camera_position, frustum_center, up_dir);
    const shadow_camera_view_proj = zmath.mul(shadow_camera_view, shadow_camera_proj);

    var tex_scale_bias = zmath.scaling(0.5, -0.5, 1.0);
    tex_scale_bias[3][0] = 0.5;
    tex_scale_bias[3][1] = 0.5;
    tex_scale_bias[3][2] = 0.0;

    return zmath.mul(shadow_camera_view_proj, tex_scale_bias);
}

fn updateDescriptorSets() void {
    // Compositor Material: Per Frame
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
            .{
                .name = "g_overlay",
                .binding_type = .render_target,
                .render_target_handle = gfx.overlay_buffer,
            },
        };

        gfx.compositor_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
    }

    // Sprite Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CB",
                .binding_type = .buffer,
                .buffer_handle = gfx.sprite_constant_buffers[frame_index],
            },
        };

        gfx.sprite_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
    }

    // // Object Material: Per Frame
    // for (0..zf.frames_in_flight_count) |frame_index| {
    //     // GBuffer Pass
    //     {
    //         const resource_binding_descs = [_]zf.ResourceBindingDesc{
    //             .{
    //                 .name = "g_CBO",
    //                 .binding_type = .buffer,
    //                 .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
    //             },
    //         };

    //         gfx.object_material.updateDescriptorSet(.gbuffer, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
    //     }

    //     // Shadow Caster Pass
    //     for (0..CSMSettings.cascades_max_count) |cascade_index| {
    //         const resource_binding_descs = [_]zf.ResourceBindingDesc{
    //             .{
    //                 .name = "g_CBO",
    //                 .binding_type = .buffer,
    //                 .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
    //             },
    //             .{
    //                 .name = "g_ShadowCasterCB",
    //                 .binding_type = .buffer,
    //                 .buffer_handle = gfx.shadow_caster_constant_buffers[frame_index][cascade_index],
    //             },
    //         };

    //         gfx.object_material.updateDescriptorSet(.shadow_caster, &resource_binding_descs, .per_frame, @intCast(frame_index), @intCast(cascade_index));
    //     }
    // }

    // Deferred Shading Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_ShadowCB",
                .binding_type = .buffer,
                .buffer_handle = gfx.shadow_frame_constant_buffers[frame_index],
            },
            .{
                .name = "g_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.scene_color,
            },
            .{
                .name = "g_debug_output",
                .binding_type = .render_texture,
                .render_texture_handle = gfx.debug_buffer,
            },
        };

        gfx.deferred_shading_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
    }

    // Deferred Shading Material: Persistent
    {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_gbuffer0",
                .binding_type = .render_target,
                .render_target_handle = gfx.gbuffer0,
            },
            .{
                .name = "g_gbuffer1",
                .binding_type = .render_target,
                .render_target_handle = gfx.gbuffer1,
            },
            .{
                .name = "g_depth_buffer",
                .binding_type = .render_target,
                .render_target_handle = gfx.depth_buffer,
            },
            .{
                .name = "g_shadow_map",
                .binding_type = .render_target,
                .render_target_handle = gfx.shadow_depth_buffer,
            },
        };

        gfx.deferred_shading_material.updateDescriptorSet(.default, &resource_binding_descs, .persistent, 0, 0);
    }

    // Clear Buffer Material: Per Frame
    for (0..zf.frames_in_flight_count) |frame_index| {
        const resource_binding_descs = [_]zf.ResourceBindingDesc{
            .{
                .name = "g_CBO",
                .binding_type = .buffer,
                .buffer_handle = gfx.clear_buffer_constant_buffers[frame_index],
            },
        };

        gfx.clear_buffer_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
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

        gfx.gauss_blur_horizontal_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
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

        gfx.gauss_blur_horizontal_material.updateDescriptorSet(.default, &resource_binding_descs, .persistent, 0, 0);
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

        gfx.gauss_blur_vertical_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
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

        gfx.gauss_blur_vertical_material.updateDescriptorSet(.default, &resource_binding_descs, .persistent, 0, 0);
    }

    // Meshlet Renderer
    // ================
    {
        for (0..zf.frames_in_flight_count) |frame_index| {
            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_ClearUAVParams",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.clear_counters_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_clear_counters_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }

            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_CBO",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
                    },
                    .{
                        .name = "g_CullInstancesParams",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.meshlet_cull_instances_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_cull_instances_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }

            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_MeshletCullArgsParams",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.meshlet_cull_args_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_cull_args_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }

            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_CBO",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
                    },
                    .{
                        .name = "g_CullMeshletsParams",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.meshlet_cull_meshlets_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_cull_meshlets_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }

            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_MeshletDispatchArgsParams",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.meshlet_dispatch_args_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_dispatch_args_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }

            {
                const resource_binding_descs = [_]zf.ResourceBindingDesc{
                    .{
                        .name = "g_CBO",
                        .binding_type = .buffer,
                        .buffer_handle = gfx.global_frame_constant_buffers[frame_index],
                    },
                };

                gfx.meshlet_rasterizer_material.updateDescriptorSet(.default, &resource_binding_descs, .per_frame, @intCast(frame_index), 0);
            }
        }
    }
}

// ███╗   ███╗███████╗███████╗██╗  ██╗███████╗███████╗
// ████╗ ████║██╔════╝██╔════╝██║  ██║██╔════╝██╔════╝
// ██╔████╔██║█████╗  ███████╗███████║█████╗  ███████╗
// ██║╚██╔╝██║██╔══╝  ╚════██║██╔══██║██╔══╝  ╚════██║
// ██║ ╚═╝ ██║███████╗███████║██║  ██║███████╗███████║
// ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝
//

pub fn loadMesh(mesh_key: HashKey, content_path: []const u8, file_name: []const u8) void {
    var mesh_data = std.ArrayList(geometry.MeshData).init(gfx_allocator);
    defer mesh_data.deinit();

    var load_desc: geometry.MeshLoadDesc = undefined;
    load_desc.base_path = content_path;
    load_desc.file_name = file_name;
    load_desc.allocator = gfx_allocator;
    load_desc.mesh_data = &mesh_data;
    geometry.loadMesh(&load_desc);

    const mesh_index = gfx.clustered_meshes.items.len;
    const mesh_count: u32 = @intCast(mesh_data.items.len);
    gfx.clustered_mesh_map.put(mesh_key.key, .{ .index = @intCast(mesh_index), .count = mesh_count }) catch unreachable;
    uploadMesh(&mesh_data);
}

fn uploadMesh(mesh_datas: *std.ArrayList(geometry.MeshData)) void {
    gfx.mesh_buffer_mutex.lock();
    defer gfx.mesh_buffer_mutex.unlock();

    var gpu_mesh_data = std.ArrayList(GPUMesh).init(gfx_allocator);
    defer gpu_mesh_data.deinit();

    for (mesh_datas.items) |mesh_data| {
        var mesh = std.mem.zeroes(Mesh);
        var data_size: usize = 0;
        data_size += mesh_data.indices.items.len * @sizeOf(u32);
        data_size += mesh_data.positions_stream.items.len * @sizeOf([3]f32);
        data_size += mesh_data.normals_stream.items.len * @sizeOf([3]f32);
        data_size += mesh_data.texcoords_stream.items.len * @sizeOf([2]f32);
        data_size += mesh_data.meshlets.items.len * @sizeOf(geometry.Meshlet);
        data_size += mesh_data.meshlet_bounds.items.len * @sizeOf(geometry.MeshletBounds);
        data_size += mesh_data.meshlet_triangles.items.len * @sizeOf(geometry.MeshletTriangle);
        data_size += mesh_data.meshlet_vertices.items.len * @sizeOf(u32);

        mesh.data_buffer = zf.createRawBuffer(data_size, u32, true, false, "Mesh");

        const buffer_data = gfx_allocator.alloc(u8, data_size) catch unreachable;
        defer gfx_allocator.free(buffer_data);

        var buffer_data_offset: usize = 0;
        const buffer_gpu_address = zf.getBufferGPUAddress(mesh.data_buffer);
        // Positions
        {
            const stride = @sizeOf([3]f32);
            mesh.position_stream_location.location = buffer_gpu_address + buffer_data_offset;
            mesh.position_stream_location.elements = @intCast(mesh_data.positions_stream.items.len);
            mesh.position_stream_location.stride = @intCast(stride);
            mesh.position_stream_location.offset_from_start = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.positions_stream.items.ptr), buffer_data_offset, mesh_data.positions_stream.items.len * stride);
            buffer_data_offset += mesh_data.positions_stream.items.len * stride;
        }
        // Normals
        {
            const stride = @sizeOf([3]f32);
            mesh.normal_stream_location.location = buffer_gpu_address + buffer_data_offset;
            mesh.normal_stream_location.elements = @intCast(mesh_data.normals_stream.items.len);
            mesh.normal_stream_location.stride = @intCast(stride);
            mesh.normal_stream_location.offset_from_start = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.normals_stream.items.ptr), buffer_data_offset, mesh_data.normals_stream.items.len * stride);
            buffer_data_offset += mesh_data.normals_stream.items.len * stride;
        }
        // Texcoords
        {
            const stride = @sizeOf([2]f32);
            mesh.texcoord_stream_location.location = buffer_gpu_address + buffer_data_offset;
            mesh.texcoord_stream_location.elements = @intCast(mesh_data.texcoords_stream.items.len);
            mesh.texcoord_stream_location.stride = @intCast(stride);
            mesh.texcoord_stream_location.offset_from_start = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.texcoords_stream.items.ptr), buffer_data_offset, mesh_data.texcoords_stream.items.len * stride);
            buffer_data_offset += mesh_data.texcoords_stream.items.len * stride;
        }
        // Indices
        {
            // TODO
            // const small_indices = mesh_data.positions_stream.items.len < std.math.maxInt(u16);
            // const index_size = if (small_indices) @sizeOf(u16) else @sizeOf(u32);
            const stride = @sizeOf(u32);
            mesh.indices_location.location = buffer_gpu_address + buffer_data_offset;
            mesh.indices_location.elements = @intCast(mesh_data.indices.items.len);
            mesh.indices_location.offset_from_start = @intCast(buffer_data_offset);
            mesh.indices_location.index_type = .INDEX_TYPE_UINT32;

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.indices.items.ptr), buffer_data_offset, mesh_data.indices.items.len * stride);
            buffer_data_offset += mesh_data.indices.items.len * stride;
        }
        // Meshlets
        {
            const stride = @sizeOf(geometry.Meshlet);
            mesh.meshlets_location = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.meshlets.items.ptr), buffer_data_offset, mesh_data.meshlets.items.len * stride);
            buffer_data_offset += mesh_data.meshlets.items.len * stride;
        }
        // Meshlet Vertices
        {
            const stride = @sizeOf(u32);
            mesh.meshlet_vertices_location = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.meshlet_vertices.items.ptr), buffer_data_offset, mesh_data.meshlet_vertices.items.len * stride);
            buffer_data_offset += mesh_data.meshlet_vertices.items.len * stride;
        }
        // Meshlet Triangles
        {
            const stride = @sizeOf(geometry.MeshletTriangle);
            mesh.meshlet_triangles_location = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.meshlet_triangles.items.ptr), buffer_data_offset, mesh_data.meshlet_triangles.items.len * stride);
            buffer_data_offset += mesh_data.meshlet_triangles.items.len * stride;
        }
        // Meshlet Bounds
        {
            const stride = @sizeOf(geometry.MeshletBounds);
            mesh.meshlet_bounds_location = @intCast(buffer_data_offset);

            zf.memcpy(@ptrCast(buffer_data), @ptrCast(mesh_data.meshlet_bounds.items.ptr), buffer_data_offset, mesh_data.meshlet_bounds.items.len * stride);
            buffer_data_offset += mesh_data.meshlet_bounds.items.len * stride;
        }

        mesh.meshlet_count = @intCast(mesh_data.meshlets.items.len);
        mesh.bounds.center = mesh_data.bounds.center;
        mesh.bounds.extents = mesh_data.bounds.extents;

        const data_slice = zf.DataSlice{
            .data = @ptrCast(buffer_data),
            .size = data_size,
        };
        zf.updateBuffer(data_slice, 0, mesh.data_buffer);
        gfx.clustered_meshes.append(mesh) catch unreachable;

        const gpu_mesh = GPUMesh{
            .data_buffer = zf.getBufferBindlessIndex(mesh.data_buffer),
            .index_byte_size = 4, // TODO
            .indices_offset = @intCast(mesh.indices_location.offset_from_start),
            .positions_offset = @intCast(mesh.position_stream_location.offset_from_start),
            .normals_offset = @intCast(mesh.normal_stream_location.offset_from_start),
            .texcoords_offset = @intCast(mesh.texcoord_stream_location.offset_from_start),
            .meshlet_offset = mesh.meshlets_location,
            .meshlet_bounds_offset = mesh.meshlet_bounds_location,
            .meshlet_triangle_offset = mesh.meshlet_triangles_location,
            .meshlet_vertex_offset = mesh.meshlet_vertices_location,
            .meshlet_count = mesh.meshlet_count,
        };

        gpu_mesh_data.append(gpu_mesh) catch unreachable;
    }

    const gpu_mesh_data_slice = zf.DataSlice{
        .data = @ptrCast(gpu_mesh_data.items),
        .size = @sizeOf(GPUMesh) * gpu_mesh_data.items.len,
    };
    zf.updateBuffer(gpu_mesh_data_slice, gfx.mesh_buffer_offset, gfx.mesh_buffer);
    gfx.mesh_buffer_offset += gpu_mesh_data_slice.size;
}

pub fn loadGltfMesh(mesh_key: HashKey, content_path: []const u8, file_name: []const u8) void {
    // TODO: Allocate these at startup and reuse across function calls with clearRetainCapacity
    var mesh_vertices = std.ArrayList(geometry.Vertex).init(gfx_allocator);
    defer mesh_vertices.deinit();
    var mesh_indices = std.ArrayList(u32).init(gfx_allocator);
    defer mesh_indices.deinit();

    var load_desc: geometry.GltfLoadDesc = undefined;
    load_desc.base_path = content_path;
    load_desc.allocator = gfx_allocator;
    load_desc.mesh_vertices = &mesh_vertices;
    load_desc.mesh_indices = &mesh_indices;

    const mesh_index = gfx.meshes.items.len;
    var mesh = std.mem.zeroes(geometry.Mesh);

    load_desc.file_name = file_name;
    load_desc.allocator = gfx_allocator;
    load_desc.mesh = &mesh;

    geometry.loadGltfMesh(&load_desc);
    uploadGltfMesh(&mesh_vertices, &mesh_indices, &mesh);
    gfx.mesh_map.put(mesh_key.key, mesh_index) catch unreachable;
    gfx.meshes.append(mesh) catch unreachable;
}

fn uploadGltfMesh(vertices: *std.ArrayList(geometry.Vertex), indices: *std.ArrayList(u32), mesh: *geometry.Mesh) void {
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

pub fn loadTexture(key: HashKey, path: []const u8) void {
    const handle = loadDdsTexture(path, true, gfx_allocator) catch unreachable;
    gfx.texture_map.put(key.key, handle) catch unreachable;
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

// ███╗   ███╗ █████╗ ████████╗███████╗██████╗ ██╗ █████╗ ██╗     ███████╗
// ████╗ ████║██╔══██╗╚══██╔══╝██╔════╝██╔══██╗██║██╔══██╗██║     ██╔════╝
// ██╔████╔██║███████║   ██║   █████╗  ██████╔╝██║███████║██║     ███████╗
// ██║╚██╔╝██║██╔══██║   ██║   ██╔══╝  ██╔══██╗██║██╔══██║██║     ╚════██║
// ██║ ╚═╝ ██║██║  ██║   ██║   ███████╗██║  ██║██║██║  ██║███████╗███████║
// ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚══════╝
//

pub fn loadMaterial(key: zf.HashKey, material_desc: MaterialDataDesc) void {
    gfx.material_buffer_mutex.lock();
    defer gfx.material_buffer_mutex.unlock();

    const material_index = gfx.material_data.items.len;
    var material = GpuMaterialData{};
    @memcpy(material.base_color[0..], material_desc.base_color[0..]);

    if (material_desc.albedo_texture) |texture_key| {
        material.albedo_texture_id = zf.getTextureBindlessIndex(gfx.texture_map.get(texture_key.key).?);
    }

    if (material_desc.normal_texture) |texture_key| {
        material.normal_texture_id = zf.getTextureBindlessIndex(gfx.texture_map.get(texture_key.key).?);
    }

    gfx.material_data.append(material) catch unreachable;
    gfx.material_map.put(key.key, material_index) catch unreachable;

    const material_data = zf.DataSlice{
        .data = @ptrCast(&material),
        .size = @sizeOf(GpuMaterialData),
    };
    zf.updateBuffer(material_data, gfx.material_buffer_offset, gfx.material_buffer);


    gfx.material_buffer_offset += material_data.size;
}

// ██████╗ ███████╗███╗   ██╗██████╗ ███████╗██████╗  █████╗ ██████╗ ██╗     ███████╗███████╗
// ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗██║     ██╔════╝██╔════╝
// ██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗  ██████╔╝███████║██████╔╝██║     █████╗  ███████╗
// ██╔══██╗██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══██╗██╔══██║██╔══██╗██║     ██╔══╝  ╚════██║
// ██║  ██║███████╗██║ ╚████║██████╔╝███████╗██║  ██║██║  ██║██████╔╝███████╗███████╗███████║
// ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚══════╝
//

pub fn registerRenderable(key: HashKey, mesh_key: HashKey, materials: []const HashKey) void {
    const mesh_info = gfx.clustered_mesh_map.get(mesh_key.key).?;
    std.debug.assert(mesh_info.count == @as(u32, @intCast(materials.len)));

    var renderable: Renderable = undefined;
    renderable.mesh_key = mesh_key;
    renderable.material_count = @intCast(materials.len);
    for (0..materials.len) |i| {
        renderable.materials[i] = materials[i];
    }

    gfx.renderables.put(key.key, renderable) catch unreachable;
}

pub fn registerInstances(instances: *std.ArrayList(Instance)) void {
    var gpu_instances = std.ArrayList(GPUInstance).init(gfx_allocator);
    defer gpu_instances.deinit();

    for (instances.items, 0..) |instance, instance_id| {
        const renderable = gfx.renderables.get(instance.renderable.key).?;
        const mesh_info = gfx.clustered_mesh_map.get(renderable.mesh_key.key).?;

        for (0..mesh_info.count) |mesh_index_offset| {
            const mesh = &gfx.clustered_meshes.items[mesh_info.index + mesh_index_offset];
            const material_index = gfx.material_map.get(renderable.materials[mesh_index_offset].key).?;
            var gpu_instance = std.mem.zeroes(GPUInstance);
            @memcpy(gpu_instance.world[0..], instance.world_mat[0..]);
            gpu_instance.id = @intCast(instance_id);
            gpu_instance.mesh_index = @intCast(mesh_info.index + mesh_index_offset);
            gpu_instance.material_index = @intCast(material_index);
            gpu_instance.local_bounds_origin = mesh.bounds.center;
            gpu_instance.local_bounds_extents = mesh.bounds.extents;

            gpu_instances.append(gpu_instance) catch unreachable;
        }
    }

    const instances_data_slice = zf.DataSlice{
        .data = @ptrCast(gpu_instances.items),
        .size = @sizeOf(GPUInstance) * gpu_instances.items.len,
    };
    for (0..zf.frames_in_flight_count) |frame_index| {
        zf.updateBuffer(instances_data_slice, 0, gfx.instance_buffers[frame_index]);
    }

    gfx.registered_instances_count = @intCast(gpu_instances.items.len);
}

// ███████╗██████╗ ██████╗ ██╗████████╗███████╗███████╗
// ██╔════╝██╔══██╗██╔══██╗██║╚══██╔══╝██╔════╝██╔════╝
// ███████╗██████╔╝██████╔╝██║   ██║   █████╗  ███████╗
// ╚════██║██╔═══╝ ██╔══██╗██║   ██║   ██╔══╝  ╚════██║
// ███████║██║     ██║  ██║██║   ██║   ███████╗███████║
// ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝╚══════╝
//

fn spriteRenderer_Begin(frame_index: u32) void {
    _ = frame_index;
    gfx.sprite_instances.clearRetainingCapacity();
}

fn spriteRenderer_End(frame_index: u32) void {
    if (gfx.sprite_instances.items.len > 0) {
        const sprite_instance_data = zf.DataSlice{
            .data = @ptrCast(gfx.sprite_instances.items),
            .size = @sizeOf(SpriteInstance) * gfx.sprite_instances.items.len,
        };

        zf.updateBuffer(sprite_instance_data, 0, gfx.sprite_instance_buffers[frame_index]);
    }
}

fn spriteRenderer_RenderText(text: []const u8, color: [4]f32, transform: zmath.Mat) void {
    var text_transform = zmath.identity();
    const font_atlas_index = zf.getTextureBindlessIndex(gfx.roboto.texture);
    const font_atlas_resolution = zf.getTextureResolution(gfx.roboto.texture);

    for (0..text.len) |i| {
        const character = text[i];
        // TODO: Check if character is space or newline
        if (character == 32) {
            text_transform[3][0] += 20; // TODO: Get space width for this font
        } else {
            const char_desc = gfx.roboto.getCharDesc(@intCast(character));

            var sprite_instance: SpriteInstance = undefined;
            @memcpy(&sprite_instance.color, &color);
            zmath.storeMat(&sprite_instance.transform, zmath.transpose(zmath.mul(text_transform, transform)));

            sprite_instance.sprite_atlas_index = font_atlas_index;
            sprite_instance.font_distance_range = @floatFromInt(gfx.roboto.distance_range);
            sprite_instance.sprite_resolution[0] = @floatFromInt(font_atlas_resolution[0]);
            sprite_instance.sprite_resolution[1] = @floatFromInt(font_atlas_resolution[1]);
            sprite_instance.source_rect = .{ char_desc.source_rect.x, char_desc.source_rect.y, char_desc.source_rect.width, char_desc.source_rect.height };
            gfx.sprite_instances.append(sprite_instance) catch unreachable;
            text_transform[3][0] += char_desc.source_rect.width + 1;
        }
    }
}

// ███╗   ███╗ █████╗ ████████╗██╗  ██╗    ██╗   ██╗████████╗██╗██╗     ███████╗
// ████╗ ████║██╔══██╗╚══██╔══╝██║  ██║    ██║   ██║╚══██╔══╝██║██║     ██╔════╝
// ██╔████╔██║███████║   ██║   ███████║    ██║   ██║   ██║   ██║██║     ███████╗
// ██║╚██╔╝██║██╔══██║   ██║   ██╔══██║    ██║   ██║   ██║   ██║██║     ╚════██║
// ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║    ╚██████╔╝   ██║   ██║███████╗███████║
// ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝     ╚═════╝    ╚═╝   ╚═╝╚══════╝╚══════╝
//

pub inline fn transformVec3Coord(v: zmath.Vec, m: zmath.Mat) zmath.Vec {
    const z = zmath.splat(zmath.F32x4, v[2]);
    const y = zmath.splat(zmath.F32x4, v[1]);
    const x = zmath.splat(zmath.F32x4, v[0]);

    var result = zmath.mulAdd(z, m[2], m[3]);
    result = zmath.mulAdd(y, m[1], result);
    result = zmath.mulAdd(x, m[0], result);

    result[0] /= result[3];
    result[1] /= result[3];
    result[2] /= result[3];
    result[3] = 1.0;
    return result;
}
