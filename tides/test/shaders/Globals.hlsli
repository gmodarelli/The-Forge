#ifndef _GLOBALS_HLSLI
#define _GLOBALS_HLSLI

#include "Defines.hlsli"

struct Frame
{
    float4x4 view;
    float4x4 projection;
    float4x4 view_proj;
    // TODO: Add inverted view, projection and view_projection
    float time;
    uint transform_buffer_index;
    uint vertex_buffer_index;
};

struct Transform
{
    // TODO: Change this to float4x3
    float4x4 world;
};

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    Frame g_frame;
};

#endif // _GLOBALS_HLSLI