#include "TidesRenderer.h"
#include <stdio.h>
#include <assert.h>

#include "../../../Common_3/Graphics/Interfaces/IGraphics.h"
#include "../../../Common_3/Resources/ResourceLoader/Interfaces/IResourceLoader.h"
#include "../../../Common_3/Utilities/Interfaces/IMemory.h"
#include "../../../Common_3/Utilities/Interfaces/IFileSystem.h"
#include "../../../Common_3/Utilities/Interfaces/ILog.h"
#include "../../../Common_3/Utilities/RingBuffer.h"

// NOTE(gmodarelli): We cannot use them as they are since they rely on global Application layer state
// #include "../../../Common_3/Application/Interfaces/IFont.h"
// #include "../../../Common_3/Application/Interfaces/IProfiler.h"
// #include "../../../Common_3/Application/Interfaces/IUI.h"

#define EXIT_FAILURE 1

static const uint32_t g_DataBufferCount = 2;

Renderer *g_Renderer = NULL;
Queue *g_GraphicsQueue = NULL;
GpuCmdRing g_GraphicsCmdRing = {};
SwapChain *g_SwapChain = NULL;
Semaphore *g_ImageAcquiredSemaphore = NULL;
uint32_t g_FrameIndex = 0;

// Render Targets
// ==============
RenderTarget *g_DepthBuffer = NULL;
RenderTarget *g_GBuffer0 = NULL;
RenderTarget *g_GBuffer1 = NULL;
RenderTarget *g_GBuffer2 = NULL;
RenderTarget *g_LightingDiffuse = NULL;
RenderTarget *g_LightingSpecular = NULL;
RenderTarget *g_SceneColor = NULL;

TR_AppSettings *g_AppSettings = NULL;

TR_DrawCallInstanced *g_TerrainDrawCalls = NULL;
TR_DrawCallPushConstants *g_TerrainPushConstants = NULL;
uint32_t g_TerrainDrawCallsCountMax = 4096;
uint32_t g_TerrainDrawCallsCount = 0;

TR_DrawCallInstanced *g_LitOpaqueDrawCalls = NULL;
TR_DrawCallPushConstants *g_LitOpaquePushConstants = NULL;
uint32_t g_LitOpaqueDrawCallsCountMax = 4096;
uint32_t g_LitOpaqueDrawCallsCount = 0;

TR_DrawCallInstanced *g_LitMaskedDrawCalls = NULL;
TR_DrawCallPushConstants *g_LitMaskedPushConstants = NULL;
uint32_t g_LitMaskedDrawCallsCountMax = 4096;
uint32_t g_LitMaskedDrawCallsCount = 0;

// TODO(gmodarelli): Implement a proper resource pool
// GPU Buffer Pool
// ===============
static const uint32_t g_GpuBufferMaxCount = 256;
uint32_t g_GpuBufferCount = 0;
Buffer *g_GpuBuffers[g_GpuBufferMaxCount] = {NULL};

// TODO(gmodarelli): Implement a proper resource pool
// Mesh Pool
// =========
struct Mesh
{
	Geometry *geometry = NULL;
	GeometryData *geometryData = NULL;
	GeometryBuffer *geometryBuffer = NULL;
	GeometryBufferLayoutDesc geometryBufferLayoutDesc = {};
	bool loaded = false;
};
Mesh *g_Meshes = NULL;
uint32_t g_MeshCount = 0;
static const uint32_t g_MeshCountMax = 1024;
VertexLayout g_VertexLayoutDefault = {};

// TODO(gmodarelli): Implement a proper resource pool
// Textures Pool
// =============
static const uint32_t g_TextureCountMax = 1024;
Texture *g_Textures[g_TextureCountMax] = {NULL};
uint32_t g_TextureCount = 0;

// TODO(gmodarelli): Implement a proper resource pool
// Renderable Pool
// ===============
struct Renderable
{
	uint64_t ID;
	TR_MeshHandle meshHandle;
};

Renderable *g_RegisteredRenderables;
uint32_t g_RegisteredRenderableCount;
static const uint32_t g_RegisteredRenderableCountMax = 1024;

// Static Samplers
// ===============
Sampler *g_SamplerBilinearRepeat = NULL;
Sampler *g_SamplerBilinearClampToEdge = NULL;
Sampler *g_SamplerPointRepeat = NULL;
Sampler *g_SamplerPointClampToEdge = NULL;
Sampler *g_SamplerPointClampToBorder = NULL;

// Per-Frame Resources
// ===================
struct UniformFrameData
{
	mat4 m_ProjectionView;
	mat4 m_ProjectionViewInverted;
	vec4 m_Position;
	uint32_t m_DirectionalLightsBufferIndex;
	uint32_t m_PointLightsBufferIndex;
	uint32_t m_DirectionalLightsCount;
	uint32_t m_PointLightsCount;
};
UniformFrameData g_UniformFrameData;
Buffer *g_UniformBufferCamera[g_DataBufferCount] = {NULL};

// Terrain Shader Resources
// ========================
Shader *g_ShaderTerrain = NULL;
RootSignature *g_RootSignatureTerrain = NULL;
Pipeline *g_PipelineTerrain = NULL;
DescriptorSet *g_DescriptorSetTerrain = NULL;

// Lit Shader Resources
// ====================
Shader *g_ShaderLitOpaque = NULL;
RootSignature *g_RootSignatureLitOpaque = NULL;
Pipeline *g_PipelineLitOpaque = NULL;
DescriptorSet *g_DescriptorSetLitOpaque = NULL;
Shader *g_ShaderLitMasked = NULL;
RootSignature *g_RootSignatureLitMasked = NULL;
Pipeline *g_PipelineLitMasked = NULL;
DescriptorSet *g_DescriptorSetLitMasked = NULL;

// Deferred Shading Shader Resources
// =================================
Shader *g_ShaderDeferredShading = NULL;
RootSignature *g_RootSignatureDeferredShading = NULL;
Pipeline *g_PipelineDeferredShading = NULL;
DescriptorSet *g_DescriptorSetDeferredShading[2] = { NULL };

// Tonemapper Shader Resources
// ===========================
Shader *g_ShaderTonemapper = NULL;
RootSignature *g_RootSignatureTonemapper = NULL;
Pipeline *g_PipelineTonemapper = NULL;
DescriptorSet *g_DescriptorSetTonemapper = NULL;

// Skybox Resources
// ================
VertexLayout g_VertexLayoutSkybox = {};
UniformFrameData g_UniformFrameDataSkybox;
Shader *g_ShaderSkybox = NULL;
RootSignature *g_RootSignatureSkybox = NULL;
DescriptorSet *g_DescriptorSetSkybox[2] = {NULL};
Pipeline *g_PipelineSkybox = NULL;
Buffer *g_VertexBufferSkybox = NULL;
Buffer *g_UniformBufferCameraSkybox[g_DataBufferCount] = {NULL};
Texture *g_TextureSkybox = NULL;
Texture *g_TextureBRDFLut = NULL;
Texture *g_TextureIrradiance = NULL;
Texture *g_TextureSpecular = NULL;

// Testing Dynamic Resources
// =========================
struct InstanceTransform
{
	mat4 worldMatrix;
};

uint32_t g_TerrainLod3PatchCount = 8 * 8;
Buffer *g_TerrainLod3TransformBuffer = NULL;

bool AddSwapChain();
bool AddRenderTargets();

void AddStaticSamplers();
void RemoveStaticSamplers();

void LoadStaicEntityTransforms();
void UnloadStaticEntityTransforms();
void LoadSkybox();
void UnloadSkybox();

void AddUniformBuffers();
void RemoveUniformBuffers();

void LoadShaders();
void LoadRootSignatures();
void LoadDescriptorSets();
void UnloadShaders();
void UnloadRootSignatures();
void UnloadDescriptorSets();

void PrepareDescriptorSets();

void LoadPipelines();
void UnloadPipelines();

