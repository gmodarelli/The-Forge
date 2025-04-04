/*
 * Copyright (c) 2017-2025 The Forge Interactive Inc.
 *
 * This file is part of The-Forge
 * (see https://github.com/ConfettiFX/The-Forge).
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

// Unit Test for testing wave intrinsic operations

// Interfaces
#include "../../../../Common_3/Application/Interfaces/IApp.h"
#include "../../../../Common_3/Application/Interfaces/ICameraController.h"
#include "../../../../Common_3/Application/Interfaces/IFont.h"
#include "../../../../Common_3/OS/Interfaces/IInput.h"
#include "../../../../Common_3/Application/Interfaces/IScreenshot.h"
#include "../../../../Common_3/Application/Interfaces/IUI.h"
#include "../../../../Common_3/Game/Interfaces/IScripting.h"
#include "../../../../Common_3/Graphics/Interfaces/IGraphics.h"
#include "../../../../Common_3/Resources/ResourceLoader/Interfaces/IResourceLoader.h"
#include "../../../../Common_3/Utilities/Interfaces/IFileSystem.h"
#include "../../../../Common_3/Utilities/Interfaces/ILog.h"
#include "../../../../Common_3/Utilities/Interfaces/ITime.h"

#include "../../../../Common_3/Utilities/RingBuffer.h"

// Math
#include "../../../../Common_3/Application/Interfaces/IProfiler.h"

#include "../../../../Common_3/Utilities/Math/MathTypes.h"

#include "../../../../Common_3/Utilities/Interfaces/IMemory.h"

// fsl
#include "../../../../Common_3/Graphics/FSL/defaults.h"
#include "./Shaders/FSL/Global.srt.h"

/// Demo structures
struct SceneConstantBuffer
{
    mat4   orthProjMatrix;
    float2 mousePosition;
    float2 resolution;
    float  time;
    uint   renderMode;
    uint   laneSize;
    uint   padding;
};

// #NOTE: Two sets of resources (one in flight and one being used on CPU)
const uint32_t gDataBufferCount = 2;

Renderer* pRenderer = NULL;

Queue*     pGraphicsQueue = NULL;
GpuCmdRing gGraphicsCmdRing = {};

SwapChain* pSwapChain = NULL;
Semaphore* pImageAcquiredSemaphore = NULL;

RenderTarget* pRenderTargetIntermediate = NULL;

Shader*   pShaderWave = NULL;
Pipeline* pPipelineWave = NULL;
Shader*   pShaderMagnify = NULL;
Pipeline* pPipelineMagnify = NULL;

DescriptorSet* pDescriptorSetUniforms = NULL;
DescriptorSet* pDescriptorSetTexture = NULL;

Sampler* pSamplerPointWrap = NULL;

Buffer* pUniformBuffer[gDataBufferCount] = { NULL };
Buffer* pVertexBufferTriangle = NULL;
Buffer* pVertexBufferQuad = NULL;

uint32_t gFrameIndex = 0;

SceneConstantBuffer gSceneData;
float2              gMovePosition = {};

ProfileToken gGpuProfileToken;

/// UI
UIComponent* pGui = NULL;

enum RenderMode
{
    RenderMode1,
    RenderMode2,
    RenderMode3,
    RenderMode4,
    RenderMode5,
    RenderMode6,
    RenderMode7,
    RenderMode8,
    RenderMode9,
    RenderModeCount,
};
int32_t gRenderModeToggles = 0;

const char* gTestScripts[] = {
    "Test_WaveGetLaneIndex.lua",
    "Test_WaveIsFirstLane.lua",
    "Test_WaveGetMaxActiveIndex.lua",
    "Test_WaveActiveBallot.lua",
    "Test_WaveReadLaneFirst.lua",
    "Test_WaveActiveSum.lua",
    "Test_WavePrefixSum.lua",
    "Test_QuadReadAcross.lua",
    // Test_Normal.lua is in the end so that Test_Default outputs identical screenshots for all APIs.
    "Test_Normal.lua",
};

const char*         gLabels[RenderModeCount] = {};
WaveOpsSupportFlags gRequiredWaveFlags[RenderModeCount] = {};

FontDrawDesc gFrameTimeDraw;
uint32_t     gFontID = 0;

struct Vertex
{
    float3 position;
    float4 color;
};

struct Vertex2
{
    float3 position;
    float2 uv;
};

class WaveIntrinsics: public IApp
{
public:
    bool Init()
    {
        RendererDesc settings;
        memset(&settings, 0, sizeof(settings));
        settings.mShaderTarget = SHADER_TARGET_6_0;
        initGPUConfiguration(settings.pExtendedSettings);
        initRenderer(GetName(), &settings, &pRenderer);
        // check for init success
        if (!pRenderer)
        {
            ShowUnsupportedMessage(getUnsupportedGPUMsg());
            return false;
        }
        setupGPUConfigurationPlatformParameters(pRenderer, settings.pExtendedSettings);

        QueueDesc queueDesc = {};
        queueDesc.mType = QUEUE_TYPE_GRAPHICS;
        queueDesc.mFlag = QUEUE_FLAG_INIT_MICROPROFILE;
        initQueue(pRenderer, &queueDesc, &pGraphicsQueue);

        GpuCmdRingDesc cmdRingDesc = {};
        cmdRingDesc.pQueue = pGraphicsQueue;
        cmdRingDesc.mPoolCount = gDataBufferCount;
        cmdRingDesc.mCmdPerPoolCount = 1;
        cmdRingDesc.mAddSyncPrimitives = true;
        initGpuCmdRing(pRenderer, &cmdRingDesc, &gGraphicsCmdRing);

        initSemaphore(pRenderer, &pImageAcquiredSemaphore);

        initResourceLoaderInterface(pRenderer);

        RootSignatureDesc rootDesc = {};
        INIT_RS_DESC(rootDesc, "default.rootsig", "compute.rootsig");
        initRootSignature(pRenderer, &rootDesc);

        SamplerDesc samplerDesc = { FILTER_NEAREST,      FILTER_NEAREST,      MIPMAP_MODE_NEAREST,
                                    ADDRESS_MODE_REPEAT, ADDRESS_MODE_REPEAT, ADDRESS_MODE_CLAMP_TO_BORDER };
        addSampler(pRenderer, &samplerDesc, &pSamplerPointWrap);

        // Define the geometry for a triangle.
        Vertex triangleVertices[] = { { { 0.0f, 0.5f, 0.0f }, { 0.8f, 0.8f, 0.0f, 1.0f } },
                                      { { 0.5f, -0.5f, 0.0f }, { 0.0f, 0.8f, 0.8f, 1.0f } },
                                      { { -0.5f, -0.5f, 0.0f }, { 0.8f, 0.0f, 0.8f, 1.0f } } };

        BufferLoadDesc triangleColorDesc = {};
        triangleColorDesc.mDesc.mDescriptors = DESCRIPTOR_TYPE_VERTEX_BUFFER;
        triangleColorDesc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_GPU_ONLY;
        triangleColorDesc.mDesc.mSize = sizeof(triangleVertices);
        triangleColorDesc.pData = triangleVertices;
        triangleColorDesc.ppBuffer = &pVertexBufferTriangle;
        addResource(&triangleColorDesc, NULL);

        // Define the geometry for a rectangle.
        Vertex2 quadVertices[] = { { { -1.0f, -1.0f, 0.0f }, { 0.0f, 1.0f } }, { { -1.0f, 1.0f, 0.0f }, { 0.0f, 0.0f } },
                                   { { 1.0f, 1.0f, 0.0f }, { 1.0f, 0.0f } },

                                   { { -1.0f, -1.0f, 0.0f }, { 0.0f, 1.0f } }, { { 1.0f, 1.0f, 0.0f }, { 1.0f, 0.0f } },
                                   { { 1.0f, -1.0f, 0.0f }, { 1.0f, 1.0f } } };

        BufferLoadDesc quadUVDesc = {};
        quadUVDesc.mDesc.mDescriptors = DESCRIPTOR_TYPE_VERTEX_BUFFER;
        quadUVDesc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_GPU_ONLY;
        quadUVDesc.mDesc.mSize = sizeof(quadVertices);
        quadUVDesc.pData = quadVertices;
        quadUVDesc.ppBuffer = &pVertexBufferQuad;
        addResource(&quadUVDesc, NULL);

        BufferLoadDesc ubDesc = {};
        ubDesc.mDesc.mDescriptors = DESCRIPTOR_TYPE_UNIFORM_BUFFER;
        ubDesc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_CPU_TO_GPU;
        ubDesc.mDesc.mSize = sizeof(SceneConstantBuffer);
        ubDesc.mDesc.mFlags = BUFFER_CREATION_FLAG_PERSISTENT_MAP_BIT;
        ubDesc.pData = NULL;
        for (uint32_t i = 0; i < gDataBufferCount; ++i)
        {
            ubDesc.ppBuffer = &pUniformBuffer[i];
            addResource(&ubDesc, NULL);
        }

        // Load fonts
        FontDesc font = {};
        font.pFontPath = "TitilliumText/TitilliumText-Bold.otf";
        fntDefineFonts(&font, 1, &gFontID);

        FontSystemDesc fontRenderDesc = {};
        fontRenderDesc.pRenderer = pRenderer;
        if (!initFontSystem(&fontRenderDesc))
            return false; // report?

        // Initialize Forge User Interface Rendering
        UserInterfaceDesc uiRenderDesc = {};
        uiRenderDesc.pRenderer = pRenderer;
        initUserInterface(&uiRenderDesc);

        const char* ppGpuProfilerName[1] = { "Graphics" };

        // Initialize micro profiler and its UI.
        ProfilerDesc profiler = {};
        profiler.pRenderer = pRenderer;
        profiler.ppQueues = &pGraphicsQueue;
        profiler.ppProfilerNames = ppGpuProfilerName;
        profiler.pProfileTokens = &gGpuProfileToken;
        profiler.mGpuProfilerCount = 1;
        initProfiler(&profiler);

        gLabels[RenderMode1] = "1. Normal render.\n";
        gRequiredWaveFlags[RenderMode1] = WAVE_OPS_SUPPORT_FLAG_NONE;
        gLabels[RenderMode2] = "2. Color pixels by lane indices.\n";
        gRequiredWaveFlags[RenderMode2] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT;
        gLabels[RenderMode3] = "3. Show first lane (white dot) in each wave.\n";
        gRequiredWaveFlags[RenderMode3] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT;
        gLabels[RenderMode4] = "4. Show first(white dot) and last(red dot) lanes in each wave.\n";
        gRequiredWaveFlags[RenderMode4] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT;
        gLabels[RenderMode5] = "5. Color pixels by active lane ratio (white = 100%; black = 0%).\n";
        gRequiredWaveFlags[RenderMode5] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT;
        gLabels[RenderMode6] = "6. Broadcast the color of the first active lane to the wave.\n";
        gRequiredWaveFlags[RenderMode6] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT;
        gLabels[RenderMode7] = "7. Average the color in a wave.\n";
        gRequiredWaveFlags[RenderMode7] =
            WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT | WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT;
        gLabels[RenderMode8] = "8. Color pixels by prefix sum of distance between current and first lane.\n";
        gRequiredWaveFlags[RenderMode8] =
            WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT | WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT;
        gLabels[RenderMode9] = "9. Color pixels by their quad id.\n";
        gRequiredWaveFlags[RenderMode9] = WAVE_OPS_SUPPORT_FLAG_BASIC_BIT | WAVE_OPS_SUPPORT_FLAG_QUAD_BIT;

        const uint32_t numMaxScripts = sizeof(gTestScripts) / sizeof(gTestScripts[0]);
        const char*    testScripts[numMaxScripts] = {};
        uint32_t       numScripts = 0;

        // skip normal .. will be added last
        for (uint32_t i = 1; i < numMaxScripts; ++i)
        {
            if ((pRenderer->pGpu->mWaveOpsSupportFlags & gRequiredWaveFlags[i]) == gRequiredWaveFlags[i])
            {
                testScripts[numScripts++] = gTestScripts[i - 1];
            }
        }

        testScripts[numScripts++] = gTestScripts[numMaxScripts - 1];
        LuaScriptDesc scriptDescs[numMaxScripts] = {};
        for (uint32_t i = 0; i < numScripts; ++i)
            scriptDescs[i].pScriptFileName = testScripts[i];
        luaDefineScripts(scriptDescs, numScripts);

        AddCustomInputBindings();
        initScreenshotCapturer(pRenderer, pGraphicsQueue, GetName());
        gFrameIndex = 0;
        waitForAllResourceLoads();

        return true;
    }

    void Exit()
    {
        exitScreenshotCapturer();
        exitProfiler();

        exitUserInterface();

        exitFontSystem();

        for (uint32_t i = 0; i < gDataBufferCount; ++i)
        {
            removeResource(pUniformBuffer[i]);
        }
        removeResource(pVertexBufferQuad);
        removeResource(pVertexBufferTriangle);

        removeSampler(pRenderer, pSamplerPointWrap);

        exitSemaphore(pRenderer, pImageAcquiredSemaphore);
        exitGpuCmdRing(pRenderer, &gGraphicsCmdRing);
        exitRootSignature(pRenderer);
        exitResourceLoaderInterface(pRenderer);
        exitQueue(pRenderer, pGraphicsQueue);
        exitRenderer(pRenderer);
        exitGPUConfiguration();
        pRenderer = NULL;
    }

    bool Load(ReloadDesc* pReloadDesc)
    {
        if (pReloadDesc->mType == RELOAD_TYPE_ALL)
        {
            gSceneData.mousePosition.x = mSettings.mWidth * 0.5f;
            gSceneData.mousePosition.y = mSettings.mHeight * 0.5f;
        }

        if (pReloadDesc->mType & RELOAD_TYPE_SHADER)
        {
            addShaders();
            addDescriptorSets();
        }

        if (pReloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
        {
            loadProfilerUI(mSettings.mWidth, mSettings.mHeight);

            UIComponentDesc guiDesc = {};
            guiDesc.mStartPosition = vec2(mSettings.mWidth * 0.01f, mSettings.mHeight * 0.2f);
            uiAddComponent("Render Modes", &guiDesc, &pGui);

            for (uint32_t i = 0; i < RenderModeCount; ++i)
            {
                if ((pRenderer->pGpu->mWaveOpsSupportFlags & gRequiredWaveFlags[i]) != gRequiredWaveFlags[i])
                {
                    continue;
                }

                RadioButtonWidget modeToggle;
                modeToggle.pData = &gRenderModeToggles;
                modeToggle.mRadioId = i;
                luaRegisterWidget(uiAddComponentWidget(pGui, gLabels[i], &modeToggle, WIDGET_TYPE_RADIO_BUTTON));
            }

            // Radio button doesn't register any function to set it.
            // Also radio buttons label is unusable in Lua script.
#ifdef AUTOMATED_TESTING
            DropdownWidget     ddRenderMode;
            static const char* shorterLabels[RenderModeCount] = {
                "Normal",        "WaveGetLaneIndex", "WaveIsFirstLane", "WaveGetMaxActiveIndex", "WaveActiveBallot", "WaveReadLaneFirst",
                "WaveActiveSum", "WavePrefixSum",    "QuadReadAcross",
            };
            ddRenderMode.pData = (uint32_t*)&gRenderModeToggles;
            ddRenderMode.pNames = shorterLabels;
            ddRenderMode.mCount = sizeof(shorterLabels) / sizeof(shorterLabels[0]);
            luaRegisterWidget(uiAddComponentWidget(pGui, "Render Mode", &ddRenderMode, WIDGET_TYPE_DROPDOWN));
#endif

            if (!addSwapChain())
                return false;

            if (!addIntermediateRenderTarget())
                return false;
        }

        if (pReloadDesc->mType & (RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
        {
            addPipelines();
        }

        prepareDescriptorSets();

        UserInterfaceLoadDesc uiLoad = {};
        uiLoad.mColorFormat = pSwapChain->ppRenderTargets[0]->mFormat;
        uiLoad.mHeight = mSettings.mHeight;
        uiLoad.mWidth = mSettings.mWidth;
        uiLoad.mLoadType = pReloadDesc->mType;
        loadUserInterface(&uiLoad);

        FontSystemLoadDesc fontLoad = {};
        fontLoad.mColorFormat = pSwapChain->ppRenderTargets[0]->mFormat;
        fontLoad.mHeight = mSettings.mHeight;
        fontLoad.mWidth = mSettings.mWidth;
        fontLoad.mLoadType = pReloadDesc->mType;
        loadFontSystem(&fontLoad);

        gMovePosition = float2(mSettings.mWidth * 0.5f, mSettings.mHeight * 0.5f);

        return true;
    }

    void Unload(ReloadDesc* pReloadDesc)
    {
        waitQueueIdle(pGraphicsQueue);

        unloadFontSystem(pReloadDesc->mType);
        unloadUserInterface(pReloadDesc->mType);

        if (pReloadDesc->mType & (RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
        {
            removePipelines();
        }

        if (pReloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
        {
            removeSwapChain(pRenderer, pSwapChain);
            removeRenderTarget(pRenderer, pRenderTargetIntermediate);
            uiRemoveComponent(pGui);
            unloadProfilerUI();
        }

        if (pReloadDesc->mType & RELOAD_TYPE_SHADER)
        {
            removeDescriptorSets();
            removeShaders();
        }
    }

    void Update(float deltaTime)
    {
        if (!uiIsFocused())
        {
            if (inputGetValue(0, CUSTOM_PT_DOWN))
            {
                gMovePosition = { inputGetValue(0, CUSTOM_PT_X), inputGetValue(0, CUSTOM_PT_Y) };
            }
            if (inputGetValue(0, CUSTOM_TOGGLE_FULLSCREEN))
            {
                toggleFullscreen(pWindow);
            }
            if (inputGetValue(0, CUSTOM_TOGGLE_UI))
            {
                uiToggleActive();
            }
            if (inputGetValue(0, CUSTOM_DUMP_PROFILE))
            {
                dumpProfileData(GetName());
            }
            if (inputGetValue(0, CUSTOM_EXIT))
            {
                requestShutdown();
            }
            gMovePosition += float2{ inputGetValue(0, CUSTOM_MOVE_X), -inputGetValue(0, CUSTOM_MOVE_Y) } * 0.25f;
        }
        /************************************************************************/
        // Uniforms
        /************************************************************************/
        static float currentTime = 0.0f;
        currentTime += deltaTime * 1000.0f;

        float aspectRatio = (float)mSettings.mWidth / mSettings.mHeight;
        gSceneData.orthProjMatrix = mat4::orthographicLH(-1.0f * aspectRatio, 1.0f * aspectRatio, -1.0f, 1.0f, 0.0f, 1.0f);
        gSceneData.laneSize = pRenderer->pGpu->mWaveLaneCount;
        gSceneData.time = currentTime;
        gSceneData.resolution.x = (float)(mSettings.mWidth);
        gSceneData.resolution.y = (float)(mSettings.mHeight);
        gSceneData.renderMode = (gRenderModeToggles + 1);
        gSceneData.mousePosition = gMovePosition;
    }

    void Draw()
    {
        if ((bool)pSwapChain->mEnableVsync != mSettings.mVSyncEnabled)
        {
            waitQueueIdle(pGraphicsQueue);
            ::toggleVSync(pRenderer, &pSwapChain);
        }

        uint32_t swapchainImageIndex;
        acquireNextImage(pRenderer, pSwapChain, pImageAcquiredSemaphore, NULL, &swapchainImageIndex);
        /************************************************************************/
        /************************************************************************/
        // Stall if CPU is running "gDataBufferCount" frames ahead of GPU
        GpuCmdRingElement elem = getNextGpuCmdRingElement(&gGraphicsCmdRing, true, 1);
        FenceStatus       fenceStatus;
        getFenceStatus(pRenderer, elem.pFence, &fenceStatus);
        if (fenceStatus == FENCE_STATUS_INCOMPLETE)
            waitForFences(pRenderer, 1, &elem.pFence);

        resetCmdPool(pRenderer, elem.pCmdPool);

        /************************************************************************/
        // Scene Update
        /************************************************************************/
        BufferUpdateDesc viewProjCbv = { pUniformBuffer[gFrameIndex] };
        beginUpdateResource(&viewProjCbv);
        memcpy(viewProjCbv.pMappedData, &gSceneData, sizeof(gSceneData));
        endUpdateResource(&viewProjCbv);

        RenderTarget* pRenderTarget = pRenderTargetIntermediate;
        RenderTarget* pScreenRenderTarget = pSwapChain->ppRenderTargets[swapchainImageIndex];

        // simply record the screen cleaning command

        Cmd* cmd = elem.pCmds[0];
        beginCmd(cmd);
        cmdBeginGpuFrameProfile(cmd, gGpuProfileToken);

        RenderTargetBarrier rtBarrier[] = {
            { pRenderTarget, RESOURCE_STATE_PIXEL_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
            { pScreenRenderTarget, RESOURCE_STATE_PRESENT, RESOURCE_STATE_RENDER_TARGET },
        };
        cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 2, rtBarrier);

        cmdBeginGpuTimestampQuery(cmd, gGpuProfileToken, "Wave Shader");

        BindRenderTargetsDesc bindRenderTargets = {};
        bindRenderTargets.mRenderTargetCount = 1;
        bindRenderTargets.mRenderTargets[0] = { pRenderTarget, LOAD_ACTION_CLEAR };
        cmdBindRenderTargets(cmd, &bindRenderTargets);
        cmdSetViewport(cmd, 0.0f, 0.0f, (float)pRenderTarget->mWidth, (float)pRenderTarget->mHeight, 0.0f, 1.0f);
        cmdSetScissor(cmd, 0, 0, pRenderTarget->mWidth, pRenderTarget->mHeight);

        // wave debug
        const uint32_t triangleStride = sizeof(Vertex);
        cmdBeginDebugMarker(cmd, 0, 0, 1, "Wave Shader");
        cmdBindPipeline(cmd, pPipelineWave);
        cmdBindDescriptorSet(cmd, gFrameIndex, pDescriptorSetUniforms);
        cmdBindVertexBuffer(cmd, 1, &pVertexBufferTriangle, &triangleStride, NULL);
        cmdDraw(cmd, 3, 0);
        cmdEndGpuTimestampQuery(cmd, gGpuProfileToken);
        cmdEndDebugMarker(cmd);

        cmdBindRenderTargets(cmd, NULL);

        // magnify
        cmdBeginDebugMarker(cmd, 1, 0, 1, "Magnify");
        cmdBeginGpuTimestampQuery(cmd, gGpuProfileToken, "Magnify");
        RenderTargetBarrier srvBarrier[] = {
            { pRenderTarget, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_PIXEL_SHADER_RESOURCE },
        };
        cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, srvBarrier);

        bindRenderTargets = {};
        bindRenderTargets.mRenderTargetCount = 1;
        bindRenderTargets.mRenderTargets[0] = { pScreenRenderTarget, LOAD_ACTION_CLEAR };
        cmdBindRenderTargets(cmd, &bindRenderTargets);

        const uint32_t quadStride = sizeof(Vertex2);
        cmdBindPipeline(cmd, pPipelineMagnify);
        cmdBindDescriptorSet(cmd, gFrameIndex, pDescriptorSetUniforms);
        cmdBindDescriptorSet(cmd, 0, pDescriptorSetTexture);
        cmdBindVertexBuffer(cmd, 1, &pVertexBufferQuad, &quadStride, NULL);
        cmdDrawInstanced(cmd, 6, 0, 2, 0);

        cmdEndGpuTimestampQuery(cmd, gGpuProfileToken);
        cmdEndDebugMarker(cmd);

        cmdBeginDebugMarker(cmd, 0, 1, 0, "Draw UI");

        FontDrawDesc frameTimeDraw;
        frameTimeDraw.mFontColor = 0xff0080ff;
        frameTimeDraw.mFontSize = 18.0f;
        frameTimeDraw.mFontID = gFontID;
        float2 txtSize = cmdDrawCpuProfile(cmd, float2(8.0f, 15.0f), &frameTimeDraw);
        cmdDrawGpuProfile(cmd, float2(8.f, txtSize.y + 75.f), gGpuProfileToken, &frameTimeDraw);

        cmdDrawUserInterface(cmd);
        cmdBindRenderTargets(cmd, NULL);
        cmdEndDebugMarker(cmd);

        RenderTargetBarrier presentBarrier = { pScreenRenderTarget, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_PRESENT };
        cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, &presentBarrier);

        cmdEndGpuFrameProfile(cmd, gGpuProfileToken);
        endCmd(cmd);

        FlushResourceUpdateDesc flushUpdateDesc = {};
        flushUpdateDesc.mNodeIndex = 0;
        flushResourceUpdates(&flushUpdateDesc);
        Semaphore* waitSemaphores[2] = { flushUpdateDesc.pOutSubmittedSemaphore, pImageAcquiredSemaphore };

        QueueSubmitDesc submitDesc = {};
        submitDesc.mCmdCount = 1;
        submitDesc.mSignalSemaphoreCount = 1;
        submitDesc.mWaitSemaphoreCount = TF_ARRAY_COUNT(waitSemaphores);
        submitDesc.ppCmds = &cmd;
        submitDesc.ppSignalSemaphores = &elem.pSemaphore;
        submitDesc.ppWaitSemaphores = waitSemaphores;
        submitDesc.pSignalFence = elem.pFence;
        queueSubmit(pGraphicsQueue, &submitDesc);
        QueuePresentDesc presentDesc = {};
        presentDesc.mIndex = (uint8_t)swapchainImageIndex;
        presentDesc.mWaitSemaphoreCount = 1;
        presentDesc.ppWaitSemaphores = &elem.pSemaphore;
        presentDesc.pSwapChain = pSwapChain;
        presentDesc.mSubmitDone = true;
        queuePresent(pGraphicsQueue, &presentDesc);

        flipProfiler();

        gFrameIndex = (gFrameIndex + 1) % gDataBufferCount;
    }

    const char* GetName() { return "14_WaveIntrinsics"; }

    bool addSwapChain()
    {
        SwapChainDesc swapChainDesc = {};
        swapChainDesc.mWindowHandle = pWindow->handle;
        swapChainDesc.mPresentQueueCount = 1;
        swapChainDesc.ppPresentQueues = &pGraphicsQueue;
        swapChainDesc.mWidth = mSettings.mWidth;
        swapChainDesc.mHeight = mSettings.mHeight;
        swapChainDesc.mImageCount = getRecommendedSwapchainImageCount(pRenderer, &pWindow->handle);
        swapChainDesc.mColorFormat = getSupportedSwapchainFormat(pRenderer, &swapChainDesc, COLOR_SPACE_SDR_SRGB);
        swapChainDesc.mColorSpace = COLOR_SPACE_SDR_SRGB;
        swapChainDesc.mEnableVsync = mSettings.mVSyncEnabled;
        ::addSwapChain(pRenderer, &swapChainDesc, &pSwapChain);

        return pSwapChain != NULL;
    }

    void addDescriptorSets()
    {
        DescriptorSetDesc setDesc = SRT_SET_DESC(SrtData, Persistent, 1, 0);
        addDescriptorSet(pRenderer, &setDesc, &pDescriptorSetTexture);
        setDesc = SRT_SET_DESC(SrtData, PerFrame, gDataBufferCount, 0);
        addDescriptorSet(pRenderer, &setDesc, &pDescriptorSetUniforms);
    }

    void removeDescriptorSets()
    {
        removeDescriptorSet(pRenderer, pDescriptorSetUniforms);
        removeDescriptorSet(pRenderer, pDescriptorSetTexture);
    }

    void addShaders()
    {
        ShaderLoadDesc waveShader = {};
        waveShader.mVert.pFileName = "wave.vert";
        auto waveFlags = pRenderer->pGpu->mWaveOpsSupportFlags;

        if ((waveFlags & WAVE_OPS_SUPPORT_FLAG_BASIC_BIT) && (waveFlags & WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT) &&
            (waveFlags & WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT) && (waveFlags & WAVE_OPS_SUPPORT_FLAG_QUAD_BIT))
        {
            waveShader.mFrag.pFileName = "wave_all.frag";
        }
        else if ((waveFlags & WAVE_OPS_SUPPORT_FLAG_BASIC_BIT) && (waveFlags & WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT) &&
                 (waveFlags & WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT))
        {
            waveShader.mFrag.pFileName = "wave_basic_ballot_arithmetic.frag";
        }
        else if ((waveFlags & WAVE_OPS_SUPPORT_FLAG_BASIC_BIT) && (waveFlags & WAVE_OPS_SUPPORT_FLAG_BALLOT_BIT))
        {
            waveShader.mFrag.pFileName = "wave_basic_ballot.frag";
        }
        else if ((waveFlags & WAVE_OPS_SUPPORT_FLAG_BASIC_BIT) && (waveFlags & WAVE_OPS_SUPPORT_FLAG_ARITHMETIC_BIT))
        {
            waveShader.mFrag.pFileName = "wave_basic_arithmetic.frag";
        }
        else
        {
            waveShader.mFrag.pFileName = "wave_basic.frag";
        }
        addShader(pRenderer, &waveShader, &pShaderWave);

        ShaderLoadDesc magnifyShader = {};
        magnifyShader.mVert.pFileName = "magnify.vert";
        magnifyShader.mFrag.pFileName = "magnify.frag";
        addShader(pRenderer, &magnifyShader, &pShaderMagnify);
    }

    void removeShaders()
    {
        removeShader(pRenderer, pShaderMagnify);
        removeShader(pRenderer, pShaderWave);
    }

    void addPipelines()
    {
        // layout and pipeline for sphere draw
        VertexLayout vertexLayout = {};
        vertexLayout.mBindingCount = 1;
        vertexLayout.mAttribCount = 2;
        vertexLayout.mAttribs[0].mSemantic = SEMANTIC_POSITION;
        vertexLayout.mAttribs[0].mFormat = TinyImageFormat_R32G32B32_SFLOAT;
        vertexLayout.mAttribs[0].mBinding = 0;
        vertexLayout.mAttribs[0].mLocation = 0;
        vertexLayout.mAttribs[0].mOffset = 0;
        vertexLayout.mAttribs[1].mSemantic = SEMANTIC_COLOR;
        vertexLayout.mAttribs[1].mFormat = TinyImageFormat_R32G32B32A32_SFLOAT;
        vertexLayout.mAttribs[1].mBinding = 0;
        vertexLayout.mAttribs[1].mLocation = 1;
        vertexLayout.mAttribs[1].mOffset = 3 * sizeof(float);

        RasterizerStateDesc rasterizerStateDesc = {};
        rasterizerStateDesc.mCullMode = CULL_MODE_NONE;

        DepthStateDesc depthStateDesc = {};

        PipelineDesc desc = {};
        PIPELINE_LAYOUT_DESC(desc, SRT_LAYOUT_DESC(SrtData, Persistent), SRT_LAYOUT_DESC(SrtData, PerFrame), NULL, NULL);
        desc.mType = PIPELINE_TYPE_GRAPHICS;
        GraphicsPipelineDesc& pipelineSettings = desc.mGraphicsDesc;
        pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
        pipelineSettings.mRenderTargetCount = 1;
        pipelineSettings.pDepthState = &depthStateDesc;
        pipelineSettings.pColorFormats = &pSwapChain->ppRenderTargets[0]->mFormat;
        pipelineSettings.mSampleCount = pSwapChain->ppRenderTargets[0]->mSampleCount;
        pipelineSettings.mSampleQuality = pSwapChain->ppRenderTargets[0]->mSampleQuality;
        pipelineSettings.pShaderProgram = pShaderWave;
        pipelineSettings.pVertexLayout = &vertexLayout;
        pipelineSettings.pRasterizerState = &rasterizerStateDesc;
        addPipeline(pRenderer, &desc, &pPipelineWave);

        // layout and pipeline for skybox draw
        vertexLayout.mAttribs[1].mSemantic = SEMANTIC_TEXCOORD0;
        vertexLayout.mAttribs[1].mFormat = TinyImageFormat_R32G32_SFLOAT;
        vertexLayout.mAttribs[1].mBinding = 0;
        vertexLayout.mAttribs[1].mLocation = 1;
        vertexLayout.mAttribs[1].mOffset = 3 * sizeof(float);

        pipelineSettings.pShaderProgram = pShaderMagnify;
        addPipeline(pRenderer, &desc, &pPipelineMagnify);
    }

    void removePipelines()
    {
        removePipeline(pRenderer, pPipelineMagnify);
        removePipeline(pRenderer, pPipelineWave);
    }

    void prepareDescriptorSets()
    {
        for (uint32_t i = 0; i < gDataBufferCount; ++i)
        {
            DescriptorData params[1] = {};
            params[0].mIndex = SRT_RES_IDX(SrtData, PerFrame, gSceneConstantBuffer);
            params[0].ppBuffers = &pUniformBuffer[i];
            updateDescriptorSet(pRenderer, i, pDescriptorSetUniforms, 1, params);
        }

        DescriptorData magnifyParams[2] = {};
        magnifyParams[0].mIndex = SRT_RES_IDX(SrtData, Persistent, gTexture);
        magnifyParams[0].ppTextures = &pRenderTargetIntermediate->pTexture;
        magnifyParams[1].mIndex = SRT_RES_IDX(SrtData, Persistent, gSampler);
        magnifyParams[1].ppSamplers = &pSamplerPointWrap;
        updateDescriptorSet(pRenderer, 0, pDescriptorSetTexture, 2, magnifyParams);
    }

    bool addIntermediateRenderTarget()
    {
        ESRAM_BEGIN_ALLOC(pRenderer, "Intermediate", 0);

        RenderTargetDesc rtDesc = {};
        rtDesc.mArraySize = 1;
        rtDesc.mClearValue = {
            { 0.001f, 0.001f, 0.001f, 0.001f }
        }; // This is a temporary workaround for AMD cards on macOS. Setting this to (0,0,0,0) will introduce weird behavior.
        rtDesc.mDepth = 1;
        rtDesc.mDescriptors = DESCRIPTOR_TYPE_TEXTURE;
        rtDesc.mFormat = pSwapChain->mFormat;
        rtDesc.mStartState = RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
        rtDesc.mHeight = mSettings.mHeight;
        rtDesc.mSampleCount = SAMPLE_COUNT_1;
        rtDesc.mSampleQuality = 0;
        rtDesc.mWidth = mSettings.mWidth;
        rtDesc.mFlags = TEXTURE_CREATION_FLAG_ESRAM | TEXTURE_CREATION_FLAG_VR_MULTIVIEW;
        addRenderTarget(pRenderer, &rtDesc, &pRenderTargetIntermediate);

        ESRAM_END_ALLOC(pRenderer);

        return pRenderTargetIntermediate != NULL;
    }
};

DEFINE_APPLICATION_MAIN(WaveIntrinsics)
