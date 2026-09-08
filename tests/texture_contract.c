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
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-texture", NULL, NULL);
    if (!window) { glfwTerminate(); return 2; }
    if (Metal.create(window) != 0) return 3;

    const LWMGLTextureDesc desc = {
        4u,
        4u,
        LWMGL_RGBA8_UNORM,
        LWMGL_TEXTURE_SAMPLED | LWMGL_TEXTURE_READ,
        LWMGL_STORAGE_SHARED
    };
    LWMGLTexture texture = Metal.createTexture(&desc);
    if (!texture) return 4;
    if (Metal.textureWidth(texture) != 4u || Metal.textureHeight(texture) != 4u) return 5;

    uint8_t pixels[64];
    for (size_t i = 0; i < sizeof pixels; ++i) pixels[i] = (uint8_t)(i * 3u);
    if (Metal.uploadTexture2D(texture, pixels, 16u) != 0) return 6;
    if (Metal.uploadTexture2D(texture, pixels, 15u) == 0) return 7;

    const LWMGLTextureDesc bad = {
        0u,
        4u,
        LWMGL_RGBA8_UNORM,
        LWMGL_TEXTURE_SAMPLED,
        LWMGL_STORAGE_SHARED
    };
    if (Metal.createTexture(&bad) != NULL) return 8;

    const LWMGLSamplerDesc samplerDesc = {
        LWMGL_FILTER_LINEAR,
        LWMGL_FILTER_NEAREST,
        LWMGL_ADDRESS_CLAMP,
        LWMGL_ADDRESS_REPEAT
    };
    LWMGLSampler sampler = Metal.createSampler(&samplerDesc);
    if (!sampler) return 9;

    Metal.destroySampler(sampler);
    Metal.destroyTexture(texture);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