int TR_initRenderer(TR_AppSettings *appSettings)
{
	g_AppSettings = appSettings;
	const char *appName = "Tides Renderer";

	if (!initMemAlloc(appName))
		return EXIT_FAILURE;

	FileSystemInitDesc fsDesc = {};
	if (!initFileSystem(&fsDesc))
		return EXIT_FAILURE;

	fsSetPathForResourceDir(pSystemFileIO, RM_DEBUG, RD_LOG, "");

	initLog(appName, DEFAULT_LOG_LEVEL);

	fsSetPathForResourceDir(pSystemFileIO, RM_CONTENT, RD_GPU_CONFIG, "GPUCfg");
	fsSetPathForResourceDir(pSystemFileIO, RM_CONTENT, RD_SHADER_BINARIES, "content/compiled_shaders");
	fsSetPathForResourceDir(pSystemFileIO, RM_CONTENT, RD_TEXTURES, "content");
	fsSetPathForResourceDir(pSystemFileIO, RM_CONTENT, RD_MESHES, "content");

	g_TerrainDrawCalls = (TR_DrawCallInstanced *)tf_malloc(sizeof(TR_DrawCallInstanced) * g_TerrainDrawCallsCountMax);
	assert(g_TerrainDrawCalls);
	memset(g_TerrainDrawCalls, 0, sizeof(TR_DrawCallInstanced) * g_TerrainDrawCallsCountMax);

	g_TerrainPushConstants = (TR_DrawCallPushConstants *)tf_malloc(sizeof(TR_DrawCallPushConstants) * g_TerrainDrawCallsCountMax);
	assert(g_TerrainPushConstants);
	memset(g_TerrainPushConstants, 0, sizeof(TR_DrawCallPushConstants) * g_TerrainDrawCallsCountMax);

	g_LitOpaqueDrawCalls = (TR_DrawCallInstanced *)tf_malloc(sizeof(TR_DrawCallInstanced) * g_LitOpaqueDrawCallsCountMax);
	assert(g_LitOpaqueDrawCalls);
	memset(g_LitOpaqueDrawCalls, 0, sizeof(TR_DrawCallInstanced) * g_LitOpaqueDrawCallsCountMax);

	g_LitOpaquePushConstants = (TR_DrawCallPushConstants *)tf_malloc(sizeof(TR_DrawCallPushConstants) * g_LitOpaqueDrawCallsCountMax);
	assert(g_LitOpaquePushConstants);
	memset(g_LitOpaquePushConstants, 0, sizeof(TR_DrawCallPushConstants) * g_LitOpaqueDrawCallsCountMax);

	g_LitMaskedDrawCalls = (TR_DrawCallInstanced *)tf_malloc(sizeof(TR_DrawCallInstanced) * g_LitMaskedDrawCallsCountMax);
	assert(g_LitMaskedDrawCalls);
	memset(g_LitMaskedDrawCalls, 0, sizeof(TR_DrawCallInstanced) * g_LitMaskedDrawCallsCountMax);

	g_LitMaskedPushConstants = (TR_DrawCallPushConstants *)tf_malloc(sizeof(TR_DrawCallPushConstants) * g_LitMaskedDrawCallsCountMax);
	assert(g_LitMaskedPushConstants);
	memset(g_LitMaskedPushConstants, 0, sizeof(TR_DrawCallPushConstants) * g_LitMaskedDrawCallsCountMax);

	g_Meshes = (Mesh *)tf_malloc(sizeof(Mesh) * g_MeshCountMax);
	assert(g_Meshes);
	memset(g_Meshes, 0, sizeof(Mesh) * g_MeshCountMax);

	// TODO(gmodarelli): This memory should be supported by a proper allocator
	g_RegisteredRenderables = (Renderable *)tf_malloc(sizeof(Renderable) * g_RegisteredRenderableCountMax);
	assert(g_RegisteredRenderables);

	RendererDesc settings;
	memset(&settings, 0, sizeof(settings));
	settings.mD3D11Supported = false;
	settings.mGLESSupported = false;
	settings.mShaderTarget = SHADER_TARGET_6_6;
	settings.mDisableShaderServer = true;
	initRenderer(appName, &settings, &g_Renderer);

	if (!g_Renderer)
	{
		printf("Failed to initialize the renderer\n");
		return EXIT_FAILURE;
	}

	QueueDesc queueDesc = {};
	queueDesc.mType = QUEUE_TYPE_GRAPHICS;
	queueDesc.mFlag = QUEUE_FLAG_INIT_MICROPROFILE;
	addQueue(g_Renderer, &queueDesc, &g_GraphicsQueue);

	GpuCmdRingDesc cmdRingDesc = {};
	cmdRingDesc.pQueue = g_GraphicsQueue;
	cmdRingDesc.mPoolCount = g_DataBufferCount;
	cmdRingDesc.mCmdPerPoolCount = 1;
	cmdRingDesc.mAddSyncPrimitives = true;
	addGpuCmdRing(g_Renderer, &cmdRingDesc, &g_GraphicsCmdRing);

	addSemaphore(g_Renderer, &g_ImageAcquiredSemaphore);

	ResourceLoaderDesc resourceLoaderDesc = {256ull * TF_MB, 2, false, false};
	initResourceLoaderInterface(g_Renderer, &resourceLoaderDesc);

	AddStaticSamplers();

	// TODO(gmodarelli): Figure out how to support different vertex formats.
	// TODO(gmodarelli): Add support for color
	g_VertexLayoutDefault = {};
	g_VertexLayoutDefault.mBindingCount = 4;
	g_VertexLayoutDefault.mAttribCount = 4;
	g_VertexLayoutDefault.mAttribs[0].mSemantic = SEMANTIC_POSITION;
	g_VertexLayoutDefault.mAttribs[0].mFormat = TinyImageFormat_R32G32B32_SFLOAT;
	g_VertexLayoutDefault.mAttribs[0].mBinding = 0;
	g_VertexLayoutDefault.mAttribs[0].mLocation = 0;
	g_VertexLayoutDefault.mAttribs[0].mOffset = 0;
	g_VertexLayoutDefault.mAttribs[1].mSemantic = SEMANTIC_NORMAL;
	g_VertexLayoutDefault.mAttribs[1].mFormat = TinyImageFormat_R32_UINT;
	g_VertexLayoutDefault.mAttribs[1].mBinding = 1;
	g_VertexLayoutDefault.mAttribs[1].mLocation = 1;
	g_VertexLayoutDefault.mAttribs[1].mOffset = 0;
	g_VertexLayoutDefault.mAttribs[2].mSemantic = SEMANTIC_TANGENT;
	g_VertexLayoutDefault.mAttribs[2].mFormat = TinyImageFormat_R32_UINT;
	g_VertexLayoutDefault.mAttribs[2].mBinding = 2;
	g_VertexLayoutDefault.mAttribs[2].mLocation = 2;
	g_VertexLayoutDefault.mAttribs[2].mOffset = 0;
	g_VertexLayoutDefault.mAttribs[3].mSemantic = SEMANTIC_TEXCOORD0;
	g_VertexLayoutDefault.mAttribs[3].mFormat = TinyImageFormat_R32_UINT;
	g_VertexLayoutDefault.mAttribs[3].mBinding = 3;
	g_VertexLayoutDefault.mAttribs[3].mLocation = 3;
	g_VertexLayoutDefault.mAttribs[3].mOffset = 0;
	// g_VertexLayoutDefault.mAttribs[4].mSemantic = SEMANTIC_COLOR;
	// g_VertexLayoutDefault.mAttribs[4].mFormat = TinyImageFormat_R8G8B8A8_UNORM;
	// g_VertexLayoutDefault.mAttribs[4].mBinding = 4;
	// g_VertexLayoutDefault.mAttribs[4].mLocation = 4;
	// g_VertexLayoutDefault.mAttribs[4].mOffset = 0;

	LoadSkybox();
	LoadStaicEntityTransforms();

	AddUniformBuffers();

	waitForAllResourceLoads();

	g_FrameIndex = 0;

	printf("Renderer initialized succesfully\n");
	return 0;
}

void TR_exitRenderer()
{
	for (uint32_t i = 0; i < g_GpuBufferCount; i++)
	{
		if (g_GpuBuffers[i])
		{
			removeResource(g_GpuBuffers[i]);
			g_GpuBuffers[i] = NULL;
		}
	}
	g_GpuBufferCount = 0;

	tf_free(g_TerrainDrawCalls);
	tf_free(g_TerrainPushConstants);
	g_TerrainDrawCallsCount = 0;

	tf_free(g_LitOpaqueDrawCalls);
	tf_free(g_LitOpaquePushConstants);
	g_LitOpaqueDrawCallsCount = 0;

	tf_free(g_LitMaskedDrawCalls);
	tf_free(g_LitMaskedPushConstants);
	g_LitMaskedDrawCallsCount = 0;

	if (g_Meshes)
	{
		for (uint32_t i = 0; i < g_MeshCount; i++)
		{
			if (g_Meshes[i].loaded)
			{
				removeResource(g_Meshes[i].geometry);
				g_Meshes[i].geometry = NULL;

				removeGeometryBuffer(g_Meshes[i].geometryBuffer);
				g_Meshes[i].geometryBuffer = NULL;

				removeResource(g_Meshes[i].geometryData);
				g_Meshes[i].geometryData = NULL;

				g_Meshes[i].loaded = false;
			}
		}
		tf_free(g_Meshes);
		g_Meshes = NULL;
	}

	for (uint32_t i = 0; i < g_TextureCount; i++)
	{
		removeResource(g_Textures[i]);
	}

	if (g_RegisteredRenderables)
	{
		for (uint32_t i = 0; i < g_RegisteredRenderableCount; i++)
		{
			Renderable *renderable = &g_RegisteredRenderables[i];
		}
		tf_free(g_RegisteredRenderables);
		g_RegisteredRenderables = NULL;
	}

	UnloadStaticEntityTransforms();
	UnloadSkybox();
	RemoveStaticSamplers();
	RemoveUniformBuffers();

	exitResourceLoaderInterface(g_Renderer);
	removeSemaphore(g_Renderer, g_ImageAcquiredSemaphore);
	removeGpuCmdRing(g_Renderer, &g_GraphicsCmdRing);
	removeQueue(g_Renderer, g_GraphicsQueue);
	exitRenderer(g_Renderer);
	g_Renderer = NULL;

	exitLog();

	exitMemAlloc();
}

uint32_t TR_frameIndex()
{
	return g_FrameIndex;
}

uint32_t TR_inFlightFramesCount()
{
	return g_DataBufferCount;
}

bool TR_requestReload(ReloadDesc* reloadDesc)
{
	TR_onUnload(reloadDesc);
	return TR_onLoad(reloadDesc);
}

