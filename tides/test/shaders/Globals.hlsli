#ifndef _GLOBALS_HLSLI
#define _GLOBALS_HLSLI

#include "Defines.hlsli"

static const uint CASCADES_MAX_COUNT = 4;

struct Frame
{
    float4x4 view;
    float4x4 projection;
    float4x4 view_proj;
    float4x4 inv_view_proj;
    // TODO: Add inverted view, projection
    float4x4 cascade_view_proj[CASCADES_MAX_COUNT];
    float4 camera_position;
    float camera_near_plane;
    float camera_far_plane;
    float time;
    uint _padding0;
    // Default samplers
    // TODO: Add more default samplers
    uint linear_repeat_sampler_index;
    uint linear_clamp_sampler_index;
    uint shadow_sampler_index;
    uint shadow_pcf_sampler_index;

    uint vertex_buffer_index;
    uint material_buffer_index;
    uint instance_buffer_index;
    uint meshes_buffer_index;

    uint instances_count;
    uint3 _padding;
};

struct Mesh
{
	uint data_buffer_index;
	uint positions_offset;
	uint normals_offset;
	uint texcoords_offset;
	uint indices_offset;
	uint index_byte_size;
	uint meshlet_offset;
	uint meshlet_vertex_offset;
	uint meshlet_triangle_offset;
	uint meshlet_bounds_offset;
	uint meshlet_count;
};

struct MeshletBounds
{
    float3 local_center;
    float3 local_extents;
};

struct Instance
{
    float4x4 world;
    float3 local_bounds_origin;
    uint _pad0;
    float3 local_bounds_extents;
    uint id;
    uint mesh_index;
    uint material_index;
    uint2 _pad1;
};

struct Transform
{
    // TODO: Change this to float4x3
    float4x4 world;
};

struct MaterialData
{
    uint albedo_texture_index;
    uint albedo_sampler_index;
    uint normal_texture_index;
    uint normal_sampler_index;
};

struct InstanceData
{
    uint transform_index;
    uint material_index;
    uint mesh_index;
    uint sub_mesh_index;
};

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    Frame g_frame;
};

#ifdef SHADOW_CASTER
struct ShadowCasterFrame
{
    uint cascade_index;
    uint3 _padding;
};

cbuffer g_ShadowCasterCB : register(b1, SPACE_PerFrame)
{
    ShadowCasterFrame g_shadow_caster_frame;
};
#endif

InstanceData getInstanceData(uint instance_index)
{
    ByteAddressBuffer instance_buffer = ResourceDescriptorHeap[g_frame.instance_buffer_index];
    InstanceData instance = instance_buffer.Load<InstanceData>(instance_index * sizeof(InstanceData));
    return instance;
}

MaterialData getMaterial(uint material_index)
{
    ByteAddressBuffer material_buffer = ResourceDescriptorHeap[g_frame.material_buffer_index];
    MaterialData material = material_buffer.Load<MaterialData>(material_index * sizeof(MaterialData));
    return material;
}

bool hasValidDescriptor(uint descriptor_index)
{
    return descriptor_index != k_invalid_descriptor_index;
}

#endif // _GLOBALS_HLSLI