#include "internal.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct LWMGLAccelerationStructureImpl {
    void *metalAccelerationStructure;
    void *descriptor;
};

static int requireRayTracing(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->device || !state->queue) {
        lwmglSetErrorInternal("Metal context is not created");
        return -1;
    }
    if (!lwmglRayTracingSupportedInternal()) {
        lwmglSetErrorInternal("Metal ray tracing is not supported by this device/API");
        return -1;
    }
    return 0;
}

int lwmglRayTracingSupportedInternal(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->device) return 0;

    if (@available(macOS 11.0, *)) {
        if (![state->device respondsToSelector:@selector(supportsRaytracing)]) return 0;
        return state->device.supportsRaytracing ? 1 : 0;
    }
    return 0;
}

static id<MTLAccelerationStructure> buildDescriptor(MTLAccelerationStructureDescriptor *descriptor)
{
    @autoreleasepool {
        if (requireRayTracing() != 0) return nil;
        if (!descriptor) {
            lwmglSetErrorInternal("acceleration structure descriptor is null");
            return nil;
        }

        LWMGLContextState *state = lwmglContextState();
        if (@available(macOS 11.0, *)) {
            const MTLAccelerationStructureSizes sizes =
                [state->device accelerationStructureSizesWithDescriptor:descriptor];
            if (sizes.accelerationStructureSize == 0u) {
                lwmglSetErrorInternal("Metal returned an empty acceleration structure size");
                return nil;
            }

            id<MTLAccelerationStructure> accelerationStructure =
                [state->device newAccelerationStructureWithSize:sizes.accelerationStructureSize];
            if (!accelerationStructure) {
                lwmglSetErrorInternal("failed to allocate Metal acceleration structure");
                return nil;
            }

            const NSUInteger scratchLength =
                sizes.buildScratchBufferSize > 0u ? sizes.buildScratchBufferSize : 1u;
            id<MTLBuffer> scratch = [state->device newBufferWithLength:scratchLength
                                                               options:MTLResourceStorageModePrivate];
            if (!scratch) {
                lwmglSetErrorInternal("failed to allocate acceleration structure scratch buffer");
                return nil;
            }

            id<MTLCommandBuffer> command = [state->queue commandBuffer];
            if (!command) {
                lwmglSetErrorInternal("failed to create acceleration structure command buffer");
                return nil;
            }

            id<MTLAccelerationStructureCommandEncoder> encoder =
                [command accelerationStructureCommandEncoder];
            if (!encoder) {
                lwmglSetErrorInternal("failed to create acceleration structure command encoder");
                return nil;
            }

            [encoder buildAccelerationStructure:accelerationStructure
                                     descriptor:descriptor
                                  scratchBuffer:scratch
                            scratchBufferOffset:0u];
            [encoder endEncoding];
            [command commit];
            [command waitUntilCompleted];

            if (command.status == MTLCommandBufferStatusError || command.error) {
                const char *message = command.error.localizedDescription.UTF8String;
                lwmglSetErrorInternal(
                    message && message[0] ? message : "Metal acceleration structure build failed");
                return nil;
            }
            return accelerationStructure;
        }

        lwmglSetErrorInternal("Metal ray tracing is unavailable on this macOS version");
        return nil;
    }
}

static int validateVertexRange(const LWMGLTriangleGeometryDesc *geometry)
{
    id<MTLBuffer> vertexBuffer = lwmglNativeBufferInternal(geometry->vertexBuffer);
    if (!vertexBuffer) {
        lwmglSetErrorInternal("triangle geometry vertex buffer is null");
        return -1;
    }
    if (geometry->vertexCount < 3u || geometry->vertexStride < 12u) {
        lwmglSetErrorInternal("triangle geometry requires at least three float3 vertices");
        return -1;
    }

    const size_t bufferSize = lwmglBufferSizeInternal(geometry->vertexBuffer);
    const size_t lastVertex = (size_t)geometry->vertexCount - 1u;
    if (lastVertex > (SIZE_MAX - 12u) / geometry->vertexStride) {
        lwmglSetErrorInternal("triangle vertex range overflows size_t");
        return -1;
    }
    const size_t required = lastVertex * geometry->vertexStride + 12u;
    if (geometry->vertexOffset > bufferSize || required > bufferSize - geometry->vertexOffset) {
        lwmglSetErrorInternal("triangle vertex range exceeds buffer allocation");
        return -1;
    }
    return 0;
}

