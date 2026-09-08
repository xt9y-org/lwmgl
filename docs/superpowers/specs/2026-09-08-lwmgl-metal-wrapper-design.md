# lwmgl Metal Wrapper Design

Date: 2026-09-08
Status: Approved architecture, pending spec review
Repository: `xt9y/lwmgl`

## Purpose

`lwmgl` is a standalone low-level Apple Metal wrapper for C and C++ with the same design philosophy, repository style, build flow, and public ABI discipline as `lwcgl`.

Its job is to expose Metal cleanly to ordinary C and C++ code without leaking Objective-C types into consumers. It is not a renderer, engine, path tracer, scene system, or `lwcgl` extension.

The first production consumer is `xt9y/Horse`, whose `Renderer::PathTracer` will use `lwmgl` on macOS instead of falling back to rasterization.

## Non-goals

`lwmgl` does not contain:

- ECS code,
- model loading,
- scene management,
- camera logic,
- material systems,
- BVH construction policy,
- path tracing algorithms,
- GLSL translation,
- an OpenGL compatibility layer,
- LWJGL compatibility APIs,
- a duplicate `Display`, `Keyboard`, or `Mouse` implementation.

There must be no rasterization fallback in `Horse` simply because OpenGL 4.3 compute is unavailable on macOS.

## Compatibility boundary

`lwmgl` is standalone. It does not link against or require `lwcgl` as an implementation dependency.

The `README` file, with no `.md` extension, must explicitly state that `lwmgl` is currently only tested together with:

`https://github.com/xt9y/lwcgl`

The intended integration is that a program may create its window through `lwcgl`, retrieve the native window pointer, and pass that pointer to `lwmgl` for Metal surface attachment. This testing relationship must not become a hard dependency in the library ABI.

## Repository style

The repository should deliberately look and behave like a sibling of `lwcgl`.

Target layout:

```text
lwmgl/
├── README
├── Makefile
├── lwmgl-1.0.0.pc.in
├── include/
│   └── lwmgl/
│       ├── lwmgl.h
│       ├── context.h
│       ├── buffer.h
│       ├── texture.h
│       ├── shader.h
│       └── raytracing.h
├── src/
│   ├── internal.h
│   ├── context.mm
│   ├── surface.mm
│   ├── buffer.mm
│   ├── texture.mm
│   ├── shader.mm
│   ├── command.mm
│   ├── raytracing.mm
│   └── error.c
├── tests/
│   ├── api_contract.c
│   ├── api_contract.cpp
│   ├── header_contract.c
│   ├── header_contract.cpp
│   ├── runtime_smoke.c
│   ├── runtime_smoke.cpp
│   ├── stage_consumer.c
│   └── stage_consumer.cpp
└── examples/
    ├── clear.c
    └── clear.cpp
```

Exact file splitting may change during implementation if a unit becomes too large, but the public layout and build/install style must remain consistent with this design.

## Versioning and install contract

Initial version: `1.0.0`.

The normal workflow must be:

```bash
make
sudo make install
```

Additional supported targets:

```bash
make check
make clean
sudo make uninstall
```

The install should mirror `lwcgl` conventions:

```text
/usr/local/include/lwmgl-1.0.0/lwmgl/*.h
/usr/local/lib/liblwmgl-1.0.0.a
/usr/local/lib/liblwmgl-1.0.0.dylib
/usr/local/lib/liblwmgl.a
/usr/local/lib/liblwmgl.dylib
/usr/local/lib/pkgconfig/lwmgl-1.0.0.pc
```

The shared library install name must be relocatable through `@rpath/liblwmgl-1.0.0.dylib`.

The pkg-config package must support both C and C++ consumers.

## Platform scope

Version 1.0.0 targets macOS only.

Unsupported hosts must fail at build configuration with a clear message rather than silently producing a stub library.

The implementation may use:

- Metal,
- QuartzCore,
- AppKit,
- Objective-C++ internally,
- Apple's C/Objective-C runtime facilities where required.

