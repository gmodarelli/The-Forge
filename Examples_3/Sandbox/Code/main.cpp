#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <Windows.h>

//#define EXTERNAL_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalConfig.h"
//#define EXTERNAL_RENDERER_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalRendererConfig.h"

#define STB_DS_IMPLEMENTATION
#include "../../../Common_3/Utilities/Math/BStringHashMap.h"

#include "../../../Common_3/Graphics/Interfaces/IGraphics.h"

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
    RenderTarget* scene_color = NULL;

    // Samplers
    Sampler* linear_repeat_sampler = NULL;
    Sampler* linear_clamp_sampler = NULL;

    // TODO: This should be part of a gpu_backend struct maybe, so we don't expose D3D12 resources
    ID3D12RootSignature* graphics_rs = NULL;
    ID3D12RootSignature* compute_rs = NULL;
    // TODO: All shaders here
    Shader* clear_screen_cs = NULL;

    DescriptorSet* clear_screen_descriptor_set = NULL;
};

static Gpu g_gpu;

void gpu_init();
void gpu_exit();
bool gpu_on_load(ReloadDesc reload_desc);
void gpu_on_unload(ReloadDesc reload_desc);

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
}

void gpu_exit()
{
    removeSampler(g_gpu.renderer, g_gpu.linear_clamp_sampler);
    removeSampler(g_gpu.renderer, g_gpu.linear_repeat_sampler);

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

    descriptor_sets_prepare();

    return true;
}

void gpu_on_unload(ReloadDesc reload_desc)
{
    assert(g_gpu.renderer);

    waitQueueIdle(g_gpu.graphics_queue);
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
    ::addSwapChain(g_gpu.renderer, &desc, &g_gpu.swapchain);

    return g_gpu.swapchain != NULL;
}

void swapchain_exit() { removeSwapChain(g_gpu.renderer, g_gpu.swapchain); }

bool render_targets_init()
{
    {
        RenderTargetDesc desc = {};
        desc.mWidth = g_gpu.swapchain->ppRenderTargets[0]->mWidth;
        desc.mHeight = g_gpu.swapchain->ppRenderTargets[0]->mHeight;
        desc.mDepth = 1;
        desc.mArraySize = 1;
        desc.mClearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
        desc.mFormat = TinyImageFormat_R8G8B8A8_SRGB;
        desc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
        desc.mSampleCount = SAMPLE_COUNT_1;
        desc.mSampleQuality = 0;
        desc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
        addRenderTarget(g_gpu.renderer, &desc, &g_gpu.scene_color);

        if (!g_gpu.scene_color)
        {
            return false;
        }
    }

    return true;
}

void render_targets_exit()
{
    removeRenderTarget(g_gpu.renderer, g_gpu.scene_color);
}

extern "C" void initRootSignatureImpl(Renderer*, const void*, uint32_t, ID3D12RootSignature**);
extern "C" void exitRootSignatureImpl(Renderer*, ID3D12RootSignature*);

bool load_root_signature(const char* path, ID3D12RootSignature** root_signature);

bool default_root_signatures_init() 
{
    if (!load_root_signature("shaders/DefaultRootSignature.rs", &g_gpu.graphics_rs))
    {
        return false;
    }

    if (!load_root_signature("shaders/ComputeRootSignature.rs", &g_gpu.compute_rs))
    {
        return false;
    }

    return true;
}

void default_root_signatures_exit()
{
    exitRootSignatureImpl(g_gpu.renderer, g_gpu.graphics_rs);
    exitRootSignatureImpl(g_gpu.renderer, g_gpu.compute_rs);
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
}

void shaders_exit()
{
    removeShader(g_gpu.renderer, g_gpu.clear_screen_cs);
}

void descriptor_sets_init()
{
    {
        DescriptorSetDesc desc = {};
        desc.mIndex = ROOT_PARAM_PerFrame;
        desc.mMaxSets = FRAMES_IN_FLIGHT_COUNT;
        desc.mNodeIndex = 0;
        desc.mDescriptorCount = 1;
        desc.pDescriptors = SRT_ClearScreenShaderData::per_frame_ptr();
        addDescriptorSet(g_gpu.renderer, &desc, &g_gpu.clear_screen_descriptor_set);
    }
}

void descriptor_sets_prepare()
{
    for (uint32_t i = 0; i < FRAMES_IN_FLIGHT_COUNT; i++)
    {
        DescriptorData params[1] = {};
        params[0].mIndex = (offsetof(SRT_ClearScreenShaderData::PerFrame, g_output)) / sizeof(Descriptor);
        params[0].ppTextures = &g_gpu.scene_color->pTexture;
        updateDescriptorSet(g_gpu.renderer, i, g_gpu.clear_screen_descriptor_set, 1, params);
    }
}

void descriptor_sets_exit()
{
    removeDescriptorSet(g_gpu.renderer, g_gpu.clear_screen_descriptor_set);
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

// IOperatingSystem.h implementation
void requestReset(const ResetDesc* pResetDesc)
{
    (void)pResetDesc;
    assert(false);
}