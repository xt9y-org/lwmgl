#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

int main(void)
{
    if (!glfwInit()) return 1;
    glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(320, 200, "lwmgl-presentation", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    if (Metal.resize(320u, 200u) != 0) return 4;
    if (Metal.drawableWidth() != 320u || Metal.drawableHeight() != 200u) return 5;

    LWMGLCommand command = Metal.begin();
    if (!command) return 6;
    LWMGLClearColor clear = {0.25, 0.5, 0.75, 1.0};
    if (Metal.beginRenderToDrawable(command, clear, 1) != 0) return 7;
    if (Metal.endEncoding(command) != 0) return 8;
    if (Metal.present(command) != 0) return 9;
    if (Metal.commit(command) != 0) return 10;
    if (Metal.wait(command) != 0) return 11;
    Metal.destroyCommand(command);

    if (Metal.resize(640u, 400u) != 0) return 12;
    if (Metal.drawableWidth() != 640u || Metal.drawableHeight() != 400u) return 13;

    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
