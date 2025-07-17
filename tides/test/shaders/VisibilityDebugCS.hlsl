#include "Globals.hlsli"

uint Flatten2D(uint2 index, uint dimensionsX)
{
	return index.x + index.y * dimensionsX;
}

//-----------------------------------------------------------------------------------------

// Quick And Easy GPU Random Numbers In D3D11 - Nathan Reed - 2013
// http://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
// Hash Functions for GPU Rendering - Nathan Reed
// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/

uint SeedThread(uint seed)
{
#if 0
	//Wang hash to initialize the seed
	seed = (seed ^ 61) ^ (seed >> 16);
	seed *= 9;
	seed = seed ^ (seed >> 4);
	seed *= 0x27d4eb2d;
	seed = seed ^ (seed >> 15);
	return seed;
#else
  	uint state = seed * 747796405u + 2891336453u;
  	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
   	return (word >> 22u) ^ word;
#endif
}

uint SeedThread(uint2 pixel, uint2 resolution, uint frameIndex)
{
	uint rngState = Flatten2D(pixel, resolution.x) ^ SeedThread(frameIndex);
	return SeedThread(rngState);
}

uint XORShift(inout uint rng_state)
{
	// Xorshift algorithm from George Marsaglia's paper.
	rng_state ^= (rng_state << 13);
	rng_state ^= (rng_state >> 17);
	rng_state ^= (rng_state << 5);
	return rng_state;
}

float Random01(inout uint rng_state)
{
	return asfloat(0x3f800000 | XORShift(rng_state) >> 9) - 1.0;
}

uint Random(inout uint rng_state, uint minimum, uint maximum)
{
	return minimum + uint(float(maximum - minimum + 1) * Random01(rng_state));
}

float3 RandomColor(inout uint rng_state)
{
	return float3(Random01(rng_state), Random01(rng_state), Random01(rng_state));
}

//-----------------------------------------------------------------------------------------

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

bool UnpackVisBuffer(uint data, out uint candidateIndex, out uint primitiveID)
{
	primitiveID = data & 0x7F;
	candidateIndex = data >> 7;
	candidateIndex -= 1; // Value of 0 means 'Invalid'
	return candidateIndex != 0xFFFFFFFF;
}

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