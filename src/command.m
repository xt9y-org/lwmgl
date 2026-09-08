#include "internal.h"

#include <stdlib.h>

struct LWMGLCommandImpl {
    void *commandBuffer;
    void *computeEncoder;
    void *renderEncoder;
    void *blitEncoder;
    void *drawable;
    NSUInteger computeExecutionWidth;
    NSUInteger computeMaxThreads;
    int computePipelineSet;
    int presented;
    int committed;
};

static id<MTLCommandBuffer> nativeCommandBuffer(LWMGLCommand command)
{
    return command && command->commandBuffer
        ? (__bridge id<MTLCommandBuffer>)command->commandBuffer
        : nil;
}

static id<MTLComputeCommandEncoder> nativeComputeEncoder(LWMGLCommand command)
{
    return command && command->computeEncoder
        ? (__bridge id<MTLComputeCommandEncoder>)command->computeEncoder
        : nil;
}

static id<MTLRenderCommandEncoder> nativeRenderEncoder(LWMGLCommand command)
{
    return command && command->renderEncoder
        ? (__bridge id<MTLRenderCommandEncoder>)command->renderEncoder
        : nil;
}

static id<MTLBlitCommandEncoder> nativeBlitEncoder(LWMGLCommand command)
{
    return command && command->blitEncoder
        ? (__bridge id<MTLBlitCommandEncoder>)command->blitEncoder
        : nil;
}

static id<CAMetalDrawable> nativeDrawable(LWMGLCommand command)
{
    return command && command->drawable
        ? (__bridge id<CAMetalDrawable>)command->drawable
        : nil;
}

static void releaseRetained(void **object)
{
    if (!object || !*object) return;
    id released = (__bridge_transfer id)*object;
    (void)released;
    *object = NULL;
}

static int validateMutableCommand(LWMGLCommand command)
{
    if (!command || !command->commandBuffer) {
        lwmglSetErrorInternal("command is null");
        return -1;
    }
    if (command->committed) {
        lwmglSetErrorInternal("command has already been committed");
        return -1;
    }
    return 0;
}

static void endActiveEncoder(LWMGLCommand command)
{
    if (!command) return;
    if (command->computeEncoder) {
        [(__bridge id<MTLComputeCommandEncoder>)command->computeEncoder endEncoding];
        releaseRetained(&command->computeEncoder);
        command->computePipelineSet = 0;
    }
    if (command->renderEncoder) {
        [(__bridge id<MTLRenderCommandEncoder>)command->renderEncoder endEncoding];
        releaseRetained(&command->renderEncoder);
    }
    if (command->blitEncoder) {
        [(__bridge id<MTLBlitCommandEncoder>)command->blitEncoder endEncoding];
        releaseRetained(&command->blitEncoder);
    }
}

static id<MTLBlitCommandEncoder> ensureBlitEncoder(LWMGLCommand command)
{
    if (validateMutableCommand(command) != 0) return nil;
    if (command->blitEncoder) return nativeBlitEncoder(command);

    endActiveEncoder(command);
    id<MTLCommandBuffer> commandBuffer = nativeCommandBuffer(command);
    id<MTLBlitCommandEncoder> encoder = [commandBuffer blitCommandEncoder];
    if (!encoder) {
        lwmglSetErrorInternal("failed to create Metal blit encoder");
        return nil;
    }
    command->blitEncoder = (__bridge_retained void *)encoder;
    return encoder;
}

LWMGLCommand lwmglCommandBeginInternal(void)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->queue) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        id<MTLCommandBuffer> object = [state->queue commandBuffer];
        if (!object) {
            lwmglSetErrorInternal("failed to create Metal command buffer");
            return NULL;
        }

        LWMGLCommand handle = (LWMGLCommand)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate command handle");
            return NULL;
        }
        handle->commandBuffer = (__bridge_retained void *)object;
        return handle;
    }
}

int lwmglCommandBeginComputeInternal(LWMGLCommand command)
{
    @autoreleasepool {
        if (validateMutableCommand(command) != 0) return -1;
        endActiveEncoder(command);
        id<MTLComputeCommandEncoder> encoder = [nativeCommandBuffer(command) computeCommandEncoder];
        if (!encoder) {
            lwmglSetErrorInternal("failed to create Metal compute encoder");
            return -1;
        }
        command->computeEncoder = (__bridge_retained void *)encoder;
        command->computePipelineSet = 0;
        return 0;
    }
}

