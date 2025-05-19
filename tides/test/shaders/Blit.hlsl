#include "Globals.hlsli"

Texture2D<float4> g_source : register(t1, SPACE_PerFrame);

struct Varyings
{
    float4 Position : SV_Position;
    float2 UV : TEXCOORD0;
};

[RootSignature(DefaultRootSignature)]
Varyings FullscreenVertex(uint VertexID : SV_VertexID)
{
    Varyings Output = (Varyings) 0;
    Output.UV = float2((VertexID << 1) & 2, VertexID & 2);
    Output.Position = float4(Output.UV * float2(2, -2) + float2(-1, 1), 0, 1);

    return Output;
}

[RootSignature(DefaultRootSignature)]
float4 BlitFragment(Varyings varyings) : SV_Target0
{
    SamplerState sampler = SamplerDescriptorHeap[g_frame.linear_clamp_sampler_index];
    float3 color = g_source.Sample(sampler, varyings.UV).rgb;
    return float4(color, saturate(g_frame.time));
}