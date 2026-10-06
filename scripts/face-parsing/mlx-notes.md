# Local MLX SAM evaluation

This is an offline mask experiment. It does not modify the app, documents,
accepted coverage, rendering versions or source photographs.

Environment: `/tmp/portrait-mlx-env`, Python3.12, mlx-vlm0.7.6; pinned packages in
`mlx-requirements-tested.txt`. Models are cached outside the repo under
`/tmp/portrait-parsing-weights/mlx/`. Snapshot revisions are recorded in
`sam3-comparison.md`. No remote image inference is used.

```sh
/tmp/portrait-mlx-env/bin/python scripts/face-parsing/mlx-evaluate.py \
  --model /tmp/portrait-parsing-weights/mlx/sam3-bf16 \
  --output /Users/xiaoman/Developer/assets/face-parsing-trial/mlx-sam3-bf16
```

Repeat with `sam3.1-bf16` and `sam3-8bit`. Run the same command with
`--details-only` and a new output directory to test the fixed rhinestone exemplar
box and right-cheek glitter crop. Output directories must not exist. Scripts
currently use the two project samples and saved native crop metadata explicitly;
these are not general-purpose application interfaces.

```sh
/tmp/portrait-mlx-env/bin/python scripts/face-parsing/mlx-review.py \
  --root /Users/xiaoman/Developer/assets/face-parsing-trial
```

Baseline: same 1008px processor, score threshold0.3, text prompts rhinestones,
glitter, sequins, eyeglasses, pearls, glitter makeup. Model loading uses strict=True.
The 3.1-specific processor and 3.1 checkpoint are used for3.1. No substituted
SAM3 weights or silent partial loading is allowed. Trials run in separate serial
processes on the same machine. Initial inference includes initialization/compiling;
warm timing summaries exclude the first prompt. MLX peak allocated memory is not
whole-process RSS or total application memory. Precision differences and source
weight tensor types must be reported alongside timings.

Each output includes original-size binary union PNG, per-query masks/scores/boxes
in compressed NPZ, a diagnostic overlay and incremental JSON report. Union
consistency, dimensions, finite scores and original file hashes are checked.
Query counts are not counts of physical objects: masks can overlap. Confidence
scores are not benchmark accuracy. Agreement between variants is not correctness.
There is no hand-labeled ground truth; two crops cannot support a general ranking.

No smoothing or export is performed here. The outputs need face/skin restriction,
semantic acceptance and locked protection/feather validation before application use.

Found runtime limitation: mlx-vlm0.7.6 SAM3.1 DetectorModel accepts boxes but does not use them. Exemplar output is invalid. Community sam3.1-bf16 actually stores F32 tensors; --cast-bf16 explicitly converts floating parameters in memory, preserving cached weights. Results: /Users/xiaoman/Developer/assets/face-parsing-trial/mlx-results.md.
