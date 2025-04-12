#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <Windows.h>

//#define EXTERNAL_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalConfig.h"
//#define EXTERNAL_RENDERER_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalRendererConfig.h"

#define STB_DS_IMPLEMENTATION
#include "../../../Common_3/Utilities/Math/BStringHashMap.h"

#include "../../../Common_3/Graphics/Interfaces/IGraphicsTides.h"

// TODO: Implement the following interfaces
// IOperatingSystem.h

#include "DescriptorSets.autogen.h"

typedef struct Window Window;
struct Window
{
    HWND window;
    uint32_t width;
    uint32_t height;
    bool     should_close;
};

static Window g_window;

void window_create();
void window_destroy();

#define FRAMES_IN_FLIGHT_COUNT 2

typedef struct Gpu Gpu;
struct Gpu
{
    Renderer* renderer;
    Queue* graphics_queue;
    Semaphore* image_acquired_semaphore;
    CmdPool* cmd_pools[FRAMES_IN_FLIGHT_COUNT] = { NULL };
    Cmd* cmds[FRAMES_IN_FLIGHT_COUNT] = { NULL };
    Fence* fences[FRAMES_IN_FLIGHT_COUNT] = { NULL };
    Semaphore* semaphores[FRAMES_IN_FLIGHT_COUNT] = { NULL };
    SwapChain* swapchain;

    // Render Targets
    Texture* scene_color = NULL;

    // Samplers
    Sampler* linear_repeat_sampler = NULL;
    Sampler* linear_clamp_sampler = NULL;

    // Engine Shaders
    Shader* clear_screen_cs = NULL;
    DescriptorSet* clear_screen_per_frame_descriptor_set = NULL;
    Pipeline* clear_screen_pso = NULL;
    Shader* blit_shader = NULL;
    DescriptorSet* blit_persistent_descriptor_set = NULL;
    DescriptorSet* blit_per_frame_descriptor_set = NULL;
    Pipeline* blit_pso = NULL;

    // Frame Constant Buffer
    Buffer* global_frame_constant_buffers[FRAMES_IN_FLIGHT_COUNT] = { NULL };

    bool has_started_frame = false;
    uint32_t frame_index = 0;
};

static Gpu g_gpu;

void gpu_init();
void gpu_exit();
bool gpu_on_load(ReloadDesc reload_desc);
void gpu_on_unload(ReloadDesc reload_desc);
void gpu_frame_start();
void gpu_frame_submit();

