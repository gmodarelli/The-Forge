#define IMEMORY_FROM_HEADER
#include "../Utilities/Interfaces/IMemory.h"

#include <Windows.h>

void* tf_malloc_internal(size_t size, const char* f, int l, const char* sf)
{
    return tf_memalign_internal(16, size, f, l, sf);
}

void* tf_realloc_internal(void* ptr, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    void* new_ptr = _aligned_realloc(ptr, size, 16);
    return new_ptr;
}

void tf_free_internal(void* ptr, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    _aligned_free(ptr);
}

void* tf_calloc_internal(size_t count, size_t size, const char* f, int l, const char* sf)
{
    return tf_calloc_memalign_internal(count, 16, size, f, l, sf);
}

void* tf_memalign_internal(size_t align, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    void* ptr = _aligned_malloc(size, align);
    memset(ptr, 0, size);
    return ptr;
}

void* tf_calloc_memalign_internal(size_t count, size_t align, size_t size, const char* f, int l, const char* sf)
{
    (void)f;
    (void)l;
    (void)sf;

    size_t new_size = count * size;
    void* ptr = _aligned_malloc(new_size, align);
    memset(ptr, 0, new_size);
    return ptr;
}