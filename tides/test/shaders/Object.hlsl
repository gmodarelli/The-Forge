#include "Globals.hlsli"

struct Vertex
{
    float3 position;
    float2 uv;
    float3 normal;
};

struct VertexShaderInput
{
    uint vertex_id : SV_VertexID;
    uint instance_id : SV_InstanceID;
    uint start_vertex_location : SV_StartVertexLocation;
    uint start_instance_location : SV_StartInstanceLocation;
};

struct Varyings
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    uint instance_index : SV_INSTANCEID;
};

[RootSignature(DefaultRootSignature)]
Varyings ObjectVS(VertexShaderInput input)
{
    Varyings output = (Varyings) 0;

    uint instance_index = input.instance_id + input.start_instance_location;
    InstanceData instance = getInstanceData(instance_index);
    Transform transform = getTransform(instance.transform_index);

    uint vertex_index = input.vertex_id + input.start_vertex_location;
    ByteAddressBuffer vertex_buffer = ResourceDescriptorHeap[g_frame.vertex_buffer_index];
    Vertex vertex = vertex_buffer.Load<Vertex>(vertex_index * sizeof(Vertex));

    float4x4 mvp = mul(g_frame.view_proj, transform.world);
    output.position = mul(mvp, float4(vertex.position, 1));
    output.uv = vertex.uv;
    output.normal = vertex.normal;
    output.instance_index = instance_index;

    return output;
}

[RootSignature(DefaultRootSignature)]
float4 ObjectPS(Varyings varyings) : SV_Target0
{
    InstanceData instance = getInstanceData(varyings.instance_index);
    MaterialData material = getMaterial(instance.material_index);

    float3 color = 0.0;

    if (hasValidDescriptor(material.albedo_texture_index)) {
        Texture2D albedo = ResourceDescriptorHeap[material.albedo_texture_index];

        uint sampler_index = material.albedo_sampler_index;
        if (!hasValidDescriptor(sampler_index)) {
            sampler_index = g_frame.linear_repeat_sampler_index;
        }
        SamplerState sampler = SamplerDescriptorHeap[sampler_index];

        float4 albedo_sample = albedo.Sample(sampler, varyings.uv);
        clip(albedo_sample.a - 0.5);

        color = albedo_sample.rgb;
    }

    if (false && hasValidDescriptor(material.normal_texture_index)) {
        Texture2D normal = ResourceDescriptorHeap[material.normal_texture_index];

        uint sampler_index = material.normal_sampler_index;
        if (!hasValidDescriptor(sampler_index)) {
            sampler_index = g_frame.linear_repeat_sampler_index;
        }
        SamplerState sampler = SamplerDescriptorHeap[sampler_index];

        float2 normal_sample = normal.Sample(sampler, varyings.uv).xy;
        float3 tangent_normal = 0;
        tangent_normal.xy = normal_sample * 2.0 - 1.0;
        tangent_normal.z = sqrt(1.0 - saturate(dot(tangent_normal, tangent_normal)));

        color = tangent_normal * 0.5 + 0.5;
    }

    return float4(color, 1.0f);
}