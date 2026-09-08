#ifndef LWMGL_TEXTURE_H
#define LWMGL_TEXTURE_H

#include <lwmgl/buffer.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LWMGLTextureImpl *LWMGLTexture;
typedef struct LWMGLSamplerImpl *LWMGLSampler;

typedef enum LWMGLPixelFormat {
    LWMGL_BGRA8_UNORM = 0,
    LWMGL_RGBA8_UNORM = 1,
    LWMGL_RGBA16_FLOAT = 2,
    LWMGL_RGBA32_FLOAT = 3
} LWMGLPixelFormat;

typedef enum LWMGLTextureUsage {
    LWMGL_TEXTURE_SAMPLED = 1u << 0,
    LWMGL_TEXTURE_READ = 1u << 1,
    LWMGL_TEXTURE_WRITE = 1u << 2,
    LWMGL_TEXTURE_RENDER_TARGET = 1u << 3
} LWMGLTextureUsage;

typedef struct LWMGLTextureDesc {
    uint32_t width;
    uint32_t height;
    LWMGLPixelFormat format;
    uint32_t usage;
    LWMGLStorageMode storage;
} LWMGLTextureDesc;

typedef enum LWMGLFilter {
    LWMGL_FILTER_NEAREST = 0,
    LWMGL_FILTER_LINEAR = 1
} LWMGLFilter;

typedef enum LWMGLAddressMode {
    LWMGL_ADDRESS_CLAMP = 0,
    LWMGL_ADDRESS_REPEAT = 1
} LWMGLAddressMode;

typedef struct LWMGLSamplerDesc {
    LWMGLFilter minFilter;
    LWMGLFilter magFilter;
    LWMGLAddressMode addressU;
    LWMGLAddressMode addressV;
} LWMGLSamplerDesc;

#ifdef __cplusplus
}
#endif

#endif
