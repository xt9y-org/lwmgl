#ifndef LWMGL_H
#define LWMGL_H

#include <lwmgl/context.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LWMGLMetalAPI {
    int (*create)(void *nativeWindow);
    void (*destroy)(void);
    int (*isCreated)(void);
    int (*getDeviceInfo)(LWMGLDeviceInfo *outInfo);
    size_t structSize;
    uint32_t abiVersion;
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;

#ifdef __cplusplus
}
#endif

#endif
