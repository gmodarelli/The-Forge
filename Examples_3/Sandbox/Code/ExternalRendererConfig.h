#pragma once


#include "../../../Common_3/Graphics/Direct3D12/Direct3D12Config.h"

// TODO: Implement these
#define VALIDATE_DESCRIPTOR(descriptor, ...)
#define IF_VALIDATE_DESCRIPTOR(...)
#define IF_VALIDATE_DESCRIPTOR_MEMBER(T, Name)

#if defined(_DEBUG)
#define ENABLE_GRAPHICS_RUNTIME_CHECK
#define ENABLE_GRAPHICS_VALIDATION
#define ENABLE_GRAPHICS_DEBUG_ANNOTATION
#endif