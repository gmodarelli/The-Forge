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
};

[RootSignature(DefaultRootSignature)]
Varyings ObjectVS(VertexShaderInput input)
{
    Varyings output = (Varyings) 0;

    uint instance_index = input.instance_id + input.start_instance_location;
    ByteAddressBuffer transform_buffer = ResourceDescriptorHeap[g_frame.transform_buffer_index];
    Transform transform = transform_buffer.Load<Transform>(instance_index * sizeof(Transform));

    uint vertex_index = input.vertex_id + input.start_vertex_location;
    ByteAddressBuffer vertex_buffer = ResourceDescriptorHeap[g_frame.vertex_buffer_index];
    Vertex vertex = vertex_buffer.Load<Vertex>(vertex_index * sizeof(Vertex));

    float4x4 view_proj = mul(g_frame.view, g_frame.projection);
    float4x4 mvp = mul(view_proj, transform.world);
    output.position = mul(mvp, float4(vertex.position, 1));
    output.uv = vertex.uv;
    output.normal = vertex.normal;

    return output;
}

[RootSignature(DefaultRootSignature)]
float4 ObjectPS(Varyings varyings) : SV_Target0
{
    return float4(varyings.uv, 0.0f, 1.0f);
}