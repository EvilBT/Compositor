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
