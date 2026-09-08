#ifndef LWMGL_INTERNAL_H
#define LWMGL_INTERNAL_H

#include <lwmgl/lwmgl.h>

#ifdef __OBJC__
#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif
void lwmglSetErrorInternal(const char *message);
#ifdef __cplusplus
}
#endif

#ifdef __OBJC__
typedef struct LWMGLContextState {
    __strong id<MTLDevice> device;
    __strong id<MTLCommandQueue> queue;
    void *glfwWindow;
    __unsafe_unretained NSWindow *nsWindow;
    __unsafe_unretained NSView *view;
    __strong CAMetalLayer *layer;
    __strong CALayer *previousLayer;
    BOOL previousWantsLayer;
    __strong id<CAMetalDrawable> drawable;
    int created;
} LWMGLContextState;

LWMGLContextState *lwmglContextState(void);
int lwmglSurfaceAttach(void *nativeWindow);
void lwmglSurfaceDetach(void);
int lwmglSurfaceAcquireDrawable(void);
void lwmglSurfaceUpdateDrawableSize(void);
#endif

#endif
