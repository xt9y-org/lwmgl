#define LWCGL_ENABLE_LWJGL2_COMPAT 1
#include <lwcgl/lwcgl.h>
#include <lwcgl/context.h>
#include <lwmgl/lwmgl.h>

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include <cstdio>
#include <cstring>

int main()
{
    DisplayMode mode = {320, 200, 0, 0, LWCGL_FALSE};
    if (Display.setDisplayMode(&mode) != 0) return 1;

    lwcglSetContextVersion(4, 3);
    lwcglSetContextProfile(LWCGL_CONTEXT_COMPATIBILITY_PROFILE);
    if (Display.create() != 0) {
        const char *glfw_error = nullptr;
        const int glfw_code = glfwGetError(&glfw_error);
        std::fprintf(
            stderr,
            "lwcgl: %s; requested=%d.%d profile=%d; glfw=%d%s%s\n",
            lwcglGetLastError(),
            lwcglRequestedContextMajorVersion(),
            lwcglRequestedContextMinorVersion(),
            lwcglRequestedContextProfile(),
            glfw_code,
            glfw_error ? ": " : "",
            glfw_error ? glfw_error : ""
        );
        if (
            glfw_code == GLFW_FORMAT_UNAVAILABLE &&
            glfw_error &&
            std::strstr(glfw_error, "NSGL: Failed to find a suitable pixel format") != nullptr)
        {
            return 77;
        }
        return 2;
    }

    void *window = Display.getNativeWindow();
    if (!window) return 3;
    if (Metal.create(window) != 0) {
        std::fprintf(stderr, "lwmgl: %s\n", lwmglGetLastError());
        return 4;
    }

    if (Metal.resize(0u, 0u) != 0) return 5;
    if (Metal.drawableWidth() == 0u || Metal.drawableHeight() == 0u) return 6;

    LWMGLCommand command = Metal.begin();
    if (!command) return 7;
    LWMGLClearColor clear = {0.2, 0.4, 0.7, 1.0};
    if (Metal.beginRenderToDrawable(command, clear, 1) != 0) return 8;
    if (Metal.endEncoding(command) != 0) return 9;
    if (Metal.present(command) != 0) return 10;
    if (Metal.commit(command) != 0) return 11;
    if (Metal.wait(command) != 0) return 12;
    Metal.destroyCommand(command);

    Metal.destroy();
    if (!Display.isCreated() || Display.getNativeWindow() != window) return 13;

    glViewport(0, 0, Display.getWidth(), Display.getHeight());
    glClearColor(0.1f, 0.2f, 0.3f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glFinish();
    Display.updateNoMessages();

    Display.destroy();
    return Display.isCreated() ? 14 : 0;
}