int lwmglCommandSetComputePipelineInternal(LWMGLCommand command, LWMGLComputePipeline pipeline)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLComputeCommandEncoder> encoder = nativeComputeEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("compute encoding is not active");
        return -1;
    }
    id<MTLComputePipelineState> state = lwmglNativeComputePipelineInternal(pipeline);
    if (!state) {
        lwmglSetErrorInternal("compute pipeline is null");
        return -1;
    }

    [encoder setComputePipelineState:state];
    command->computeExecutionWidth = state.threadExecutionWidth;
    command->computeMaxThreads = state.maxTotalThreadsPerThreadgroup;
    command->computePipelineSet = 1;
    return 0;
}

int lwmglCommandSetBufferInternal(LWMGLCommand command, LWMGLBuffer buffer, size_t offset, uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLComputeCommandEncoder> encoder = nativeComputeEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("compute encoding is not active");
        return -1;
    }
    id<MTLBuffer> native = lwmglNativeBufferInternal(buffer);
    if (!native) {
        lwmglSetErrorInternal("buffer is null");
        return -1;
    }
    const size_t bufferSize = lwmglBufferSizeInternal(buffer);
    if (offset > bufferSize) {
        lwmglSetErrorInternal("buffer binding offset exceeds allocation");
        return -1;
    }
    [encoder setBuffer:native offset:offset atIndex:index];
    return 0;
}

int lwmglCommandSetTextureInternal(LWMGLCommand command, LWMGLTexture texture, uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLComputeCommandEncoder> encoder = nativeComputeEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("compute encoding is not active");
        return -1;
    }
    id<MTLTexture> native = lwmglNativeTextureInternal(texture);
    if (!native) {
        lwmglSetErrorInternal("texture is null");
        return -1;
    }
    [encoder setTexture:native atIndex:index];
    return 0;
}

int lwmglCommandSetSamplerInternal(LWMGLCommand command, LWMGLSampler sampler, uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLComputeCommandEncoder> encoder = nativeComputeEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("compute encoding is not active");
        return -1;
    }
    id<MTLSamplerState> native = lwmglNativeSamplerInternal(sampler);
    if (!native) {
        lwmglSetErrorInternal("sampler is null");
        return -1;
    }
    [encoder setSamplerState:native atIndex:index];
    return 0;
}

int lwmglCommandDispatchInternal(LWMGLCommand command, uint32_t x, uint32_t y, uint32_t z)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLComputeCommandEncoder> encoder = nativeComputeEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("compute encoding is not active");
        return -1;
    }
    if (!command->computePipelineSet) {
        lwmglSetErrorInternal("compute pipeline is not bound");
        return -1;
    }
    if (x == 0u || y == 0u || z == 0u) {
        lwmglSetErrorInternal("dispatch dimensions must be non-zero");
        return -1;
    }

    NSUInteger maxThreads = command->computeMaxThreads ? command->computeMaxThreads : 1u;
    NSUInteger executionWidth = command->computeExecutionWidth ? command->computeExecutionWidth : 1u;
    NSUInteger tgX = executionWidth < maxThreads ? executionWidth : maxThreads;
    if (tgX < 1u) tgX = 1u;

    NSUInteger tgY = 1u;
    NSUInteger tgZ = 1u;
    if (y > 1u) {
        NSUInteger remaining = maxThreads / tgX;
        if (remaining < 1u) remaining = 1u;
        tgY = y < remaining ? y : remaining;
    }
    if (z > 1u) {
        NSUInteger product = tgX * tgY;
        NSUInteger remaining = product < maxThreads ? maxThreads / product : 1u;
        if (remaining < 1u) remaining = 1u;
        tgZ = z < remaining ? z : remaining;
    }

    [encoder dispatchThreads:MTLSizeMake(x, y, z)
       threadsPerThreadgroup:MTLSizeMake(tgX, tgY, tgZ)];
    return 0;
}

