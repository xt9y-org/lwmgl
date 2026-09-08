#ifndef LWMGL_INTERNAL_H
#define LWMGL_INTERNAL_H

#include <lwmgl/lwmgl.h>

#ifdef __OBJC__
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif
void lwmglSetErrorInternal(const char *message);
#ifdef __cplusplus
}
#endif

#ifdef __OBJC__
typedef struct LWMGLContextState {
    __strong id<MTLDevice> device;
    __strong id<MTLCommandQueue> queue;
    void *glfwWindow;
    __unsafe_unretained NSWindow *nsWindow;
    __unsafe_unretained NSView *view;
    __strong CAMetalLayer *layer;
    __strong CALayer *previousLayer;
    BOOL previousWantsLayer;
    __strong id<CAMetalDrawable> drawable;
    int created;
} LWMGLContextState;

LWMGLContextState *lwmglContextState(void);
int lwmglSurfaceAttach(void *nativeWindow);
void lwmglSurfaceDetach(void);
int lwmglSurfaceAcquireDrawable(void);
void lwmglSurfaceUpdateDrawableSize(void);

LWMGLBuffer lwmglBufferCreateInternal(const LWMGLBufferDesc *desc, const void *initialData);
void lwmglBufferDestroyInternal(LWMGLBuffer buffer);
void *lwmglBufferContentsInternal(LWMGLBuffer buffer);
size_t lwmglBufferSizeInternal(LWMGLBuffer buffer);
int lwmglBufferUploadInternal(LWMGLBuffer buffer, size_t offset, const void *data, size_t size);
id<MTLBuffer> lwmglNativeBufferInternal(LWMGLBuffer buffer);

LWMGLTexture lwmglTextureCreateInternal(const LWMGLTextureDesc *desc);
void lwmglTextureDestroyInternal(LWMGLTexture texture);
int lwmglTextureUpload2DInternal(LWMGLTexture texture, const void *data, size_t bytesPerRow);
uint32_t lwmglTextureWidthInternal(LWMGLTexture texture);
uint32_t lwmglTextureHeightInternal(LWMGLTexture texture);
LWMGLSampler lwmglSamplerCreateInternal(const LWMGLSamplerDesc *desc);
void lwmglSamplerDestroyInternal(LWMGLSampler sampler);
id<MTLTexture> lwmglNativeTextureInternal(LWMGLTexture texture);
id<MTLSamplerState> lwmglNativeSamplerInternal(LWMGLSampler sampler);

LWMGLLibrary lwmglLibraryCreateFromSourceInternal(const char *source, size_t length);
LWMGLLibrary lwmglLibraryCreateFromFileInternal(const char *path);
void lwmglLibraryDestroyInternal(LWMGLLibrary library);
LWMGLFunction lwmglFunctionCreateInternal(LWMGLLibrary library, const char *name);
void lwmglFunctionDestroyInternal(LWMGLFunction function);
LWMGLComputePipeline lwmglComputePipelineCreateInternal(LWMGLFunction function);
void lwmglComputePipelineDestroyInternal(LWMGLComputePipeline pipeline);
LWMGLRenderPipeline lwmglRenderPipelineCreateInternal(LWMGLFunction vertex, LWMGLFunction fragment, LWMGLPixelFormat colorFormat);
void lwmglRenderPipelineDestroyInternal(LWMGLRenderPipeline pipeline);
id<MTLComputePipelineState> lwmglNativeComputePipelineInternal(LWMGLComputePipeline pipeline);
id<MTLRenderPipelineState> lwmglNativeRenderPipelineInternal(LWMGLRenderPipeline pipeline);

LWMGLCommand lwmglCommandBeginInternal(void);
int lwmglCommandBeginComputeInternal(LWMGLCommand command);
int lwmglCommandSetComputePipelineInternal(LWMGLCommand command, LWMGLComputePipeline pipeline);
int lwmglCommandSetBufferInternal(LWMGLCommand command, LWMGLBuffer buffer, size_t offset, uint32_t index);
int lwmglCommandSetTextureInternal(LWMGLCommand command, LWMGLTexture texture, uint32_t index);
int lwmglCommandSetSamplerInternal(LWMGLCommand command, LWMGLSampler sampler, uint32_t index);
int lwmglCommandDispatchInternal(LWMGLCommand command, uint32_t x, uint32_t y, uint32_t z);
int lwmglCommandCopyBufferInternal(LWMGLCommand command, LWMGLBuffer src, size_t srcOffset, LWMGLBuffer dst, size_t dstOffset, size_t size);
int lwmglCommandEndEncodingInternal(LWMGLCommand command);
int lwmglCommandCommitInternal(LWMGLCommand command);
int lwmglCommandWaitInternal(LWMGLCommand command);
void lwmglCommandDestroyInternal(LWMGLCommand command);
int lwmglCommandWaitIdleInternal(void);
id<MTLCommandBuffer> lwmglNativeCommandBufferInternal(LWMGLCommand command);
id<MTLComputeCommandEncoder> lwmglNativeComputeEncoderInternal(LWMGLCommand command);
#endif

#endif
