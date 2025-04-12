#pragma once

#include <Shaders/ShaderGlobals.h>
#include <Graphics/Interfaces/IGraphics.h>

struct SRT_ClearScreenShaderData
{
	struct PerFrame
	{
        const Descriptor g_CB0 =
        {
#if defined IF_VALIDATE_DESCRIPTOR
            "g_CB0",
            ROOT_PARAM_PerFrame,
#endif
            DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, 0
        };

        const Descriptor g_output =
		{
#if defined IF_VALIDATE_DESCRIPTOR
			"g_output", ROOT_PARAM_PerFrame,
#endif
			DESCRIPTOR_TYPE_RW_TEXTURE, 1, 1
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

struct SRT_BlitShaderData
{
    struct Persistent
    {
        const ::Descriptor g_linear_repeat_sampler = {
#if defined IF_VALIDATE_DESCRIPTOR
            "g_linear_repeat_sampler", ROOT_PARAM_Persistent_SAMPLER,
#endif
            ::DESCRIPTOR_TYPE_SAMPLER, 1, 0
        };
    }* persistent;

    static const ::Descriptor* persistent_ptr()
    {
        if (!sizeof(Persistent))
        {
            return 0;
        }

        static Persistent layout = {};
        ::Descriptor*     desc = (::Descriptor*)((uint64_t)&layout);
        return &desc[0];
    }

    struct PerFrame
    {
        const Descriptor g_CB0 = {
#if defined IF_VALIDATE_DESCRIPTOR
            "g_CB0", ROOT_PARAM_PerFrame,
#endif
            DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, 0
        };

        const Descriptor g_source = {
#if defined IF_VALIDATE_DESCRIPTOR
            "g_source", ROOT_PARAM_PerFrame,
#endif
            DESCRIPTOR_TYPE_TEXTURE, 1, 1
        };
    }* per_frame;

    static const Descriptor* per_frame_ptr()
    {
        if (!sizeof(PerFrame))
        {
            return 0;
        }

        static PerFrame layout = {};
        Descriptor*     desc = (Descriptor*)((uint64_t)&layout);
        return &desc[0];
    }
};