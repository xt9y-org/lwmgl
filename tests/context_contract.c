#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-context", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return 2;
    }

    if (Metal.create(window) != 0) return 3;
    if (!Metal.isCreated()) return 4;

    LWMGLDeviceInfo info = {0};
    if (Metal.getDeviceInfo(&info) != 0) return 5;
    if (!info.name[0] || info.maxThreadsPerThreadgroup == 0) return 6;

    Metal.destroy();
    if (Metal.isCreated()) return 7;
    if (glfwWindowShouldClose(window)) return 8;

    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
