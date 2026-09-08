#include <lwmgl/lwmgl.h>

int main(void)
{
    if (!Metal.setFragmentBuffer) return 1;
    if (!Metal.setFragmentTexture) return 2;
    if (!Metal.setFragmentSampler) return 3;
    return 0;
}
