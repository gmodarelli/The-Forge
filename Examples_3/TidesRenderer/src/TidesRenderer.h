#include <stdint.h>
#include "../../../Common_3/Graphics/Interfaces/IGraphics.h"
#define TR_API __declspec(dllexport)

extern "C"
{

typedef struct TR_Slice {
	const void* data;
	size_t dataSize;
} TR_Slice;

typedef enum TR_OutputMode
{
	OUTPUT_MODE_SDR = 0,
	OUTPUT_MODE_P2020,
	OUTPUT_MODE_COUNT
} TR_OutputMode;

typedef struct TR_AppSettings {
	int32_t width = -1;
	int32_t height = -1;
	void* windowHandle = 0;
	bool vSyncEnabled = true;
	TR_OutputMode outputMode = OUTPUT_MODE_SDR;
} TR_AppSettings;

typedef struct TR_BufferHandle {
	unsigned int ID;
} TR_BufferHandle;

typedef struct TR_MeshHandle {
	unsigned int ID;
} TR_MeshHandle;

typedef struct TR_TextureHandle {
	unsigned int ID;
} TR_TextureHandle;

typedef struct TR_FrameData {
	float viewMatrix[16];
	float projectionMatrix[16];
	float position[3];
	uint32_t directionalLightsBufferIndex;
	uint32_t pointLightsBufferIndex;
	uint32_t directionalLightsCount;
	uint32_t pointLightsCount;
	TR_MeshHandle skyboxMeshHandle;
	uint32_t uiInstanceBufferIndex;
	uint32_t uiInstanceCount;
} TR_FrameData;

typedef struct TR_PointLight
{
	float position[3];
	float radius;
	float color;
	float intensity;
} TR_PointLight;

typedef struct TR_DirectionalLight
{
	float direction[3];
	int   mShadowMap;
	float color[3];
	float intensity;
	float shadowRange;
	float _pad[2];
	int   shadowMapDimensions;
	float viewProj[16];
} TR_DirectionalLight;

struct ReloadDesc;

TR_API int TR_initRenderer(TR_AppSettings* appSettings);
TR_API void TR_exitRenderer();
TR_API uint32_t TR_frameIndex();
TR_API uint32_t TR_inFlightFramesCount();
TR_API bool TR_requestReload(ReloadDesc* reloadDesc);
TR_API bool TR_onLoad(ReloadDesc* reloadDesc);
TR_API void TR_onUnload(ReloadDesc* reloadDesc);

TR_API void TR_draw(TR_FrameData frameData);

TR_API TR_BufferHandle TR_createBuffer(TR_Slice initialData, uint32_t dataStride, const char* debugName);
TR_API void TR_updateBuffer(TR_Slice data, TR_BufferHandle bufferHandle);
TR_API uint32_t TR_bufferBindlessIndex(TR_BufferHandle bufferHandle);

TR_API TR_MeshHandle TR_loadMesh(const char* path);
TR_API uint32_t TR_getSubMeshCount(TR_MeshHandle meshHandle);

TR_API TR_TextureHandle TR_loadTexture(const char* path);
TR_API TR_TextureHandle TR_loadTextureFromMemory(uint32_t width, uint32_t height, TinyImageFormat format, TR_Slice dataSlice, const char* debugName);
TR_API uint32_t TR_textureBindlessIndex(TR_TextureHandle textureHandle);

typedef struct TR_DrawCallInstanced {
	TR_MeshHandle meshHandle;
	uint32_t subMeshIndex;
	uint32_t startInstanceLocation;
	uint32_t instanceCount;
} TR_DrawCallInstanced;

typedef struct TR_DrawCallPushConstants {
	uint32_t start_instance_location;
	uint32_t instance_data_buffer_index;
	uint32_t material_buffer_index;
} TR_DrawCallPushConstants;

TR_API void TR_registerTerrainDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice);
TR_API void TR_registerLitOpaqueDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice);
TR_API void TR_registerLitMaskedDrawCalls(TR_Slice drawCallsSlice, TR_Slice pushConstantsSlice);

}