Public headers must remain valid plain C headers and compile cleanly as both C11 and C++17 or newer.

## Public ABI style

The public ABI is C-compatible.

C++ consumers use the same ABI directly. No C++ classes, templates, exceptions, STL types, Objective-C objects, `id<MTL...>`, `NSView*`, `CAMetalLayer*`, or implementation-owned Objective-C declarations may appear in public API signatures.

Public resource types are opaque handles or fixed-layout value structs.

Example handle style:

```c
typedef struct LWMGLBufferImpl *LWMGLBuffer;
typedef struct LWMGLTextureImpl *LWMGLTexture;
typedef struct LWMGLShaderImpl *LWMGLShader;
typedef struct LWMGLComputePipelineImpl *LWMGLComputePipeline;
```

The primary entry surface follows `lwcgl`'s function-table style:

```c
typedef struct LWMGLMetalAPI {
    int (*create)(void *native_window);
    void (*destroy)(void);
    /* resource and command functions */
} LWMGLMetalAPI;

extern const LWMGLMetalAPI Metal;
```

This allows identical syntax in C and C++:

```c
Metal.create(native_window);
Metal.dispatch(...);
```

## Context and surface ownership

`lwmgl` must not create the application window.

The caller owns the native window. `lwmgl` attaches the Metal presentation surface to that existing window and owns only the Metal-facing objects it creates, including the Metal device, command queue, `CAMetalLayer`, drawable lifecycle, pipelines, buffers, and textures.

The primary integration path with `lwcgl` is conceptually:

```cpp
Display.create();
Metal.create(Display.nativeWindow());
```

`Metal.destroy()` must release only `lwmgl` resources and must never destroy the caller's native window.

## Device and capability API

The API must expose enough information for a renderer to make explicit decisions instead of guessing.

At minimum:

- default Metal device creation,
- device name,
- unified-memory capability,
- recommended working-set information where available,
- maximum threadgroup dimensions,
- maximum threads per threadgroup,
- ray-tracing support,
- acceleration-structure support,
- family/feature capability queries needed by `Horse`.

Capability absence is not a reason for hidden fallback. The caller receives an explicit unsupported result.

## Buffer API

The buffer layer must support:

- creation with size,
- creation initialized from CPU data,
- destruction,
- shared/private storage modes where meaningful,
- CPU mapping/access for shared buffers,
- explicit copy/upload path for private buffers,
- offset binding,
- bounds validation in debug/test paths.

The API must be suitable for BVH nodes, triangles, materials, camera/light constants, and other path-tracer GPU data.

## Texture API

The texture layer must support the formats required by the path tracer and presentation path, including at minimum:

- RGBA8 unorm,
- RGBA16 float if supported by the chosen design,
- RGBA32 float,
- read/write shader usage,
- sampled usage,
- drawable-compatible presentation usage where applicable.

It must support:

- texture creation,
- destruction,
- CPU upload,
- dimensions and format description,
- binding by slot,
- clear/copy operations needed by accumulation history.

## Shader and pipeline API

Version 1.0.0 uses native Metal Shading Language rather than GLSL translation.

The library must support:

- creating a Metal library from MSL source,
- loading a precompiled `.metallib`,
- looking up named functions,
- creating compute pipelines,
- creating render pipelines needed for final presentation,
- clear error reporting with compiler/linker diagnostics.

Shader source ownership must be documented precisely so callers know whether source strings are copied during creation.

## Command submission API

The command API must cover the path tracer without exposing Objective-C encoders.

It must support:

- beginning a command buffer/frame,
- compute encoding,
- render encoding for presentation,
- pipeline binding,
- buffer binding,
- texture binding,
- sampler binding if required,
- thread dispatch,
- resource copies,
- encoder termination,
- command commit,
- optional wait-for-completion,
- drawable presentation.

The API should preserve the concise style:

