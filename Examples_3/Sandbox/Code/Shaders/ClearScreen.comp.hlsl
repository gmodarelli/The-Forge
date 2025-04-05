#include "ShaderGlobals.h"

RWTexture2D<float4> g_output : register(u1, SPACE_PerDraw);

[RootSignature(ComputeRootSignature)]
[numthreads(8, 8, 1)]
void main( uint3 DTid : SV_DispatchThreadID )
{
    uint width;
    uint height;
    g_output.GetDimensions(width, height);
    
    if (DTid.x < width && DTid.y < height)
    {
        g_output[DTid.xy] = float4(DTid.x / float(width), DTid.y / float(height), 0.0f, 1.0f);
    }
}
