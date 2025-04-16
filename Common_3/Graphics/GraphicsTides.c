#include "Interfaces/IGraphicsTides.h"

extern void getBufferSizeAlign(Renderer* pRenderer, const BufferDesc* pDesc, ResourceSizeAlign* pOut);
extern void getTextureSizeAlign(Renderer* pRenderer, const TextureDesc* pDesc, ResourceSizeAlign* pOut);
extern void addBuffer(Renderer* pRenderer, const BufferDesc* pDesc, bool bBindless, Buffer** pp_buffer);
extern void removeBuffer(Renderer* pRenderer, Buffer* pBuffer);
extern void mapBuffer(Renderer* pRenderer, Buffer* pBuffer, ReadRange* pRange);
extern void unmapBuffer(Renderer* pRenderer, Buffer* pBuffer);
extern void cmdUpdateBuffer(Cmd* pCmd, Buffer* pBuffer, uint64_t dstOffset, Buffer* pSrcBuffer, uint64_t srcOffset, uint64_t size);
extern void cmdUpdateSubresource(Cmd* pCmd, Texture* pTexture, Buffer* pSrcBuffer, const struct SubresourceDataDesc* pSubresourceDesc);
extern void cmdCopySubresource(Cmd* pCmd, Buffer* pDstBuffer, Texture* pTexture, const struct SubresourceDataDesc* pSubresourceDesc);
extern void addTexture(Renderer* pRenderer, const TextureDesc* pDesc, bool bBindless, Texture** ppTexture);
extern void removeTexture(Renderer* pRenderer, Texture* pTexture);

extern void initRootSignatureImpl(Renderer*, const void*, uint32_t, ID3D12RootSignature**);
extern void exitRootSignatureImpl(Renderer*, ID3D12RootSignature*);

void initGPUConfigurationEx(ExtendedSettings* pExtendedSettings)
{
	addGPUConfigurationRules(pExtendedSettings);
}

void exitGPUConfigurationEx()
{
	exitGPUConfiguration();
}

void addTextureEx(Renderer* pRenderer, const TextureDesc* pTextureDesc, bool bBindless, Texture** ppTexture)
{
    addTexture(pRenderer, pTextureDesc, bBindless, ppTexture);
}

void removeTextureEx(Renderer* pRenderer, Texture* pTexture)
{
	removeTexture(pRenderer, pTexture);
}

void addBufferEx(Renderer* pRenderer, const BufferDesc* pDesc, bool bBindless, Buffer** ppBuffer)
{
	addBuffer(pRenderer, pDesc, bBindless, ppBuffer);
}

void removeBufferEx(Renderer* pRenderer, Buffer* pBuffer)
{
	removeBuffer(pRenderer, pBuffer);
}

bool loadRootSignature(Renderer* pRenderer, const char* path, ID3D12RootSignature** ppRootSignature);

bool loadDefaultRootSignatures(Renderer* pRenderer, const char* graphicsRootSignaturePath, const char* computeRootSignaturePath)
{
	if (!loadRootSignature(pRenderer, graphicsRootSignaturePath, &pRenderer->mDx.pGraphicsRootSignature))
    {
        return false;
    }

    if (!loadRootSignature(pRenderer, computeRootSignaturePath, &pRenderer->mDx.pComputeRootSignature))
    {
        return false;
    }

	return true;
}

void releaseDefaultRootSignatures(Renderer* pRenderer)
{
	exitRootSignatureImpl(pRenderer, pRenderer->mDx.pGraphicsRootSignature);
    exitRootSignatureImpl(pRenderer, pRenderer->mDx.pComputeRootSignature);
}

bool loadRootSignature(Renderer* pRenderer, const char* path, ID3D12RootSignature** ppRootSignature)
{
    FileStream binaryFS = { 0 };
    const bool result = fsOpenStreamFromPath(RD_SHADER_BINARIES, path, FM_READ, &binaryFS);
    assert(result);
    ssize_t size = fsGetStreamFileSize(&binaryFS);
    assert(size > 0);

    void* bytecode = tf_malloc_internal(size, "", 0, "");
    assert(bytecode);
    memset(bytecode, 0, size);
    fsReadFromStream(&binaryFS, bytecode, size);

    initRootSignatureImpl(pRenderer, bytecode, (uint32_t)size, ppRootSignature);

    tf_free(bytecode);

    fsCloseStream(&binaryFS);

    return true;
}

void getWindowSize(WindowHandle windowHandle, uint32_t* pWidth, uint32_t* pHeight)
{
    RECT rect;
    if (!GetWindowRect(windowHandle.window, &rect))
    {
        assert(false);
    }

    *pWidth = rect.right - rect.left;
    *pHeight = rect.bottom - rect.top;
}