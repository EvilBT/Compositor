# Protection and feathering experiment

This is an offline diagnostic, not an app change or a trained rhinestone detector.
The baseline is FaRL's categorical face/nose labels from the earlier trial.
All edited outputs were produced by the existing Swift SkinRenderer v2, at full
crop pixel scale, radius 12, standard 0.65/0.30 and stress 0.85/0.15.

## Stages

1. Crop upright source with the saved parser rectangle. Face width is measured in
   original source pixels from Vision bounds, not the display or network resolution.
2. Find compact bright, low-saturation local details inside skin. Thresholds are
   exploratory: luminance >0.42, saturation <0.38, local excess >0.055;
   component area >=3, <=faceWidth^2*0.0006, peak luminance >0.60, excess >0.09.
3. Expand accepted cores by a square morphological maximum, radius 0.003 face width.
4. Feather only outward with distance-transform smoothstep, 0.003/0.008/0.016 face width.
   Skin boundaries feather inward; weights outside the original skin classification
   remain exactly zero. Inner protection cores are never softened back into editable pixels.
5. Contrast with an intentionally unsafe Gaussian-only baseline, and a grayscale
   guided-filter variant (radius same as feather, epsilon 0.001), clamped by the inward
   skin weight and protected core. Guided filtering is based on:
   https://people.csail.mit.edu/kaiming/eccv10/index.html

Optional SAM 2.1 Hiera Tiny: https://github.com/facebookresearch/sam2
Source revision `2b90b9f5ceec907a1c18123530e92e794ad901a4`.
Checkpoint: https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_tiny.pt
Use CPU installation with SAM2_BUILD_CUDA=0. The predictor receives at most 12
bright-detail positive prompts and local boxes. Masks not containing the prompt or
covering excessive area are rejected. This is prompted segmentation, NOT automatic
semantic identification of diamonds/glitter. Mask confidence is not material confidence.

## Reproduce

```sh
python protection.py --photo PHOTO --analysis BASELINE/analysis.json \
  --parsing PARSER_OUTPUT --output NEW_OUTPUT \
  --sam-checkpoint SAM2_CHECKPOINT --feather-fraction .008
```

Build `protection-render.swift` as a standalone SwiftPM executable. Its package must
specify macOS 15 and depend on the local PortraitFoundation package products
PortraitCore, RetouchKit and PortraitMCP. Copy it as Sources/Trial/main.swift, then
`swift run -c release --package-path HARNESS Trial NEW_OUTPUT`.
The harness reads each *-mask.png and writes standard/stress renders without overwriting.

```sh
python protection-review.py NEW_OUTPUT --photo PHOTO
```

Review verifies byte-identical seed cores and non-skin pixels for locked variants,
source hash preservation, and generates masks, actual renders and difference x8.
Raw mask/report filenames are stable; outputs are kept outside the repository.

## Results (2026-10-06)

Night face: crop1470x1470, face width890.9px, expansion3px, default feather7px;
323 candidate components, 4852 seed-core pixels. At stress strength:
- Segmentation only: all 4852 core pixels changed, maximum channel difference86.
- Gaussian-only: 4004 core pixels changed, max difference28; 35322 pixels outside
  categorical skin changed. This baseline demonstrates why ordinary blur is insufficient.
- Locked feather, guided locked, and SAM locked: core changes0 and non-skin changes0.

Narrow3px and wide14px retained the same zero-change guarantees. Wider feathering
reduced edited pixel count (374343/368455/353927 for 3/7/14px), but that is reduced
coverage, not improved quality. The displayed stress renders deliberately emphasize
weaknesses; their strength is not a calibrated recommendation.

SAM accepted5/rejected7 of12 probes. It sometimes enlarges the protected footprint;
this does not show it semantically recognized decorations. Plain guided filtering
showed no clearly preferable visual result here. Guided vs distance-only stress
output differs in31619 pixels, maximum channel delta15, so the methods are not identical.

Control face without decorations:51 candidate components,756 core pixels. They include
natural forehead/nose reflections. Thus bright-detail protection is conservative but
cannot serve as a dedicated decoration classifier. Additional semantic/context
validation or manual correction is still needed. Unselected/dark decorations can be missed.

All17 masks and34 actual renders across4 trials were audited. No hand-labeled material
truth exists; zero detected-core change does NOT mean all decorations were detected.
App/session masks, processVersion, exports and Swift source remain unchanged.
No CoreML/ANE, preview/full-image parity, or mobile performance is claimed.
