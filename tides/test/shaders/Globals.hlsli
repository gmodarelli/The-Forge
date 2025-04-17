#ifndef _GLOBALS_HLSLI
#define _GLOBALS_HLSLI

#include "ShaderInterop.h"

cbuffer g_CBO : register(b0, SPACE_PerFrame)
{
    Frame g_frame;
};

#endif // _GLOBALS_HLSLI