bool TR_onLoad(ReloadDesc *reloadDesc)
{
	printf("TR_onLoad\n");

	if (reloadDesc->mType & RELOAD_TYPE_SHADER)
	{
		LoadShaders();
		LoadRootSignatures();
		LoadDescriptorSets();
	}

	if (reloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
	{
		if (!AddSwapChain())
		{
			printf("Failed to initialize SwapChain\n");
			return false;
		}

		if (!AddRenderTargets())
		{
			printf("Failed to initialize Render Targets\n");
			return false;
		}
	}

	if (reloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
	{
		PrepareDescriptorSets();
		LoadPipelines();
	}

	return true;
}

void TR_onUnload(ReloadDesc *reloadDesc)
{
	printf("TR_onUnload\n");

	waitQueueIdle(g_GraphicsQueue);

	if (reloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_SHADER | RELOAD_TYPE_RENDERTARGET))
	{
		UnloadPipelines();
	}

	if (reloadDesc->mType & (RELOAD_TYPE_RESIZE | RELOAD_TYPE_RENDERTARGET))
	{
		removeSwapChain(g_Renderer, g_SwapChain);
		removeRenderTarget(g_Renderer, g_DepthBuffer);
		removeRenderTarget(g_Renderer, g_GBuffer0);
		removeRenderTarget(g_Renderer, g_GBuffer1);
		removeRenderTarget(g_Renderer, g_GBuffer2);
		removeRenderTarget(g_Renderer, g_LightingDiffuse);
		removeRenderTarget(g_Renderer, g_LightingSpecular);
		removeRenderTarget(g_Renderer, g_SceneColor);
	}

	if (reloadDesc->mType & RELOAD_TYPE_SHADER)
	{
		UnloadShaders();
		UnloadRootSignatures();
		UnloadDescriptorSets();
	}
}

void TR_draw(TR_FrameData frameData)
{
	// Build camera view and projection
	{
		vec4 col0 = vec4(frameData.viewMatrix[0], frameData.viewMatrix[1], frameData.viewMatrix[2], frameData.viewMatrix[3]);
		vec4 col1 = vec4(frameData.viewMatrix[4], frameData.viewMatrix[5], frameData.viewMatrix[6], frameData.viewMatrix[7]);
		vec4 col2 = vec4(frameData.viewMatrix[8], frameData.viewMatrix[9], frameData.viewMatrix[10], frameData.viewMatrix[11]);
		vec4 col3 = vec4(frameData.viewMatrix[12], frameData.viewMatrix[13], frameData.viewMatrix[14], frameData.viewMatrix[15]);
		mat4 viewMat = mat4(col0, col1, col2, col3);

		col0 = vec4(frameData.projectionMatrix[0], frameData.projectionMatrix[1], frameData.projectionMatrix[2], frameData.projectionMatrix[3]);
		col1 = vec4(frameData.projectionMatrix[4], frameData.projectionMatrix[5], frameData.projectionMatrix[6], frameData.projectionMatrix[7]);
		col2 = vec4(frameData.projectionMatrix[8], frameData.projectionMatrix[9], frameData.projectionMatrix[10], frameData.projectionMatrix[11]);
		col3 = vec4(frameData.projectionMatrix[12], frameData.projectionMatrix[13], frameData.projectionMatrix[14], frameData.projectionMatrix[15]);
		mat4 projMat = mat4(col0, col1, col2, col3);

		g_UniformFrameData.m_ProjectionView = projMat * viewMat;
		g_UniformFrameData.m_ProjectionViewInverted = ::inverse(g_UniformFrameData.m_ProjectionView);
		g_UniformFrameData.m_Position = vec4(frameData.position[0], frameData.position[1], frameData.position[2], 1.0f);
		g_UniformFrameData.m_DirectionalLightsBufferIndex = frameData.directionalLightsBufferIndex;
		g_UniformFrameData.m_PointLightsBufferIndex = frameData.pointLightsBufferIndex;
		g_UniformFrameData.m_DirectionalLightsCount = frameData.directionalLightsCount;
		g_UniformFrameData.m_PointLightsCount = frameData.pointLightsCount;

		viewMat.setTranslation(vec3(0));
		g_UniformFrameDataSkybox.m_ProjectionView = projMat * viewMat;
		g_UniformFrameDataSkybox.m_ProjectionViewInverted = ::inverse(g_UniformFrameDataSkybox.m_ProjectionView);
		g_UniformFrameDataSkybox.m_Position = vec4(frameData.position[0], frameData.position[1], frameData.position[2], 1.0f);
	}

	if (g_SwapChain->mEnableVsync != g_AppSettings->vSyncEnabled)
	{
		waitQueueIdle(g_GraphicsQueue);
		::toggleVSync(g_Renderer, &g_SwapChain);
	}

	uint32_t swapchainImageIndex;
	acquireNextImage(g_Renderer, g_SwapChain, g_ImageAcquiredSemaphore, NULL, &swapchainImageIndex);

	GpuCmdRingElement elem = getNextGpuCmdRingElement(&g_GraphicsCmdRing, true, 1);

	// Stall if CPU is running "g_DataBufferCount" frames ahead of GPU
	FenceStatus fenceStatus;
	getFenceStatus(g_Renderer, elem.pFence, &fenceStatus);
	if (fenceStatus == FENCE_STATUS_INCOMPLETE)
		waitForFences(g_Renderer, 1, &elem.pFence);

	// Reset cmd pool for this frame
	resetCmdPool(g_Renderer, elem.pCmdPool);

	Cmd *cmd = elem.pCmds[0];
	beginCmd(cmd);

	// TODO(gmodarelli): Init profiler
	// cmdBeginGpuFrameProfile(cmd, g_GpuProfileToken);

	// // Skybox Pass
	// {
	// 	LoadActionsDesc loadActions = {};
	// 	loadActions.mLoadActionsColor[0] = LOAD_ACTION_DONTCARE;
	// 	loadActions.mLoadActionDepth = LOAD_ACTION_CLEAR;
	// 	loadActions.mClearDepth = g_DepthBuffer->mClearValue;
	// 	cmdBindRenderTargets(cmd, 1, &pRenderTarget, g_DepthBuffer, &loadActions, NULL, NULL, -1, -1);
	// 	cmdSetViewport(cmd, 0.0f, 0.0f, (float)pRenderTarget->mWidth, (float)pRenderTarget->mHeight, 0.0f, 1.0f);
	// 	cmdSetScissor(cmd, 0, 0, pRenderTarget->mWidth, pRenderTarget->mHeight);

	// 	BufferUpdateDesc camBufferSkyboxUpdateDesc = {g_UniformBufferCameraSkybox[g_FrameIndex]};
	// 	beginUpdateResource(&camBufferSkyboxUpdateDesc);
	// 	memcpy(camBufferSkyboxUpdateDesc.pMappedData, &g_UniformFrameDataSkybox, sizeof(g_UniformFrameDataSkybox));
	// 	endUpdateResource(&camBufferSkyboxUpdateDesc);

	// 	const uint32_t skyboxStride = sizeof(float) * 4;
	// 	cmdBindPipeline(cmd, g_PipelineSkybox);
	// 	cmdBindDescriptorSet(cmd, 0, g_DescriptorSetSkybox[0]);
	// 	cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetSkybox[1]);
	// 	cmdBindVertexBuffer(cmd, 1, &g_VertexBufferSkybox, &skyboxStride, NULL);
	// 	cmdDraw(cmd, 36, 0);
	// 	cmdSetViewport(cmd, 0.0f, 0.0f, (float)pRenderTarget->mWidth, (float)pRenderTarget->mHeight, 0.0f, 1.0f);
	// }

	BufferUpdateDesc camBufferUpdateDesc = {g_UniformBufferCamera[g_FrameIndex]};
	beginUpdateResource(&camBufferUpdateDesc);
	memcpy(camBufferUpdateDesc.pMappedData, &g_UniformFrameData, sizeof(g_UniformFrameData));
	endUpdateResource(&camBufferUpdateDesc);

	// GBuffer Pass
	{
		RenderTarget* renderTargets[] = { g_GBuffer0, g_GBuffer1, g_GBuffer2 };
		uint32_t gBufferTargetsCount = sizeof(renderTargets) / sizeof(renderTargets[0]);
		assert(gBufferTargetsCount == 3);

		RenderTargetBarrier barriers[] = {
			{ renderTargets[0], RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
			{ renderTargets[1], RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
			{ renderTargets[2], RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
			{ g_DepthBuffer, RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_DEPTH_WRITE },
		};
		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, gBufferTargetsCount + 1, barriers);

		LoadActionsDesc loadActions = {};
		loadActions.mLoadActionsColor[0] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[0] = renderTargets[0]->mClearValue;
		loadActions.mLoadActionsColor[1] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[1] = renderTargets[1]->mClearValue;
		loadActions.mLoadActionsColor[2] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[2] = renderTargets[2]->mClearValue;
		loadActions.mLoadActionDepth = LOAD_ACTION_CLEAR;
		loadActions.mClearDepth = g_DepthBuffer->mClearValue;
		cmdBindRenderTargets(cmd, gBufferTargetsCount, renderTargets, g_DepthBuffer, &loadActions, NULL, NULL, -1, -1);
		cmdSetViewport(cmd, 0.0f, 0.0f, (float)renderTargets[0]->mWidth, (float)renderTargets[0]->mHeight, 0.0f, 1.0f);
		cmdSetScissor(cmd, 0, 0, renderTargets[0]->mWidth, renderTargets[0]->mHeight);

		// Terrain Pass
		{
			cmdBindPipeline(cmd, g_PipelineTerrain);
			cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetTerrain);

			uint32_t rootConstantIndex = getDescriptorIndexFromName(g_RootSignatureTerrain, "RootConstant");

			for (uint32_t i = 0; i < g_TerrainDrawCallsCount; i++)
			{
				const TR_DrawCallInstanced *drawCall = &g_TerrainDrawCalls[i];
				const TR_DrawCallPushConstants *pushConstants = &g_TerrainPushConstants[i];
				const Mesh *mesh = &g_Meshes[drawCall->meshHandle.ID];

				// TODO(gmodarelli): Load a default mesh if not loaded yet?
				if (mesh->loaded)
				{
					Buffer *vertexBuffers[] = {
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_POSITION]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_NORMAL]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TANGENT]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TEXCOORD0]].pBuffer,
					};

					cmdBindVertexBuffer(cmd, TF_ARRAY_COUNT(vertexBuffers), vertexBuffers, mesh->geometry->mVertexStrides, NULL);
					cmdBindIndexBuffer(cmd, mesh->geometryBuffer->mIndex.pBuffer, mesh->geometry->mIndexType, NULL);
					cmdBindPushConstants(cmd, g_RootSignatureTerrain, rootConstantIndex, (void*)pushConstants);

					cmdDrawIndexedInstanced(
						cmd,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mIndexCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mInstanceCount* drawCall->instanceCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mVertexOffset,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex + drawCall->startInstanceLocation);
				}
			}
		}

		// Lit Masked Pass
		{
			cmdBindPipeline(cmd, g_PipelineLitMasked);
			cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetLitMasked);

			uint32_t rootConstantIndex = getDescriptorIndexFromName(g_RootSignatureLitMasked, "RootConstant");

			for (uint32_t i = 0; i < g_LitMaskedDrawCallsCount; i++)
			{
				const TR_DrawCallInstanced* drawCall = &g_LitMaskedDrawCalls[i];
				const TR_DrawCallPushConstants* pushConstants = &g_LitMaskedPushConstants[i];
				const Mesh* mesh = &g_Meshes[drawCall->meshHandle.ID];

				// TODO(gmodarelli): Load a default mesh if not loaded yet?
				if (mesh->loaded)
				{
					Buffer* vertexBuffers[] = {
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_POSITION]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_NORMAL]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TANGENT]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TEXCOORD0]].pBuffer,
					};

					cmdBindVertexBuffer(cmd, TF_ARRAY_COUNT(vertexBuffers), vertexBuffers, mesh->geometry->mVertexStrides, NULL);
					cmdBindIndexBuffer(cmd, mesh->geometryBuffer->mIndex.pBuffer, mesh->geometry->mIndexType, NULL);
					cmdBindPushConstants(cmd, g_RootSignatureLitMasked, rootConstantIndex, (void*)pushConstants);

					cmdDrawIndexedInstanced(
						cmd,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mIndexCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mInstanceCount * drawCall->instanceCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mVertexOffset,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex + drawCall->startInstanceLocation);
				}
			}
		}

		// Lit Opaque Pass
		{
			cmdBindPipeline(cmd, g_PipelineLitOpaque);
			cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetLitOpaque);

			uint32_t rootConstantIndex = getDescriptorIndexFromName(g_RootSignatureLitOpaque, "RootConstant");

			for (uint32_t i = 0; i < g_LitOpaqueDrawCallsCount; i++)
			{
				const TR_DrawCallInstanced* drawCall = &g_LitOpaqueDrawCalls[i];
				const TR_DrawCallPushConstants* pushConstants = &g_LitOpaquePushConstants[i];
				const Mesh* mesh = &g_Meshes[drawCall->meshHandle.ID];

				// TODO(gmodarelli): Load a default mesh if not loaded yet?
				if (mesh->loaded)
				{
					Buffer* vertexBuffers[] = {
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_POSITION]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_NORMAL]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TANGENT]].pBuffer,
						mesh->geometryBuffer->mVertex[mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TEXCOORD0]].pBuffer,
					};

					cmdBindVertexBuffer(cmd, TF_ARRAY_COUNT(vertexBuffers), vertexBuffers, mesh->geometry->mVertexStrides, NULL);
					cmdBindIndexBuffer(cmd, mesh->geometryBuffer->mIndex.pBuffer, mesh->geometry->mIndexType, NULL);
					cmdBindPushConstants(cmd, g_RootSignatureLitOpaque, rootConstantIndex, (void*)pushConstants);

					cmdDrawIndexedInstanced(
						cmd,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mIndexCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mInstanceCount * drawCall->instanceCount,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mVertexOffset,
						mesh->geometry->pDrawArgs[drawCall->subMeshIndex].mStartIndex + drawCall->startInstanceLocation);
				}
			}
		}
		cmdBindRenderTargets(cmd, 0, NULL, NULL, NULL, NULL, NULL, -1, -1);

		barriers[0] = { renderTargets[0], RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		barriers[1] = { renderTargets[1], RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		barriers[2] = { renderTargets[2], RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		barriers[3] = { g_DepthBuffer, RESOURCE_STATE_DEPTH_WRITE, RESOURCE_STATE_SHADER_RESOURCE };
		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, gBufferTargetsCount + 1, barriers);
	}

	// Deferred Shading
	{
		RenderTargetBarrier barriers[] = {
			{ g_LightingDiffuse, RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
			{ g_LightingSpecular, RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
		};
		uint32_t barriersCount = sizeof(barriers) / sizeof(barriers[0]);
		assert(barriersCount == 2);

		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, barriersCount, barriers);
		RenderTarget* renderTargets[] = { g_LightingDiffuse, g_LightingSpecular };

		LoadActionsDesc loadActions = {};
		loadActions.mLoadActionsColor[0] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[0] = renderTargets[0]->mClearValue;
		loadActions.mLoadActionsColor[1] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[1] = renderTargets[1]->mClearValue;
		cmdBindRenderTargets(cmd, barriersCount, renderTargets, NULL, &loadActions, NULL, NULL, -1, 1);

		cmdBindPipeline(cmd, g_PipelineDeferredShading);
		cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetDeferredShading[0]);
		cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetDeferredShading[1]);
		cmdSetViewport(cmd, 0.0f, 0.0f, (float)renderTargets[0]->mWidth, (float)renderTargets[0]->mHeight, 0.0f, 1.0f);
		cmdDraw(cmd, 3, 0);
		cmdBindRenderTargets(cmd, 0, NULL, NULL, NULL, NULL, NULL, -1, -1);

		barriers[0] = { g_LightingDiffuse, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		barriers[1] = { g_LightingSpecular, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, barriersCount, barriers);
	}

	// Tonemapper
	{
		RenderTargetBarrier barriers[] = {
			// { g_SceneColor, RESOURCE_STATE_SHADER_RESOURCE, RESOURCE_STATE_RENDER_TARGET },
			{ g_SwapChain->ppRenderTargets[swapchainImageIndex], RESOURCE_STATE_PRESENT, RESOURCE_STATE_RENDER_TARGET },
		};
		uint32_t barriersCount = sizeof(barriers) / sizeof(barriers[0]);
		assert(barriersCount == 1);

		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, barriersCount, barriers);
		// RenderTarget* renderTargets[] = { g_SceneColor };
		RenderTarget* renderTargets[] = { g_SwapChain->ppRenderTargets[swapchainImageIndex] };

		LoadActionsDesc loadActions = {};
		loadActions.mLoadActionsColor[0] = LOAD_ACTION_CLEAR;
		loadActions.mClearColorValues[0] = renderTargets[0]->mClearValue;
		cmdBindRenderTargets(cmd, barriersCount, renderTargets, NULL, &loadActions, NULL, NULL, -1, 1);

		cmdBindPipeline(cmd, g_PipelineTonemapper);
		cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetTonemapper);
		cmdSetViewport(cmd, 0.0f, 0.0f, (float)renderTargets[0]->mWidth, (float)renderTargets[0]->mHeight, 0.0f, 1.0f);
		cmdDraw(cmd, 3, 0);
		cmdBindRenderTargets(cmd, 0, NULL, NULL, NULL, NULL, NULL, -1, -1);

		// barriers[0] = { g_SceneColor, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_SHADER_RESOURCE };
		barriers[0] = { g_SwapChain->ppRenderTargets[swapchainImageIndex], RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_PRESENT };
		cmdResourceBarrier(cmd, 0, NULL, 0, NULL, barriersCount, barriers);
	}

	// Blit to swapchain
	// {
	//	RenderTarget *pRenderTarget = g_SwapChain->ppRenderTargets[swapchainImageIndex];
	// 	RenderTargetBarrier barriers[] = {
	// 		{ pRenderTarget, RESOURCE_STATE_PRESENT, RESOURCE_STATE_RENDER_TARGET },
	// 	};
	// 	cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, barriers);

	// 	LoadActionsDesc loadActions = {};
	// 	loadActions.mLoadActionsColor[0] = LOAD_ACTION_CLEAR;
	// 	cmdBindRenderTargets(cmd, 1, &pRenderTarget, NULL, &loadActions, NULL, NULL, -1, 1);

	// 	cmdBindPipeline(cmd, g_PipelineDeferredShading);
	// 	cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetDeferredShading[0]);
	// 	cmdBindDescriptorSet(cmd, g_FrameIndex, g_DescriptorSetDeferredShading[1]);
	// 	cmdSetViewport(cmd, 0.0f, 0.0f, (float)pRenderTarget->mWidth, (float)pRenderTarget->mHeight, 0.0f, 1.0f);
	// 	cmdDraw(cmd, 3, 0);

	// 	barriers[0] = {pRenderTarget, RESOURCE_STATE_RENDER_TARGET, RESOURCE_STATE_PRESENT};
	// 	cmdResourceBarrier(cmd, 0, NULL, 0, NULL, 1, barriers);
	// }

	// TODO(gmodarelli): Init profiler
	// cmdEndGpuFrameProfile(cmd, m_GpuProfileToken);

	endCmd(cmd);

	FlushResourceUpdateDesc flushUpdateDesc = {};
	flushUpdateDesc.mNodeIndex = 0;
	flushResourceUpdates(&flushUpdateDesc);
	Semaphore *waitSemaphores[2] = {flushUpdateDesc.pOutSubmittedSemaphore, g_ImageAcquiredSemaphore};

	QueueSubmitDesc submitDesc = {};
	submitDesc.mCmdCount = 1;
	submitDesc.mSignalSemaphoreCount = 1;
	submitDesc.mWaitSemaphoreCount = TF_ARRAY_COUNT(waitSemaphores);
	submitDesc.ppCmds = &cmd;
	submitDesc.ppSignalSemaphores = &elem.pSemaphore;
	submitDesc.ppWaitSemaphores = waitSemaphores;
	submitDesc.pSignalFence = elem.pFence;
	queueSubmit(g_GraphicsQueue, &submitDesc);
	QueuePresentDesc presentDesc = {};
	presentDesc.mIndex = swapchainImageIndex;
	presentDesc.mWaitSemaphoreCount = 1;
	presentDesc.pSwapChain = g_SwapChain;
	presentDesc.ppWaitSemaphores = &elem.pSemaphore;
	presentDesc.mSubmitDone = true;

	queuePresent(g_GraphicsQueue, &presentDesc);
	// TODO(gmodarelli): Init profiler
	// flipProfiler();

	g_FrameIndex = (g_FrameIndex + 1) % g_DataBufferCount;
}

