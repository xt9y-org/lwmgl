#ifndef LWMGL_H
#define LWMGL_H

#include <lwmgl/context.h>
#include <lwmgl/buffer.h>

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

    size_t structSize;
    uint32_t abiVersion;
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;

#ifdef __cplusplus
}
#endif

#endif
