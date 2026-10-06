#!/usr/bin/env python3
"""Local same-runtime SAM comparison; confidence is not semantic accuracy."""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import time

import mlx.core as mx
import numpy as np
from PIL import Image, ImageDraw
from mlx_vlm.utils import load_model
from mlx_vlm.models.sam3.generate import Sam3Predictor
from mlx_vlm.models.sam3.processing_sam3 import Sam3Processor
from mlx_vlm.models.sam3_1.processing_sam3_1 import Sam31Processor


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--model', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--threshold', type=float, default=.3)
    ap.add_argument('--details-only', action='store_true')
    ap.add_argument('--cast-bf16', action='store_true')
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    assets = Path('/Users/xiaoman/Developer/assets')
    trials = assets / 'face-parsing-trial'
    cases = [('decorated', assets / '0229_95_1.jpg', trials / 'protection-night-v2'),
             ('control', assets / '20261005.jpg', trials / 'protection-control')]
    hashes = {name: hashlib.sha256(photo.read_bytes()).hexdigest() for name, photo, _ in cases}
    report = {'model': str(args.model), 'threshold': args.threshold,
              'versions': {x: importlib.metadata.version(x) for x in ['mlx-vlm', 'mlx', 'numpy', 'pillow']},
              'runs': [], 'note': 'No labeled ground truth; scores are confidence, not accuracy.'}
    start = time.perf_counter()
    model = load_model(args.model, strict=True)
    if args.cast_bf16:
        model.set_dtype(mx.bfloat16)
    report['cast_bf16'] = args.cast_bf16
    mx.eval(model.parameters())
    report['load_seconds'] = time.perf_counter() - start
    processor_cls = Sam31Processor if '3.1' in args.model.name else Sam3Processor
    processor = processor_cls.from_pretrained(str(args.model))
    report['input_size'] = processor.image_size
    predictor = Sam3Predictor(model, processor, score_threshold=args.threshold)
    for name, photo, previous in cases:
        metadata = json.loads((previous / 'mask-report.json').read_text())
        source = Image.open(previous / 'source.png').convert('RGB')
        report.setdefault('sources', {})[name] = {'sha256': hashes[name], 'rect': metadata['source_rect'], 'size': source.size}
        tasks = [(p, source, None, None) for p in ['rhinestones', 'glitter', 'sequins', 'eyeglasses', 'pearls', 'glitter makeup']]
        if args.details_only:
            if name == 'control':
                continue
            tasks = [('rhinestones-exemplar', source, np.array([[515, 555, 536, 577]], dtype=np.float32), 'rhinestones'),
                     ('glitter-cheek', source.crop((800, 570, 1080, 870)), None, 'glitter'),
                     ('glitter-makeup-cheek', source.crop((800, 570, 1080, 870)), None, 'glitter makeup')]
        for prompt, test_image, boxes, text_override in tasks:
            mx.reset_peak_memory()
            start = time.perf_counter()
            result = predictor.predict(test_image, text_prompt=text_override or prompt, boxes=boxes)
            elapsed = time.perf_counter() - start
            assert result.masks.shape[1:] == (test_image.height, test_image.width)
            assert len(result.scores) == len(result.masks) == len(result.boxes)
            union = np.any(result.masks > 0, axis=0)
            stem = name + '-' + prompt
            Image.fromarray(union.astype(np.uint8) * 255).save(args.output / (stem + '-mask.png'))
            np.savez_compressed(args.output / (stem + '-instances.npz'), masks=result.masks, scores=result.scores, boxes=result.boxes)
            rgb = np.asarray(test_image).copy()
            rgb[union] = (rgb[union] * .45 + np.array([0, 220, 255]) * .55).astype(np.uint8)
            panel = Image.fromarray(rgb)
            panel.thumbnail((550,550))
            canvas = Image.new('RGB',(550,600),'#202020')
            canvas.paste(panel, ((550-panel.width)//2,45))
            ImageDraw.Draw(canvas).text((12,12), f'{args.model.name} | {name} | {prompt} | n={len(result.scores)}', fill='white')
            canvas.save(args.output / (stem + '-overlay.jpg'))
            row = {'case': name, 'prompt': prompt, 'count': len(result.scores), 'pixels': int(union.sum()),
                   'input_size': test_image.size, 'box_prompt': None if boxes is None else boxes.tolist(),
                   'detail_rect': [800,570,1080,870] if 'cheek' in prompt else None,
                   'valid_prompt': not (boxes is not None and '3.1' in args.model.name),
                   'prompt_limit': 'mlx-vlm0.7.6 SAM3.1 detector ignores boxes' if boxes is not None and '3.1' in args.model.name else None,
                   'scores': result.scores.tolist(), 'seconds': elapsed, 'peak_mlx_bytes': mx.get_peak_memory()}
            report['runs'].append(row)
            (args.output / 'report.json').write_text(json.dumps(report, indent=2))
            print(json.dumps(row), flush=True)
    report['source_unchanged'] = all(hashlib.sha256(photo.read_bytes()).hexdigest() == hashes[name] for name, photo, _ in cases)
    assert report['source_unchanged']
    (args.output / 'report.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