TR_BufferHandle TR_createBuffer(TR_Slice initialData, uint32_t dataStride, const char *debugName)
{
	assert(g_GpuBufferCount < g_GpuBufferMaxCount - 1);
	TR_BufferHandle result = {g_GpuBufferCount++};
	Buffer *buffer = NULL;

	BufferLoadDesc desc = {};
	desc.mDesc.mDescriptors = DESCRIPTOR_TYPE_BUFFER_RAW;
	desc.mDesc.mFlags = BUFFER_CREATION_FLAG_NO_DESCRIPTOR_VIEW_CREATION;
	desc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_GPU_ONLY;
	desc.mDesc.mSize = initialData.dataSize;
	// NOTE(gmodarelli): The persistent SRV uses a R32_TYPELESS representation, so we need to provide an element count in terms of 32bit data
	desc.mDesc.mElementCount = (uint32_t)(initialData.dataSize / sizeof(uint32_t));
	desc.mDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
	if (initialData.data)
	{
		desc.pData = initialData.data;
	}
	desc.ppBuffer = &buffer;

	SyncToken token = {};
	addResource(&desc, &token);
	waitForToken(&token);

	DECLARE_RENDERER_FUNCTION(void, addPersistentBufferSrv, Renderer *pRenderer, const BufferDesc *pDesc, Buffer **pp_buffer);
	addPersistentBufferSrv(g_Renderer, &desc.mDesc, &buffer);

	g_GpuBuffers[result.ID] = buffer;
	return result;
}

void TR_updateBuffer(TR_Slice data, TR_BufferHandle bufferHandle)
{
	Buffer *buffer = g_GpuBuffers[bufferHandle.ID];
	assert(buffer);

	BufferUpdateDesc updateDesc = {buffer};
	beginUpdateResource(&updateDesc);
	memcpy(updateDesc.pMappedData, data.data, data.dataSize);
	endUpdateResource(&updateDesc);
}

