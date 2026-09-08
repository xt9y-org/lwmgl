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
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-runtime-c", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }

    if (Metal.create(window) != 0) return 3;
    LWMGLDeviceInfo info = {0};
    if (Metal.getDeviceInfo(&info) != 0 || !info.name[0] || info.maxThreadsPerThreadgroup == 0u) return 4;

    uint32_t initial[256];
    for (uint32_t i = 0u; i < 256u; ++i) initial[i] = i;
    LWMGLBufferDesc bufferDesc = {sizeof initial, LWMGL_STORAGE_SHARED};
    LWMGLBuffer buffer = Metal.createBuffer(&bufferDesc, initial);
    if (!buffer) return 5;

    LWMGLLibrary library = Metal.createLibraryFromSource(kSource, sizeof kSource - 1u);
    LWMGLFunction function = library ? Metal.createFunction(library, "add_one") : NULL;
    LWMGLComputePipeline pipeline = function ? Metal.createComputePipeline(function) : NULL;
    if (!library || !function || !pipeline) return 6;

    LWMGLCommand compute = Metal.begin();
    if (!compute || Metal.beginCompute(compute) != 0 ||
        Metal.setComputePipeline(compute, pipeline) != 0 ||
        Metal.setBuffer(compute, buffer, 0u, 0u) != 0 ||
        Metal.dispatch(compute, 256u, 1u, 1u) != 0 ||
        Metal.endEncoding(compute) != 0 ||
        Metal.commit(compute) != 0 || Metal.wait(compute) != 0) return 7;

    uint32_t *values = (uint32_t *)Metal.bufferContents(buffer);
    if (!values) return 8;
    for (uint32_t i = 0u; i < 256u; ++i) if (values[i] != i + 1u) return 9;
    Metal.destroyCommand(compute);

    if (Metal.resize(64u, 64u) != 0) return 10;
    LWMGLCommand render = Metal.begin();
    LWMGLClearColor clear = {0.12, 0.18, 0.24, 1.0};
    if (!render || Metal.beginRenderToDrawable(render, clear, 1) != 0 ||
        Metal.endEncoding(render) != 0 || Metal.present(render) != 0 ||
        Metal.commit(render) != 0 || Metal.wait(render) != 0) return 11;
    Metal.destroyCommand(render);

    Metal.destroyComputePipeline(pipeline);
    Metal.destroyFunction(function);
    Metal.destroyLibrary(library);
    Metal.destroyBuffer(buffer);
    Metal.destroy();
    if (Metal.isCreated()) return 12;
    if (glfwWindowShouldClose(window)) return 13;

    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