int lwmglCommandCopyBufferInternal(
    LWMGLCommand command,
    LWMGLBuffer src,
    size_t srcOffset,
    LWMGLBuffer dst,
    size_t dstOffset,
    size_t size)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLBuffer> nativeSrc = lwmglNativeBufferInternal(src);
    id<MTLBuffer> nativeDst = lwmglNativeBufferInternal(dst);
    if (!nativeSrc || !nativeDst) {
        lwmglSetErrorInternal("buffer copy requires non-null source and destination");
        return -1;
    }
    const size_t srcSize = lwmglBufferSizeInternal(src);
    const size_t dstSize = lwmglBufferSizeInternal(dst);
    if (srcOffset > srcSize || size > srcSize - srcOffset ||
        dstOffset > dstSize || size > dstSize - dstOffset) {
        lwmglSetErrorInternal("buffer copy range exceeds allocation");
        return -1;
    }
    if (size == 0u) return 0;

    id<MTLBlitCommandEncoder> encoder = ensureBlitEncoder(command);
    if (!encoder) return -1;
    [encoder copyFromBuffer:nativeSrc
               sourceOffset:srcOffset
                   toBuffer:nativeDst
          destinationOffset:dstOffset
                       size:size];
    return 0;
}

int lwmglCommandBeginRenderToDrawableInternal(LWMGLCommand command, LWMGLClearColor clearColor, int clear)
{
    @autoreleasepool {
        if (validateMutableCommand(command) != 0) return -1;
        if (command->drawable) {
            lwmglSetErrorInternal("command already owns a drawable");
            return -1;
        }
        endActiveEncoder(command);
        if (lwmglSurfaceAcquireDrawable() != 0) return -1;

        LWMGLContextState *state = lwmglContextState();
        id<CAMetalDrawable> drawable = state->drawable;
        if (!drawable) {
            lwmglSetErrorInternal("Metal drawable is unavailable");
            return -1;
        }
        command->drawable = (__bridge_retained void *)drawable;
        state->drawable = nil;

        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        if (!pass) {
            releaseRetained(&command->drawable);
            lwmglSetErrorInternal("failed to create Metal render pass descriptor");
            return -1;
        }
        pass.colorAttachments[0].texture = drawable.texture;
        pass.colorAttachments[0].loadAction = clear ? MTLLoadActionClear : MTLLoadActionLoad;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(
            clearColor.r, clearColor.g, clearColor.b, clearColor.a);

        id<MTLRenderCommandEncoder> encoder = [nativeCommandBuffer(command) renderCommandEncoderWithDescriptor:pass];
        if (!encoder) {
            releaseRetained(&command->drawable);
            lwmglSetErrorInternal("failed to create Metal render encoder");
            return -1;
        }
        command->renderEncoder = (__bridge_retained void *)encoder;
        return 0;
    }
}

int lwmglCommandSetRenderPipelineInternal(LWMGLCommand command, LWMGLRenderPipeline pipeline)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLRenderCommandEncoder> encoder = nativeRenderEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    id<MTLRenderPipelineState> native = lwmglNativeRenderPipelineInternal(pipeline);
    if (!native) {
        lwmglSetErrorInternal("render pipeline is null");
        return -1;
    }
    [encoder setRenderPipelineState:native];
    return 0;
}

int lwmglCommandSetFragmentBufferInternal(
    LWMGLCommand command,
    LWMGLBuffer buffer,
    size_t offset,
    uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLRenderCommandEncoder> encoder = nativeRenderEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    id<MTLBuffer> native = lwmglNativeBufferInternal(buffer);
    if (!native) {
        lwmglSetErrorInternal("buffer is null");
        return -1;
    }
    const size_t bufferSize = lwmglBufferSizeInternal(buffer);
    if (offset > bufferSize) {
        lwmglSetErrorInternal("buffer binding offset exceeds allocation");
        return -1;
    }
    [encoder setFragmentBuffer:native offset:offset atIndex:index];
    return 0;
}

int lwmglCommandSetFragmentTextureInternal(
    LWMGLCommand command,
    LWMGLTexture texture,
    uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLRenderCommandEncoder> encoder = nativeRenderEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    id<MTLTexture> native = lwmglNativeTextureInternal(texture);
    if (!native) {
        lwmglSetErrorInternal("texture is null");
        return -1;
    }
    [encoder setFragmentTexture:native atIndex:index];
    return 0;
}

