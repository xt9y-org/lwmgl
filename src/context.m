#include "internal.h"

#include <limits.h>
#include <stdio.h>
#include <string.h>

static LWMGLContextState g_context = {0};

LWMGLContextState *lwmglContextState(void)
{
    return &g_context;
}

static int contextCreate(void *nativeWindow)
{
    @autoreleasepool {
        lwmglClearError();
        if (!nativeWindow) {
            lwmglSetErrorInternal("invalid native window");
            return -1;
        }
        if (g_context.created) return 0;

        g_context.device = MTLCreateSystemDefaultDevice();
        if (!g_context.device) {
            lwmglSetErrorInternal("no Metal device is available");
            return -1;
        }

        g_context.queue = [g_context.device newCommandQueue];
        if (!g_context.queue) {
            g_context.device = nil;
            lwmglSetErrorInternal("failed to create Metal command queue");
            return -1;
        }

        if (lwmglSurfaceAttach(nativeWindow) != 0) {
            g_context.queue = nil;
            g_context.device = nil;
            return -1;
        }

        g_context.created = 1;
        return 0;
    }
}

static void contextDestroy(void)
{
    @autoreleasepool {
        if (!g_context.created && !g_context.layer && !g_context.device) return;
        lwmglSurfaceDetach();
        g_context.queue = nil;
        g_context.device = nil;
        g_context.created = 0;
        lwmglClearError();
    }
}

static int contextIsCreated(void)
{
    return g_context.created;
}

static int contextGetDeviceInfo(LWMGLDeviceInfo *outInfo)
{
    if (!outInfo) {
        lwmglSetErrorInternal("device info output is null");
        return -1;
    }
    if (!g_context.created || !g_context.device) {
        lwmglSetErrorInternal("Metal context is not created");
        return -1;
    }

    memset(outInfo, 0, sizeof *outInfo);
    const char *name = g_context.device.name.UTF8String;
    snprintf(outInfo->name, sizeof outInfo->name, "%s", name ? name : "Metal Device");

    if ([g_context.device respondsToSelector:@selector(recommendedMaxWorkingSetSize)]) {
        outInfo->recommendedMaxWorkingSetSize = (uint64_t)g_context.device.recommendedMaxWorkingSetSize;
    }

    const MTLSize groupLimit = g_context.device.maxThreadsPerThreadgroup;
    outInfo->maxThreadsPerThreadgroup = groupLimit.width > UINT32_MAX
        ? UINT32_MAX
        : (uint32_t)groupLimit.width;

    if ([g_context.device respondsToSelector:@selector(hasUnifiedMemory)]) {
        outInfo->hasUnifiedMemory = g_context.device.hasUnifiedMemory ? 1u : 0u;
    }

    if ([g_context.device respondsToSelector:@selector(supportsRaytracing)]) {
        const BOOL supported = g_context.device.supportsRaytracing;
        outInfo->supportsRayTracing = supported ? 1u : 0u;
        outInfo->supportsAccelerationStructures = supported ? 1u : 0u;
    }

    return 0;
}

const LWMGLMetalAPI Metal = {
    contextCreate,
    contextDestroy,
    contextIsCreated,
    contextGetDeviceInfo,
    sizeof(LWMGLMetalAPI),
    LWMGL_ABI_VERSION
};
