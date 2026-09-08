#include "internal.h"

#include <stdlib.h>

struct LWMGLLibraryImpl { void *metalLibrary; };
struct LWMGLFunctionImpl { void *metalFunction; };
struct LWMGLComputePipelineImpl { void *metalPipeline; };
struct LWMGLRenderPipelineImpl { void *metalPipeline; };

static void setNSError(NSError *error, const char *fallback)
{
    if (error) {
        const char *message = error.localizedDescription.UTF8String;
        if (message && message[0]) {
            lwmglSetErrorInternal(message);
            return;
        }
    }
    lwmglSetErrorInternal(fallback);
}

static MTLPixelFormat mapPipelineFormat(LWMGLPixelFormat format)
{
    switch (format) {
        case LWMGL_BGRA8_UNORM: return MTLPixelFormatBGRA8Unorm;
        case LWMGL_RGBA8_UNORM: return MTLPixelFormatRGBA8Unorm;
        case LWMGL_RGBA16_FLOAT: return MTLPixelFormatRGBA16Float;
        case LWMGL_RGBA32_FLOAT: return MTLPixelFormatRGBA32Float;
    }
    return MTLPixelFormatInvalid;
}

static LWMGLLibrary wrapLibrary(id<MTLLibrary> object)
{
    LWMGLLibrary handle = (LWMGLLibrary)calloc(1u, sizeof *handle);
    if (!handle) {
        lwmglSetErrorInternal("failed to allocate library handle");
        return NULL;
    }
    handle->metalLibrary = (__bridge_retained void *)object;
    return handle;
}

LWMGLLibrary lwmglLibraryCreateFromSourceInternal(const char *source, size_t length)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!source || length == 0u) {
            lwmglSetErrorInternal("shader source is empty");
            return NULL;
        }

        NSString *sourceString = [[NSString alloc] initWithBytes:source
                                                          length:length
                                                        encoding:NSUTF8StringEncoding];
        if (!sourceString) {
            lwmglSetErrorInternal("shader source is not valid UTF-8");
            return NULL;
        }

        NSError *error = nil;
        id<MTLLibrary> object = [state->device newLibraryWithSource:sourceString options:nil error:&error];
        if (!object) {
            setNSError(error, "Metal shader compilation failed");
            return NULL;
        }
        return wrapLibrary(object);
    }
}

LWMGLLibrary lwmglLibraryCreateFromFileInternal(const char *path)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!path || !path[0]) {
            lwmglSetErrorInternal("metallib path is empty");
            return NULL;
        }

        NSString *pathString = [NSString stringWithUTF8String:path];
        if (!pathString) {
            lwmglSetErrorInternal("metallib path is not valid UTF-8");
            return NULL;
        }
        NSURL *url = [NSURL fileURLWithPath:pathString];
        NSError *error = nil;
        id<MTLLibrary> object = [state->device newLibraryWithURL:url error:&error];
        if (!object) {
            setNSError(error, "failed to load Metal library file");
            return NULL;
        }
        return wrapLibrary(object);
    }
}

void lwmglLibraryDestroyInternal(LWMGLLibrary library)
{
    if (!library) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)library->metalLibrary;
        (void)released;
        library->metalLibrary = NULL;
        free(library);
    }
}

LWMGLFunction lwmglFunctionCreateInternal(LWMGLLibrary library, const char *name)
{
    @autoreleasepool {
        if (!library || !library->metalLibrary) {
            lwmglSetErrorInternal("library is null");
            return NULL;
        }
        if (!name || !name[0]) {
            lwmglSetErrorInternal("shader function name is empty");
            return NULL;
        }
        NSString *functionName = [NSString stringWithUTF8String:name];
        if (!functionName) {
            lwmglSetErrorInternal("shader function name is not valid UTF-8");
            return NULL;
        }
        id<MTLLibrary> nativeLibrary = (__bridge id<MTLLibrary>)library->metalLibrary;
        id<MTLFunction> object = [nativeLibrary newFunctionWithName:functionName];
        if (!object) {
            lwmglSetErrorInternal("Metal shader function was not found");
            return NULL;
        }

        LWMGLFunction handle = (LWMGLFunction)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate function handle");
            return NULL;
        }
        handle->metalFunction = (__bridge_retained void *)object;
        return handle;
    }
}

void lwmglFunctionDestroyInternal(LWMGLFunction function)
{
    if (!function) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)function->metalFunction;
        (void)released;
        function->metalFunction = NULL;
        free(function);
    }
}

LWMGLComputePipeline lwmglComputePipelineCreateInternal(LWMGLFunction function)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!function || !function->metalFunction) {
            lwmglSetErrorInternal("compute function is null");
            return NULL;
        }

        NSError *error = nil;
        id<MTLFunction> nativeFunction = (__bridge id<MTLFunction>)function->metalFunction;
        id<MTLComputePipelineState> object = [state->device newComputePipelineStateWithFunction:nativeFunction error:&error];
        if (!object) {
            setNSError(error, "failed to create Metal compute pipeline");
            return NULL;
        }

        LWMGLComputePipeline handle = (LWMGLComputePipeline)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate compute pipeline handle");
            return NULL;
        }
        handle->metalPipeline = (__bridge_retained void *)object;
        return handle;
    }
}

void lwmglComputePipelineDestroyInternal(LWMGLComputePipeline pipeline)
{
    if (!pipeline) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)pipeline->metalPipeline;
        (void)released;
        pipeline->metalPipeline = NULL;
        free(pipeline);
    }
}

LWMGLRenderPipeline lwmglRenderPipelineCreateInternal(
    LWMGLFunction vertex,
    LWMGLFunction fragment,
    LWMGLPixelFormat colorFormat)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!vertex || !vertex->metalFunction || !fragment || !fragment->metalFunction) {
            lwmglSetErrorInternal("render pipeline requires vertex and fragment functions");
            return NULL;
        }
        const MTLPixelFormat nativeFormat = mapPipelineFormat(colorFormat);
        if (nativeFormat == MTLPixelFormatInvalid) {
            lwmglSetErrorInternal("invalid render pipeline color format");
            return NULL;
        }

        MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
        desc.vertexFunction = (__bridge id<MTLFunction>)vertex->metalFunction;
        desc.fragmentFunction = (__bridge id<MTLFunction>)fragment->metalFunction;
        desc.colorAttachments[0].pixelFormat = nativeFormat;

        NSError *error = nil;
        id<MTLRenderPipelineState> object = [state->device newRenderPipelineStateWithDescriptor:desc error:&error];
        if (!object) {
            setNSError(error, "failed to create Metal render pipeline");
            return NULL;
        }

        LWMGLRenderPipeline handle = (LWMGLRenderPipeline)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate render pipeline handle");
            return NULL;
        }
        handle->metalPipeline = (__bridge_retained void *)object;
        return handle;
    }
}

void lwmglRenderPipelineDestroyInternal(LWMGLRenderPipeline pipeline)
{
    if (!pipeline) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)pipeline->metalPipeline;
        (void)released;
        pipeline->metalPipeline = NULL;
        free(pipeline);
    }
}

id<MTLComputePipelineState> lwmglNativeComputePipelineInternal(LWMGLComputePipeline pipeline)
{
    return pipeline && pipeline->metalPipeline
        ? (__bridge id<MTLComputePipelineState>)pipeline->metalPipeline
        : nil;
}

id<MTLRenderPipelineState> lwmglNativeRenderPipelineInternal(LWMGLRenderPipeline pipeline)
{
    return pipeline && pipeline->metalPipeline
        ? (__bridge id<MTLRenderPipelineState>)pipeline->metalPipeline
        : nil;
}
