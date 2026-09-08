#include <lwmgl/lwmgl.h>

int main()
{
    if (Metal.abiVersion != LWMGL_ABI_VERSION) return 1;
    if (Metal.structSize != sizeof(LWMGLMetalAPI)) return 2;
    if (!Metal.create || !Metal.begin || !Metal.createBuffer || !Metal.createLibraryFromSource) return 3;
    return 0;
}
