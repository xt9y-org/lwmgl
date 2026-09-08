#include <lwmgl/context.h>

#include <stdio.h>

static _Thread_local char g_lwmgl_error[512];

const char *lwmglGetLastError(void)
{
    return g_lwmgl_error[0] ? g_lwmgl_error : NULL;
}

void lwmglClearError(void)
{
    g_lwmgl_error[0] = '\0';
}

void lwmglSetErrorInternal(const char *message)
{
    if (!message) message = "unknown lwmgl error";
    snprintf(g_lwmgl_error, sizeof g_lwmgl_error, "%s", message);
}
