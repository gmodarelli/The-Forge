#include <stdio.h>
#include <stdint.h>
#include <assert.h>

#define STB_DS_IMPLEMENTATION
#include "../../../Common_3/Utilities/Math/BStringHashMap.h"

#define EXTERNAL_RENDERER_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalRendererConfig.h"
#include "../../../Common_3/Graphics/Interfaces/IGraphics.h"

// TODO: Implement the following interfaces
// IOperatingSystem.h

#define FRAMES_IN_FLIGHT_COUNT 2

Renderer* g_renderer;
Queue* g_graphicsQueue;
Semaphore* g_imageAcquireSemaphore;
CmdPool* g_cmdPools[FRAMES_IN_FLIGHT_COUNT] = { NULL };
Cmd* g_cmds[FRAMES_IN_FLIGHT_COUNT] = { NULL };
Fence* g_fences[FRAMES_IN_FLIGHT_COUNT] = { NULL };
Semaphore* g_semaphores[FRAMES_IN_FLIGHT_COUNT] = { NULL };

void initializeCommandPools()
{
    assert(g_renderer);
    assert(g_graphicsQueue);

    CmdPoolDesc poolDesc = {};
    poolDesc.mTransient = false;
    poolDesc.pQueue = g_graphicsQueue;

    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        initCmdPool(g_renderer, &poolDesc, &g_cmdPools[i]);
        CmdDesc cmdDesc = {};
        cmdDesc.pPool = g_cmdPools[i];
#if defined(ENABLE_GRAPHICS_DEBUG_ANNOTATION)
        static char buffer[128];
        snprintf(buffer, sizeof(buffer), "Pool %u Cmd %u", i, 0);
        cmdDesc.pName = buffer;
#endif

        initCmd(g_renderer, &cmdDesc, &g_cmds[i]);
        initFence(g_renderer, &g_fences[i]);
        initSemaphore(g_renderer, &g_semaphores[i]);
    }
}

void exitCommandPools()
{
    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        exitCmd(g_renderer, g_cmds[i]);
        exitSemaphore(g_renderer, g_semaphores[i]);
        exitFence(g_renderer, g_fences[i]);
        exitCmdPool(g_renderer, g_cmdPools[i]);

        g_cmds[i] = NULL;
        g_semaphores[i] = NULL;
        g_fences[i] = NULL;
        g_cmdPools[i] = NULL;
    }
}

int main(int argc, char** argv)
{
	printf("Sandbox\n");

    // Initialize Renderer
    {
        RendererDesc desc = RendererDesc{};
        memset((void*)&desc, 0, sizeof(RendererDesc));
        desc.mShaderTarget = ::SHADER_TARGET_6_4;
        initGPUConfiguration(desc.pExtendedSettings);

        initRenderer("Sandbox", &desc, &g_renderer);
        assert(g_renderer);
        setupGPUConfigurationPlatformParameters(g_renderer, desc.pExtendedSettings);
    }

    // Initialize Graphics Queue
    {
        QueueDesc queueDesc = {};
        queueDesc.mType = QUEUE_TYPE_GRAPHICS;
        queueDesc.mFlag = QUEUE_FLAG_NONE;
        initQueue(g_renderer, &queueDesc, &g_graphicsQueue);
    }

    initializeCommandPools();
    
    // Initialize Swapchain Semaphore
    initSemaphore(g_renderer, &g_imageAcquireSemaphore);

    exitSemaphore(g_renderer, g_imageAcquireSemaphore);
    exitCommandPools();
    exitQueue(g_renderer, g_graphicsQueue);
    exitRenderer(g_renderer);
	return 0;
}

// IOperatingSystem.h implementation
void requestReset(const ResetDesc* pResetDesc)
{
    (void)pResetDesc;
}