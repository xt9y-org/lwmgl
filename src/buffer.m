#include "internal.h"

#include <stdlib.h>
#include <string.h>

struct LWMGLBufferImpl {
    void *metalBuffer;
    size_t size;
    LWMGLStorageMode storage;
};

static id<MTLBuffer> nativeBuffer(LWMGLBuffer buffer)
{
    return buffer ? (__bridge id<MTLBuffer>)buffer->metalBuffer : nil;
}

static int validateRange(LWMGLBuffer buffer, size_t offset, size_t size)
{
    if (!buffer) {
        lwmglSetErrorInternal("buffer is null");
        return -1;
    }
    if (offset > buffer->size || size > buffer->size - offset) {
        lwmglSetErrorInternal("buffer range exceeds allocation");
        return -1;
    }
    return 0;
}

static int blitUpload(id<MTLBuffer> destination, size_t offset, const void *data, size_t size)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->device || !state->queue) {
        lwmglSetErrorInternal("Metal context is not created");
        return -1;
    }
    if (size == 0u) return 0;

    id<MTLBuffer> staging = [state->device newBufferWithBytes:data
                                                       length:size
                                                      options:MTLResourceStorageModeShared];
    if (!staging) {
        lwmglSetErrorInternal("failed to allocate private-buffer staging resource");
        return -1;
    }

    id<MTLCommandBuffer> command = [state->queue commandBuffer];
    if (!command) {
        lwmglSetErrorInternal("failed to create upload command buffer");
        return -1;
    }

    id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
    if (!blit) {
        lwmglSetErrorInternal("failed to create upload blit encoder");
        return -1;
    }

    [blit copyFromBuffer:staging
            sourceOffset:0u
                toBuffer:destination
       destinationOffset:offset
                    size:size];
    [blit endEncoding];
    [command commit];
    return 0;
}

LWMGLBuffer lwmglBufferCreateInternal(const LWMGLBufferDesc *desc, const void *initialData)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!desc || desc->size == 0u) {
            lwmglSetErrorInternal("buffer descriptor must have a non-zero size");
            return NULL;
        }
        if (desc->storage != LWMGL_STORAGE_SHARED && desc->storage != LWMGL_STORAGE_PRIVATE) {
            lwmglSetErrorInternal("invalid buffer storage mode");
            return NULL;
        }

        const MTLResourceOptions options = desc->storage == LWMGL_STORAGE_PRIVATE
            ? MTLResourceStorageModePrivate
            : MTLResourceStorageModeShared;

        id<MTLBuffer> object = nil;
        if (desc->storage == LWMGL_STORAGE_SHARED && initialData) {
            object = [state->device newBufferWithBytes:initialData length:desc->size options:options];
        } else {
            object = [state->device newBufferWithLength:desc->size options:options];
        }
        if (!object) {
            lwmglSetErrorInternal("failed to allocate Metal buffer");
            return NULL;
        }

        LWMGLBuffer handle = (LWMGLBuffer)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate buffer handle");
            return NULL;
        }

        handle->metalBuffer = (__bridge_retained void *)object;
        handle->size = desc->size;
        handle->storage = desc->storage;

        if (desc->storage == LWMGL_STORAGE_PRIVATE && initialData) {
            if (blitUpload(object, 0u, initialData, desc->size) != 0) {
                id released = (__bridge_transfer id)handle->metalBuffer;
                (void)released;
                free(handle);
                return NULL;
            }
        }

        return handle;
    }
}

void lwmglBufferDestroyInternal(LWMGLBuffer buffer)
{
    if (!buffer) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)buffer->metalBuffer;
        (void)released;
        buffer->metalBuffer = NULL;
        free(buffer);
    }
}

void *lwmglBufferContentsInternal(LWMGLBuffer buffer)
{
    if (!buffer) {
        lwmglSetErrorInternal("buffer is null");
        return NULL;
    }
    if (buffer->storage != LWMGL_STORAGE_SHARED) {
        lwmglSetErrorInternal("private Metal buffers are not CPU-mappable");
        return NULL;
    }

    id<MTLBuffer> object = nativeBuffer(buffer);
    if (!object) {
        lwmglSetErrorInternal("buffer has no Metal resource");
        return NULL;
    }
    return object.contents;
}

size_t lwmglBufferSizeInternal(LWMGLBuffer buffer)
{
    if (!buffer) {
        lwmglSetErrorInternal("buffer is null");
        return 0u;
    }
    return buffer->size;
}

int lwmglBufferUploadInternal(LWMGLBuffer buffer, size_t offset, const void *data, size_t size)
{
    if (validateRange(buffer, offset, size) != 0) return -1;
    if (size == 0u) return 0;
    if (!data) {
        lwmglSetErrorInternal("buffer upload data is null");
        return -1;
    }

    id<MTLBuffer> object = nativeBuffer(buffer);
    if (!object) {
        lwmglSetErrorInternal("buffer has no Metal resource");
        return -1;
    }

    if (buffer->storage == LWMGL_STORAGE_SHARED) {
        memcpy((unsigned char *)object.contents + offset, data, size);
        return 0;
    }

    return blitUpload(object, offset, data, size);
}
