#include "../Utilities/Interfaces/ILog.h"

#include <Windows.h>

void writeLog(uint32_t level, const char* filename, int line_number, const char* message, ...)
{
    (void)level;
    (void)filename;
    (void)line_number;
    (void)message;

    char    buffer[1024];
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