```c
Metal.begin();
Metal.setComputePipeline(pipeline);
Metal.setBuffer(buffer, 0);
Metal.setTexture(texture, 0);
Metal.dispatch(x, y, z);
Metal.end();
Metal.present();
```

Internally this may map to multiple Metal command/encoder objects, but that detail must not leak through the primary API.

## Synchronization

The first version must provide the synchronization primitives required for correct compute-to-present and upload-to-compute ordering.

It should prefer Metal's command-buffer ordering guarantees where sufficient and expose explicit synchronization only where the caller genuinely needs it.

The wrapper must not introduce unconditional GPU waits into every frame. Waiting is an explicit operation.

## Presentation

`lwmgl` owns a `CAMetalLayer` attached to the supplied macOS window/view.

Presentation must handle:

- current drawable acquisition,
- drawable-size changes,
- Retina backing scale,
- resizing,
- pixel format configuration,
- presenting the current drawable,
- a temporarily unavailable drawable without corrupting state.

The caller continues to own its ordinary event processing and application lifecycle.

## Ray tracing

The public ABI should reserve and implement a coherent ray-tracing section in v1.0.0 rather than forcing an ABI redesign later.

It must expose capability queries and, on supported hardware/API levels, enough primitives for:

- bottom-level geometry acceleration structures,
- top-level instance acceleration structures,
- build/refit operations where applicable,
- resource destruction,
- binding acceleration structures to shaders.

However, `lwmgl` does not decide how `Horse` partitions geometry or when its scene should rebuild. Those policies remain in `Horse`.

The initial `Horse` Metal backend may first use its existing custom BVH in ordinary buffers to preserve exact behavior before optionally adopting native Metal acceleration structures.

## Error model

The API uses return codes and a thread-safe or thread-local last-error mechanism compatible with both C and C++.

No Objective-C exceptions or C++ exceptions cross the public ABI.

Errors must include actionable diagnostic text for:

- missing Metal device,
- invalid native window,
- layer setup failure,
- shader compilation failure,
- pipeline creation failure,
- resource allocation failure,
- unsupported capability,
- invalid resource arguments.

Failure must leave objects either valid or clearly invalid; partially initialized public resources must not escape.

## Threading model

Version 1.0.0 does not promise that one `Metal` context may be mutated from arbitrary threads concurrently.

Context creation, destruction, drawable management, encoding, and presentation are expected on one render thread unless a specific API is documented thread-safe.

Independent immutable resource handles may be retained by caller code, but their destruction must follow documented synchronization/lifetime rules.

## C and C++ parity

Every public header must compile independently as C and C++.

The tests must prove:

- C can include and use the API,
- C++ can include and use the same API,
- public struct sizes/ABI version constants are stable,
- no Objective-C syntax leaks into C compilation,
- no C++ runtime is required merely to call the public C ABI from a C program.

The implementation may of course link the Objective-C runtime and Apple frameworks internally.

## ABI/version contract

`lwmgl` should expose an ABI version constant independent of the marketing/library version, following the discipline already used by `lwcgl`.

Public API tables should include size and ABI-version information so consumers can detect mismatches.

Breaking public ABI changes require an ABI version increment.

## Makefile requirements

The Makefile should be a stylistic sibling of `lwcgl`'s Makefile.

Required behavior:

- `make` builds static and shared libraries,
- strict warnings and `-Werror` for project code,
- Objective-C++ sources compile separately but into the same library,
- `make check` runs API, header, staging, C/C++, and runtime smoke tests,
- `make install` installs versioned headers/libraries/pkg-config metadata and unversioned symlinks,
- `make uninstall` removes exactly installed project files,
- stage-install tests compile consumers against the staged prefix rather than the source tree,
- the dynamic library uses an `@rpath` install name,
- build outputs live under `build/`,
- no CMake or secondary build system is introduced.

## README contract

The repository uses `README`, not `README.md`.

