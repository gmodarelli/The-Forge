#include "Globals.hlsli"

struct Vertex
{
    float3 position;
    float2 uv;
    float3 normal;
};

struct Varyings
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
};

[RootSignature(DefaultRootSignature)]
Varyings ObjectVS(uint VertexID : SV_VertexID)
{
    Varyings output = (Varyings) 0;

    ByteAddressBuffer vertex_buffer = ResourceDescriptorHeap[g_frame.vertex_buffer_index];
    Vertex vertex = vertex_buffer.Load<Vertex>(VertexID * sizeof(Vertex));

    float4x4 view_proj = mul(g_frame.view, g_frame.projection);
    output.position = mul(view_proj, float4(vertex.position, 1));
    output.uv = vertex.uv;
    output.normal = vertex.normal;

    return output;
}

[RootSignature(DefaultRootSignature)]
float4 ObjectPS(Varyings varyings) : SV_Target0
{
    return float4(varyings.uv, 0.0f, 1.0f);
}