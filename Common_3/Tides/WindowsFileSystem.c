#include "../Utilities/Interfaces/IFileSystem.h"

#include <Windows.h>
#include <assert.h>
#include <io.h>

typedef struct WindowsFileStream WindowsFileStream;
struct WindowsFileStream
{
    FILE*  file;
    HANDLE handle;
    HANDLE fileMapping;
    LPVOID mapView;
};

#define WSD(name, fs) struct WindowsFileStream* name = (struct WindowsFileStream*)(fs)->mUser.data

bool    fsOpen(IFileSystem* pIO, const ResourceDirectory resourceDir, const char* filename, FileMode mode, FileStream* pOut);
bool    fsClose(FileStream* pFile);
size_t  fsRead(FileStream* fs, void* dst, size_t size);
ssize_t fsGetFileSize(FileStream* pFile);

static IFileSystem g_fileSystemIO = {
    fsOpen, fsClose, fsRead, NULL, NULL, NULL, fsGetFileSize, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
};

bool fsOpen(IFileSystem* pIO, const ResourceDirectory resourceDir, const char* filename, FileMode mode, FileStream* pOut)
{
    (void)pIO;

    FILE* fp;
    errno_t err = fopen_s(&fp, filename, "rb");
    assert(err == 0);
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
    LARGE_INTEGER fileSize = {0};
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