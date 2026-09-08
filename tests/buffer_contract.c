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
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-buffer", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    if (!Metal.createBuffer || !Metal.destroyBuffer || !Metal.bufferContents ||
        !Metal.bufferSize || !Metal.uploadBuffer) return 4;

    uint8_t initial[64];
    for (size_t i = 0; i < sizeof initial; ++i) initial[i] = (uint8_t)i;

    const LWMGLBufferDesc desc = {64u, LWMGL_STORAGE_SHARED};
    LWMGLBuffer buffer = Metal.createBuffer(&desc, initial);
    if (!buffer) return 5;
    if (Metal.bufferSize(buffer) != 64u) return 6;

    uint8_t *mapped = (uint8_t *)Metal.bufferContents(buffer);
    if (!mapped || memcmp(mapped, initial, 64u) != 0) return 7;

    uint8_t replacement[16];
    memset(replacement, 0xA5, sizeof replacement);
    if (Metal.uploadBuffer(buffer, 16u, replacement, sizeof replacement) != 0) return 8;
    if (memcmp(mapped + 16u, replacement, sizeof replacement) != 0) return 9;

    uint8_t tooLarge[8] = {0};
    if (Metal.uploadBuffer(buffer, 60u, tooLarge, sizeof tooLarge) == 0) return 10;

    Metal.destroyBuffer(buffer);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
