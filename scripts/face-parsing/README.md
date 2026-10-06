# Offline face parsing trial

This diagnostic compares existing landmark/chroma coverage with official SegFace
Swin-B and MobileNet (CelebAMask-HQ, 512), and FaRL CelebM/448 via FACER.
It does not install a model in the application, change saved masks, or render retouched photos.

Upstream source revisions used:
- https://github.com/Kartik-3004/SegFace : `9416628e7b5a3e4b9a1068b8467bdc0cf0be7a7d`
- https://github.com/FacePerceiver/facer : `ddd35c76ff840174b8a5403ad1c1255e37b8782b`

Use a separate Python 3.12 environment, with `requirements-tested.txt`. Download
SegFace's `swinb_celeba_512/model_299.pt` and `mobilenet_celeba_512/model_299.pt`
from the author's https://huggingface.co/kartiknarayan/SegFace repository.
FaRL CelebM JIT weights are published at:
https://github.com/FacePerceiver/facer/releases/download/models-v1/face_parsing.farl.celebm.main_ema_181500_jit.pt
Save those as `farl-celebm.pt` in the weights folder. Save RetinaFace's
https://github.com/elliottzheng/face-detection/releases/download/0.0.1/mobilenet0.25_Final.pth
as `retinaface-mobilenet.pth` there.

Generate the baseline with `portrait-mcp --photo PHOTO --review BASELINE`, then run:

```sh
python evaluate.py --photo PHOTO --baseline BASELINE --segface SEGFACE_CHECKOUT \
  --facer FACER_CHECKOUT --weights WEIGHTS_DIRECTORY --output NEW_OUTPUT_DIRECTORY
```

Output directory must not exist, to prevent replacing previous results. Model
failures are recorded in report.json and not treated as successful comparisons.
The report records source and checkpoint hashes and verifies the photo remained unchanged.

## Interpretation

Vision face bounds define square crops enlarged by 1.65. SegFace uses RGB,
512x512 input and official ImageNet normalization. Loading the complete parsing
checkpoint is strict; constructor-only ImageNet weights are skipped. FaRL uses
768x768 crop inputs, official RetinaFace detection and FACER alignment/warping,
then its native 448 model. Thus this is an end-to-end visual trial, not a controlled
architecture benchmark: crop alignment differs. CPU, four threads, timings are
cold single inference, omit model loading, and FaRL includes detection.

Magenta = skin + nose, cyan = eyeglasses, gold = hair. Neck and ears are excluded
from the skin display for comparison with face-only coverage. Raw class IDs are
saved separately. Current heuristic is a continuous coverage mask; learned model
overlays use categorical predictions. These are not identical to the modified-pixel
overlay in the app. No hand-labeled truth is available, so no accuracy/F1/IoU is
claimed. Neither 19-class model provides a separate beard class. No Core ML or
mobile speed/precision validation is included in this trial.

## Expanded trial (round 2)

Optional `--segformer LOCAL_MODEL_DIRECTORY` adds the publisher's
https://huggingface.co/jonathandinu/face-parsing (SegFormer-B5). Download only
`config.json`, `preprocessor_config.json` and `model.safetensors` via
`snapshot_download`; inference uses local files only. Preprocessing is the
publisher's configured 512x512 RGB processor. Class IDs differ from SegFace/FaRL,
so semantic IDs are read from `id2label`, never reused by position. Raw SegFormer
class maps use its own label numbering, recorded in report.json.

`--crop-scale 1.4` versus default 1.65 tests sensitivity to surrounding context.
Compare masks only within the same original-photo region after projecting class
maps through the recorded face_crops. Disagreement is stability, not accuracy.

Other investigated candidates (not run):
- DML-CSR, CVPR 2022: https://github.com/deepinsight/insightface/tree/master/parsing/dml_csr
  Joint parsing, binary-edge and category-edge tasks; old PyTorch/CUDA/Inplace-ABN
  dependencies increase native Apple integration work.
- DINOv3 + VGG19: https://github.com/jseobyun/FaceParsing
  The publisher lists a separate beard class. This is an exploratory third-party
  model, not evidence that official DINOv3 is a validated face parser. Decoder and
  DINOv3 weights are separate; no comparative benchmark was verified in this trial.

SegFormer model card states non-commercial research/educational use. Treat each
checkpoint's terms separately from source-code licensing before product distribution.

Tested SegFormer revision: `758b82e15a0178c9db39c1ff666a8b56e3a550c8`;
weight SHA-256: `c2bec795a8c243db71bd95be538fd62559003566466c71237e45c99b920f4b62`.
For crop stability use:

```sh
python stability.py --first DEFAULT_CROP_OUTPUT --second CROP_14_OUTPUT \
  --analysis BASELINE/analysis.json --output NEW_REPORT.json
```

Both reports must describe the same source. Raw class maps are projected back
through their saved crops, then compared only in the fixed Vision face rectangle.
Skin/nose IDs and glasses IDs differ for SegFormer; they are explicitly mapped.
This measures changed predictions, not correctness. No image labels are altered.
