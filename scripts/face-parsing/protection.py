"""Experimental protection masks. Bright-detail seeds are NOT a trained gem detector."""
import argparse, hashlib, json, time
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageOps
from scipy.ndimage import gaussian_filter, distance_transform_edt, label, maximum_filter


def guided(gray, p, radius, eps=0.001):
    size=radius*2+1
    mean=lambda a:cv2.boxFilter(a,-1,(size,size),normalize=True,borderType=cv2.BORDER_REFLECT)
    mi,mp=mean(gray),mean(p)
    a=(mean(gray*p)-mi*mp)/(mean(gray*gray)-mi*mi+eps)
    b=mp-a*mi
    return np.clip(mean(a)*gray+mean(b),0,1)


def smoothstep(x):
    x=np.clip(x,0,1);return x*x*(3-2*x)


def main():
    ap=argparse.ArgumentParser()
    for k in ['photo','analysis','parsing','output']:ap.add_argument('--'+k,type=Path,required=True)
    ap.add_argument('--sam-checkpoint',type=Path)
    ap.add_argument('--feather-fraction',type=float,default=.008)
    a=ap.parse_args()
    if not .001<=a.feather_fraction<=.05:ap.error('feather-fraction must be between .001 and .05')
    a.output.mkdir(parents=True,exist_ok=False)
    report=json.loads((a.parsing/'report.json').read_text());rect=report['face_crops'][0]
    photo=ImageOps.exif_transpose(Image.open(a.photo)).convert('RGB');crop=photo.crop(rect)
    crop.save(a.output/'source.png');rgb=np.asarray(crop).astype(np.float32)/255
    gray=rgb@np.array([.2126,.7152,.0722],dtype=np.float32)
    labels=np.asarray(Image.open(a.parsing/'farl-face-1-labels.png').resize(crop.size,Image.Resampling.NEAREST))
    skin=np.isin(labels,[2,10]); skin_f=skin.astype(np.float32)
    geometry=json.loads(a.analysis.read_text())['faces'][0]
    face_width=geometry['boundingBox']['size'][0]*photo.width
    expansion=max(1,round(face_width*.003)); feather=max(2,round(face_width*a.feather_fraction))
    # Compact locally bright, low-saturation details; broad natural highlights are rejected by area.
    saturation=(rgb.max(2)-rgb.min(2))/(rgb.max(2)+1e-6)
    contrast=gray-gaussian_filter(gray,max(2,face_width*.007))
    candidate=skin&(gray>.42)&(saturation<.38)&(contrast>.055)
    components,n=label(candidate);core=np.zeros_like(skin);points=[]
    for i in range(1,n+1):
        ys,xs=np.where(components==i);area=len(xs)
        if (3<=area<=face_width*face_width*.0006
                and float(gray[ys,xs].max())>.60 and float(contrast[ys,xs].max())>.09):
            core[ys,xs]=True
            index=np.argmax(contrast[ys,xs]);points.append([int(xs[index]),int(ys[index])])
    expanded=maximum_filter(core.astype(np.uint8),size=expansion*2+1)>0
    outside=distance_transform_edt(~expanded)
    protection=1-smoothstep(outside/feather)
    inner=smoothstep(distance_transform_edt(skin)/feather)
    naive=gaussian_filter(skin_f,feather/2)*(1-gaussian_filter(expanded.astype(float),feather/2))
    inward=skin_f*inner
    variants={'segmentation':skin_f,'gaussian_unlocked':naive,
              'locked_feather':inward*(1-protection),
              'guided_locked':np.minimum(guided(gray,skin_f,feather),inward)*(1-protection)}
    sam_report={'status':'not_requested'}
    if a.sam_checkpoint:
        try:
            import torch
            from sam2.build_sam import build_sam2
            from sam2.sam2_image_predictor import SAM2ImagePredictor
            torch.set_num_threads(4)
            predictor=SAM2ImagePredictor(build_sam2('configs/sam2.1/sam2.1_hiera_t.yaml',str(a.sam_checkpoint),device='cpu',apply_postprocessing=False))
            started=time.perf_counter();sam_core=np.zeros_like(skin);accepted=0;rejected=0
            # Probe up to 12 bright seeds with local boxes. This is automated prompting, not gem recognition.
            probes=sorted(points,key=lambda p:float(contrast[p[1],p[0]]),reverse=True)[:12]
            with torch.inference_mode():
                predictor.set_image(np.asarray(crop))
                for x,y in probes:
                    pad=max(8,round(face_width*.025))
                    box=np.array([max(0,x-pad),max(0,y-pad),min(crop.width-1,x+pad),min(crop.height-1,y+pad)])
                    masks,scores,_=predictor.predict(point_coords=np.array([[x,y]]),point_labels=np.array([1]),box=box,multimask_output=True)
                    valid=[j for j,m in enumerate(masks) if m[y,x] and 2<=int(m.sum())<=face_width*face_width*.0008]
                    if not valid:rejected+=1;continue
                    j=max(valid,key=lambda j:float(scores[j]));sam_core|=masks[j]>.5;accepted+=1
            sam_core&=skin
            sam_expanded=maximum_filter((sam_core|core).astype(np.uint8),size=expansion*2+1)>0
            sam_protection=1-smoothstep(distance_transform_edt(~sam_expanded)/feather)
            variants['sam_locked']=inward*(1-sam_protection)
            Image.fromarray(np.uint8(sam_core)*255).save(a.output/'sam-candidates.png')
            sam_report={'status':'success','probes':len(probes),'accepted':accepted,'rejected':rejected,'seconds':time.perf_counter()-started,
                        'note':'Score means mask confidence, not probability of a rhinestone.'}
        except Exception as e:sam_report={'status':'error','error':repr(e)}
    Image.fromarray(np.uint8(core)*255).save(a.output/'detail-seeds.png')
    Image.fromarray(np.uint8(protection*255)).save(a.output/'protection.png')
    for name,mask in variants.items():
        Image.fromarray(np.uint8(np.clip(mask,0,1)*255)).convert('RGB').save(a.output/f'{name}-mask.png')
    metrics={'source_sha256':hashlib.sha256(a.photo.read_bytes()).hexdigest(),'source_rect':rect,'face_width_pixels':face_width,
             'expansion_pixels':expansion,'feather_pixels':feather,'candidate_components':len(points),'core_pixels':int(core.sum()),
             'sam':sam_report,'variants':list(variants),'note':'Bright-detail heuristic; false positives/negatives possible. No labeled gem ground truth.'}
    (a.output/'mask-report.json').write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics,indent=2),flush=True)


if __name__=='__main__':main()
