#define IMEMORY_FROM_HEADER
#include "../Utilities/Interfaces/IMemory.h"

#include <memory.h>

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