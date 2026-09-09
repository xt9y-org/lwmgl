#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <lwmgl/lwmgl.h>

#include <stdint.h>
#include <string.h>

static const char source[] =
    "#include <metal_stdlib>\n"
    "using namespace metal;\n"
    "struct VOut { float4 position [[position]]; float2 uv; };\n"
    "vertex VOut binding_vertex(uint id [[vertex_id]], device const float2 *positions [[buffer(0)]]) {\n"
    "  float2 p = positions[id];\n"
    "  VOut o; o.position=float4(p,0.0,1.0); o.uv=p*0.5+0.5; return o;\n"
    "}\n"
    "fragment float4 binding_fragment(VOut in [[stage_in]], constant float4& tint [[buffer(0)]], texture2d<float> image [[texture(0)]], sampler imageSampler [[sampler(0)]]) {\n"
    "  return image.sample(imageSampler, in.uv) * tint;\n"
    "}\n";

int main(void)
{
    if (!Metal.setBuffer || !Metal.setFragmentBuffer || !Metal.setFragmentTexture || !Metal.setFragmentSampler) return 1;
    if (!glfwInit()) return 2;
    glfwWindowHint(GLFW_VISIBLE, GLFW_TRUE);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow *window = glfwCreateWindow(64, 64, "lwmgl-render-binding", NULL, NULL);
    if (!window) { glfwTerminate(); return 3; }
    if (Metal.create(window) != 0) return 4;

    LWMGLLibrary library = Metal.createLibraryFromSource(source, strlen(source));
    if (!library) return 5;
    LWMGLFunction vertex = Metal.createFunction(library, "binding_vertex");
    LWMGLFunction fragment = Metal.createFunction(library, "binding_fragment");
    if (!vertex || !fragment) return 6;
    LWMGLRenderPipeline pipeline = Metal.createRenderPipeline(vertex, fragment, LWMGL_BGRA8_UNORM);
    if (!pipeline) return 7;

    const float positions[6] = {-1.0f, -1.0f, 3.0f, -1.0f, -1.0f, 3.0f};
    const LWMGLBufferDesc vertexBufferDesc = {sizeof positions, LWMGL_STORAGE_SHARED};
    LWMGLBuffer vertexBuffer = Metal.createBuffer(&vertexBufferDesc, positions);
    if (!vertexBuffer) return 8;

    const float tint[4] = {1.0f, 0.5f, 0.25f, 1.0f};
    const LWMGLBufferDesc bufferDesc = {sizeof tint, LWMGL_STORAGE_SHARED};
    LWMGLBuffer buffer = Metal.createBuffer(&bufferDesc, tint);
    if (!buffer) return 9;

    const LWMGLTextureDesc textureDesc = {
        1u, 1u, LWMGL_RGBA8_UNORM,
        LWMGL_TEXTURE_SAMPLED,
        LWMGL_STORAGE_SHARED
    };
    LWMGLTexture texture = Metal.createTexture(&textureDesc);
    if (!texture) return 10;
    const uint8_t pixel[4] = {255u, 255u, 255u, 255u};
    if (Metal.uploadTexture2D(texture, pixel, 4u) != 0) return 11;

    const LWMGLSamplerDesc samplerDesc = {
        LWMGL_FILTER_LINEAR, LWMGL_FILTER_LINEAR,
        LWMGL_ADDRESS_CLAMP, LWMGL_ADDRESS_CLAMP
    };
    LWMGLSampler sampler = Metal.createSampler(&samplerDesc);
    if (!sampler) return 12;

    LWMGLCommand command = Metal.begin();
    if (!command) return 13;
    const LWMGLClearColor clear = {0.0, 0.0, 0.0, 1.0};
    if (Metal.beginRenderToDrawable(command, clear, 1) != 0) return 14;
    if (Metal.setRenderPipeline(command, pipeline) != 0) return 15;
    if (Metal.setBuffer(command, vertexBuffer, 0u, 0u) != 0) return 16;
    if (Metal.setFragmentBuffer(command, buffer, 0u, 0u) != 0) return 17;
    if (Metal.setFragmentTexture(command, texture, 0u) != 0) return 18;
    if (Metal.setFragmentSampler(command, sampler, 0u) != 0) return 19;
    if (Metal.draw(command, 0u, 3u) != 0) return 20;
    if (Metal.present(command) != 0) return 21;
    if (Metal.commit(command) != 0) return 22;
    if (Metal.wait(command) != 0) return 23;
    Metal.destroyCommand(command);

    Metal.destroySampler(sampler);
    Metal.destroyTexture(texture);
    Metal.destroyBuffer(buffer);
    Metal.destroyBuffer(vertexBuffer);
    Metal.destroyRenderPipeline(pipeline);
    Metal.destroyFunction(fragment);
    Metal.destroyFunction(vertex);
    Metal.destroyLibrary(library);
    Metal.destroy();
    glfwDestroyWindow(window);
    glfwTerminate();
    return 0;
}
