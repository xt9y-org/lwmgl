#ifndef LWMGL_H
#define LWMGL_H

#include <lwmgl/context.h>
#include <lwmgl/buffer.h>
#include <lwmgl/texture.h>
#include <lwmgl/shader.h>
#include <lwmgl/command.h>
#include <lwmgl/raytracing.h>

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

    int (*resize)(uint32_t pixelWidth, uint32_t pixelHeight);
    uint32_t (*drawableWidth)(void);
    uint32_t (*drawableHeight)(void);
    int (*beginRenderToDrawable)(LWMGLCommand command, LWMGLClearColor clearColor, int clear);
    int (*setRenderPipeline)(LWMGLCommand command, LWMGLRenderPipeline pipeline);
    int (*draw)(LWMGLCommand command, uint32_t vertexStart, uint32_t vertexCount);
    int (*present)(LWMGLCommand command);

    int (*supportsRayTracing)(void);
    LWMGLAccelerationStructure (*createTriangleAccelerationStructure)(const LWMGLTriangleGeometryDesc *geometries, uint32_t geometryCount);
    LWMGLAccelerationStructure (*createInstanceAccelerationStructure)(const LWMGLInstanceDesc *instances, uint32_t instanceCount);
    int (*rebuildAccelerationStructure)(LWMGLAccelerationStructure accelerationStructure);
    void (*destroyAccelerationStructure)(LWMGLAccelerationStructure accelerationStructure);
    int (*setAccelerationStructure)(LWMGLCommand command, LWMGLAccelerationStructure accelerationStructure, uint32_t index);

    size_t structSize;
    uint32_t abiVersion;

    /* Append-only v1 extension: render-stage fragment resources. */
    int (*setFragmentBuffer)(LWMGLCommand command, LWMGLBuffer buffer, size_t offset, uint32_t index);
    int (*setFragmentTexture)(LWMGLCommand command, LWMGLTexture texture, uint32_t index);
    int (*setFragmentSampler)(LWMGLCommand command, LWMGLSampler sampler, uint32_t index);

    /* Append-only v1 extension: borrowed native handles for backend interop. */
    void *(*nativeDevice)(void);
    void *(*nativeCommandBuffer)(LWMGLCommand command);
    void *(*nativeRenderEncoder)(LWMGLCommand command);
    void *(*nativeRenderPassDescriptor)(LWMGLCommand command);
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;

#ifdef __cplusplus
}
#endif

#endif
