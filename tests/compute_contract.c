#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

#include <stdint.h>

static const char kSource[] =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "kernel void add_one(device uint *values [[buffer(0)]], uint id [[thread_position_in_grid]]) {\n"
    "    values[id] += 1;\n"
    "}\n";

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-compute", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    uint32_t initial[256];
    for (uint32_t i = 0u; i < 256u; ++i) initial[i] = i;
    LWMGLBufferDesc bufferDesc = { sizeof initial, LWMGL_STORAGE_SHARED };
    LWMGLBuffer buffer = Metal.createBuffer(&bufferDesc, initial);
    if (!buffer) return 4;

    LWMGLLibrary library = Metal.createLibraryFromSource(kSource, sizeof kSource - 1u);
    if (!library) return 5;
    LWMGLFunction function = Metal.createFunction(library, "add_one");
    if (!function) return 6;
    LWMGLComputePipeline pipeline = Metal.createComputePipeline(function);
    if (!pipeline) return 7;

    LWMGLCommand command = Metal.begin();
    if (!command) return 8;
    if (Metal.beginCompute(command) != 0) return 9;
    if (Metal.setComputePipeline(command, pipeline) != 0) return 10;
    if (Metal.setBuffer(command, buffer, 0u, 0u) != 0) return 11;
    if (Metal.dispatch(command, 256u, 1u, 1u) != 0) return 12;
    if (Metal.endEncoding(command) != 0) return 13;
    if (Metal.commit(command) != 0) return 14;
    if (Metal.wait(command) != 0) return 15;

    uint32_t *values = (uint32_t *)Metal.bufferContents(buffer);
    if (!values) return 16;
    for (uint32_t i = 0u; i < 256u; ++i) {
        if (values[i] != i + 1u) return 17;
    }

    Metal.destroyCommand(command);
    if (Metal.waitIdle() != 0) return 18;
    Metal.destroyComputePipeline(pipeline);
    Metal.destroyFunction(function);
    Metal.destroyLibrary(library);
    Metal.destroyBuffer(buffer);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
