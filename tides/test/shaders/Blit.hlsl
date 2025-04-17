#include "ShaderInterop.h"
#include "Globals.hlsli"

SamplerState g_linear_repeat_sampler : register(s0, SPACE_Persistent);
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
    float3 color = g_source.Sample(g_linear_repeat_sampler, varyings.UV).rgb;
    return float4(color, 1.0);
}