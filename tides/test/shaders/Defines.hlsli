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

#endif // _DEFINES_HLSLI