uint32_t TR_bufferBindlessIndex(TR_BufferHandle bufferHandle)
{
	Buffer *buffer = g_GpuBuffers[bufferHandle.ID];
	assert(buffer);

	return (uint32_t)buffer->mDx.mPersistentGPUDescriptors;
}

TR_MeshHandle TR_loadMesh(const char *path)
{
	assert(g_MeshCount < g_MeshCountMax - 1);
	TR_MeshHandle result = {g_MeshCount++};

	Mesh *mesh = &g_Meshes[result.ID];

	mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_POSITION] = 0;
	mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_NORMAL] = 1;
	mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TANGENT] = 2;
	mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_TEXCOORD0] = 3;
	// mesh->geometryBufferLayoutDesc.mSemanticBindings[SEMANTIC_COLOR] = 4;

	mesh->geometryBufferLayoutDesc.mVerticesStrides[0] = sizeof(float3);
	mesh->geometryBufferLayoutDesc.mVerticesStrides[1] = sizeof(uint32_t);
	mesh->geometryBufferLayoutDesc.mVerticesStrides[2] = sizeof(uint32_t);
	mesh->geometryBufferLayoutDesc.mVerticesStrides[3] = sizeof(uint32_t);
	// mesh->geometryBufferLayoutDesc.mVerticesStrides[4] = sizeof(uint32_t);

	GeometryBufferLoadDesc geometryBufferLoadDesc = {};
	geometryBufferLoadDesc.mStartState = RESOURCE_STATE_COPY_DEST;
	geometryBufferLoadDesc.pOutGeometryBuffer = &mesh->geometryBuffer;

	uint32_t maxIndexCount = 1024 * 1024;
	uint32_t maxVertexCount = 1024 * 1024;
	geometryBufferLoadDesc.mIndicesSize = sizeof(uint32_t) * maxIndexCount;
	geometryBufferLoadDesc.mVerticesSizes[0] = mesh->geometryBufferLayoutDesc.mVerticesStrides[0] * maxVertexCount;
	geometryBufferLoadDesc.mVerticesSizes[1] = mesh->geometryBufferLayoutDesc.mVerticesStrides[1] * maxVertexCount;
	geometryBufferLoadDesc.mVerticesSizes[2] = mesh->geometryBufferLayoutDesc.mVerticesStrides[2] * maxVertexCount;
	geometryBufferLoadDesc.mVerticesSizes[3] = mesh->geometryBufferLayoutDesc.mVerticesStrides[3] * maxVertexCount;
	// geometryBufferLoadDesc.mVerticesSizes[4] = mesh->geometryBufferLayoutDesc.mVerticesStrides[3] * maxVertexCount;

	geometryBufferLoadDesc.pNameIndexBuffer = "Indices";
	geometryBufferLoadDesc.pNamesVertexBuffers[0] = "Positions";
	geometryBufferLoadDesc.pNamesVertexBuffers[1] = "Normals";
	geometryBufferLoadDesc.pNamesVertexBuffers[2] = "Tangents";
	geometryBufferLoadDesc.pNamesVertexBuffers[3] = "UVs";
	// geometryBufferLoadDesc.pNamesVertexBuffers[4] = "Color";

	addGeometryBuffer(&geometryBufferLoadDesc);

	GeometryLoadDesc loadDesc = {};
	loadDesc.pFileName = path;
	loadDesc.pVertexLayout = &g_VertexLayoutDefault;
	loadDesc.pGeometryBuffer = mesh->geometryBuffer;
	loadDesc.pGeometryBufferLayoutDesc = &mesh->geometryBufferLayoutDesc;
	loadDesc.ppGeometry = &mesh->geometry;
	loadDesc.ppGeometryData = &mesh->geometryData;

	SyncToken token = {};
	addResource(&loadDesc, &token);
	waitForToken(&token);

	mesh->loaded = true;

	return result;
}

uint32_t TR_getSubMeshCount(TR_MeshHandle meshHandle)
{
	const Mesh *mesh = &g_Meshes[meshHandle.ID];
	if (!mesh)
		return 0;
	if (!mesh->loaded)
		return 0;

	if (mesh->geometry->mDrawArgCount > 1) {
		return mesh->geometry->mDrawArgCount;
	}

	return mesh->geometry->mDrawArgCount;
}

TR_TextureHandle TR_loadTexture(const char *path)
{
	assert(g_TextureCount < g_TextureCountMax - 1);
	TR_TextureHandle result = {g_TextureCount++};
	Texture *texture = NULL;

	TextureDesc desc = {};
	desc.bBindless = true;
	TextureLoadDesc textureLoadDesc = {};
	textureLoadDesc.pFileName = path;
	textureLoadDesc.pDesc = &desc;
	textureLoadDesc.ppTexture = &texture;

	SyncToken token = {};
	addResource(&textureLoadDesc, &token);
	waitForToken(&token);

	assert(texture);
	g_Textures[result.ID] = texture;
	return result;
}

TR_API TR_TextureHandle TR_loadTextureFromMemory(uint32_t width, uint32_t height, TinyImageFormat format, TR_Slice dataSlice, const char *debugName)
{
	assert(g_TextureCount < g_TextureCountMax - 1);
	TR_TextureHandle result = {g_TextureCount++};
	Texture *texture = NULL;

	TextureDesc desc = {};
	desc.mWidth = width;
	desc.mHeight = height;
	desc.mFormat = format;
	desc.mDepth = 1;
	desc.mMipLevels = 1;
	desc.mArraySize = 1;
	desc.mSampleCount = SAMPLE_COUNT_1;
	desc.mSampleQuality = 0;
	desc.pName = debugName;
	desc.bBindless = true;
	desc.mDescriptors = DESCRIPTOR_TYPE_TEXTURE;
	TextureLoadDesc textureLoadDesc = {};
	textureLoadDesc.pDesc = &desc;
	textureLoadDesc.ppTexture = &texture;
	textureLoadDesc.pFileName = NULL;
	textureLoadDesc.pTextureData = dataSlice.data;
	textureLoadDesc.mTextureDataSize = dataSlice.dataSize;

	SyncToken token = {};
	addResource(&textureLoadDesc, &token);
	waitForToken(&token);

	assert(texture);
	g_Textures[result.ID] = texture;
	return result;
}

uint32_t TR_textureBindlessIndex(TR_TextureHandle textureHandle)
{
	if (textureHandle.ID == (uint32_t)-1)
		return (uint32_t)-1;

	Texture *texture = g_Textures[textureHandle.ID];
	assert(texture);

	return (uint32_t)texture->mDx.mPersistentDescriptors;
}

void TR_registerTerrainDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice)
{
	g_TerrainDrawCallsCount = (uint32_t)(drawCallsSlice.dataSize / sizeof(TR_DrawCallInstanced));
	assert(g_TerrainDrawCallsCount < g_TerrainDrawCallsCountMax);
	memcpy(g_TerrainDrawCalls, drawCallsSlice.data, drawCallsSlice.dataSize);
	memcpy(g_TerrainPushConstants, pushConstantsSlice.data, pushConstantsSlice.dataSize);
}

void TR_registerLitOpaqueDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice)
{
	g_LitOpaqueDrawCallsCount = (uint32_t)(drawCallsSlice.dataSize / sizeof(TR_DrawCallInstanced));
	assert(g_LitOpaqueDrawCallsCount < g_LitOpaqueDrawCallsCountMax);
	memcpy(g_LitOpaqueDrawCalls, drawCallsSlice.data, drawCallsSlice.dataSize);
	memcpy(g_LitOpaquePushConstants, pushConstantsSlice.data, pushConstantsSlice.dataSize);
}

void TR_registerLitMaskedDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice)
{
	g_LitMaskedDrawCallsCount = (uint32_t)(drawCallsSlice.dataSize / sizeof(TR_DrawCallInstanced));
	assert(g_LitMaskedDrawCallsCount < g_LitMaskedDrawCallsCountMax);
	memcpy(g_LitMaskedDrawCalls, drawCallsSlice.data, drawCallsSlice.dataSize);
	memcpy(g_LitMaskedPushConstants, pushConstantsSlice.data, pushConstantsSlice.dataSize);
}

bool AddSwapChain()
{
	WindowHandle windowHandle = {};
	windowHandle.type = WINDOW_HANDLE_TYPE_WIN32;
	windowHandle.window = (HWND)g_AppSettings->windowHandle;

	SwapChainDesc swapChainDesc = {};
	swapChainDesc.mWindowHandle = windowHandle;
	swapChainDesc.mPresentQueueCount = 1;
	swapChainDesc.ppPresentQueues = &g_GraphicsQueue;
	swapChainDesc.mWidth = g_AppSettings->width;
	swapChainDesc.mHeight = g_AppSettings->height;
	swapChainDesc.mImageCount = getRecommendedSwapchainImageCount(g_Renderer, &windowHandle);
	swapChainDesc.mColorFormat = getSupportedSwapchainFormat(g_Renderer, &swapChainDesc, COLOR_SPACE_SDR_SRGB);
	swapChainDesc.mColorSpace = COLOR_SPACE_SDR_SRGB;
	swapChainDesc.mEnableVsync = g_AppSettings->vSyncEnabled;
	swapChainDesc.mFlags = SWAP_CHAIN_CREATION_FLAG_ENABLE_FOVEATED_RENDERING_VR;

	TinyImageFormat hdrFormat = getSupportedSwapchainFormat(g_Renderer, &swapChainDesc, COLOR_SPACE_P2020);
	const bool wantsHDR = OUTPUT_MODE_P2020 == g_AppSettings->outputMode;
	const bool supportsHDR = g_Renderer->pGpu->mSettings.mHDRSupported && hdrFormat != TinyImageFormat_UNDEFINED;
	if (wantsHDR)
	{
		if (supportsHDR)
		{
			swapChainDesc.mColorFormat = hdrFormat;
			swapChainDesc.mColorSpace = COLOR_SPACE_P2020;
		}
	}

	addSwapChain(g_Renderer, &swapChainDesc, &g_SwapChain);
	return g_SwapChain != NULL;
}

