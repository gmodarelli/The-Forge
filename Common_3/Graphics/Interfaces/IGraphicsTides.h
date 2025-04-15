#pragma once

#include "IGraphics.h"

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

bool loadDefaultRootSignatures(Renderer* pRenderer, const char* graphicsRootSignaturePath, const char* computeRootSignaturePath);
void releaseDefaultRootSignatures(Renderer* pRenderer);

#ifdef __cplusplus
}
#endif
