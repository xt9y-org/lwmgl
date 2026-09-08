#include <lwmgl/lwmgl.h>
#include <stddef.h>

_Static_assert(LWMGL_ABI_VERSION == 1u, "unexpected ABI version");

int main(void)
{
    if (Metal.structSize != sizeof(LWMGLMetalAPI)) return 1;
    if (Metal.abiVersion != LWMGL_ABI_VERSION) return 2;
    if (!Metal.create || !Metal.destroy) return 3;
    return 0;
}
