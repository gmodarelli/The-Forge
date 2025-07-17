#include "Globals.hlsli"

struct PassParams
{
    uint visible_meshlets_buffer_index;
    uint3 _pad0;
};

cbuffer g_PassParams : register(b1, SPACE_PerFrame)
{
    PassParams g_pass_params;
};

Texture2D<uint> g_visibilityBuffer : register(t0, SPACE_Persistent);
RWTexture2D<float4> g_outputBuffer : register(u1, SPACE_Persistent);

[RootSignature(ComputeRootSignature)]
[numthreads(8, 8, 1)]
void VisibilityDebugCS(uint3 thread_id : SV_DispatchThreadID)
{
    ByteAddressBuffer visible_meshlet_buffer = ResourceDescriptorHeap[g_pass_params.visible_meshlets_buffer_index];

    uint2 texel = thread_id.xy;
    if (any(texel >= g_frame.viewport_info.xy))
    {
        return;
    }

    float2 uv_ss = ((float2)texel + 0.5f) * g_frame.viewport_info.zw;
    float3 color = 0;

    uint candidate_index, primitive_id;
    if (UnpackVisBuffer(g_visibilityBuffer[texel], candidate_index, primitive_id))
    {
        MeshletCandidate candidate = visible_meshlet_buffer.Load<MeshletCandidate>(candidate_index * sizeof(MeshletCandidate));
        uint seed = SeedThread(candidate.meshlet_index);
        color = RandomColor(seed);
    }

    g_outputBuffer[texel] = float4(color, 1);
}