int lwmglCommandSetFragmentSamplerInternal(
    LWMGLCommand command,
    LWMGLSampler sampler,
    uint32_t index)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLRenderCommandEncoder> encoder = nativeRenderEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    id<MTLSamplerState> native = lwmglNativeSamplerInternal(sampler);
    if (!native) {
        lwmglSetErrorInternal("sampler is null");
        return -1;
    }
    [encoder setFragmentSamplerState:native atIndex:index];
    return 0;
}

int lwmglCommandDrawInternal(LWMGLCommand command, uint32_t vertexStart, uint32_t vertexCount)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<MTLRenderCommandEncoder> encoder = nativeRenderEncoder(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    if (vertexCount == 0u) {
        lwmglSetErrorInternal("draw vertex count must be non-zero");
        return -1;
    }
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:vertexStart vertexCount:vertexCount];
    return 0;
}

int lwmglCommandPresentInternal(LWMGLCommand command)
{
    if (validateMutableCommand(command) != 0) return -1;
    id<CAMetalDrawable> drawable = nativeDrawable(command);
    if (!drawable) {
        lwmglSetErrorInternal("command has no drawable to present");
        return -1;
    }
    if (command->presented) {
        lwmglSetErrorInternal("drawable has already been scheduled for presentation");
        return -1;
    }
    endActiveEncoder(command);
    [nativeCommandBuffer(command) presentDrawable:drawable];
    command->presented = 1;
    return 0;
}

int lwmglCommandEndEncodingInternal(LWMGLCommand command)
{
    if (validateMutableCommand(command) != 0) return -1;
    endActiveEncoder(command);
    return 0;
}

int lwmglCommandCommitInternal(LWMGLCommand command)
{
    if (validateMutableCommand(command) != 0) return -1;
    endActiveEncoder(command);
    [nativeCommandBuffer(command) commit];
    command->committed = 1;
    releaseRetained(&command->drawable);
    return 0;
}

int lwmglCommandWaitInternal(LWMGLCommand command)
{
    if (!command || !command->commandBuffer) {
        lwmglSetErrorInternal("command is null");
        return -1;
    }
    if (!command->committed) {
        lwmglSetErrorInternal("command must be committed before wait");
        return -1;
    }

    id<MTLCommandBuffer> native = nativeCommandBuffer(command);
    [native waitUntilCompleted];
    if (native.status == MTLCommandBufferStatusError || native.error) {
        const char *message = native.error.localizedDescription.UTF8String;
        lwmglSetErrorInternal(message && message[0] ? message : "Metal command buffer failed");
        return -1;
    }
    return 0;
}

void lwmglCommandDestroyInternal(LWMGLCommand command)
{
    if (!command) return;
    @autoreleasepool {
        if (!command->committed) endActiveEncoder(command);
        releaseRetained(&command->computeEncoder);
        releaseRetained(&command->renderEncoder);
        releaseRetained(&command->blitEncoder);
        releaseRetained(&command->drawable);
        releaseRetained(&command->commandBuffer);
        free(command);
    }
}

int lwmglCommandWaitIdleInternal(void)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->queue) {
            lwmglSetErrorInternal("Metal context is not created");
            return -1;
        }
        id<MTLCommandBuffer> command = [state->queue commandBuffer];
        if (!command) {
            lwmglSetErrorInternal("failed to create idle-wait command buffer");
            return -1;
        }
        [command commit];
        [command waitUntilCompleted];
        if (command.status == MTLCommandBufferStatusError || command.error) {
            const char *message = command.error.localizedDescription.UTF8String;
            lwmglSetErrorInternal(message && message[0] ? message : "Metal idle wait failed");
            return -1;
        }
        return 0;
    }
}

id<MTLCommandBuffer> lwmglNativeCommandBufferInternal(LWMGLCommand command)
{
    return nativeCommandBuffer(command);
}

id<MTLComputeCommandEncoder> lwmglNativeComputeEncoderInternal(LWMGLCommand command)
{
    return nativeComputeEncoder(command);
}
