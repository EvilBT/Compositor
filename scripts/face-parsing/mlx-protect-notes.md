# Automatic local SAM protection experiment

This standalone diagnostic leaves Swift/App code, documents and source photos
unchanged. The fixed local datasets are the same two project samples and saved
Vision/FaRL analyses. SAM3.1 is explicitly cast to BF16 and no box prompts are
used. It does not repair the MLX3.1 geometry-prompt limitation.

```sh
/tmp/portrait-mlx-env/bin/python scripts/face-parsing/mlx-protect.py \
  --model /tmp/portrait-parsing-weights/mlx/sam3-bf16 \
  --output /Users/xiaoman/Developer/assets/face-parsing-trial/NEW_OUTPUT
/tmp/portrait-mlx-env/bin/python scripts/face-parsing/mlx-protect-tests.py
```

Repeat the first command with sam3.1-bf16 and a new directory. Both code and
package versions are pinned in mlx-requirements-tested.txt. The scripts use
existing night-expanded/couple-expanded parsing and night-baseline/baseline
Vision coordinates, assert the source identity and never overwrite outputs.

Build protection-render.swift in the temporary SwiftPM harness described in
protection-notes.md. Run the Release Trial executable on each *-face-* output
folder, then:

```sh
/tmp/portrait-mlx-env/bin/python scripts/face-parsing/mlx-protect-review.py OUTPUT
```

Mask types: baseline inward skin; whole text detection restricted to skin;
permissive whole plus automatic local detections; optimized two-phrase agreement.
A shared ROI encoder preserves predictions exactly in a checked sample per model;
cache is fresh for every ROI and restored in finally before uncached comparison.
This is inference reuse, not a trained model change.

Agreement prompts are correlated; they are not independent semantic evidence.
Conservative intersection can lose true decorations. Vision face rectangles and
FaRL classes can be inaccurate, so clipping cannot prove segmentation accuracy.
Hard-core zero-change audits are byte preservation tests, not detection recall.
Both classes of candidate masks and per-ROI predictions are retained for review.

Completed report: /Users/xiaoman/Developer/assets/face-parsing-trial/mlx-protection-results.md.
