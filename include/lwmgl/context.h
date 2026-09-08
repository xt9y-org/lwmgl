#ifndef LWMGL_CONTEXT_H
#define LWMGL_CONTEXT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LWMGL_VERSION_MAJOR 1
#define LWMGL_VERSION_MINOR 0
#define LWMGL_VERSION_PATCH 0
#define LWMGL_ABI_VERSION 1u

typedef struct LWMGLDeviceInfo {
    char name[256];
    uint64_t recommendedMaxWorkingSetSize;
    uint32_t maxThreadsPerThreadgroup;
    uint8_t hasUnifiedMemory;
    uint8_t supportsRayTracing;
    uint8_t supportsAccelerationStructures;
    uint8_t reserved;
} LWMGLDeviceInfo;

const char *lwmglGetLastError(void);
void lwmglClearError(void);

#ifdef __cplusplus
}
#endif

#endif
