#ifndef LWMGL_H
#define LWMGL_H

#include <lwmgl/context.h>
#include <lwmgl/buffer.h>
#include <lwmgl/texture.h>
#include <lwmgl/shader.h>
#include <lwmgl/command.h>

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

    LWMGLCommand (*begin)(void);
    int (*beginCompute)(LWMGLCommand command);
    int (*setComputePipeline)(LWMGLCommand command, LWMGLComputePipeline pipeline);
    int (*setBuffer)(LWMGLCommand command, LWMGLBuffer buffer, size_t offset, uint32_t index);
    int (*setTexture)(LWMGLCommand command, LWMGLTexture texture, uint32_t index);
    int (*setSampler)(LWMGLCommand command, LWMGLSampler sampler, uint32_t index);
    int (*dispatch)(LWMGLCommand command, uint32_t x, uint32_t y, uint32_t z);
    int (*copyBuffer)(LWMGLCommand command, LWMGLBuffer src, size_t srcOffset, LWMGLBuffer dst, size_t dstOffset, size_t size);
    int (*endEncoding)(LWMGLCommand command);
    int (*commit)(LWMGLCommand command);
    int (*wait)(LWMGLCommand command);
    void (*destroyCommand)(LWMGLCommand command);
    int (*waitIdle)(void);

    size_t structSize;
    uint32_t abiVersion;
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;

#ifdef __cplusplus
}
#endif

#endif
