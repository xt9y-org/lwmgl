#include "internal.h"

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include <limits.h>

static void applyBackingState(LWMGLContextState *state)
{
    state->layer.contentsScale = state->nsWindow && state->nsWindow.backingScaleFactor > 0.0
        ? state->nsWindow.backingScaleFactor
        : 1.0;
    state->layer.frame = state->view ? state->view.bounds : CGRectZero;
}

static void applyFramebufferSize(LWMGLContextState *state)
{
    int width = 0;
    int height = 0;
    glfwGetFramebufferSize((GLFWwindow *)state->glfwWindow, &width, &height);
    if (width < 1) width = 1;
    if (height < 1) height = 1;
    state->layer.drawableSize = CGSizeMake((CGFloat)width, (CGFloat)height);
}

int lwmglSurfaceAttach(void *nativeWindow)
{
    LWMGLContextState *state = lwmglContextState();
    GLFWwindow *window = (GLFWwindow *)nativeWindow;
    if (!window) {
        lwmglSetErrorInternal("invalid native window");
        return -1;
    }

    if (state->layer && state->glfwWindow == window) return 0;
    if (state->layer) lwmglSurfaceDetach();

    NSWindow *nsWindow = glfwGetCocoaWindow(window);
    if (!nsWindow) {
        lwmglSetErrorInternal("unable to resolve Cocoa window from GLFW window");
        return -1;
    }

    NSView *view = nsWindow.contentView;
    if (!view) {
        lwmglSetErrorInternal("Cocoa window has no content view");
        return -1;
    }

    CAMetalLayer *layer = [CAMetalLayer layer];
    if (!layer) {
        lwmglSetErrorInternal("failed to create CAMetalLayer");
        return -1;
    }

    state->glfwWindow = window;
    state->nsWindow = nsWindow;
    state->view = view;
    state->previousLayer = view.layer;
    state->previousWantsLayer = view.wantsLayer;
    state->layer = layer;
    state->autoDrawableSize = 1;

    layer.device = state->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO;
    applyBackingState(state);

    view.wantsLayer = YES;
    view.layer = layer;
    applyFramebufferSize(state);
    return 0;
}

void lwmglSurfaceDetach(void)
{
    LWMGLContextState *state = lwmglContextState();
    state->drawable = nil;

    if (state->view && state->view.layer == state->layer) {
        state->view.layer = state->previousLayer;
        state->view.wantsLayer = state->previousWantsLayer;
    }

    state->layer = nil;
    state->previousLayer = nil;
    state->view = nil;
    state->nsWindow = nil;
    state->glfwWindow = NULL;
    state->autoDrawableSize = 0;
}

int lwmglSurfaceResizeInternal(uint32_t pixelWidth, uint32_t pixelHeight)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->layer || !state->glfwWindow) {
        lwmglSetErrorInternal("Metal surface is not created");
        return -1;
    }

    if ((pixelWidth == 0u) != (pixelHeight == 0u)) {
        lwmglSetErrorInternal("drawable width and height must both be zero or both be non-zero");
        return -1;
    }

    applyBackingState(state);
    if (pixelWidth == 0u) {
        state->autoDrawableSize = 1;
        applyFramebufferSize(state);
    } else {
        state->autoDrawableSize = 0;
        state->layer.drawableSize = CGSizeMake((CGFloat)pixelWidth, (CGFloat)pixelHeight);
    }
    return 0;
}

void lwmglSurfaceUpdateDrawableSize(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->layer || !state->glfwWindow) return;
    applyBackingState(state);
    if (state->autoDrawableSize) applyFramebufferSize(state);
}

uint32_t lwmglSurfaceDrawableWidthInternal(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->layer) {
        lwmglSetErrorInternal("Metal surface is not created");
        return 0u;
    }
    lwmglSurfaceUpdateDrawableSize();
    const double width = state->layer.drawableSize.width;
    if (width <= 0.0) return 0u;
    if (width >= (double)UINT32_MAX) return UINT32_MAX;
    return (uint32_t)(width + 0.5);
}

uint32_t lwmglSurfaceDrawableHeightInternal(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->layer) {
        lwmglSetErrorInternal("Metal surface is not created");
        return 0u;
    }
    lwmglSurfaceUpdateDrawableSize();
    const double height = state->layer.drawableSize.height;
    if (height <= 0.0) return 0u;
    if (height >= (double)UINT32_MAX) return UINT32_MAX;
    return (uint32_t)(height + 0.5);
}

int lwmglSurfaceAcquireDrawable(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->created || !state->layer) {
        lwmglSetErrorInternal("Metal surface is not created");
        return -1;
    }

    lwmglSurfaceUpdateDrawableSize();
    state->drawable = [state->layer nextDrawable];
    if (!state->drawable) {
        lwmglSetErrorInternal("Metal drawable is temporarily unavailable");
        return -1;
    }
    return 0;
}
