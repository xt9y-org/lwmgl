#include "internal.h"

#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_COCOA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

int lwmglSurfaceAttach(void *nativeWindow)
{
    LWMGLContextState *state = lwmglContextState();
    GLFWwindow *window = (GLFWwindow *)nativeWindow;
    if (!window) {
        lwmglSetErrorInternal("invalid native window");
        return -1;
    }

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

    layer.device = state->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO;
    layer.contentsScale = nsWindow.backingScaleFactor > 0.0 ? nsWindow.backingScaleFactor : 1.0;
    layer.frame = view.bounds;

    view.wantsLayer = YES;
    view.layer = layer;
    lwmglSurfaceUpdateDrawableSize();
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
}

void lwmglSurfaceUpdateDrawableSize(void)
{
    LWMGLContextState *state = lwmglContextState();
    if (!state->layer || !state->glfwWindow) return;

    int width = 0;
    int height = 0;
    glfwGetFramebufferSize((GLFWwindow *)state->glfwWindow, &width, &height);
    if (width < 1) width = 1;
    if (height < 1) height = 1;

    state->layer.contentsScale = state->nsWindow && state->nsWindow.backingScaleFactor > 0.0
        ? state->nsWindow.backingScaleFactor
        : 1.0;
    state->layer.frame = state->view ? state->view.bounds : CGRectZero;
    state->layer.drawableSize = CGSizeMake((CGFloat)width, (CGFloat)height);
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