static int validateIndexRange(const LWMGLTriangleGeometryDesc *geometry)
{
    if (!geometry->indexBuffer) {
        if (geometry->indexCount != 0u || geometry->vertexCount % 3u != 0u) {
            lwmglSetErrorInternal("non-indexed triangle geometry requires vertexCount divisible by three");
            return -1;
        }
        return 0;
    }

    id<MTLBuffer> indexBuffer = lwmglNativeBufferInternal(geometry->indexBuffer);
    if (!indexBuffer) {
        lwmglSetErrorInternal("triangle geometry index buffer is invalid");
        return -1;
    }
    if (geometry->indexCount < 3u || geometry->indexCount % 3u != 0u) {
        lwmglSetErrorInternal("triangle index count must be a non-zero multiple of three");
        return -1;
    }

    const size_t indexSize = geometry->index32 ? 4u : 2u;
    if (geometry->indexOffset % indexSize != 0u) {
        lwmglSetErrorInternal("triangle index offset is not aligned to the index type");
        return -1;
    }
    if ((size_t)geometry->indexCount > SIZE_MAX / indexSize) {
        lwmglSetErrorInternal("triangle index range overflows size_t");
        return -1;
    }
    const size_t required = (size_t)geometry->indexCount * indexSize;
    const size_t bufferSize = lwmglBufferSizeInternal(geometry->indexBuffer);
    if (geometry->indexOffset > bufferSize || required > bufferSize - geometry->indexOffset) {
        lwmglSetErrorInternal("triangle index range exceeds buffer allocation");
        return -1;
    }
    return 0;
}

static LWMGLAccelerationStructure wrapAccelerationStructure(
    id<MTLAccelerationStructure> accelerationStructure,
    MTLAccelerationStructureDescriptor *descriptor)
{
    if (!accelerationStructure || !descriptor) return NULL;

    LWMGLAccelerationStructure handle =
        (LWMGLAccelerationStructure)calloc(1u, sizeof *handle);
    if (!handle) {
        lwmglSetErrorInternal("failed to allocate acceleration structure handle");
        return NULL;
    }
    handle->metalAccelerationStructure = (__bridge_retained void *)accelerationStructure;
    handle->descriptor = (__bridge_retained void *)descriptor;
    return handle;
}

LWMGLAccelerationStructure lwmglTriangleAccelerationStructureCreateInternal(
    const LWMGLTriangleGeometryDesc *geometries,
    uint32_t geometryCount)
{
    @autoreleasepool {
        if (requireRayTracing() != 0) return NULL;
        if (!geometries || geometryCount == 0u) {
            lwmglSetErrorInternal("triangle acceleration structure requires geometry");
            return NULL;
        }

        NSMutableArray *nativeGeometries = [NSMutableArray arrayWithCapacity:geometryCount];
        if (!nativeGeometries) {
            lwmglSetErrorInternal("failed to allocate triangle geometry descriptor array");
            return NULL;
        }

        for (uint32_t i = 0u; i < geometryCount; ++i) {
            const LWMGLTriangleGeometryDesc *geometry = &geometries[i];
            if (validateVertexRange(geometry) != 0 || validateIndexRange(geometry) != 0) return NULL;

            MTLAccelerationStructureTriangleGeometryDescriptor *native =
                [MTLAccelerationStructureTriangleGeometryDescriptor descriptor];
            if (!native) {
                lwmglSetErrorInternal("failed to create Metal triangle geometry descriptor");
                return NULL;
            }

            native.vertexBuffer = lwmglNativeBufferInternal(geometry->vertexBuffer);
            native.vertexBufferOffset = geometry->vertexOffset;
            native.vertexStride = geometry->vertexStride;
            native.vertexFormat = MTLAttributeFormatFloat3;
            native.opaque = YES;

            if (geometry->indexBuffer) {
                native.indexBuffer = lwmglNativeBufferInternal(geometry->indexBuffer);
                native.indexBufferOffset = geometry->indexOffset;
                native.indexType = geometry->index32 ? MTLIndexTypeUInt32 : MTLIndexTypeUInt16;
                native.triangleCount = geometry->indexCount / 3u;
            } else {
                native.triangleCount = geometry->vertexCount / 3u;
            }
            [nativeGeometries addObject:native];
        }

        MTLPrimitiveAccelerationStructureDescriptor *descriptor =
            [[MTLPrimitiveAccelerationStructureDescriptor alloc] init];
        if (!descriptor) {
            lwmglSetErrorInternal("failed to allocate primitive acceleration structure descriptor");
            return NULL;
        }
        descriptor.geometryDescriptors = nativeGeometries;

        id<MTLAccelerationStructure> accelerationStructure = buildDescriptor(descriptor);
        return wrapAccelerationStructure(accelerationStructure, descriptor);
    }
}