It should remain intentionally short and match `lwcgl`'s style. It must include the testing statement requested for this project.

Target wording:

```text
lwmgl v1.0.0

Native C/C++ interface to Apple Metal.
Currently only tested together with https://github.com/xt9y/lwcgl

install --> make && sudo make install
check   --> make check
```

## Tests

Testing is part of the v1.0.0 contract, not a later cleanup task.

### Compile-time contracts

- all public headers compile standalone as C,
- all public headers compile standalone as C++,
- umbrella-header inclusion works in both languages,
- ABI table sizes/version values are checked,
- no implementation/private header is required by a consumer.

### Stage-install contracts

A staged `make install PREFIX=...` must be able to compile and link:

- a plain C consumer using pkg-config,
- a C++ consumer using pkg-config,
- static library consumption,
- shared library consumption where appropriate.

### Runtime smoke contracts

On a supported macOS machine:

- create a window in the test harness,
- attach `lwmgl`,
- create a Metal device and queue,
- clear/present a drawable,
- create and dispatch a tiny compute pipeline,
- verify a deterministic buffer result,
- cleanly destroy all `lwmgl` objects without destroying the caller-owned window.

Tests may use GLFW as the minimal window harness because the library is explicitly intended to be testable alongside `lwcgl`, but the core implementation must not require a `lwcgl` symbol.

## Horse integration contract

The renderer repository is `xt9y/Horse`.

After `lwmgl` itself is complete and verified, `Horse` should have one `Renderer::PathTracer` public renderer with platform-specific GPU backends:

```text
Renderer::PathTracer
├── shared scene/material/BVH/sampling state
├── OpenGL backend
│   └── lwcgl + OpenGL 4.3 compute
└── macOS Metal backend
    └── lwmgl
```

There is no ordinary rasterizer fallback for macOS.

Backend selection is platform/capability explicit. A backend initialization failure is reported as a `PathTracer` initialization failure rather than silently selecting a different rendering algorithm.

The existing OpenGL path tracer remains available on platforms that support its required OpenGL 4.3 compute feature set.

## Shader ownership in Horse

`Horse` owns the actual path-tracing algorithms and shaders.

The OpenGL backend retains GLSL. The Metal backend gets equivalent MSL.

`lwmgl` only compiles/loads the MSL and exposes Metal resources and dispatch facilities. It must not contain path-tracer shader source.

The first Metal implementation should prioritize behavioral equivalence with the OpenGL backend before Metal-specific algorithmic changes.

## Performance rules

The wrapper must remain thin.

In particular:

- no hidden per-frame heap allocation where reusable state can be retained,
- no unconditional command-buffer wait after submit,
- no CPU copies for private GPU resources unless requested/required,
- no opaque background threads,
- no shader recompilation per frame,
- no implicit resource recreation on every bind,
- no renderer-level policy in the wrapper.

Resource and command wrappers should add negligible CPU overhead compared with the underlying Metal calls.

## Completion criteria for lwmgl v1.0.0

`lwmgl` v1.0.0 is complete when:

1. the repo follows the approved `lwcgl`-style layout and commands;
2. `make && sudo make install` is the normal install path;
3. static and dynamic libraries plus pkg-config metadata install correctly;
4. all public headers compile from both C and C++;
5. the same `Metal.*` API syntax is usable from both languages;
6. an externally owned macOS window can be attached without `lwmgl` owning/destroying it;
7. buffers, textures, MSL compilation, compute pipelines, dispatch, synchronization, and presentation work;
8. ray-tracing capability and acceleration-structure APIs are present and tested where supported;
9. stage-install consumers prove the installed package rather than source-tree includes;
10. the README is extensionless and states that the project is currently only tested with `https://github.com/xt9y/lwcgl`;
11. `lwmgl` contains no `Horse` renderer logic;
12. `lwmgl` has no hard dependency on `lwcgl`;
13. no rasterization fallback is introduced into `Horse` as part of macOS support.
