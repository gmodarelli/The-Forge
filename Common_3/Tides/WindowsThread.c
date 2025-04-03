#include "../Utilities/Interfaces/IThread.h"

#include <Windows.h>

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

void acquireMutex(Mutex* mutex) { EnterCriticalSection((CRITICAL_SECTION*)&mutex->mHandle); }

void releaseMutex(Mutex* mutex) { LeaveCriticalSection((CRITICAL_SECTION*)&mutex->mHandle); }

void threadSleep(unsigned mSec) { Sleep(mSec); }