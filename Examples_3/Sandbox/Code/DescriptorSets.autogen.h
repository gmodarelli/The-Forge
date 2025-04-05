#pragma once

#include <Shaders/ShaderGlobals.h>
#include <Graphics/Interfaces/IGraphics.h>

struct SRT_ClearScreenShaderData
{
	struct PerFrame
	{
        const Descriptor g_output =
		{
#if defined IF_VALIDATE_DESCRIPTOR
			"g_output", ROOT_PARAM_PerFrame,
#endif
			DESCRIPTOR_TYPE_RW_TEXTURE, 1, 0
		};
	}*per_frame;

	static const Descriptor* per_frame_ptr()
	{
		if (!sizeof(PerFrame))
		{
			return 0;
		}

		static PerFrame layout = {};
		Descriptor* desc = (Descriptor*)((uint64_t)&layout);
		return &desc[0];
	}
};