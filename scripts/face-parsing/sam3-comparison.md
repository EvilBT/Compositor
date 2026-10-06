# SAM 3 / 3.1 comparison registration

Checked 2026-10-06. This is an offline evaluation specification and availability
check, not a completed inference experiment or an app integration.

## Candidates and current evidence

| Candidate | Role | Status |
|---|---|---|
| SAM 2.1 Hiera Tiny | Identical point/box boundary refinement baseline | Previous local CPU experiment completed; 12 probes, 5 accepted |
| SAM 3 | Text/exemplar discovery and point/box refinement | Registered; weights unavailable in anonymous download |
| SAM 3.1 Object Multiplex | New checkpoint; single-frame diagnostic and eventual multi-object video evaluation | Registered; weights unavailable in anonymous download; static-image compatibility unverified |

Official sources:
- https://github.com/facebookresearch/sam3
- https://github.com/facebookresearch/sam3/blob/main/RELEASE_SAM3p1.md
- https://huggingface.co/facebook/sam3
- https://huggingface.co/facebook/sam3.1

HF metadata revisions checked: SAM 3 `3c879f39826c281e95690f02c7821c4de09afae7`,
SAM 3.1 `daa63191845a41281374e725f4c9e51c7a824460`.
Both metadata responses declare `gated: manual`. Anonymous HEAD requests to
`sam3.pt` and `sam3.1_multiplex.pt` returned HTTP 401. No photos were uploaded.

The official image builder defaults to the SAM 3 checkpoint. SAM 3.1 is selected
by the multiplex video predictor. Do not relabel an unchanged SAM 3 image run as
SAM 3.1, or infer image superiority from video tracking benchmarks. The image
checkpoint loader uses strict=False and reports missing keys; a future 3.1 image
trial must audit missing/unexpected keys and loaded detector coverage, or reject
that route. Partial loading is not a valid comparative result.

The documented installation requires Python >=3.12, PyTorch >=2.7 and CUDA >=12.6.
Current builder contains CPU device defaults, but that alone does not establish
end-to-end CPU/MPS compatibility or acceptable performance. Those remain untested.

## Controlled evaluation after checkpoint access

Use the existing two local source photos and native face crops. Keep original
files immutable, source hashes, crop coordinates, prompt coordinates and masks.
Do not upload images to a hosted playground.

1. Discovery: separate short prompts `rhinestones`, `glitter`, `sequins`,
   `eyeglasses`; record thresholds and every returned instance, including no matches.
2. Exemplars: fix a real rhinestone box on the cosplay image. Evaluate same-class
   retrieval separately from text prompts. Use the undecorated male face as a
   negative control for natural highlights.
3. Boundary refinement: reuse the exact 12 SAM 2.1 probes and boxes. Keep discovery
   and boundary quality as separate measurements.
4. SAM 3.1: prefer the official predictor. If evaluating a single-frame sequence,
   label it explicitly; it is not a video speed benchmark. Reject unsupported
   checkpoint/builder combinations instead of substituting SAM 3 weights.
5. Measure manually annotated small-object recall, false protections, boundary
   overlap, runtime and peak memory. Without annotations, publish visual evidence
   and counts only, not accuracy rankings.
6. Feed accepted masks through the existing locked-core/inward-skin feathering
   and actual SkinRenderer v2. Assert protected core and non-skin changes equal
   zero. Preserve standard/stress rendering and 3/7/14px controls.

No weights were downloaded, inference performed, or Swift source modified in
this registration. Next dependency: authorized local official checkpoint files
(or a Hugging Face account with approved access); then compatibility and inference.
