#include "Globals.hlsli"

struct Varyings
{
    float4 position : SV_Position;
    float3 color : COLOR;
};

[RootSignature(DefaultRootSignature)]
Varyings ObjectVS(uint VertexID : SV_VertexID)
{
    Varyings output = (Varyings) 0;

    ByteAddressBuffer vertex_buffer = ResourceDescriptorHeap[g_frame.vertex_buffer_index];
    float3 position = vertex_buffer.Load<float3>(VertexID * sizeof(float3));

    float4x4 view_proj = mul(g_frame.view, g_frame.projection);
    output.position = mul(view_proj, float4(position, 1));
    float t = sin(g_frame.time) * 0.5 + 0.5;
    output.color = float3(t, t, t);

    return output;
}

[RootSignature(DefaultRootSignature)]
float4 ObjectPS(Varyings varyings) : SV_Target0
{
    return float4(varyings.color, 1.0f);
}