LWMGLAccelerationStructure lwmglInstanceAccelerationStructureCreateInternal(
    const LWMGLInstanceDesc *instances,
    uint32_t instanceCount)
{
    @autoreleasepool {
        if (requireRayTracing() != 0) return NULL;
        if (!instances || instanceCount == 0u) {
            lwmglSetErrorInternal("instance acceleration structure requires instances");
            return NULL;
        }
        if ((size_t)instanceCount > SIZE_MAX / sizeof(MTLAccelerationStructureUserIDInstanceDescriptor)) {
            lwmglSetErrorInternal("instance descriptor buffer size overflows size_t");
            return NULL;
        }

        LWMGLContextState *state = lwmglContextState();
        const size_t descriptorBytes =
            (size_t)instanceCount * sizeof(MTLAccelerationStructureUserIDInstanceDescriptor);
        id<MTLBuffer> instanceBuffer =
            [state->device newBufferWithLength:descriptorBytes options:MTLResourceStorageModeShared];
        if (!instanceBuffer) {
            lwmglSetErrorInternal("failed to allocate Metal instance descriptor buffer");
            return NULL;
        }

        MTLAccelerationStructureUserIDInstanceDescriptor *nativeInstances =
            (MTLAccelerationStructureUserIDInstanceDescriptor *)instanceBuffer.contents;
        memset(nativeInstances, 0, descriptorBytes);

        NSMutableArray *nativeStructures = [NSMutableArray arrayWithCapacity:instanceCount];
        if (!nativeStructures) {
            lwmglSetErrorInternal("failed to allocate instance acceleration structure array");
            return NULL;
        }

        for (uint32_t i = 0u; i < instanceCount; ++i) {
            id<MTLAccelerationStructure> accelerationStructure =
                lwmglNativeAccelerationStructureInternal(instances[i].accelerationStructure);
            if (!accelerationStructure) {
                lwmglSetErrorInternal("instance references a null acceleration structure");
                return NULL;
            }
            [nativeStructures addObject:accelerationStructure];

            nativeInstances[i].transformationMatrix[0] = MTLPackedFloat3Make(
                instances[i].transform[0], instances[i].transform[4], instances[i].transform[8]);
            nativeInstances[i].transformationMatrix[1] = MTLPackedFloat3Make(
                instances[i].transform[1], instances[i].transform[5], instances[i].transform[9]);
            nativeInstances[i].transformationMatrix[2] = MTLPackedFloat3Make(
                instances[i].transform[2], instances[i].transform[6], instances[i].transform[10]);
            nativeInstances[i].transformationMatrix[3] = MTLPackedFloat3Make(
                instances[i].transform[3], instances[i].transform[7], instances[i].transform[11]);
            nativeInstances[i].options = MTLAccelerationStructureInstanceOptionNone;
            nativeInstances[i].mask = instances[i].mask;
            nativeInstances[i].intersectionFunctionTableOffset = 0u;
            nativeInstances[i].accelerationStructureIndex = i;
            nativeInstances[i].userID = instances[i].userId;
        }

        MTLInstanceAccelerationStructureDescriptor *descriptor =
            [[MTLInstanceAccelerationStructureDescriptor alloc] init];
        if (!descriptor) {
            lwmglSetErrorInternal("failed to allocate instance acceleration structure descriptor");
            return NULL;
        }
        descriptor.instanceDescriptorType = MTLAccelerationStructureInstanceDescriptorTypeUserID;
        descriptor.instanceDescriptorBuffer = instanceBuffer;
        descriptor.instanceDescriptorBufferOffset = 0u;
        descriptor.instanceDescriptorStride = sizeof(MTLAccelerationStructureUserIDInstanceDescriptor);
        descriptor.instanceCount = instanceCount;
        descriptor.instancedAccelerationStructures = nativeStructures;

        id<MTLAccelerationStructure> accelerationStructure = buildDescriptor(descriptor);
        return wrapAccelerationStructure(accelerationStructure, descriptor);
    }
}

