#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

#include <stdint.h>
#include <string.h>

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-raytracing", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    if (!Metal.supportsRayTracing()) {
        lwmglClearError();
        if (Metal.createTriangleAccelerationStructure(NULL, 0u) != NULL) return 4;
        const char *error = lwmglGetLastError();
        if (!error || !error[0] || strstr(error, "ray tracing") == NULL) return 5;
        Metal.destroy();
        glfwDestroyWindow(window);
        glfwTerminate();
        return 0;
    }

    const float vertices[9] = {
        -1.0f, -1.0f, 0.0f,
         1.0f, -1.0f, 0.0f,
         0.0f,  1.0f, 0.0f
    };
    const uint32_t indices[3] = {0u, 1u, 2u};
    LWMGLBufferDesc vertexDesc = {sizeof vertices, LWMGL_STORAGE_SHARED};
    LWMGLBufferDesc indexDesc = {sizeof indices, LWMGL_STORAGE_SHARED};
    LWMGLBuffer vertexBuffer = Metal.createBuffer(&vertexDesc, vertices);
    LWMGLBuffer indexBuffer = Metal.createBuffer(&indexDesc, indices);
    if (!vertexBuffer || !indexBuffer) return 6;

    LWMGLTriangleGeometryDesc geometry = {
        vertexBuffer,
        0u,
        12u,
        3u,
        indexBuffer,
        0u,
        3u,
        1u
    };
    LWMGLAccelerationStructure blas =
        Metal.createTriangleAccelerationStructure(&geometry, 1u);
    if (!blas) return 7;

    LWMGLInstanceDesc instance = {0};
    instance.accelerationStructure = blas;
    instance.transform[0] = 1.0f;
    instance.transform[5] = 1.0f;
    instance.transform[10] = 1.0f;
    instance.mask = 0xffu;
    instance.userId = 7u;

    LWMGLAccelerationStructure tlas =
        Metal.createInstanceAccelerationStructure(&instance, 1u);
    if (!tlas) return 8;

    LWMGLCommand command = Metal.begin();
    if (!command || Metal.beginCompute(command) != 0) return 9;
    if (Metal.setAccelerationStructure(command, tlas, 0u) != 0) return 10;
    if (Metal.endEncoding(command) != 0 || Metal.commit(command) != 0 || Metal.wait(command) != 0) return 11;
    Metal.destroyCommand(command);

    if (Metal.rebuildAccelerationStructure(blas) != 0) return 12;

    Metal.destroyAccelerationStructure(tlas);
    Metal.destroyAccelerationStructure(blas);
    Metal.destroyBuffer(indexBuffer);
    Metal.destroyBuffer(vertexBuffer);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
