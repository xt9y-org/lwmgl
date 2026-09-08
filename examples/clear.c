#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

#include <stdio.h>

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(640, 400, "lwmgl clear C", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) {
        fprintf(stderr, "%s\n", lwmglGetLastError());
        return 3;
    }
    if (Metal.resize(0u, 0u) != 0) return 4;

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();
        LWMGLCommand command = Metal.begin();
        if (!command) return 5;
        LWMGLClearColor clear = {0.08, 0.12, 0.18, 1.0};
        if (Metal.beginRenderToDrawable(command, clear, 1) != 0 ||
            Metal.endEncoding(command) != 0 ||
            Metal.present(command) != 0 ||
            Metal.commit(command) != 0) {
            fprintf(stderr, "%s\n", lwmglGetLastError());
            Metal.destroyCommand(command);
            return 6;
        }
        Metal.destroyCommand(command);
    }

    if (Metal.waitIdle() != 0) return 7;
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