int lwmglAccelerationStructureRebuildInternal(LWMGLAccelerationStructure accelerationStructure)
{
    @autoreleasepool {
        if (requireRayTracing() != 0) return -1;
        if (!accelerationStructure || !accelerationStructure->descriptor) {
            lwmglSetErrorInternal("acceleration structure is null");
            return -1;
        }

        MTLAccelerationStructureDescriptor *descriptor =
            (__bridge MTLAccelerationStructureDescriptor *)accelerationStructure->descriptor;
        id<MTLAccelerationStructure> rebuilt = buildDescriptor(descriptor);
        if (!rebuilt) return -1;

        id released = (__bridge_transfer id)accelerationStructure->metalAccelerationStructure;
        (void)released;
        accelerationStructure->metalAccelerationStructure = (__bridge_retained void *)rebuilt;
        return 0;
    }
}

void lwmglAccelerationStructureDestroyInternal(LWMGLAccelerationStructure accelerationStructure)
{
    if (!accelerationStructure) return;
    @autoreleasepool {
        id releasedAccelerationStructure =
            (__bridge_transfer id)accelerationStructure->metalAccelerationStructure;
        id releasedDescriptor = (__bridge_transfer id)accelerationStructure->descriptor;
        (void)releasedAccelerationStructure;
        (void)releasedDescriptor;
        accelerationStructure->metalAccelerationStructure = NULL;
        accelerationStructure->descriptor = NULL;
        free(accelerationStructure);
    }
}

int lwmglCommandSetAccelerationStructureInternal(
    LWMGLCommand command,
    LWMGLAccelerationStructure accelerationStructure,
    uint32_t index)
{
    @autoreleasepool {
        if (requireRayTracing() != 0) return -1;
        id<MTLComputeCommandEncoder> encoder = lwmglNativeComputeEncoderInternal(command);
        if (!encoder) {
            lwmglSetErrorInternal("compute encoding is not active");
            return -1;
        }
        id<MTLAccelerationStructure> native =
            lwmglNativeAccelerationStructureInternal(accelerationStructure);
        if (!native) {
            lwmglSetErrorInternal("acceleration structure is null");
            return -1;
        }
        if (@available(macOS 11.0, *)) {
            [encoder setAccelerationStructure:native atBufferIndex:index];
            return 0;
        }
        lwmglSetErrorInternal("Metal ray tracing is unavailable on this macOS version");
        return -1;
    }
}

id<MTLAccelerationStructure> lwmglNativeAccelerationStructureInternal(
    LWMGLAccelerationStructure accelerationStructure)
{
    return accelerationStructure && accelerationStructure->metalAccelerationStructure
        ? (__bridge id<MTLAccelerationStructure>)accelerationStructure->metalAccelerationStructure
        : nil;
}
