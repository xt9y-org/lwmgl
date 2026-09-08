#ifndef LWMGL_RAYTRACING_H
#define LWMGL_RAYTRACING_H

#include <lwmgl/buffer.h>

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LWMGLAccelerationStructureImpl *LWMGLAccelerationStructure;

typedef struct LWMGLTriangleGeometryDesc {
    LWMGLBuffer vertexBuffer;
    size_t vertexOffset;
    uint32_t vertexStride;
    uint32_t vertexCount;
    LWMGLBuffer indexBuffer;
    size_t indexOffset;
    uint32_t indexCount;
    uint8_t index32;
} LWMGLTriangleGeometryDesc;

typedef struct LWMGLInstanceDesc {
    LWMGLAccelerationStructure accelerationStructure;
    float transform[12];
    uint32_t mask;
    uint32_t userId;
} LWMGLInstanceDesc;

#ifdef __cplusplus
}
#endif

#endif