int main(int argc, char** argv)
{
	printf("Sandbox\n");

    window_create();
    gpu_init();
    if (!gpu_on_load({ RELOAD_TYPE_ALL }))
    {
        assert(false);
    }

    while (!g_window.should_close)
    {
        MSG msg;
        if (PeekMessage(&msg, g_window.window, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        // render
        gpu_frame_start();
        gpu_frame_submit();
    }

    gpu_on_unload({ RELOAD_TYPE_ALL });
    gpu_exit();
    window_destroy();
	return 0;
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT Msg, WPARAM wParam, LPARAM lParam);

void window_create()
{
    HINSTANCE   hinstance = GetModuleHandleA(NULL);

    g_window.width = 1920;
    g_window.height = 1080;

    // Register the window class.
    WNDCLASSEXA wc = { 0 };
    wc.cbSize = sizeof(wc);
    wc.style = 0;
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hinstance;
    // wc.hCursor = LoadCursorA(NULL, IDC_ARROW);
    wc.lpszClassName = "Ze Forge";

    ATOM class_atom = RegisterClassExA(&wc);
    assert(class_atom != 0);

    HWND hwnd = CreateWindowExA(0, "Ze Forge", "Ze Forge", WS_OVERLAPPEDWINDOW,

                                CW_USEDEFAULT, CW_USEDEFAULT, g_window.width, g_window.height,

                                NULL, // Parent window
                                NULL, // Menu
                                hinstance,
                                NULL // Additional application data
    );

    assert(hwnd);

    ShowWindow(hwnd, true);

    g_window.window = hwnd;
    g_window.should_close = false;
}

void window_destroy() { DestroyWindow(g_window.window); }

LRESULT CALLBACK WndProc(HWND hwnd, UINT Msg, WPARAM wParam, LPARAM lParam)
{
    switch (Msg)
    {
    case WM_CLOSE:
        g_window.should_close = true;
        return 0;

    default:
        return DefWindowProcA(hwnd, Msg, wParam, lParam);
    }
}

void command_pools_init();
void command_pools_exit();
bool swapchain_init();
void swapchain_exit();
bool render_targets_init();
void render_targets_exit();
bool default_root_signatures_init();
void default_root_signatures_exit();
void shaders_init();
void shaders_exit();
void descriptor_sets_init();
void descriptor_sets_prepare();
void descriptor_sets_exit();
void pipelines_init();
void pipelines_exit();

void gpu_init()
{
    g_gpu = {};

    // Initialize Renderer
    {
        RendererDesc desc = RendererDesc{};
        memset((void*)&desc, 0, sizeof(RendererDesc));
        desc.mShaderTarget = ::SHADER_TARGET_6_4;
        initGPUConfiguration(desc.pExtendedSettings);

        initRenderer("Sandbox", &desc, &g_gpu.renderer);
        assert(g_gpu.renderer);
        setupGPUConfigurationPlatformParameters(g_gpu.renderer, desc.pExtendedSettings);
    }

    // Initialize Graphics Queue
    {
        QueueDesc queueDesc = {};
        queueDesc.mType = QUEUE_TYPE_GRAPHICS;
        queueDesc.mFlag = QUEUE_FLAG_NONE;
        initQueue(g_gpu.renderer, &queueDesc, &g_gpu.graphics_queue);
    }

    command_pools_init();

    initSemaphore(g_gpu.renderer, &g_gpu.image_acquired_semaphore);

    default_root_signatures_init();

    // Static Samplers
    {
        SamplerDesc sampler_desc = {
            FILTER_LINEAR,
            FILTER_LINEAR,
            MIPMAP_MODE_LINEAR,
            ADDRESS_MODE_REPEAT,
            ADDRESS_MODE_REPEAT,
            ADDRESS_MODE_REPEAT,
        };
        addSampler(g_gpu.renderer, &sampler_desc, &g_gpu.linear_repeat_sampler);

        sampler_desc.mAddressU = ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressV = ADDRESS_MODE_CLAMP_TO_EDGE;
        sampler_desc.mAddressW = ADDRESS_MODE_CLAMP_TO_EDGE;
        addSampler(g_gpu.renderer, &sampler_desc, &g_gpu.linear_clamp_sampler);
    }

    // Global Frame Constant Buffers
    {
        BufferDesc buffer_desc = {};
        buffer_desc.mDescriptors = DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        buffer_desc.mMemoryUsage = RESOURCE_MEMORY_USAGE_CPU_TO_GPU;
        buffer_desc.mFlags = BUFFER_CREATION_FLAG_PERSISTENT_MAP_BIT;
        buffer_desc.pName = "Global Frame Buffer";
        buffer_desc.mSize = sizeof(Frame);

        for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
        {
            addBufferEx(g_gpu.renderer, &buffer_desc, false, &g_gpu.global_frame_constant_buffers[i]);
        }
    }
}

void gpu_exit()
{
    removeSampler(g_gpu.renderer, g_gpu.linear_clamp_sampler);
    removeSampler(g_gpu.renderer, g_gpu.linear_repeat_sampler);
    
    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        removeBufferEx(g_gpu.renderer, g_gpu.global_frame_constant_buffers[i]);
    }

    default_root_signatures_exit();

    exitSemaphore(g_gpu.renderer, g_gpu.image_acquired_semaphore);
    command_pools_exit();
    exitQueue(g_gpu.renderer, g_gpu.graphics_queue);
    exitRenderer(g_gpu.renderer);
}

bool gpu_on_load(ReloadDesc reload_desc)
{
    assert(g_gpu.renderer);

    if (reload_desc.mType & RELOAD_TYPE_SHADER)
    {
        shaders_init();
        descriptor_sets_init();
    }

    if (reload_desc.mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
    {
        if (!swapchain_init())
        {
            return false;
        }

        if (!render_targets_init())
        {
            return false;
        }
    }

    if (reload_desc.mType & (RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
    {
        pipelines_init();
    }

    descriptor_sets_prepare();

    return true;
}

void gpu_on_unload(ReloadDesc reload_desc)
{
    assert(g_gpu.renderer);

    waitQueueIdle(g_gpu.graphics_queue);
    
    if (reload_desc.mType & (RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
    {
        pipelines_exit();
    }

    if (reload_desc.mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
    {
        render_targets_exit();
        swapchain_exit();
    }

    if (reload_desc.mType & RELOAD_TYPE_SHADER)
    {
        descriptor_sets_exit();
        shaders_exit();
    }
}

void gpu_frame_start()
{
    assert(!g_gpu.has_started_frame);
    g_gpu.has_started_frame = true;
        
    Fence*      frame_fence = g_gpu.fences[g_gpu.frame_index];
    FenceStatus fence_status;
    getFenceStatus(g_gpu.renderer, frame_fence, &fence_status);
    if (fence_status == FENCE_STATUS_INCOMPLETE)
    {
        waitForFences(g_gpu.renderer, 1, &frame_fence);
    }

    CmdPool* cmd_pool = g_gpu.cmd_pools[g_gpu.frame_index];
    resetCmdPool(g_gpu.renderer, cmd_pool);
    Cmd* cmd = g_gpu.cmds[g_gpu.frame_index];

    beginCmd(cmd);

    // Update global frame data
    {
        Frame frame_data = {};
        frame_data.time = 0.5f;

        // TODO: Move to a dedicated update buffer function
        Buffer* buffer = g_gpu.global_frame_constant_buffers[g_gpu.frame_index];
        uint64_t copy_size = sizeof(frame_data);
        assert(copy_size <= buffer->mSize);
        memcpy(buffer->pCpuMappedAddress, &frame_data, sizeof(frame_data));
    }

    TextureBarrier texture_barriers[] = {
        { g_gpu.scene_color, RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_UNORDERED_ACCESS },
    };
    cmdResourceBarrier(cmd, 0, NULL, 1, texture_barriers, 0, NULL);

    cmdBindPipeline(cmd, g_gpu.clear_screen_pso);
    cmdBindDescriptorSet(cmd, g_gpu.frame_index, g_gpu.clear_screen_per_frame_descriptor_set);
    cmdDispatch(cmd, g_gpu.scene_color->mWidth / 8, g_gpu.scene_color->mHeight / 8, 1);

    texture_barriers[0].mCurrentState = RESOURCE_STATE_UNORDERED_ACCESS;
    texture_barriers[0].mNewState = RESOURCE_STATE_SHADER_RESOURCE;
    cmdResourceBarrier(cmd, 0, NULL, 1, texture_barriers, 0, NULL);
}

void gpu_frame_submit()
{
    assert(g_gpu.has_started_frame);

    uint32_t swapchain_image_index;
    acquireNextImage(g_gpu.renderer, g_gpu.swapchain, g_gpu.image_acquired_semaphore, NULL, &swapchain_image_index);
    RenderTarget* swapchain_buffer = g_gpu.swapchain->ppRenderTargets[swapchain_image_index];

    Cmd* cmd = g_gpu.cmds[g_gpu.frame_index];

    RenderTargetBarrier render_target_barriers[] = {
        { swapchain_buffer, RESOURCE_STATE_PRESENT, RESOURCE_STATE_RENDER_TARGET },
    };
    cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, render_target_barriers);

    BindRenderTargetsDesc bind_render_targets_desc = {};
    bind_render_targets_desc.mRenderTargetCount = 1;
    bind_render_targets_desc.mRenderTargets[0] = {};
    bind_render_targets_desc.mRenderTargets[0].pRenderTarget = swapchain_buffer;
    bind_render_targets_desc.mRenderTargets[0].mLoadAction = LOAD_ACTION_CLEAR;
    cmdBindRenderTargets(cmd, &bind_render_targets_desc);

    cmdSetViewport(cmd, 0.0f, 0.0f, (float)swapchain_buffer->mWidth, (float)swapchain_buffer->mHeight, 0.0f, 1.0f);
    cmdSetScissor(cmd, 0, 0, swapchain_buffer->mWidth, swapchain_buffer->mHeight);

    cmdBindPipeline(cmd, g_gpu.blit_pso);
    cmdBindDescriptorSet(cmd, 0, g_gpu.blit_persistent_descriptor_set);
    cmdBindDescriptorSet(cmd, g_gpu.frame_index, g_gpu.blit_per_frame_descriptor_set);
    cmdDraw(cmd, 3, 0);

    render_target_barriers[0].mCurrentState = RESOURCE_STATE_RENDER_TARGET;
    render_target_barriers[0].mNewState = RESOURCE_STATE_PRESENT;
    cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, render_target_barriers);

    endCmd(cmd);

    Semaphore* wait_semaphores[1] = { g_gpu.image_acquired_semaphore };
    Semaphore* signal_semaphores[1] = { g_gpu.semaphores[g_gpu.frame_index] };

    QueueSubmitDesc submit_desc = {};
    submit_desc.mCmdCount = 1;
    submit_desc.ppCmds = &cmd;
    submit_desc.mSignalSemaphoreCount = 1;
    submit_desc.ppSignalSemaphores = signal_semaphores;
    submit_desc.mWaitSemaphoreCount = 1;
    submit_desc.ppWaitSemaphores = wait_semaphores;
    submit_desc.pSignalFence = g_gpu.fences[g_gpu.frame_index];
    queueSubmit(g_gpu.graphics_queue, &submit_desc);

    wait_semaphores[0] = { g_gpu.semaphores[g_gpu.frame_index] };

    QueuePresentDesc present_desc = {};
    present_desc.mIndex = (uint8_t)swapchain_image_index;
    present_desc.pSwapChain = g_gpu.swapchain;
    present_desc.mWaitSemaphoreCount = 1;
    present_desc.ppWaitSemaphores = wait_semaphores;
    present_desc.mSubmitDone = true;
    queuePresent(g_gpu.graphics_queue, &present_desc);

    g_gpu.frame_index += 1;
    g_gpu.frame_index %= FRAMES_IN_FLIGHT_COUNT;
    g_gpu.has_started_frame = false;
}

void command_pools_init()
{
    assert(g_gpu.renderer);
    assert(g_gpu.graphics_queue);

    CmdPoolDesc poolDesc = {};
    poolDesc.mTransient = false;
    poolDesc.pQueue = g_gpu.graphics_queue;

    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        initCmdPool(g_gpu.renderer, &poolDesc, &g_gpu.cmd_pools[i]);
        CmdDesc cmdDesc = {};
        cmdDesc.pPool = g_gpu.cmd_pools[i];
#if defined(ENABLE_GRAPHICS_DEBUG_ANNOTATION)
        static char buffer[128];
        snprintf(buffer, sizeof(buffer), "Pool %u Cmd %u", i, 0);
        cmdDesc.pName = buffer;
#endif

        initCmd(g_gpu.renderer, &cmdDesc, &g_gpu.cmds[i]);
        initFence(g_gpu.renderer, &g_gpu.fences[i]);
        initSemaphore(g_gpu.renderer, &g_gpu.semaphores[i]);
    }
}

void command_pools_exit()
{
    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        exitCmd(g_gpu.renderer, g_gpu.cmds[i]);
        exitSemaphore(g_gpu.renderer, g_gpu.semaphores[i]);
        exitFence(g_gpu.renderer, g_gpu.fences[i]);
        exitCmdPool(g_gpu.renderer, g_gpu.cmd_pools[i]);

        g_gpu.cmds[i] = NULL;
        g_gpu.semaphores[i] = NULL;
        g_gpu.fences[i] = NULL;
        g_gpu.cmd_pools[i] = NULL;
    }
}

bool swapchain_init()
{
    WindowHandle window_handle = { WINDOW_HANDLE_TYPE_WIN32, g_window.window };
    RECT         rect;
    if (!GetWindowRect(g_window.window, &rect))
    {
        assert(false);
    }

    uint32_t width = rect.right - rect.left;
    uint32_t height = rect.bottom - rect.top;

    SwapChainDesc desc = {};
    desc.mWindowHandle = window_handle;
    desc.mPresentQueueCount = 1;
    desc.ppPresentQueues = &g_gpu.graphics_queue;
    desc.mWidth = width;
    desc.mHeight = height;
    desc.mImageCount = ::getRecommendedSwapchainImageCount(g_gpu.renderer, &window_handle);
    desc.mColorFormat = ::getSupportedSwapchainFormat(g_gpu.renderer, &desc, ::COLOR_SPACE_SDR_SRGB);
    desc.mColorSpace = ::COLOR_SPACE_SDR_SRGB;
    desc.mEnableVsync = true;
    desc.mFlags = ::SWAP_CHAIN_CREATION_FLAG_NONE;
    addSwapChain(g_gpu.renderer, &desc, &g_gpu.swapchain);

    return g_gpu.swapchain != NULL;
}

void swapchain_exit() { removeSwapChain(g_gpu.renderer, g_gpu.swapchain); }

bool render_targets_init()
{
    {
        TextureDesc desc = {};
        desc.mWidth = g_gpu.swapchain->ppRenderTargets[0]->mWidth;
        desc.mHeight = g_gpu.swapchain->ppRenderTargets[0]->mHeight;
        desc.mDepth = 1;
        desc.mArraySize = 1;
        desc.mMipLevels = 1;
        desc.mClearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
        desc.mFormat = TinyImageFormat_R8G8B8A8_SRGB;
        desc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
        desc.mDescriptors = DESCRIPTOR_TYPE_TEXTURE | DESCRIPTOR_TYPE_RW_TEXTURE;
        desc.mSampleCount = SAMPLE_COUNT_1;
        desc.mSampleQuality = 0;
        desc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
        addTextureEx(g_gpu.renderer, &desc, false, &g_gpu.scene_color);

        if (!g_gpu.scene_color)
        {
            return false;
        }
    }

    return true;
}

void render_targets_exit()
{
    removeTextureEx(g_gpu.renderer, g_gpu.scene_color);
}

extern "C" void initRootSignatureImpl(Renderer*, const void*, uint32_t, ID3D12RootSignature**);
extern "C" void exitRootSignatureImpl(Renderer*, ID3D12RootSignature*);

bool load_root_signature(const char* path, ID3D12RootSignature** root_signature);

bool default_root_signatures_init() 
{
    if (!load_root_signature("shaders/DefaultRootSignature.rs", &g_gpu.renderer->mDx.pGraphicsRootSignature))
    {
        return false;
    }

    if (!load_root_signature("shaders/ComputeRootSignature.rs", &g_gpu.renderer->mDx.pComputeRootSignature))
    {
        return false;
    }

    return true;
}

void default_root_signatures_exit()
{
    exitRootSignatureImpl(g_gpu.renderer, g_gpu.renderer->mDx.pGraphicsRootSignature);
    exitRootSignatureImpl(g_gpu.renderer, g_gpu.renderer->mDx.pComputeRootSignature);
}

bool load_root_signature(const char* path, ID3D12RootSignature** root_signature)
{
    FileStream binaryFS = {};
    const bool result = fsOpenStreamFromPath(RD_SHADER_BINARIES, path, FM_READ, &binaryFS);
    assert(result);
    ssize_t size = fsGetStreamFileSize(&binaryFS);
    assert(size > 0);

    void* bytecode = tf_malloc_internal(size, "", 0, "");
    assert(bytecode);
    memset(bytecode, 0, size);
    fsReadFromStream(&binaryFS, bytecode, size);

    initRootSignatureImpl(g_gpu.renderer, bytecode, (uint32_t)size, root_signature);

    tf_free(bytecode);

    fsCloseStream(&binaryFS);

    return true;
}

typedef struct ShaderStageLoadDesc ShaderStageLoadDesc;
struct ShaderStageLoadDesc
{
    const char* path;
    const char* entry;
};

typedef struct ShaderLoadDesc ShaderLoadDesc;
struct ShaderLoadDesc
{
    ShaderStageLoadDesc vert;
    ShaderStageLoadDesc frag;
    ShaderStageLoadDesc comp;
};

void shader_load(const ShaderLoadDesc* shader_load_desc, Shader** out_shader);
void shader_stage_load(const ShaderStageLoadDesc* shader_load_desc, BinaryShaderStageDesc* binary_shader_stage_desc);

void shaders_init()
{
    {
        ShaderLoadDesc shader_load_desc = {};
        shader_load_desc.comp.entry = "main";
        shader_load_desc.comp.path = "shaders/ClearScreen.comp";

        shader_load(&shader_load_desc, &g_gpu.clear_screen_cs);
    }

    {
        ShaderLoadDesc shader_load_desc = {};
        shader_load_desc.vert.entry = "main";
        shader_load_desc.vert.path = "shaders/Blit.vert";
        shader_load_desc.frag.entry = "main";
        shader_load_desc.frag.path = "shaders/Blit.frag";

        shader_load(&shader_load_desc, &g_gpu.blit_shader);
    }
}

void shaders_exit()
{
    removeShader(g_gpu.renderer, g_gpu.clear_screen_cs);
    removeShader(g_gpu.renderer, g_gpu.blit_shader);
}

void descriptor_sets_init()
{
    // Clear Screen
    {
        DescriptorSetDesc desc = {};
        desc.mIndex = ROOT_PARAM_PerFrame;
        desc.mMaxSets = FRAMES_IN_FLIGHT_COUNT;
        desc.mNodeIndex = 0;
        desc.mDescriptorCount = 2;
        desc.pDescriptors = SRT_ClearScreenShaderData::per_frame_ptr();
        addDescriptorSet(g_gpu.renderer, &desc, &g_gpu.clear_screen_per_frame_descriptor_set);
    }

    // Blit
    {
        DescriptorSetDesc desc = {};
        desc.mIndex = ROOT_PARAM_Persistent_SAMPLER;
        desc.mMaxSets = 1;
        desc.mNodeIndex = 0;
        desc.mDescriptorCount = 1;
        desc.pDescriptors = SRT_BlitShaderData::persistent_ptr();
        addDescriptorSet(g_gpu.renderer, &desc, &g_gpu.blit_persistent_descriptor_set);

        desc.mIndex = ROOT_PARAM_PerFrame;
        desc.mMaxSets = FRAMES_IN_FLIGHT_COUNT;
        desc.mNodeIndex = 0;
        desc.mDescriptorCount = 2;
        desc.pDescriptors = SRT_BlitShaderData::per_frame_ptr();
        addDescriptorSet(g_gpu.renderer, &desc, &g_gpu.blit_per_frame_descriptor_set);
    }
}

void descriptor_sets_prepare()
{
    // Per Frame
    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        // Clear screen
        {
            DescriptorData params[2] = {};
            params[0].mIndex = (offsetof(SRT_ClearScreenShaderData::PerFrame, g_CB0)) / sizeof(Descriptor);
            params[0].ppBuffers = &g_gpu.global_frame_constant_buffers[i];
            params[1].mIndex = (offsetof(SRT_ClearScreenShaderData::PerFrame, g_output)) / sizeof(Descriptor);
            params[1].ppTextures = &g_gpu.scene_color;
            updateDescriptorSet(g_gpu.renderer, i, g_gpu.clear_screen_per_frame_descriptor_set, 2, params);
        }

        // Blit
        {
            DescriptorData params[2] = {};
            params[0].mIndex = (offsetof(SRT_BlitShaderData::PerFrame, g_CB0)) / sizeof(Descriptor);
            params[0].ppBuffers = &g_gpu.global_frame_constant_buffers[i];
            params[1].mIndex = (offsetof(SRT_BlitShaderData::PerFrame, g_source)) / sizeof(Descriptor);
            params[1].ppTextures = &g_gpu.scene_color;
            updateDescriptorSet(g_gpu.renderer, i, g_gpu.blit_per_frame_descriptor_set, 2, params);
        }
    }

    // Persisten
    // Blit
    {
        DescriptorData params[1] = {};
        params[0].mIndex = (offsetof(SRT_BlitShaderData::Persistent, g_linear_repeat_sampler)) / sizeof(Descriptor);
        params[0].ppSamplers = &g_gpu.linear_repeat_sampler;
        updateDescriptorSet(g_gpu.renderer, 0, g_gpu.blit_persistent_descriptor_set, 1, params);
    }
}

void descriptor_sets_exit()
{
    // Clear screen
    removeDescriptorSet(g_gpu.renderer, g_gpu.clear_screen_per_frame_descriptor_set);
    // Blit
    removeDescriptorSet(g_gpu.renderer, g_gpu.blit_per_frame_descriptor_set);
    removeDescriptorSet(g_gpu.renderer, g_gpu.blit_persistent_descriptor_set);
}

void pipelines_init()
{
    // Clear screen
    {
        PipelineDesc desc = {};
        desc.mType = PIPELINE_TYPE_COMPUTE;
        ComputePipelineDesc* pipeline = &desc.mComputeDesc;
        pipeline->pShaderProgram = g_gpu.clear_screen_cs;
        addPipeline(g_gpu.renderer, &desc, &g_gpu.clear_screen_pso);
    }

    // Blit
    {
        PipelineDesc desc = {};
        desc.mType = PIPELINE_TYPE_GRAPHICS;
        GraphicsPipelineDesc* pipeline = &desc.mGraphicsDesc;

        RasterizerStateDesc raster_state_desc = {};
        raster_state_desc.mCullMode = CULL_MODE_NONE;

        DepthStateDesc depth_state_desc = {};
        depth_state_desc.mDepthTest = false;
        depth_state_desc.mDepthWrite = false;

        pipeline->mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
        pipeline->mRenderTargetCount = 1;
        pipeline->pDepthState = &depth_state_desc;
        pipeline->pColorFormats = &g_gpu.swapchain->ppRenderTargets[0]->mFormat;
        pipeline->mSampleCount = g_gpu.swapchain->ppRenderTargets[0]->mSampleCount;
        pipeline->mSampleQuality = g_gpu.swapchain->ppRenderTargets[0]->mSampleQuality;
        pipeline->pShaderProgram = g_gpu.blit_shader;
        pipeline->pVertexLayout = NULL;
        pipeline->pRasterizerState = &raster_state_desc;
        pipeline->mVRFoveatedRendering = false;
        addPipeline(g_gpu.renderer, &desc, &g_gpu.blit_pso);
    }
}

void pipelines_exit()
{
    removePipeline(g_gpu.renderer, g_gpu.clear_screen_pso);
    removePipeline(g_gpu.renderer, g_gpu.blit_pso);
}

void shader_load(const ShaderLoadDesc* shader_load_desc, Shader** out_shader)
{
    BinaryShaderDesc binary_shader_desc = {};

    if (shader_load_desc->vert.path)
    {
        shader_stage_load(&shader_load_desc->vert, &binary_shader_desc.mVert);
        binary_shader_desc.mStages |= SHADER_STAGE_VERT;
    }

    if (shader_load_desc->frag.path)
    {
        shader_stage_load(&shader_load_desc->frag, &binary_shader_desc.mFrag);
        binary_shader_desc.mStages |= SHADER_STAGE_FRAG;
    }

    if (shader_load_desc->comp.path)
    {
        shader_stage_load(&shader_load_desc->comp, &binary_shader_desc.mComp);
        binary_shader_desc.mStages |= SHADER_STAGE_COMP;
    }

    addShaderBinary(g_gpu.renderer, &binary_shader_desc, out_shader);

    if (shader_load_desc->vert.path)
    {
        tf_free(binary_shader_desc.mVert.pByteCode);
    }

    if (shader_load_desc->frag.path)
    {
        tf_free(binary_shader_desc.mFrag.pByteCode);
    }

    if (shader_load_desc->comp.path)
    {
        tf_free(binary_shader_desc.mComp.pByteCode);
    }
}

void shader_stage_load(const ShaderStageLoadDesc* shader_load_desc, BinaryShaderStageDesc* binary_shader_stage_desc)
{
    FileStream binary_fs = {};
    const bool result = fsOpenStreamFromPath(RD_SHADER_BINARIES, shader_load_desc->path, FM_READ, &binary_fs);
    assert(result);
    ssize_t size = fsGetStreamFileSize(&binary_fs);
    assert(size > 0);

    binary_shader_stage_desc->pByteCode = tf_malloc_internal(size, "", 0, "");
    assert(binary_shader_stage_desc->pByteCode);
    memset(binary_shader_stage_desc->pByteCode, 0, size);
    fsReadFromStream(&binary_fs, binary_shader_stage_desc->pByteCode, size);
    binary_shader_stage_desc->mByteCodeSize = (uint32_t)size;
    binary_shader_stage_desc->pEntryPoint = shader_load_desc->entry;
    binary_shader_stage_desc->pName = shader_load_desc->path;

    fsCloseStream(&binary_fs);
}
