#ifndef LWMGL_H
#define LWMGL_H

#include <lwmgl/context.h>
#include <lwmgl/buffer.h>
#include <lwmgl/texture.h>
#include <lwmgl/shader.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LWMGLMetalAPI {
    int (*create)(void *nativeWindow);
    void (*destroy)(void);
    int (*isCreated)(void);
    int (*getDeviceInfo)(LWMGLDeviceInfo *outInfo);

    LWMGLBuffer (*createBuffer)(const LWMGLBufferDesc *desc, const void *initialData);
    void (*destroyBuffer)(LWMGLBuffer buffer);
    void *(*bufferContents)(LWMGLBuffer buffer);
    size_t (*bufferSize)(LWMGLBuffer buffer);
    int (*uploadBuffer)(LWMGLBuffer buffer, size_t offset, const void *data, size_t size);

    LWMGLTexture (*createTexture)(const LWMGLTextureDesc *desc);
    void (*destroyTexture)(LWMGLTexture texture);
    int (*uploadTexture2D)(LWMGLTexture texture, const void *data, size_t bytesPerRow);
    uint32_t (*textureWidth)(LWMGLTexture texture);
    uint32_t (*textureHeight)(LWMGLTexture texture);
    LWMGLSampler (*createSampler)(const LWMGLSamplerDesc *desc);
    void (*destroySampler)(LWMGLSampler sampler);

    LWMGLLibrary (*createLibraryFromSource)(const char *source, size_t length);
    LWMGLLibrary (*createLibraryFromFile)(const char *path);
    void (*destroyLibrary)(LWMGLLibrary library);
    LWMGLFunction (*createFunction)(LWMGLLibrary library, const char *name);
    void (*destroyFunction)(LWMGLFunction function);
    LWMGLComputePipeline (*createComputePipeline)(LWMGLFunction function);
    void (*destroyComputePipeline)(LWMGLComputePipeline pipeline);
    LWMGLRenderPipeline (*createRenderPipeline)(LWMGLFunction vertex, LWMGLFunction fragment, LWMGLPixelFormat colorFormat);
    void (*destroyRenderPipeline)(LWMGLRenderPipeline pipeline);

    size_t structSize;
    uint32_t abiVersion;
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;

#ifdef __cplusplus
}
#endif

#endif
