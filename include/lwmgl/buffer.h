#ifndef LWMGL_BUFFER_H
#define LWMGL_BUFFER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LWMGLBufferImpl *LWMGLBuffer;

typedef enum LWMGLStorageMode {
    LWMGL_STORAGE_SHARED = 0,
    LWMGL_STORAGE_PRIVATE = 1
} LWMGLStorageMode;

typedef struct LWMGLBufferDesc {
    size_t size;
    LWMGLStorageMode storage;
} LWMGLBufferDesc;

#ifdef __cplusplus
}
#endif

#endif
