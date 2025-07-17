#ifndef _DEFINES_HLSLI
#define _DEFINES_HLSLI

#define SET_Persistent                0
#define SET_PerFrame                  1
#define SET_PerBatch                  2
#define SET_PerDraw                   3

#define SPACE_Persistent              space0
#define SPACE_PerFrame                space1
#define SPACE_PerBatch                space2
#define SPACE_PerDraw                 space3

#define DESCRIPTOR_TABLE(space)                                            \
    "DescriptorTable("                                                     \
    "SRV(t0, numDescriptors = unbounded, space = " #space ", offset = 0)," \
    "CBV(b0, numDescriptors = unbounded, space = " #space ", offset = 0)," \
    "UAV(u0, numDescriptors = unbounded, space = " #space ", offset = 0)),"

#define SAMPLER_DESCRIPTOR_TABLE(space) \
    "DescriptorTable("                  \
    "SAMPLER(s0, numDescriptors = unbounded, space = " #space ", offset = 0)),"

#define DefaultRootSignature                                                                                    \
    "RootFlags(CBV_SRV_UAV_HEAP_DIRECTLY_INDEXED | SAMPLER_HEAP_DIRECTLY_INDEXED),"                             \
    DESCRIPTOR_TABLE(3)                                                                                         \
    DESCRIPTOR_TABLE(2)                                                                                         \
    DESCRIPTOR_TABLE(1)                                                                                         \
    DESCRIPTOR_TABLE(0)                                                                                         \
    SAMPLER_DESCRIPTOR_TABLE(0)                                                                                 \
    "StaticSampler(s0, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s1, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s2, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_LINEAR_MIP_POINT,"                                                                 \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s3, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_LINEAR_MIP_POINT,"                                                                 \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s4, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s5, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s6, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_MIRROR, addressV = TEXTURE_ADDRESS_MIRROR, addressW = TEXTURE_ADDRESS_MIRROR)," \
    "StaticSampler(s7, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT, borderColor = STATIC_BORDER_COLOR_TRANSPARENT_BLACK,"                   \
    "addressU = TEXTURE_ADDRESS_BORDER, addressV = TEXTURE_ADDRESS_BORDER, addressW = TEXTURE_ADDRESS_BORDER)," \
    "StaticSampler(s8, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_MIRROR, addressV = TEXTURE_ADDRESS_MIRROR, addressW = TEXTURE_ADDRESS_MIRROR)," \
    "StaticSampler(s9, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR, borderColor = STATIC_BORDER_COLOR_TRANSPARENT_BLACK,"                  \
    "addressU = TEXTURE_ADDRESS_BORDER, addressV = TEXTURE_ADDRESS_BORDER, addressW = TEXTURE_ADDRESS_BORDER)," \
    "StaticSampler(s10, space = 100,"                                                                           \
    "filter = FILTER_ANISOTROPIC, maxAnisotropy = 8,"                                                           \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP)"

