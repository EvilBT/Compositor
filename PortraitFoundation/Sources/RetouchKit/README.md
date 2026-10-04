# Skin reference renderer

`SkinRenderer` is a CPU reference implementation of `RetouchRenderer`, shared by
macOS and iOS. It implements `skin` only. Other known operations fail explicitly;
disabled and unknown operations are excluded by `PortraitDocument.renderOrder`.

```swift
import PortraitCore
import RetouchKit

let renderer = SkinRenderer()
let context = RenderContext(scale: .full, assets: [:], faces: [], skinMask: coverage)
let result = try renderer.renderStack(document, input: original, context: context)
```

## Saved semantics

The document's `processVersion` governs a stack, overriding the context's default.
An independent single-step fold must use a context with that same saved version.
Missing JSON `processVersion` means version 1, permanently, even as defaults advance.
Versions other than 1 and 2 fail before rendering, including for an empty stack.

- **1** separates a local base from detail, smooths the base, and reconstructs it
  with linear `texturePreservation`.
- **2** limits low-frequency changes at strong structures and uses square-root
  texture retention, retaining more pores at the same setting. New documents use 2.

The smoothing kernel is three separable box passes with clamped edges, computed in
encoded sRGB. This is an RGBA8 reference, not a linear-light or 16-bit production
pipeline. Quality settings currently share this exact path. There is no stack fusion:
`renderStack` folds `renderStep` and has a tolerance of zero.

## Coverage and previews

`skinMask` is grayscale coverage (black protects, white edits), with the input's
dimensions and top-left orientation. It is supplied by the host, not persisted as a
new field of `SkinParams`. Explicit coverage is honored even with `protectNonSkin`
disabled; without coverage that option allows full-image processing.

With protection enabled, absent coverage and absent face analysis leave the input
untouched. Faces without coverage cause `missingSkinMask`: a face rectangle cannot
protect eyes, lips or hair. Automatic segmentation remains unimplemented.

Mask expansion/erosion uses a separable square neighborhood whose radius is
`abs(maskExpansion) * radius`, scaled for previews. Smoothing is normalized by mask
coverage and alpha, preventing surrounding protected colors from bleeding in. The
reference preserves alpha and protected canonical sRGB bytes. Nonzero
`blemishStrength` fails explicitly until blemish detection is implemented.

For `.preview(maxDimension:)`, the caller resizes both the input and coverage first,
then supplies `sourcePixelSize` for the original dimensions. The renderer scales
spatial parameters once; it does not resize at every stack step. Preview geometry
is checked for size and aspect ratio. Full renders use the original radius.

The default ceiling is 16 million pixels because several floating-point surfaces
are needed. Hosts may raise `maximumPixels` only after budgeting memory. Full-size
camera-image performance, tiled processing and GPU acceleration are future work.

## Validation

Run `swift test` from `PortraitFoundation`. The analytic fixture combines slow tonal
variation with pore-scale texture; its discrete Laplacian energy is measured away
from boundaries. Both versions must retain at least 60% at texture 0.85 and at most
25% at texture 0.10. At strength 1, the current fixture yields:

| Process version | Texture 0.85 | Texture 0.10 | Texture 0 (blur control) |
| --- | ---: | ---: | ---: |
| 1 | 72.73% | 1.23% | 0.16% |
| 2 | 85.25% | 10.17% | 0.17% |

These are this fixture's measurements, not the earlier 81.6% / 4.4% experiment.
Fixed output fingerprints match in Debug and Release and guard saved versions; independent folds check exact stack
parity. Tests also cover masks, alpha, identity, preview scaling and explicit errors.
Real portraits, detector-provided skin masks and device-to-device pixel parity still
need validation before this becomes a production retouching tool.
