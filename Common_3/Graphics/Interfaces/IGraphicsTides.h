#pragma once

#include "IGraphics.h"

#ifdef __cplusplus
extern "C"
{
#endif

void addTextureEx(Renderer* pRenderer, const TextureDesc* pTextureDesc, bool bBindless, Texture** texture);
void removeTextureEx(Renderer* pRenderer, Texture* pTexture);
void addBufferEx(Renderer* pRenderer, const BufferDesc* pDesc, bool bBindless, Buffer** ppBuffer);
void removeBufferEx(Renderer* pRenderer, Buffer* pBuffer);

#ifdef __cplusplus
}
#endif