bool AddRenderTargets()
{
	{
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Depth Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue.depth = 0.0f;
		rtDesc.mClearValue.stencil = 0;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_D32_SFLOAT;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_DepthBuffer);
	}

	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Base Color Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R8G8B8A8_UNORM;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_GBuffer0);
	}

	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "World Normals Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R10G10B10A2_UNORM;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_GBuffer1);
	}

	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 1.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Material Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R8G8B8A8_UNORM;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_GBuffer2);
	}

	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Lighting Diffuse Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R16G16B16A16_SFLOAT;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_LightingDiffuse);
	}
	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Lighting Specular Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R16G16B16A16_SFLOAT;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_LightingSpecular);
	}

	{
		ClearValue clearValue = { 0.0f, 0.0f, 0.0f, 0.0f };
		RenderTargetDesc rtDesc = {};
		rtDesc.pName = "Scene Color Buffer";
		rtDesc.mArraySize = 1;
		rtDesc.mClearValue = clearValue;
		rtDesc.mDepth = 1;
		rtDesc.mFormat = TinyImageFormat_R8G8B8A8_UNORM;
		rtDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
		rtDesc.mWidth = g_AppSettings->width;
		rtDesc.mHeight = g_AppSettings->height;
		rtDesc.mSampleCount = SAMPLE_COUNT_1;
		rtDesc.mSampleQuality = 0;
		rtDesc.mFlags = TEXTURE_CREATION_FLAG_ON_TILE;
		addRenderTarget(g_Renderer, &rtDesc, &g_SceneColor);
	}


	return g_DepthBuffer != NULL &&
			g_GBuffer0 != NULL &&
			g_GBuffer1 != NULL &&
			g_GBuffer2 != NULL &&
			g_LightingDiffuse != NULL &&
			g_LightingSpecular != NULL &&
			g_SceneColor != NULL;
}

void LoadStaicEntityTransforms()
{
	uint64_t dataSize = g_TerrainLod3PatchCount * sizeof(InstanceTransform);
	InstanceTransform *initialData = (InstanceTransform *)tf_malloc(dataSize);
	assert(initialData);

	uint32_t sideSize = (uint32_t)sqrt(g_TerrainLod3PatchCount);
	float spacing = 512.0f;
	uint32_t i = 0;
	for (uint32_t y = 0; y < sideSize; y++)
	{
		for (uint32_t x = 0; x < sideSize; x++)
		{
			InstanceTransform *transform = &initialData[i++];
			transform->worldMatrix = mat4::identity();
			transform->worldMatrix.setTranslation(vec3(x * spacing, 0.0f, y * spacing));
		}
	}

	BufferLoadDesc desc = {};
	desc.mDesc.mDescriptors = DESCRIPTOR_TYPE_BUFFER_RAW;
	desc.mDesc.mFlags = BUFFER_CREATION_FLAG_NO_DESCRIPTOR_VIEW_CREATION;
	desc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_GPU_ONLY;
	desc.mDesc.mSize = dataSize;
	// NOTE(gmodarelli): The persistent SRV uses a R32_TYPELESS representation, so we need to provide an element count in terms of 32bit data
	desc.mDesc.mElementCount = g_TerrainLod3PatchCount * sizeof(InstanceTransform) / sizeof(uint32_t);
	desc.mDesc.mStartState = RESOURCE_STATE_SHADER_RESOURCE;
	desc.pData = initialData;
	desc.ppBuffer = &g_TerrainLod3TransformBuffer;

	SyncToken token = {};
	addResource(&desc, &token);
	waitForToken(&token);

	tf_free(initialData);

	DECLARE_RENDERER_FUNCTION(void, addPersistentBufferSrv, Renderer *pRenderer, const BufferDesc *pDesc, Buffer **pp_buffer);
	addPersistentBufferSrv(g_Renderer, &desc.mDesc, &g_TerrainLod3TransformBuffer);
}

void UnloadStaticEntityTransforms()
{
	removeResource(g_TerrainLod3TransformBuffer);
}

void LoadSkybox()
{
	g_VertexLayoutSkybox.mBindingCount = 1;
	g_VertexLayoutSkybox.mAttribCount = 1;
	g_VertexLayoutSkybox.mAttribs[0].mSemantic = SEMANTIC_POSITION;
	g_VertexLayoutSkybox.mAttribs[0].mFormat = TinyImageFormat_R32G32B32A32_SFLOAT;
	g_VertexLayoutSkybox.mAttribs[0].mBinding = 0;
	g_VertexLayoutSkybox.mAttribs[0].mLocation = 0;
	g_VertexLayoutSkybox.mAttribs[0].mOffset = 0;

	// Generate skybox vertex buffer
	float skyBoxPoints[] = {
		0.5f,
		-0.5f,
		-0.5f,
		1.0f, // -z
		-0.5f,
		-0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		0.5f,
		-0.5f,
		1.0f,
		0.5f,
		0.5f,
		-0.5f,
		1.0f,
		0.5f,
		-0.5f,
		-0.5f,
		1.0f,

		-0.5f,
		-0.5f,
		0.5f,
		1.0f, //-x
		-0.5f,
		-0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		0.5f,
		0.5f,
		1.0f,
		-0.5f,
		-0.5f,
		0.5f,
		1.0f,

		0.5f,
		-0.5f,
		-0.5f,
		1.0f, //+x
		0.5f,
		-0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		-0.5f,
		1.0f,
		0.5f,
		-0.5f,
		-0.5f,
		1.0f,

		-0.5f,
		-0.5f,
		0.5f,
		1.0f, // +z
		-0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		-0.5f,
		0.5f,
		1.0f,
		-0.5f,
		-0.5f,
		0.5f,
		1.0f,

		-0.5f,
		0.5f,
		-0.5f,
		1.0f, //+y
		0.5f,
		0.5f,
		-0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		0.5f,
		0.5f,
		0.5f,
		1.0f,
		-0.5f,
		0.5f,
		0.5f,
		1.0f,
		-0.5f,
		0.5f,
		-0.5f,
		1.0f,

		0.5f,
		-0.5f,
		0.5f,
		1.0f, //-y
		0.5f,
		-0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		-0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		-0.5f,
		-0.5f,
		1.0f,
		-0.5f,
		-0.5f,
		0.5f,
		1.0f,
		0.5f,
		-0.5f,
		0.5f,
		1.0f,
	};

	uint64_t skyBoxDataSize = 4 * 6 * 6 * sizeof(float);
	BufferLoadDesc skyboxVbDesc = {};
	skyboxVbDesc.mDesc.mDescriptors = DESCRIPTOR_TYPE_VERTEX_BUFFER;
	skyboxVbDesc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_GPU_ONLY;
	skyboxVbDesc.mDesc.mSize = skyBoxDataSize;
	skyboxVbDesc.mDesc.mStartState = RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER;
	skyboxVbDesc.pData = skyBoxPoints;
	skyboxVbDesc.ppBuffer = &g_VertexBufferSkybox;

	SyncToken token = {};
	addResource(&skyboxVbDesc, &token);

	TextureLoadDesc skyboxLoadDesc = {};
	skyboxLoadDesc.pFileName = "textures/env/sunset_fairwayEnvHDR.dds";
	skyboxLoadDesc.ppTexture = &g_TextureSkybox;
	addResource(&skyboxLoadDesc, &token);

	TextureLoadDesc irradianceLoadDesc = {};
	irradianceLoadDesc.pFileName = "textures/env/sunset_fairwayDiffuseHDR.dds";
	irradianceLoadDesc.ppTexture = &g_TextureIrradiance;
	addResource(&irradianceLoadDesc, &token);

	TextureLoadDesc specularLoadDesc = {};
	specularLoadDesc.pFileName = "textures/env/sunset_fairwaySpecularHDR.dds";
	specularLoadDesc.ppTexture = &g_TextureSpecular;
	addResource(&specularLoadDesc, &token);

	TextureLoadDesc brdfLoadDesc = {};
	brdfLoadDesc.pFileName = "textures/env/sunset_fairwayBrdf.dds";
	brdfLoadDesc.ppTexture = &g_TextureBRDFLut;
	addResource(&brdfLoadDesc, &token);

	waitForToken(&token);
}

void UnloadSkybox()
{
	removeResource(g_TextureSkybox);
	removeResource(g_TextureIrradiance);
	removeResource(g_TextureSpecular);
	removeResource(g_TextureBRDFLut);
	removeResource(g_VertexBufferSkybox);
}

void AddUniformBuffers()
{
	// Uniform buffer for camera data
	BufferLoadDesc cameraUBDesc = {};
	cameraUBDesc.mDesc.mDescriptors = DESCRIPTOR_TYPE_UNIFORM_BUFFER;
	cameraUBDesc.mDesc.mMemoryUsage = RESOURCE_MEMORY_USAGE_CPU_TO_GPU;
	cameraUBDesc.mDesc.mSize = sizeof(UniformFrameData);
	cameraUBDesc.mDesc.mFlags = BUFFER_CREATION_FLAG_PERSISTENT_MAP_BIT;
	cameraUBDesc.pData = NULL;

	for (uint32_t i = 0; i < g_DataBufferCount; ++i)
	{
		cameraUBDesc.ppBuffer = &g_UniformBufferCameraSkybox[i];
		addResource(&cameraUBDesc, NULL);

		cameraUBDesc.ppBuffer = &g_UniformBufferCamera[i];
		addResource(&cameraUBDesc, NULL);
	}
}

void RemoveUniformBuffers()
{
	for (uint32_t i = 0; i < g_DataBufferCount; ++i)
	{
		removeResource(g_UniformBufferCamera[i]);
		removeResource(g_UniformBufferCameraSkybox[i]);
	}
}

