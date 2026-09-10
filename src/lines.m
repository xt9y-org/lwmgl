#include "internal.h"

int lwmglCommandDrawLinesInternal(LWMGLCommand command, uint32_t vertexStart, uint32_t vertexCount)
{
    if (!command) {
        lwmglSetErrorInternal("command is null");
        return -1;
    }

    id<MTLRenderCommandEncoder> encoder = lwmglNativeRenderEncoderInternal(command);
    if (!encoder) {
        lwmglSetErrorInternal("render encoding is not active");
        return -1;
    }
    if (vertexCount == 0u) {
        lwmglSetErrorInternal("draw line vertex count must be non-zero");
        return -1;
    }

    [encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:vertexStart vertexCount:vertexCount];
    return 0;
}
