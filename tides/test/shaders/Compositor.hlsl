#include "Globals.hlsli"

Texture2D<float4> g_source : register(t1, SPACE_PerFrame);
Texture2D<float4> g_overlay : register(t2, SPACE_PerFrame);

struct Varyings
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[RootSignature(DefaultRootSignature)]
Varyings FullscreenTriangleVS(uint VertexID : SV_VertexID)
{
    Varyings output = (Varyings) 0;
    output.uv = float2((VertexID << 1) & 2, VertexID & 2);
    output.position = float4(output.uv * float2(2, -2) + float2(-1, 1), 0, 1);

    return output;
}

[RootSignature(DefaultRootSignature)]
float4 CompositorPS(Varyings varyings) : SV_Target0
{
    SamplerState sampler = SamplerDescriptorHeap[g_frame.linear_clamp_sampler_index];
    float3 color = g_source.Sample(sampler, varyings.uv).rgb;
    float4 overlay = g_overlay.Sample(sampler, varyings.uv);

    return float4(lerp(color, overlay.rgb, overlay.a), 1.0f);
}