#define ComputeRootSignature                                                                                    \
    "RootFlags(CBV_SRV_UAV_HEAP_DIRECTLY_INDEXED | SAMPLER_HEAP_DIRECTLY_INDEXED),"                             \
    DESCRIPTOR_TABLE(3)                                                                                         \
    DESCRIPTOR_TABLE(2)                                                                                         \
    DESCRIPTOR_TABLE(1)                                                                                         \
    DESCRIPTOR_TABLE(0)                                                                                         \
    SAMPLER_DESCRIPTOR_TABLE(0)                                                                                 \
    "StaticSampler(s0, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s1, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s2, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_LINEAR_MIP_POINT,"                                                                 \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s3, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_LINEAR_MIP_POINT,"                                                                 \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s4, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_CLAMP, addressV = TEXTURE_ADDRESS_CLAMP, addressW = TEXTURE_ADDRESS_CLAMP),"    \
    "StaticSampler(s5, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP),"       \
    "StaticSampler(s6, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT,"                                                                        \
    "addressU = TEXTURE_ADDRESS_MIRROR, addressV = TEXTURE_ADDRESS_MIRROR, addressW = TEXTURE_ADDRESS_MIRROR)," \
    "StaticSampler(s7, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_POINT, borderColor = STATIC_BORDER_COLOR_TRANSPARENT_BLACK,"                   \
    "addressU = TEXTURE_ADDRESS_BORDER, addressV = TEXTURE_ADDRESS_BORDER, addressW = TEXTURE_ADDRESS_BORDER)," \
    "StaticSampler(s8, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR,"                                                                       \
    "addressU = TEXTURE_ADDRESS_MIRROR, addressV = TEXTURE_ADDRESS_MIRROR, addressW = TEXTURE_ADDRESS_MIRROR)," \
    "StaticSampler(s9, space = 100,"                                                                            \
    "filter = FILTER_MIN_MAG_MIP_LINEAR, borderColor = STATIC_BORDER_COLOR_TRANSPARENT_BLACK,"                  \
    "addressU = TEXTURE_ADDRESS_BORDER, addressV = TEXTURE_ADDRESS_BORDER, addressW = TEXTURE_ADDRESS_BORDER)," \
    "StaticSampler(s10, space = 100,"                                                                           \
    "filter = FILTER_ANISOTROPIC, maxAnisotropy = 8,"                                                           \
    "addressU = TEXTURE_ADDRESS_WRAP, addressV = TEXTURE_ADDRESS_WRAP, addressW = TEXTURE_ADDRESS_WRAP)"

#define k_invalid_descriptor_index 0xffffffff;

#define MESHLET_COUNT_MAX 1 << 20
#define CULL_INSTANCES_THREADS_COUNT 64
#define CULL_MESHLETS_THREADS_COUNT 64
#define MESHLET_THREADS_COUNT 32
#define MESHLET_MAX_TRIANGLES 124
#define MESHLET_MAX_VERTICES 64

/*
	Helper functions that accelerate atomic write operations between threads using wave operations.
*/

#define InterlockedAdd_WaveOps(bufferResource, elementIndex, numValues, originalValue) 			\
{																								\
	uint count = WaveActiveCountBits(true) * numValues;											\
	if(WaveIsFirstLane())																		\
		InterlockedAdd(bufferResource[elementIndex], count, originalValue);						\
	originalValue = WaveReadLaneFirst(originalValue) + WavePrefixCountBits(true);				\
}

#define InterlockedAdd_Varying_WaveOps(bufferResource, elementIndex, numValues, originalValue) 	\
{																								\
	uint count = WaveActiveSum(numValues);														\
	if(WaveIsFirstLane())																		\
		InterlockedAdd(bufferResource[elementIndex], count, originalValue);						\
	originalValue = WaveReadLaneFirst(originalValue) + WavePrefixSum(numValues);				\
}

#define InterlockedAdd_WaveOps_ByteAddressBuffer(bufferResource, elementOffset, numValues, originalValue) 			\
{																								\
	uint count = WaveActiveCountBits(true) * numValues;											\
	if(WaveIsFirstLane())																		\
		bufferResource.InterlockedAdd(elementOffset, count, originalValue);						\
	originalValue = WaveReadLaneFirst(originalValue) + WavePrefixCountBits(true);				\
}

#define InterlockedAdd_Varying_WaveOps_ByteAddressBuffer(bufferResource, elementOffset, numValues, originalValue) 	\
{																								\
	uint count = WaveActiveSum(numValues);														\
	if(WaveIsFirstLane())																		\
		bufferResource.InterlockedAdd(elementOffset, count, originalValue);						\
	originalValue = WaveReadLaneFirst(originalValue) + WavePrefixSum(numValues);				\
}

bool UnpackVisBuffer(uint data, out uint candidateIndex, out uint primitiveID)
{
	primitiveID = data & 0x7F;
	candidateIndex = data >> 7;
	candidateIndex -= 1; // Value of 0 means 'Invalid'
	return candidateIndex != 0xFFFFFFFF;
}

uint PackVisBuffer(uint candidateIndex, uint primitiveID)
{
	return primitiveID | ((candidateIndex + 1) << 7);
}

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


#endif // _DEFINES_HLSLI