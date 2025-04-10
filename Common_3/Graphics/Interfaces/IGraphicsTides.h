#pragma once

#include "IGraphics.h"

#ifdef __cplusplus
extern "C"
{
#endif

void addTextureEx(Renderer* pRenderer, const TextureDesc* pTextureDesc, Texture** texture, bool bBindless);
void removeTextureEx(Renderer* pRenderer, Texture* ppTexture);

#ifdef __cplusplus
}
#endif
