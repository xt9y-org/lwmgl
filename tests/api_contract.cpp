#include <lwmgl/lwmgl.h>
#include <type_traits>

static_assert(LWMGL_ABI_VERSION == 1u);
static_assert(std::is_standard_layout_v<LWMGLMetalAPI>);

int main()
{
    return Metal.structSize == sizeof(LWMGLMetalAPI) &&
           Metal.abiVersion == LWMGL_ABI_VERSION ? 0 : 1;
}
