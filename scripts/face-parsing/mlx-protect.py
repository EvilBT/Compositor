#!/usr/bin/env python3
"""Offline automatic landmark crops, semantic protection and inward feathering."""
import argparse
import hashlib
import json
from pathlib import Path
import time

import mlx.core as mx
import mlx.nn as nn
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
from scipy.ndimage import distance_transform_edt, maximum_filter
from mlx_vlm.utils import load_model
from mlx_vlm.models.sam3.generate import Sam3Predictor
from mlx_vlm.models.sam3.processing_sam3 import Sam3Processor
from mlx_vlm.models.sam3_1.processing_sam3_1 import Sam31Processor


class CachedVision(nn.Module):
    """A fresh cache per immutable ROI avoids re-encoding it for every phrase."""
    def __init__(self, inner):
        super().__init__()
        self.inner = inner
        self.cached = None
        self.calls = 0

    def __call__(self, *args, **kwargs):
        self.calls += 1
        if self.cached is None:
            self.cached = self.inner(*args, **kwargs)
            mx.eval(self.cached)
        return self.cached


def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x*x*(3-2*x)


def crop_rect(cx, top, width, height, size):
    return [max(0, round(cx-width/2)), max(0, round(top)),
            min(size[0], round(cx+width/2)), min(size[1], round(top+height))]


def regions(face, rect, photo_size, size):
    fw = face['boundingBox']['size'][0]*photo_size[0]
    landmarks = {k: (v[0]*photo_size[0]-rect[0], v[1]*photo_size[1]-rect[1])
                 for k,v in face['landmarks'].items()}
    bb = face['boundingBox']; x,y = bb['origin']; w,h = bb['size']
    box = [x*photo_size[0]-rect[0],y*photo_size[1]-rect[1],
           (x+w)*photo_size[0]-rect[0],(y+h)*photo_size[1]-rect[1]]
    rois = {}
    for side in ['Left','Right']:
        eye = landmarks['eye'+side]; cheek = landmarks['cheek'+side]
        rois['cheek'+side] = crop_rect((eye[0]+cheek[0])/2, eye[1]-.055*fw, .44*fw,
                                     max(.44*fw, cheek[1]-eye[1]+.20*fw), size)
    rois['forehead'] = crop_rect((box[0]+box[2])/2, box[1], .90*fw, .34*fw, size)
    mouth = landmarks['mouthCenter']
    rois['lowerFace'] = crop_rect(mouth[0], mouth[1]-.05*fw, .84*fw,
                                 max(.25*fw,box[3]-mouth[1]+.05*fw),size)
    guard = np.zeros((size[1],size[0]), dtype=bool)
    x0,y0,x1,y1 = [round(v) for v in box]
    guard[max(0,y0):min(size[1],y1),max(0,x0):min(size[0],x1)] = True
    return rois,guard,fw


def infer_tile(predictor, image, verify=False):
    det=predictor.model.detector_model; original=det.vision_encoder
    cache=CachedVision(original); det.vision_encoder=cache
    started=time.perf_counter(); results=[]
    try:
        for text in ['rhinestones','glitter','pearls','glitter makeup']:
            results.append((text,predictor.predict(image,text_prompt=text)))
    finally:
        det.vision_encoder=original
    seconds=time.perf_counter()-started
    assert cache.calls==4
    if verify:
        check=predictor.predict(image,text_prompt='glitter')
        cached=results[1][1]
        assert np.array_equal(check.masks,cached.masks), 'Cached masks changed'
        assert np.array_equal(check.scores,cached.scores), 'Cached scores changed'
        assert np.array_equal(check.boxes,cached.boxes), 'Cached boxes changed'
    return results,seconds


