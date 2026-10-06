# T3: conservative blemish review candidates

The Swift detector is in PortraitAnalysis/BlemishDetector.swift. It does not repair an
image or add a retouch operation. No neural model, OpenCV, GPL implementation or network
service is used. Skin coverage and existing skin process versions remain unchanged.

## Algorithm and contract

- Face-width scales 0.006 / 0.010 / 0.016, rounded to at least two analysis pixels.
- Integral-image inner/outer box means approximate multiscale blob contrast; this is not
  an exact Gaussian LoG implementation or a trained acne classifier.
- Require local darkening, relative and absolute red excess, and seven of eight surrounding
  samples supporting the anomaly. Reject strongly dark spots and uneven surroundings.
- Omit a nose corridor and neighborhoods of pale bright points. These rules also omit
  genuine lesions near shadows/highlights; they cannot semantically identify decorations.
- Default heuristic score threshold 0.8. Scores are rankings, not probabilities.
- Center coverage >=128, surrounding samples >=128, full candidate disk coverage >0.
  Soft coverage inside a red lesion remains eligible. No candidate disk crosses a zero mask pixel.
- Stable score/y/x/radius order and overlap suppression. Same detector input repeats exactly
  in this build. Different analysis resolutions can yield different candidates/radii.

Candidates expose face-relative AnchoredPoint, face-width radius, confidence and detector
version. blemishFraction is the union of candidate disks intersecting coverage >=128 divided
by that face's coverage >=128 pixels. It is not the historical placeholder or a clinical
severity score. Do not translate these numbers into stronger smoothing automatically.

Fresh results and MCP analyze_faces include candidates/version/availability. Optional fields
in the existing version-1 analysis cache preserve them. A legacy cache gets metadata using
its frozen mask, not another Vision/chroma run; the next save persists that metadata.
Detector changes must use a new detector version. Accepted spot placement/rendering is T4/T5,
not this task. Existing cached detections are not silently recomputed merely for a newer tag.

## Reproduce

From the repository root, supply a NEW output directory:

```sh
scripts/blemish-trial/run.sh /Users/xiaoman/Developer/assets/20261005.jpg /tmp/NEW_BLEMISH_COUPLE
/tmp/portrait-parsing-env/bin/python scripts/blemish-trial/review.py /tmp/NEW_BLEMISH_COUPLE
```

The runner builds a disposable local SwiftPM Release harness, writes source/skin/candidate
PNG and report.json, checks each disk against coverage and repeats detection three times.
It never saves an edit. The review helper needs Pillow; it only annotates copies of output.
The detector input is an upright preview up to 2048px (the same scale as the host). Timing
excludes photo loading. Repeat on 0229_95_1.jpg and on the previously verified native source
crops in assets/face-parsing-trial/mlx-protection-sam3-v2/*-face-1/source.png. Native crops run
Vision afresh; they demonstrate resolution sensitivity, not a full-resolution app integration.

## Completed checks (2026-10-07)

Artifacts: /Users/xiaoman/Developer/assets/blemish-trial/results.md.
Final directories: couple-final, decorated-final, male-native-final, decorated-native-final.

Two original photos, three faces: one lower-chin review candidate on the male, zero on the
other two. Native male crop: two candidates, including the prominent chin redness; decorated
crop: zero. Earlier broad prototype found 36 + 4 candidates, including shading and ordinary
texture; this is why the final default was tightened. Prior v1/v2/v3 outputs are exploratory,
not the released detector defaults. Final and v4 detections matched in separate processes.

Release detector median over three local repeats: couple preview 17.0ms; decorated preview
6.8ms; male native crop 110.5ms; decorated native crop 76.3ms. Not an iPad benchmark or a
formal performance/accuracy comparison. Total Vision/coverage/blemish analysis is separate
in each report. There is no manual ground truth, so no precision/recall claim.

Debug/Release each 60 tests and iOS build pass. Four new detector tests cover a soft red
lesion, dark mole/neutral freckle/highlight/smooth negatives, protected coverage and input
rejection, nearby decoration and soft nonzero coverage. One MCP test covers additive cache
metadata, legacy frozen-mask upgrade and availability response. Independent stdio calls on
both original photos returned available=true, 1/0 candidates, revision=0 and empty stacks;
source SHA-256s unchanged. Logs: /tmp/portrait-t3-{debug,release,ios,protocol}.log.

## Limits

This conservative default misses mild/non-red lesions, lesions near highlights and those
excluded by coverage or nose shading rules. A single image cannot establish temporariness;
a red mole, makeup mark or inflamed follicle can resemble a lesion. No observed selection of
dark moles/glitter in these outputs is not a general safety guarantee. Review candidates,
keep rejected permanent features, and retain manual placement in the later repair UI.
T4 actual healing and T5 automatic channel are still unimplemented. No native candidate
review UI was added in T3; the figures and MCP metadata are the current review surfaces.
