#include "Interfaces/IGraphicsTides.h"

extern void getBufferSizeAlign(Renderer* pRenderer, const BufferDesc* pDesc, ResourceSizeAlign* pOut);
extern void getTextureSizeAlign(Renderer* pRenderer, const TextureDesc* pDesc, ResourceSizeAlign* pOut);
extern void addBuffer(Renderer* pRenderer, const BufferDesc* pDesc, Buffer** pp_buffer);
extern void removeBuffer(Renderer* pRenderer, Buffer* pBuffer);
extern void mapBuffer(Renderer* pRenderer, Buffer* pBuffer, ReadRange* pRange);
extern void unmapBuffer(Renderer* pRenderer, Buffer* pBuffer);
extern void cmdUpdateBuffer(Cmd* pCmd, Buffer* pBuffer, uint64_t dstOffset, Buffer* pSrcBuffer, uint64_t srcOffset, uint64_t size);
extern void cmdUpdateSubresource(Cmd* pCmd, Texture* pTexture, Buffer* pSrcBuffer, const struct SubresourceDataDesc* pSubresourceDesc);
extern void cmdCopySubresource(Cmd* pCmd, Buffer* pDstBuffer, Texture* pTexture, const struct SubresourceDataDesc* pSubresourceDesc);
extern void addTexture(Renderer* pRenderer, const TextureDesc* pDesc, Texture** ppTexture);
extern void removeTexture(Renderer* pRenderer, Texture* pTexture);

void addTextureEx(Renderer* pRenderer, const TextureDesc* pTextureDesc, Texture** ppTexture, bool bBindless)
{
	(void)bBindless;
    addTexture(pRenderer, pTextureDesc, ppTexture);
}

void removeTextureEx(Renderer* pRenderer, Texture* pTexture) {
	removeTexture(pRenderer, pTexture);
}