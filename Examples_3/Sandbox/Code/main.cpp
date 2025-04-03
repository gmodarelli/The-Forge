#include <stdio.h>
#include <stdint.h>
#include <memory.h>
#include <assert.h>
#include <corecrt_io.h>

#define STB_DS_IMPLEMENTATION
#include "../../../Common_3/Utilities/Math/BStringHashMap.h"

#define EXTERNAL_RENDERER_CONFIG_FILEPATH "../../Examples_3/Sandbox/Code/ExternalConfigs.h"
#include "../../../Common_3/Graphics/Interfaces/IGraphics.h"

// TODO: Implement the following interfaces
// Log.h
// IFileSystem.h
// IMemory.h
// IThread.h
// IOperatingSystem.h

Renderer* g_renderer;
Queue* g_graphicsQueue;

int main(int argc, char** argv)
{
	printf("Sandbox\n");

    // Initialize Renderer
    {
        RendererDesc desc = RendererDesc{};
        memset((void*)&desc, 0, sizeof(RendererDesc));
        desc.mShaderTarget = ::SHADER_TARGET_6_4;
        initGPUConfiguration(desc.pExtendedSettings);

        initRenderer("Sandbox", &desc, &g_renderer);
        assert(g_renderer);
        setupGPUConfigurationPlatformParameters(g_renderer, desc.pExtendedSettings);
    }

    // Initialize Graphics Queue
    {
        QueueDesc queueDesc = {};
        queueDesc.mType = QUEUE_TYPE_GRAPHICS;
        queueDesc.mFlag = QUEUE_FLAG_NONE;
        initQueue(g_renderer, &queueDesc, &g_graphicsQueue);

        exitQueue(g_renderer, g_graphicsQueue);
    }

    exitRenderer(g_renderer);
	return 0;
}

// Log.h implementation
void writeLog(uint32_t level, const char* filename, int line_number, const char* message, ...)
{
    (void)level;
    (void)filename;
    (void)line_number;
    (void)message;

    char buffer[1024];
    va_list va_args;
    va_start(va_args, message);
    vsprintf(buffer, message, va_args);
    va_end(va_args);

    OutputDebugStringA(buffer);
    OutputDebugStringA("\n");
}

void _FailedAssert(const char* file, int line, const char* statement, const char* msgFmt, ...)
{
    (void)file;
    (void)line;
    (void)statement;
    (void)msgFmt;
}

// IFileSystem.h implementation
struct WindowsFileStream
{
    FILE*  file;
    HANDLE handle;
    HANDLE fileMapping;
    LPVOID mapView;
};

#define WSD(name, fs) struct WindowsFileStream* name = (struct WindowsFileStream*)(fs)->mUser.data


bool fsOpen(IFileSystem* pIO, const ResourceDirectory resourceDir, const char* filename, FileMode mode, FileStream* pOut);
bool fsClose(FileStream* pFile);
size_t fsRead(FileStream* fs, void* dst, size_t size);
ssize_t fsGetFileSize(FileStream* pFile);

static IFileSystem g_fileSystemIO = {
    fsOpen,
    fsClose,
    fsRead,
    NULL,
    NULL,
    NULL,
    fsGetFileSize,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
};

bool fsOpen(IFileSystem* pIO, const ResourceDirectory resourceDir, const char* filename, FileMode mode, FileStream* pOut)
{
    (void)pIO;

    FILE* fp = fopen(filename, "rb");
    assert(fp);
    pOut->mMode = mode;
    pOut->pIO = &g_fileSystemIO;

    WSD(stream, pOut);
    stream->file = fp;
    stream->handle = (HANDLE)_get_osfhandle(_fileno(fp));
    assert(stream->handle);

    return true;
}

bool fsClose(FileStream* pFile)
{
    WSD(stream, pFile);
    fclose(stream->file);

    return true;
}

size_t fsRead(FileStream* fs, void* dst, size_t size)
{
    WSD(stream, fs);
    size_t read = fread(dst, 1, size, stream->file);
    assert(read == size);
    return read;
}

ssize_t fsGetFileSize(FileStream* pFile)
{
    WSD(stream, pFile);
    LARGE_INTEGER fileSize = {};
    if (GetFileSizeEx(stream->handle, &fileSize))
        return (ssize_t)fileSize.QuadPart;

    assert(false);
    return -1;
}


/// Opens the file at `filePath` using the mode `mode`, returning a new FileStream that can be used
/// to read from or modify the file. May return NULL if the file could not be opened.
bool fsOpenStreamFromPath(ResourceDirectory resourceDir, const char* fileName, FileMode mode, FileStream* pOut)
{
    (void)resourceDir;

    memset(pOut, 0, sizeof(FileStream));
    fsOpen(&g_fileSystemIO, resourceDir, fileName, mode, pOut);
    return true;
}

FSErrorContext* __fs_err_ctx(void) { return NULL; }

// IMemory.h implementation
void* tf_malloc_internal(size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    return malloc(size);
}

void* tf_realloc_internal(void* ptr, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    return realloc(ptr, size);
}

void tf_free_internal(void* ptr, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    free(ptr);
}

void* tf_calloc_internal(size_t count, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    return calloc(count, size);
}

void* tf_memalign_internal(size_t align, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;
    (void)align;

    // TODO: align allocation
    return malloc(size);
}

void* tf_calloc_memalign_internal(size_t count, size_t align, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;
    (void)align;

    // TODO: align allocation
    return calloc(count, size);
}

// IThread.h implementation
bool initMutex(Mutex* mutex)
{
    return InitializeCriticalSectionAndSpinCount((CRITICAL_SECTION*)&mutex->mHandle, (DWORD)MUTEX_DEFAULT_SPIN_COUNT);
}

void exitMutex(Mutex* mutex)
{
    CRITICAL_SECTION* cs = (CRITICAL_SECTION*)&mutex->mHandle;
    DeleteCriticalSection(cs);
    memset(&mutex->mHandle, 0, sizeof(mutex->mHandle));
}

void acquireMutex(Mutex* mutex)
{
    EnterCriticalSection((CRITICAL_SECTION*)&mutex->mHandle);
}

void releaseMutex(Mutex* mutex)
{
    LeaveCriticalSection((CRITICAL_SECTION*)&mutex->mHandle);
}

void threadSleep(unsigned mSec)
{ 
    Sleep(mSec);
}

// IOperatingSystem.h implementation
void requestReset(const ResetDesc* pResetDesc)
{
    (void)pResetDesc;
}