void LoadShaders()
{
	ShaderLoadDesc skyboxShaderDesc = {};
	skyboxShaderDesc.mStages[0].pFileName = "skybox.vert";
	skyboxShaderDesc.mStages[1].pFileName = "skybox.frag";
	addShader(g_Renderer, &skyboxShaderDesc, &g_ShaderSkybox);

	ShaderLoadDesc terrainShaderDesc = {};
	terrainShaderDesc.mStages[0].pFileName = "terrain.vert";
	terrainShaderDesc.mStages[1].pFileName = "terrain.frag";
	addShader(g_Renderer, &terrainShaderDesc, &g_ShaderTerrain);

	ShaderLoadDesc litOpaqueShaderDesc = {};
	litOpaqueShaderDesc.mStages[0].pFileName = "lit.vert";
	litOpaqueShaderDesc.mStages[1].pFileName = "lit_opaque.frag";
	addShader(g_Renderer, &litOpaqueShaderDesc, &g_ShaderLitOpaque);

	ShaderLoadDesc litMaskedShaderDesc = {};
	litMaskedShaderDesc.mStages[0].pFileName = "lit.vert";
	litMaskedShaderDesc.mStages[1].pFileName = "lit_masked.frag";
	addShader(g_Renderer, &litMaskedShaderDesc, &g_ShaderLitMasked);

	ShaderLoadDesc deferredShadingShaderDesc = {};
	deferredShadingShaderDesc.mStages[0].pFileName = "fullscreen.vert";
	deferredShadingShaderDesc.mStages[1].pFileName = "deferred_shading.frag";
	addShader(g_Renderer, &deferredShadingShaderDesc, &g_ShaderDeferredShading);

	ShaderLoadDesc tonemapperShaderDesc = {};
	tonemapperShaderDesc.mStages[0].pFileName = "fullscreen.vert";
	tonemapperShaderDesc.mStages[1].pFileName = "tonemapper.frag";
	addShader(g_Renderer, &tonemapperShaderDesc, &g_ShaderTonemapper);
}

void LoadRootSignatures()
{
	{
		const char *staticSamplerNames[] = {"materialSampler", "brdfIntegrationSampler", "environmentSampler", "skyboxSampler", "pointSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearRepeat,
			g_SamplerBilinearClampToEdge,
			g_SamplerBilinearRepeat,
			g_SamplerBilinearRepeat,
			g_SamplerPointClampToBorder};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc skyboxRootDesc = {};
		skyboxRootDesc.mStaticSamplerCount = numStaticSamplers;
		skyboxRootDesc.ppStaticSamplerNames = staticSamplerNames;
		skyboxRootDesc.ppStaticSamplers = staticSamplers;
		skyboxRootDesc.ppShaders = &g_ShaderSkybox;
		skyboxRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &skyboxRootDesc, &g_RootSignatureSkybox);
	}

	{
		const char *staticSamplerNames[] = {"bilinearRepeatSampler", "bilinearClampSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearRepeat,
			g_SamplerBilinearClampToEdge,
		};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc terrainRootDesc = {};
		terrainRootDesc.mStaticSamplerCount = numStaticSamplers;
		terrainRootDesc.ppStaticSamplerNames = staticSamplerNames;
		terrainRootDesc.ppStaticSamplers = staticSamplers;
		terrainRootDesc.ppShaders = &g_ShaderTerrain;
		terrainRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &terrainRootDesc, &g_RootSignatureTerrain);
	}

	{
		const char *staticSamplerNames[] = {"bilinearRepeatSampler", "bilinearClampSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearRepeat,
			g_SamplerBilinearClampToEdge,
		};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc litOpaqueRootDesc = {};
		litOpaqueRootDesc.mStaticSamplerCount = numStaticSamplers;
		litOpaqueRootDesc.ppStaticSamplerNames = staticSamplerNames;
		litOpaqueRootDesc.ppStaticSamplers = staticSamplers;
		litOpaqueRootDesc.ppShaders = &g_ShaderLitOpaque;
		litOpaqueRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &litOpaqueRootDesc, &g_RootSignatureLitOpaque);
	}

	{
		const char *staticSamplerNames[] = {"bilinearRepeatSampler", "bilinearClampSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearRepeat,
			g_SamplerBilinearClampToEdge,
		};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc litMaskedRootDesc = {};
		litMaskedRootDesc.mStaticSamplerCount = numStaticSamplers;
		litMaskedRootDesc.ppStaticSamplerNames = staticSamplerNames;
		litMaskedRootDesc.ppStaticSamplers = staticSamplers;
		litMaskedRootDesc.ppShaders = &g_ShaderLitMasked;
		litMaskedRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &litMaskedRootDesc, &g_RootSignatureLitMasked);
	}

	{
		const char *staticSamplerNames[] = {"bilinearRepeatSampler", "bilinearClampSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearRepeat,
			g_SamplerBilinearClampToEdge,
		};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc deferredShadingRootDesc = {};
		deferredShadingRootDesc.mStaticSamplerCount = numStaticSamplers;
		deferredShadingRootDesc.ppStaticSamplerNames = staticSamplerNames;
		deferredShadingRootDesc.ppStaticSamplers = staticSamplers;
		deferredShadingRootDesc.ppShaders = &g_ShaderDeferredShading;
		deferredShadingRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &deferredShadingRootDesc, &g_RootSignatureDeferredShading);
	}

	{
		const char *staticSamplerNames[] = {"bilinearClampSampler"};
		Sampler *staticSamplers[] = {
			g_SamplerBilinearClampToEdge,
		};
		uint32_t numStaticSamplers = sizeof(staticSamplers) / sizeof(staticSamplers[0]);

		RootSignatureDesc tonemapperRootDesc = {};
		tonemapperRootDesc.mStaticSamplerCount = numStaticSamplers;
		tonemapperRootDesc.ppStaticSamplerNames = staticSamplerNames;
		tonemapperRootDesc.ppStaticSamplers = staticSamplers;
		tonemapperRootDesc.ppShaders = &g_ShaderTonemapper;
		tonemapperRootDesc.mShaderCount = 1;
		addRootSignature(g_Renderer, &tonemapperRootDesc, &g_RootSignatureTonemapper);
	}
}

void LoadDescriptorSets()
{
	DescriptorSetDesc setDesc = {g_RootSignatureSkybox, DESCRIPTOR_UPDATE_FREQ_NONE, 1};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetSkybox[0]);
	setDesc = {g_RootSignatureSkybox, DESCRIPTOR_UPDATE_FREQ_PER_FRAME, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetSkybox[1]);

	setDesc = {g_RootSignatureTerrain, DESCRIPTOR_UPDATE_FREQ_PER_FRAME, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetTerrain);

	setDesc = {g_RootSignatureLitOpaque, DESCRIPTOR_UPDATE_FREQ_PER_FRAME, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetLitOpaque);

	setDesc = {g_RootSignatureLitMasked, DESCRIPTOR_UPDATE_FREQ_PER_FRAME, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetLitMasked);

	setDesc = {g_RootSignatureDeferredShading, DESCRIPTOR_UPDATE_FREQ_NONE, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetDeferredShading[0]);
	setDesc = {g_RootSignatureDeferredShading, DESCRIPTOR_UPDATE_FREQ_PER_FRAME, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetDeferredShading[1]);

	setDesc = {g_RootSignatureTonemapper, DESCRIPTOR_UPDATE_FREQ_NONE, g_DataBufferCount};
	addDescriptorSet(g_Renderer, &setDesc, &g_DescriptorSetTonemapper);
}

void UnloadShaders()
{
	removeShader(g_Renderer, g_ShaderSkybox);
	removeShader(g_Renderer, g_ShaderTerrain);
	removeShader(g_Renderer, g_ShaderLitOpaque);
	removeShader(g_Renderer, g_ShaderLitMasked);
	removeShader(g_Renderer, g_ShaderDeferredShading);
	removeShader(g_Renderer, g_ShaderTonemapper);
}

void UnloadRootSignatures()
{
	removeRootSignature(g_Renderer, g_RootSignatureSkybox);
	removeRootSignature(g_Renderer, g_RootSignatureTerrain);
	removeRootSignature(g_Renderer, g_RootSignatureLitOpaque);
	removeRootSignature(g_Renderer, g_RootSignatureLitMasked);
	removeRootSignature(g_Renderer, g_RootSignatureDeferredShading);
	removeRootSignature(g_Renderer, g_RootSignatureTonemapper);
}

void UnloadDescriptorSets()
{
	removeDescriptorSet(g_Renderer, g_DescriptorSetSkybox[0]);
	removeDescriptorSet(g_Renderer, g_DescriptorSetSkybox[1]);
	removeDescriptorSet(g_Renderer, g_DescriptorSetTerrain);
	removeDescriptorSet(g_Renderer, g_DescriptorSetLitOpaque);
	removeDescriptorSet(g_Renderer, g_DescriptorSetLitMasked);
	removeDescriptorSet(g_Renderer, g_DescriptorSetDeferredShading[0]);
	removeDescriptorSet(g_Renderer, g_DescriptorSetDeferredShading[1]);
	removeDescriptorSet(g_Renderer, g_DescriptorSetTonemapper);
}

void AddStaticSamplers()
{
	SamplerDesc repeatSamplerDesc = {};
	repeatSamplerDesc.mAddressU = ADDRESS_MODE_REPEAT;
	repeatSamplerDesc.mAddressV = ADDRESS_MODE_REPEAT;
	repeatSamplerDesc.mAddressW = ADDRESS_MODE_REPEAT;

	repeatSamplerDesc.mMinFilter = FILTER_LINEAR;
	repeatSamplerDesc.mMagFilter = FILTER_LINEAR;
	repeatSamplerDesc.mMipMapMode = MIPMAP_MODE_LINEAR;
	addSampler(g_Renderer, &repeatSamplerDesc, &g_SamplerBilinearRepeat);

	repeatSamplerDesc.mMinFilter = FILTER_NEAREST;
	repeatSamplerDesc.mMagFilter = FILTER_NEAREST;
	repeatSamplerDesc.mMipMapMode = MIPMAP_MODE_NEAREST;
	addSampler(g_Renderer, &repeatSamplerDesc, &g_SamplerPointRepeat);

	SamplerDesc clampToEdgeSamplerDesc = {};
	clampToEdgeSamplerDesc.mAddressU = ADDRESS_MODE_CLAMP_TO_EDGE;
	clampToEdgeSamplerDesc.mAddressV = ADDRESS_MODE_CLAMP_TO_EDGE;
	clampToEdgeSamplerDesc.mAddressW = ADDRESS_MODE_CLAMP_TO_EDGE;

	clampToEdgeSamplerDesc.mMinFilter = FILTER_LINEAR;
	clampToEdgeSamplerDesc.mMagFilter = FILTER_LINEAR;
	clampToEdgeSamplerDesc.mMipMapMode = MIPMAP_MODE_LINEAR;
	addSampler(g_Renderer, &clampToEdgeSamplerDesc, &g_SamplerBilinearClampToEdge);

	clampToEdgeSamplerDesc.mMinFilter = FILTER_NEAREST;
	clampToEdgeSamplerDesc.mMagFilter = FILTER_NEAREST;
	clampToEdgeSamplerDesc.mMipMapMode = MIPMAP_MODE_NEAREST;
	addSampler(g_Renderer, &clampToEdgeSamplerDesc, &g_SamplerPointClampToEdge);

	SamplerDesc pointSamplerDesc = {};
	pointSamplerDesc.mMinFilter = FILTER_NEAREST;
	pointSamplerDesc.mMagFilter = FILTER_NEAREST;
	pointSamplerDesc.mMipMapMode = MIPMAP_MODE_NEAREST;
	pointSamplerDesc.mAddressU = ADDRESS_MODE_CLAMP_TO_BORDER;
	pointSamplerDesc.mAddressV = ADDRESS_MODE_CLAMP_TO_BORDER;
	pointSamplerDesc.mAddressW = ADDRESS_MODE_CLAMP_TO_BORDER;
	addSampler(g_Renderer, &pointSamplerDesc, &g_SamplerPointClampToBorder);
}

