#ifndef _GLOBALS_HLSLI
#define _GLOBALS_HLSLI

#include "Defines.hlsli"

struct Frame
{
    float4x4 view;
    float4x4 projection;
    float4x4 view_proj;
    // TODO: Add inverted view, projection and view_projection
    float time;
    uint vertex_buffer_index;
    uint transform_buffer_index;
    uint material_buffer_index;
    uint instance_buffer_index;
};

struct Transform
{
    // TODO: Change this to float4x3
    float4x4 world;
};

struct MaterialData
{
    uint albedo_texture_index;
    uint normal_texture_index;
    uint2 _padding;
};

struct InstanceData
{
    uint transform_index;
    uint material_index;
    uint2 _padding;
};

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    Frame g_frame;
};

InstanceData getInstanceData(uint instance_index)
{
    ByteAddressBuffer instance_buffer = ResourceDescriptorHeap[g_frame.instance_buffer_index];
    InstanceData instance = instance_buffer.Load<InstanceData>(instance_index * sizeof(InstanceData));
    return instance;
}

Transform getTransform(uint transform_index)
{
    ByteAddressBuffer transform_buffer = ResourceDescriptorHeap[g_frame.transform_buffer_index];
    Transform transform = transform_buffer.Load<Transform>(transform_index * sizeof(Transform));
    return transform;
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