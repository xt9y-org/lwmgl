#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    FILE *file = fopen("src/raytracing.m", "rb");
    if (!file) return 1;

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return 2;
    }
    const long length = ftell(file);
    if (length < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return 3;
    }

    char *source = (char *)malloc((size_t)length + 1u);
    if (!source) {
        fclose(file);
        return 4;
    }
    const size_t bytes = fread(source, 1u, (size_t)length, file);
    fclose(file);
    source[bytes] = '\0';

    const int ok = strstr(
        source,
        "descriptor.usage = MTLAccelerationStructureUsagePreferFastIntersection;"
    ) != NULL;
    free(source);
    return ok ? 0 : 5;
}