void RemoveStaticSamplers()
{
	removeSampler(g_Renderer, g_SamplerBilinearRepeat);
	removeSampler(g_Renderer, g_SamplerPointRepeat);
	removeSampler(g_Renderer, g_SamplerBilinearClampToEdge);
	removeSampler(g_Renderer, g_SamplerPointClampToEdge);
	removeSampler(g_Renderer, g_SamplerPointClampToBorder);
}

void PrepareDescriptorSets()
{
	DescriptorData params[7] = {};

	params[0].pName = "skyboxTex";
	params[0].ppTextures = &g_TextureSkybox;
	updateDescriptorSet(g_Renderer, 0, g_DescriptorSetSkybox[0], 1, params);

	for (uint32_t i = 0; i < g_DataBufferCount; ++i)
	{
		params[0].pName = "cbFrame";
		params[0].ppBuffers = &g_UniformBufferCameraSkybox[i];
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetSkybox[1], 1, params);

		params[0].pName = "brdfIntegrationMap";
		params[0].ppTextures = &g_TextureBRDFLut;
		params[1].pName = "irradianceMap";
		params[1].ppTextures = &g_TextureIrradiance;
		params[2].pName = "specularMap";
		params[2].ppTextures = &g_TextureSpecular;
		params[3].pName = "gBuffer0";
		params[3].ppTextures = &g_GBuffer0->pTexture;
		params[4].pName = "gBuffer1";
		params[4].ppTextures = &g_GBuffer1->pTexture;
		params[5].pName = "gBuffer2";
		params[5].ppTextures = &g_GBuffer2->pTexture;
		params[6].pName = "depthBuffer";
		params[6].ppTextures = &g_DepthBuffer->pTexture;
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetDeferredShading[0], 7, params);

		params[0].pName = "cbFrame";
		params[0].ppBuffers = &g_UniformBufferCamera[i];
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetTerrain, 1, params);
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetLitOpaque, 1, params);
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetLitMasked, 1, params);
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetDeferredShading[1], 1, params);

		params[0].pName = "lightingDiffuse";
		params[0].ppTextures = &g_LightingDiffuse->pTexture;
		params[1].pName = "lightingSpecular";
		params[1].ppTextures = &g_LightingSpecular->pTexture;
		updateDescriptorSet(g_Renderer, i, g_DescriptorSetTonemapper, 2, params);
	}
}

void LoadPipelines()
{
	RasterizerStateDesc rasterizerStateDescCullFront = {};
	rasterizerStateDescCullFront.mCullMode = CULL_MODE_FRONT;

	RasterizerStateDesc rasterizerStateCullNoneDesc = {};
	rasterizerStateCullNoneDesc.mCullMode = CULL_MODE_NONE;

	DepthStateDesc depthStateDescDepthTest = {};
	depthStateDescDepthTest.mDepthWrite = true;
	depthStateDescDepthTest.mDepthTest = true;
	depthStateDescDepthTest.mDepthFunc = CMP_GEQUAL;

	{
		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = 1;
		pipelineSettings.pDepthState = NULL;
		pipelineSettings.pColorFormats = &g_SwapChain->ppRenderTargets[0]->mFormat;
		pipelineSettings.mSampleCount = g_SwapChain->ppRenderTargets[0]->mSampleCount;
		pipelineSettings.mSampleQuality = g_SwapChain->ppRenderTargets[0]->mSampleQuality;
		pipelineSettings.mDepthStencilFormat = TinyImageFormat_UNDEFINED;
		pipelineSettings.pRootSignature = g_RootSignatureSkybox;
		pipelineSettings.pShaderProgram = g_ShaderSkybox;
		pipelineSettings.pVertexLayout = &g_VertexLayoutSkybox;
		pipelineSettings.pRasterizerState = &rasterizerStateCullNoneDesc;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineSkybox);
	}

	const uint32_t gBuffersCount = 3;
	TinyImageFormat gBufferTargetFormats[gBuffersCount] = { g_GBuffer0->mFormat, g_GBuffer1->mFormat, g_GBuffer2->mFormat };

	{
		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = gBuffersCount;
		pipelineSettings.pColorFormats = gBufferTargetFormats;
		pipelineSettings.pDepthState = &depthStateDescDepthTest;
		pipelineSettings.mSampleCount = SAMPLE_COUNT_1;
		pipelineSettings.mSampleQuality = 0;
		pipelineSettings.mDepthStencilFormat = g_DepthBuffer->mFormat;
		pipelineSettings.pRootSignature = g_RootSignatureTerrain;
		pipelineSettings.pShaderProgram = g_ShaderTerrain;
		pipelineSettings.pVertexLayout = &g_VertexLayoutDefault;
		pipelineSettings.pRasterizerState = &rasterizerStateDescCullFront;
		pipelineSettings.mVRFoveatedRendering = true;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineTerrain);
	}

	{
		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = gBuffersCount;
		pipelineSettings.pColorFormats = gBufferTargetFormats;
		pipelineSettings.pDepthState = &depthStateDescDepthTest;
		pipelineSettings.mSampleCount = SAMPLE_COUNT_1;
		pipelineSettings.mSampleQuality = 0;
		pipelineSettings.mDepthStencilFormat = g_DepthBuffer->mFormat;
		pipelineSettings.pRootSignature = g_RootSignatureLitOpaque;
		pipelineSettings.pShaderProgram = g_ShaderLitOpaque;
		pipelineSettings.pVertexLayout = &g_VertexLayoutDefault;
		pipelineSettings.pRasterizerState = &rasterizerStateDescCullFront;
		pipelineSettings.mVRFoveatedRendering = true;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineLitOpaque);
	}

	{
		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = gBuffersCount;
		pipelineSettings.pColorFormats = gBufferTargetFormats;
		pipelineSettings.pDepthState = &depthStateDescDepthTest;
		pipelineSettings.mSampleCount = SAMPLE_COUNT_1;
		pipelineSettings.mSampleQuality = 0;
		pipelineSettings.mDepthStencilFormat = g_DepthBuffer->mFormat;
		pipelineSettings.pRootSignature = g_RootSignatureLitMasked;
		pipelineSettings.pShaderProgram = g_ShaderLitMasked;
		pipelineSettings.pVertexLayout = &g_VertexLayoutDefault;
		pipelineSettings.pRasterizerState = &rasterizerStateCullNoneDesc;
		pipelineSettings.mVRFoveatedRendering = true;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineLitMasked);
	}

	{
		TinyImageFormat renderTargets[] = { g_LightingDiffuse->mFormat, g_LightingSpecular->mFormat };
		uint32_t renderTargetsCount = sizeof(renderTargets) / sizeof(renderTargets[0]);
		assert(renderTargetsCount == 2);

		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = renderTargetsCount;
		pipelineSettings.pColorFormats = renderTargets;
		pipelineSettings.pDepthState = NULL;
		pipelineSettings.mSampleCount = SAMPLE_COUNT_1;
		pipelineSettings.mSampleQuality = 0;
		pipelineSettings.pRootSignature = g_RootSignatureDeferredShading;
		pipelineSettings.pShaderProgram = g_ShaderDeferredShading;
		pipelineSettings.pVertexLayout = NULL;
		pipelineSettings.pRasterizerState = &rasterizerStateCullNoneDesc;
		pipelineSettings.mVRFoveatedRendering = true;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineDeferredShading);
	}

	{
		// TinyImageFormat renderTargets[] = { g_SceneColor->mFormat };
		TinyImageFormat renderTargets[] = { g_SwapChain->ppRenderTargets[0]->mFormat };
		uint32_t renderTargetsCount = sizeof(renderTargets) / sizeof(renderTargets[0]);
		assert(renderTargetsCount == 1);

		PipelineDesc graphicsPipelineDesc = {};
		graphicsPipelineDesc.mType = PIPELINE_TYPE_GRAPHICS;
		GraphicsPipelineDesc &pipelineSettings = graphicsPipelineDesc.mGraphicsDesc;

		pipelineSettings.mPrimitiveTopo = PRIMITIVE_TOPO_TRI_LIST;
		pipelineSettings.mRenderTargetCount = renderTargetsCount;
		pipelineSettings.pColorFormats = renderTargets;
		pipelineSettings.pDepthState = NULL;
		pipelineSettings.mSampleCount = SAMPLE_COUNT_1;
		pipelineSettings.mSampleQuality = 0;
		pipelineSettings.pRootSignature = g_RootSignatureTonemapper;
		pipelineSettings.pShaderProgram = g_ShaderTonemapper;
		pipelineSettings.pVertexLayout = NULL;
		pipelineSettings.pRasterizerState = &rasterizerStateCullNoneDesc;
		pipelineSettings.mVRFoveatedRendering = true;
		addPipeline(g_Renderer, &graphicsPipelineDesc, &g_PipelineTonemapper);
	}
}

void UnloadPipelines()
{
	removePipeline(g_Renderer, g_PipelineSkybox);
	removePipeline(g_Renderer, g_PipelineTerrain);
	removePipeline(g_Renderer, g_PipelineLitOpaque);
	removePipeline(g_Renderer, g_PipelineLitMasked);
	removePipeline(g_Renderer, g_PipelineDeferredShading);
	removePipeline(g_Renderer, g_PipelineTonemapper);
}
