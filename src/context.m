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
        if (g_context.created) {
            if (g_context.references == UINT32_MAX) {
                lwmglSetErrorInternal("Metal context reference count overflow");
                return -1;
            }
            ++g_context.references;
            if (!g_context.layer && lwmglSurfaceAttach(nativeWindow) != 0) {
                --g_context.references;
                return -1;
            }
            return 0;
        }

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

        g_context.created = 1;
        g_context.references = 1u;
        if (lwmglSurfaceAttach(nativeWindow) != 0) {
            g_context.references = 0u;
            g_context.created = 0;
            g_context.queue = nil;
            g_context.device = nil;
            return -1;
        }
        return 0;
    }
}

static void contextDestroy(void)
{
    @autoreleasepool {
        if (!g_context.created && !g_context.layer && !g_context.device) return;
        if (g_context.created && g_context.references > 1u) {
            --g_context.references;
            lwmglClearError();
            return;
        }

        lwmglSurfaceDetach();
        g_context.queue = nil;
        g_context.device = nil;
        g_context.references = 0u;
        g_context.created = 0;
        lwmglClearError();
    }
}

static int contextIsCreated(void)
{
    return g_context.created;
}

static int contextAttachSurface(void *nativeWindow)
{
    if (!g_context.created || !g_context.device) {
        lwmglSetErrorInternal("Metal context is not created");
        return -1;
    }
    return lwmglSurfaceAttach(nativeWindow);
}

static void contextDetachSurface(void)
{
    if (!g_context.created && !g_context.layer) return;
    lwmglSurfaceDetach();
}

static int contextIsSurfaceAttached(void)
{
    return g_context.layer != nil;
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

void *lwmglNativeDeviceBridgeInternal(void)
{
    return g_context.device ? (__bridge void *)g_context.device : NULL;
}

const LWMGLMetalAPI Metal = {
    .create = contextCreate,
    .destroy = contextDestroy,
    .isCreated = contextIsCreated,
    .getDeviceInfo = contextGetDeviceInfo,
    .createBuffer = lwmglBufferCreateInternal,
    .destroyBuffer = lwmglBufferDestroyInternal,
    .bufferContents = lwmglBufferContentsInternal,
    .bufferSize = lwmglBufferSizeInternal,
    .uploadBuffer = lwmglBufferUploadInternal,
    .createTexture = lwmglTextureCreateInternal,
    .destroyTexture = lwmglTextureDestroyInternal,
    .uploadTexture2D = lwmglTextureUpload2DInternal,
    .textureWidth = lwmglTextureWidthInternal,
    .textureHeight = lwmglTextureHeightInternal,
    .createSampler = lwmglSamplerCreateInternal,
    .destroySampler = lwmglSamplerDestroyInternal,
    .createLibraryFromSource = lwmglLibraryCreateFromSourceInternal,
    .createLibraryFromFile = lwmglLibraryCreateFromFileInternal,
    .destroyLibrary = lwmglLibraryDestroyInternal,
    .createFunction = lwmglFunctionCreateInternal,
    .destroyFunction = lwmglFunctionDestroyInternal,
    .createComputePipeline = lwmglComputePipelineCreateInternal,
    .destroyComputePipeline = lwmglComputePipelineDestroyInternal,
    .createRenderPipeline = lwmglRenderPipelineCreateInternal,
    .destroyRenderPipeline = lwmglRenderPipelineDestroyInternal,
    .begin = lwmglCommandBeginInternal,
    .beginCompute = lwmglCommandBeginComputeInternal,
    .setComputePipeline = lwmglCommandSetComputePipelineInternal,
    .setBuffer = lwmglCommandSetBufferInternal,
    .setTexture = lwmglCommandSetTextureInternal,
    .setSampler = lwmglCommandSetSamplerInternal,
    .dispatch = lwmglCommandDispatchInternal,
    .copyBuffer = lwmglCommandCopyBufferInternal,
    .endEncoding = lwmglCommandEndEncodingInternal,
    .commit = lwmglCommandCommitInternal,
    .wait = lwmglCommandWaitInternal,
    .destroyCommand = lwmglCommandDestroyInternal,
    .waitIdle = lwmglCommandWaitIdleInternal,
    .resize = lwmglSurfaceResizeInternal,
    .drawableWidth = lwmglSurfaceDrawableWidthInternal,
    .drawableHeight = lwmglSurfaceDrawableHeightInternal,
    .beginRenderToDrawable = lwmglCommandBeginRenderToDrawableInternal,
    .setRenderPipeline = lwmglCommandSetRenderPipelineInternal,
    .draw = lwmglCommandDrawInternal,
    .present = lwmglCommandPresentInternal,
    .supportsRayTracing = lwmglRayTracingSupportedInternal,
    .createTriangleAccelerationStructure = lwmglTriangleAccelerationStructureCreateInternal,
    .createInstanceAccelerationStructure = lwmglInstanceAccelerationStructureCreateInternal,
    .rebuildAccelerationStructure = lwmglAccelerationStructureRebuildInternal,
    .destroyAccelerationStructure = lwmglAccelerationStructureDestroyInternal,
    .setAccelerationStructure = lwmglCommandSetAccelerationStructureInternal,
    .structSize = sizeof(LWMGLMetalAPI),
    .abiVersion = LWMGL_ABI_VERSION,
    .setFragmentBuffer = lwmglCommandSetFragmentBufferInternal,
    .setFragmentTexture = lwmglCommandSetFragmentTextureInternal,
    .setFragmentSampler = lwmglCommandSetFragmentSamplerInternal,
    .nativeDevice = lwmglNativeDeviceBridgeInternal,
    .nativeCommandBuffer = lwmglNativeCommandBufferBridgeInternal,
    .nativeRenderEncoder = lwmglNativeRenderEncoderBridgeInternal,
    .nativeRenderPassDescriptor = lwmglNativeRenderPassDescriptorBridgeInternal,
    .attachSurface = contextAttachSurface,
    .detachSurface = contextDetachSurface,
    .isSurfaceAttached = contextIsSurfaceAttached,
    .drawLines = lwmglCommandDrawLinesInternal
};