def collect(results, skin, roi, face_width):
    x0,y0,x1,y1=roi; allowed=skin[y0:y1,x0:x1]
    union=np.zeros_like(allowed); by_prompt={}; accepted=0; rejected=0
    for text,result in results:
        by_prompt[text]=np.zeros_like(allowed)
        for mask in result.masks:
            binary=mask>0; pixels=int(binary.sum()); clipped=binary&allowed
            # A prompt may retrieve a necklace or a whole face; clipping alone
            # would leave misleading fragments of that rejected object.
            if pixels==0 or clipped.sum()/pixels<.6 or clipped.sum()>face_width**2*.10:
                rejected+=1
            else:
                union|=clipped; by_prompt[text]|=clipped; accepted+=1
    confirmed=(by_prompt['rhinestones']&by_prompt['pearls'])|(by_prompt['glitter']&by_prompt['glitter makeup'])
    return union,confirmed,accepted,rejected


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--model',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
    a.output.mkdir(parents=True,exist_ok=False)
    base=Path('/Users/xiaoman/Developer/assets');trials=base/'face-parsing-trial'
    model=load_model(a.model,strict=True)
    if '3.1' in a.model.name:model.set_dtype(mx.bfloat16)
    mx.eval(model.parameters())
    cls=Sam31Processor if '3.1' in a.model.name else Sam3Processor
    predictor=Sam3Predictor(model,cls.from_pretrained(str(a.model)),score_threshold=.3)
    cases=[('decorated',base/'0229_95_1.jpg',trials/'night-expanded',trials/'night-baseline'),
           ('couple',base/'20261005.jpg',trials/'couple-expanded',trials/'baseline')]
    overall={'model':str(a.model),'sam31_cast_bf16':'3.1' in a.model.name,'faces':[],
             'note':'Experimental semantic masks; no labeled detection accuracy. Not an app feature.'}
    verified=False
    for case,photo,parsing,analysis in cases:
        digest=hashlib.sha256(photo.read_bytes()).hexdigest()
        full=ImageOps.exif_transpose(Image.open(photo)).convert('RGB')
        meta=json.loads((parsing/'report.json').read_text())
        assert digest==meta['source_sha256']
        analysis_report=json.loads((analysis/'analysis.json').read_text())
        assert analysis_report['photo_id']==digest[:16]
        faces=analysis_report['faces']
        assert len(faces)==len(meta['face_crops'])
        for i,rect in enumerate(meta['face_crops']):
            out=a.output/f'{case}-face-{i+1}';out.mkdir()
            source=full.crop(rect);source.save(out/'source.png')
            rois,guard,fw=regions(faces[i],rect,full.size,source.size)
            classes=np.asarray(Image.open(parsing/f'farl-face-{i+1}-labels.png').resize(source.size,Image.Resampling.NEAREST))
            skin=np.isin(classes,[2,10])&guard
            Image.fromarray(skin.astype(np.uint8)*255).save(out/'skin.png')
            core=np.zeros_like(skin);full_core=np.zeros_like(skin);balanced=np.zeros_like(skin);rows=[]
            for name,roi in [('whole',[0,0,source.width,source.height]),*rois.items()]:
                x0,y0,x1,y1=roi
                if x1<=x0 or y1<=y0 or skin[y0:y1,x0:x1].mean()<.05:
                    rows.append({'roi':name,'rect':roi,'skipped':'insufficient skin'});continue
                image=source.crop(roi)
                results,seconds=infer_tile(predictor,image,verify=not verified)
                verified=True
                clipped,confirmed,accepted,rejected=collect(results,skin,roi,fw)
                target=full_core if name=='whole' else core
                target[y0:y1,x0:x1]|=clipped
                balanced[y0:y1,x0:x1]|=confirmed
                np.savez_compressed(out/(name+'-predictions.npz'),
                    **{text+'-masks':r.masks for text,r in results},
                    **{text+'-scores':r.scores for text,r in results})
                rows.append({'roi':name,'rect':roi,'seconds_four_prompts':seconds,
                             'accepted_queries':accepted,'rejected_queries':rejected,'skin_core_pixels':int(clipped.sum()),'confirmed_pixels':int(confirmed.sum())})
                print(case,i+1,name,rows[-1],flush=True)
            # Keep discoveries from both scales; a missed local object can still
            # be found at the whole-face scale.
            core|=full_core
            radius=max(1,round(fw*.003));feather=max(2,round(fw*.008))
            raw_core=core.copy();core=balanced
            expanded=maximum_filter(core.astype(np.uint8),size=2*radius+1)>0
            expanded&=skin
            Image.fromarray(expanded.astype(np.uint8)*255).save(out/'core.png')
            Image.fromarray(full_core.astype(np.uint8)*255).save(out/'whole-core.png')
            Image.fromarray(raw_core.astype(np.uint8)*255).save(out/'permissive-core.png')
            inward=skin*smoothstep(distance_transform_edt(skin)/feather)
            masks={'baseline':inward}
            for name,seed in [('whole',full_core),('permissive',raw_core),('optimized',core)]:
                hard=maximum_filter(seed.astype(np.uint8),size=2*radius+1)>0
                protection=1-smoothstep(distance_transform_edt(~hard)/feather) if hard.any() else np.zeros_like(inward)
                masks[name]=inward*(1-protection)
            for name,mask in masks.items():
                byte=np.rint(mask*255).astype(np.uint8)
                assert not byte[~skin].any()
                if name=='optimized':assert not byte[expanded].any()
                Image.fromarray(np.repeat(byte[...,None],3,axis=2)).save(out/(name+'-mask.png'))
            panels=[];font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
            for title,seed in [('Original',np.zeros_like(core)),('Whole-face restricted',full_core),('Automatic local + confirmation',core)]:
                rgb=np.asarray(source).copy();rgb[seed]=(rgb[seed]*.4+np.array([0,220,255])*.6).astype(np.uint8)
                panel=Image.fromarray(rgb);panel.thumbnail((500,500))
                canvas=Image.new('RGB',(500,545),'#202020');canvas.paste(panel,(0,40))
                ImageDraw.Draw(canvas).text((10,10),title,fill='white',font=font);panels.append(canvas)
            grid=Image.new('RGB',(1500,545),'#202020')
            for j,p in enumerate(panels):grid.paste(p,(500*j,0))
            grid.save(out/'comparison.jpg',quality=95)
            report={'source_sha256':digest,'source_rect':rect,'face_width':fw,'model':str(a.model),
                    'radius':radius,'feather':feather,'rows':rows,'whole_core_pixels':int(full_core.sum()),
                    'permissive_core_pixels':int(raw_core.sum()),'optimized_core_pixels':int(core.sum()),'expanded_core_pixels':int(expanded.sum()),
                    'outside_skin_core_pixels':int(core[~skin].sum()),'model_cache_parity_checked':verified}
            (out/'report.json').write_text(json.dumps(report,indent=2));overall['faces'].append(report)
        assert hashlib.sha256(photo.read_bytes()).hexdigest()==digest
    overall['source_unchanged']=True
    (a.output/'report.json').write_text(json.dumps(overall,indent=2))


if __name__=='__main__':main()
