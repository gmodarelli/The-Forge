#include "Globals.hlsli"
#include "Utils.hlsli"

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
    float4 position_ws : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : NORMAL;
    uint instance_index : SV_INSTANCEID;
};

struct GBufferOutput
{
    float4 gbuffer0 : SV_TARGET0;
    float4 gbuffer1 : SV_TARGET1;
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
    output.position_ws = mul(transform.world, float4(vertex.position, 1));
    output.uv = vertex.uv;
    output.normal = mul((float3x3)transform.world, vertex.normal);
    output.instance_index = instance_index;

    return output;
}

[RootSignature(DefaultRootSignature)]
GBufferOutput ObjectPS(Varyings varyings)
{
    GBufferOutput gbuffer_output = (GBufferOutput)0;

    InstanceData instance = getInstanceData(varyings.instance_index);
    MaterialData material = getMaterial(instance.material_index);

    float3 color = 0.0;
    float3 normal = varyings.normal;

    if (hasValidDescriptor(material.albedo_texture_index)) {
        Texture2D albedo = ResourceDescriptorHeap[NonUniformResourceIndex(material.albedo_texture_index)];

        uint sampler_index = material.albedo_sampler_index;
        if (!hasValidDescriptor(sampler_index)) {
            sampler_index = g_frame.linear_repeat_sampler_index;
        }
        SamplerState sampler = SamplerDescriptorHeap[NonUniformResourceIndex(sampler_index)];

        float4 albedo_sample = albedo.Sample(sampler, varyings.uv);
        clip(albedo_sample.a - 0.5);

        color = albedo_sample.rgb;
    }

    if (hasValidDescriptor(material.normal_texture_index)) {
        Texture2D normal_map = ResourceDescriptorHeap[NonUniformResourceIndex(material.normal_texture_index)];

        uint sampler_index = material.normal_sampler_index;
        if (!hasValidDescriptor(sampler_index)) {
            sampler_index = g_frame.linear_repeat_sampler_index;
        }
        SamplerState sampler = SamplerDescriptorHeap[NonUniformResourceIndex(sampler_index)];

        float2 normal_sample = normal_map.Sample(sampler, varyings.uv).xy;
        float3 tangent_normal = 0;
        tangent_normal.xy = normal_sample * 2.0 - 1.0;
        tangent_normal.z = sqrt(1.0 - saturate(dot(tangent_normal, tangent_normal)));

        const float3 view = normalize(g_frame.camera_position.xyz - varyings.position_ws.xyz);

        normal = UnpackNormals(varyings.uv, view, tangent_normal, normal);
    }

    gbuffer_output.gbuffer0 = float4(color, 1.0f);
    gbuffer_output.gbuffer1 = float4(normal * 0.5 + 0.5, 1.0f);

    return gbuffer_output;
}