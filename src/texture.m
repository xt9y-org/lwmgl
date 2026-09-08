#include "internal.h"

#include <stdlib.h>
#include <string.h>

struct LWMGLTextureImpl {
    void *metalTexture;
    uint32_t width;
    uint32_t height;
    LWMGLPixelFormat format;
    LWMGLStorageMode storage;
    size_t bytesPerPixel;
};

struct LWMGLSamplerImpl {
    void *metalSampler;
};

static id<MTLTexture> nativeTexture(LWMGLTexture texture)
{
    return texture ? (__bridge id<MTLTexture>)texture->metalTexture : nil;
}

static MTLPixelFormat mapPixelFormat(LWMGLPixelFormat format)
{
    switch (format) {
        case LWMGL_BGRA8_UNORM: return MTLPixelFormatBGRA8Unorm;
        case LWMGL_RGBA8_UNORM: return MTLPixelFormatRGBA8Unorm;
        case LWMGL_RGBA16_FLOAT: return MTLPixelFormatRGBA16Float;
        case LWMGL_RGBA32_FLOAT: return MTLPixelFormatRGBA32Float;
    }
    return MTLPixelFormatInvalid;
}

static size_t bytesPerPixel(LWMGLPixelFormat format)
{
    switch (format) {
        case LWMGL_BGRA8_UNORM:
        case LWMGL_RGBA8_UNORM:
            return 4u;
        case LWMGL_RGBA16_FLOAT:
            return 8u;
        case LWMGL_RGBA32_FLOAT:
            return 16u;
    }
    return 0u;
}

static MTLTextureUsage mapTextureUsage(uint32_t usage)
{
    MTLTextureUsage result = MTLTextureUsageUnknown;
    if (usage & (LWMGL_TEXTURE_SAMPLED | LWMGL_TEXTURE_READ)) result |= MTLTextureUsageShaderRead;
    if (usage & LWMGL_TEXTURE_WRITE) result |= MTLTextureUsageShaderWrite;
    if (usage & LWMGL_TEXTURE_RENDER_TARGET) result |= MTLTextureUsageRenderTarget;
    return result;
}

static MTLSamplerMinMagFilter mapFilter(LWMGLFilter filter)
{
    return filter == LWMGL_FILTER_LINEAR ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
}

static MTLSamplerAddressMode mapAddressMode(LWMGLAddressMode mode)
{
    return mode == LWMGL_ADDRESS_REPEAT ? MTLSamplerAddressModeRepeat : MTLSamplerAddressModeClampToEdge;
}

static int validateSamplerDesc(const LWMGLSamplerDesc *desc)
{
    if (!desc) {
        lwmglSetErrorInternal("sampler descriptor is null");
        return -1;
    }
    if ((desc->minFilter != LWMGL_FILTER_NEAREST && desc->minFilter != LWMGL_FILTER_LINEAR) ||
        (desc->magFilter != LWMGL_FILTER_NEAREST && desc->magFilter != LWMGL_FILTER_LINEAR)) {
        lwmglSetErrorInternal("invalid sampler filter");
        return -1;
    }
    if ((desc->addressU != LWMGL_ADDRESS_CLAMP && desc->addressU != LWMGL_ADDRESS_REPEAT) ||
        (desc->addressV != LWMGL_ADDRESS_CLAMP && desc->addressV != LWMGL_ADDRESS_REPEAT)) {
        lwmglSetErrorInternal("invalid sampler address mode");
        return -1;
    }
    return 0;
}

LWMGLTexture lwmglTextureCreateInternal(const LWMGLTextureDesc *desc)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (!desc || desc->width == 0u || desc->height == 0u) {
            lwmglSetErrorInternal("texture descriptor must have non-zero dimensions");
            return NULL;
        }
        if (desc->storage != LWMGL_STORAGE_SHARED && desc->storage != LWMGL_STORAGE_PRIVATE) {
            lwmglSetErrorInternal("invalid texture storage mode");
            return NULL;
        }

        const MTLPixelFormat pixelFormat = mapPixelFormat(desc->format);
        const size_t pixelSize = bytesPerPixel(desc->format);
        if (pixelFormat == MTLPixelFormatInvalid || pixelSize == 0u) {
            lwmglSetErrorInternal("invalid texture pixel format");
            return NULL;
        }

        MTLTextureDescriptor *nativeDesc = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:pixelFormat
                                        width:desc->width
                                       height:desc->height
                                    mipmapped:NO];
        if (!nativeDesc) {
            lwmglSetErrorInternal("failed to create Metal texture descriptor");
            return NULL;
        }
        nativeDesc.usage = mapTextureUsage(desc->usage);
        nativeDesc.storageMode = desc->storage == LWMGL_STORAGE_PRIVATE
            ? MTLStorageModePrivate
            : MTLStorageModeShared;

        id<MTLTexture> object = [state->device newTextureWithDescriptor:nativeDesc];
        if (!object) {
            lwmglSetErrorInternal("failed to allocate Metal texture");
            return NULL;
        }

        LWMGLTexture handle = (LWMGLTexture)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate texture handle");
            return NULL;
        }
        handle->metalTexture = (__bridge_retained void *)object;
        handle->width = desc->width;
        handle->height = desc->height;
        handle->format = desc->format;
        handle->storage = desc->storage;
        handle->bytesPerPixel = pixelSize;
        return handle;
    }
}

void lwmglTextureDestroyInternal(LWMGLTexture texture)
{
    if (!texture) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)texture->metalTexture;
        (void)released;
        texture->metalTexture = NULL;
        free(texture);
    }
}

