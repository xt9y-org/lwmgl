#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

#include <string.h>

static const char kSource[] =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "kernel void add_one(device uint *values [[buffer(0)]], uint id [[thread_position_in_grid]]) {\n"
    "    values[id] += 1;\n"
    "}\n";

static const char kInvalidSource[] =
    "#include <metal_stdlib>\n"
    "kernel void definitely_broken( {\n";

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-shader", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    LWMGLLibrary library = Metal.createLibraryFromSource(kSource, sizeof kSource - 1u);
    if (!library) return 4;
    LWMGLFunction function = Metal.createFunction(library, "add_one");
    if (!function) return 5;
    LWMGLComputePipeline pipeline = Metal.createComputePipeline(function);
    if (!pipeline) return 6;

    lwmglClearError();
    LWMGLLibrary invalid = Metal.createLibraryFromSource(kInvalidSource, sizeof kInvalidSource - 1u);
    if (invalid != NULL) return 7;
    const char *error = lwmglGetLastError();
    if (!error || !error[0]) return 8;

    Metal.destroyComputePipeline(pipeline);
    Metal.destroyFunction(function);
    Metal.destroyLibrary(library);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
