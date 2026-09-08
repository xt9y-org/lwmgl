#include <lwmgl/lwmgl.h>

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

static int stubCreate(void *nativeWindow)
{
    (void)nativeWindow;
    lwmglSetErrorInternal("Metal context implementation not linked yet");
    return -1;
}

static void stubDestroy(void) {}
static int stubIsCreated(void) { return 0; }

static int stubGetDeviceInfo(LWMGLDeviceInfo *outInfo)
{
    (void)outInfo;
    lwmglSetErrorInternal("Metal device implementation not linked yet");
    return -1;
}

const LWMGLMetalAPI Metal = {
    stubCreate,
    stubDestroy,
    stubIsCreated,
    stubGetDeviceInfo,
    sizeof(LWMGLMetalAPI),
    LWMGL_ABI_VERSION
};
