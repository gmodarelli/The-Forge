#pragma once

#include "IGraphics.h"

#define TIDES_SPACE_DESCRIPTORS_MAX_COUNT 8
#define TIDES_DESCRIPTOR_SPACES_COUNT 5

typedef struct SpaceDescriptors
{
    uint32_t mDescriptorsCount;
    Descriptor pDescriptors[TIDES_SPACE_DESCRIPTORS_MAX_COUNT];
} SpaceDescriptors;

typedef struct SubResourceDataDesc
{
    uint64_t mSrcOffset;
    uint32_t mMipLevel;
    uint32_t mArrayLayer;
} SubResourceDataDesc;

// From Defines.hlsli
// #define ROOT_PARAM_Persistent_SAMPLER 4
// #define ROOT_PARAM_Persistent         3
// #define ROOT_PARAM_PerFrame           2
// #define ROOT_PARAM_PerBatch           1
// #define ROOT_PARAM_PerDraw            0
typedef struct Descriptors
{
    SpaceDescriptors pSpaceDescriptors[TIDES_DESCRIPTOR_SPACES_COUNT];
} Descriptors;

#ifdef __cplusplus
extern "C"
{
#endif

void initGPUConfigurationEx(ExtendedSettings* pExtendedSettings);
void exitGPUConfigurationEx();
void addTextureEx(Renderer* pRenderer, const TextureDesc* pTextureDesc, bool bBindless, Texture** texture);
void removeTextureEx(Renderer* pRenderer, Texture* pTexture);
void addBufferEx(Renderer* pRenderer, const BufferDesc* pDesc, bool bBindless, Buffer** ppBuffer);
void removeBufferEx(Renderer* pRenderer, Buffer* pBuffer);
void cmdUpdateBufferEx(Cmd* pCmd, Buffer* pBuffer, uint64_t dstOffset, Buffer* pSrcBuffer, uint64_t srcOffset, uint64_t size);
void cmdUpdateSubresourceEx(Cmd* pCmd, Texture* pTexture, Buffer* pSrcBuffer, const SubResourceDataDesc* pSubresourceDesc);
void cmdCopySubresourceEx(Cmd* pCmd, Buffer* pDstBuffer, Texture* pTexture, const SubResourceDataDesc* pSubresourceDesc);

bool loadDefaultRootSignatures(Renderer* pRenderer, const char* graphicsRootSignaturePath, const char* computeRootSignaturePath);
void releaseDefaultRootSignatures(Renderer* pRenderer);

void getWindowSize(WindowHandle windowHandle, uint32_t* pWidth, uint32_t* pHeight);

void createShaderDescriptors(Shader* pShaderProgram, Descriptors* pDescriptors);
void removeShaderDescriptors(Descriptors* pDescriptors);

void queueWaitForFence(Queue* pQueue, Fence* pFence);

#ifdef __cplusplus
}
#endif