int lwmglTextureUpload2DInternal(LWMGLTexture texture, const void *data, size_t bytesPerRow)
{
    @autoreleasepool {
        if (!texture) {
            lwmglSetErrorInternal("texture is null");
            return -1;
        }
        if (!data) {
            lwmglSetErrorInternal("texture upload data is null");
            return -1;
        }
        if (texture->width > SIZE_MAX / texture->bytesPerPixel) {
            lwmglSetErrorInternal("texture row size overflows size_t");
            return -1;
        }
        const size_t minimumRow = (size_t)texture->width * texture->bytesPerPixel;
        if (bytesPerRow < minimumRow) {
            lwmglSetErrorInternal("texture upload row pitch is too small");
            return -1;
        }
        if (texture->height > 0u && bytesPerRow > SIZE_MAX / texture->height) {
            lwmglSetErrorInternal("texture upload size overflows size_t");
            return -1;
        }

        id<MTLTexture> object = nativeTexture(texture);
        if (!object) {
            lwmglSetErrorInternal("texture has no Metal resource");
            return -1;
        }

        if (texture->storage == LWMGL_STORAGE_SHARED) {
            [object replaceRegion:MTLRegionMake2D(0u, 0u, texture->width, texture->height)
                   mipmapLevel:0u
                     withBytes:data
                   bytesPerRow:bytesPerRow];
            return 0;
        }

        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device || !state->queue) {
            lwmglSetErrorInternal("Metal context is not created");
            return -1;
        }

        const size_t alignment = 256u;
        if (minimumRow > SIZE_MAX - (alignment - 1u)) {
            lwmglSetErrorInternal("texture staging row size overflows size_t");
            return -1;
        }
        const size_t stagingRow = (minimumRow + alignment - 1u) & ~(alignment - 1u);
        if (texture->height > 0u && stagingRow > SIZE_MAX / texture->height) {
            lwmglSetErrorInternal("texture staging allocation overflows size_t");
            return -1;
        }
        const size_t stagingSize = stagingRow * texture->height;

        id<MTLBuffer> staging = [state->device newBufferWithLength:stagingSize
                                                          options:MTLResourceStorageModeShared];
        if (!staging) {
            lwmglSetErrorInternal("failed to allocate texture staging buffer");
            return -1;
        }

        unsigned char *destination = (unsigned char *)staging.contents;
        const unsigned char *source = (const unsigned char *)data;
        for (uint32_t y = 0u; y < texture->height; ++y) {
            memcpy(destination + (size_t)y * stagingRow,
                   source + (size_t)y * bytesPerRow,
                   minimumRow);
        }

        id<MTLCommandBuffer> command = [state->queue commandBuffer];
        if (!command) {
            lwmglSetErrorInternal("failed to create texture upload command buffer");
            return -1;
        }
        id<MTLBlitCommandEncoder> blit = [command blitCommandEncoder];
        if (!blit) {
            lwmglSetErrorInternal("failed to create texture upload blit encoder");
            return -1;
        }

        [blit copyFromBuffer:staging
                sourceOffset:0u
           sourceBytesPerRow:stagingRow
         sourceBytesPerImage:stagingSize
                  sourceSize:MTLSizeMake(texture->width, texture->height, 1u)
                   toTexture:object
            destinationSlice:0u
            destinationLevel:0u
           destinationOrigin:MTLOriginMake(0u, 0u, 0u)];
        [blit endEncoding];
        [command commit];
        return 0;
    }
}

uint32_t lwmglTextureWidthInternal(LWMGLTexture texture)
{
    if (!texture) {
        lwmglSetErrorInternal("texture is null");
        return 0u;
    }
    return texture->width;
}

uint32_t lwmglTextureHeightInternal(LWMGLTexture texture)
{
    if (!texture) {
        lwmglSetErrorInternal("texture is null");
        return 0u;
    }
    return texture->height;
}

LWMGLSampler lwmglSamplerCreateInternal(const LWMGLSamplerDesc *desc)
{
    @autoreleasepool {
        LWMGLContextState *state = lwmglContextState();
        if (!state->created || !state->device) {
            lwmglSetErrorInternal("Metal context is not created");
            return NULL;
        }
        if (validateSamplerDesc(desc) != 0) return NULL;

        MTLSamplerDescriptor *nativeDesc = [[MTLSamplerDescriptor alloc] init];
        if (!nativeDesc) {
            lwmglSetErrorInternal("failed to allocate sampler descriptor");
            return NULL;
        }
        nativeDesc.minFilter = mapFilter(desc->minFilter);
        nativeDesc.magFilter = mapFilter(desc->magFilter);
        nativeDesc.sAddressMode = mapAddressMode(desc->addressU);
        nativeDesc.tAddressMode = mapAddressMode(desc->addressV);
        nativeDesc.rAddressMode = MTLSamplerAddressModeClampToEdge;

        id<MTLSamplerState> object = [state->device newSamplerStateWithDescriptor:nativeDesc];
        if (!object) {
            lwmglSetErrorInternal("failed to create Metal sampler state");
            return NULL;
        }

        LWMGLSampler handle = (LWMGLSampler)calloc(1u, sizeof *handle);
        if (!handle) {
            lwmglSetErrorInternal("failed to allocate sampler handle");
            return NULL;
        }
        handle->metalSampler = (__bridge_retained void *)object;
        return handle;
    }
}

void lwmglSamplerDestroyInternal(LWMGLSampler sampler)
{
    if (!sampler) return;
    @autoreleasepool {
        id released = (__bridge_transfer id)sampler->metalSampler;
        (void)released;
        sampler->metalSampler = NULL;
        free(sampler);
    }
}
