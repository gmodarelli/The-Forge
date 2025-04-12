#include "ShaderGlobals.h"
#include "Globals.hlsli"

RWTexture2D<float4> g_output : register(u1, SPACE_PerFrame);

[RootSignature(ComputeRootSignature)]
[numthreads(8, 8, 1)]
void main( uint3 DTid : SV_DispatchThreadID )
{
    uint width;
    uint height;
    g_output.GetDimensions(width, height);
    
    if (DTid.x < width && DTid.y < height)
    {
        g_output[DTid.xy] = float4(DTid.x / float(width), 1.0f - DTid.y / float(height), frac(g_frame.time), 1.0f);
    }
}
