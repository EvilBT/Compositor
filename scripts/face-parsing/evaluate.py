"""Offline face parsing trial. Reads photos; never writes edits or changes app behavior."""
import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageDraw, ImageFont, ImageOps
from torchvision import transforms


def overlay(image, amount, color):
    rgb = np.asarray(image).astype(float)
    a = np.asarray(amount, dtype=float)[..., None] * 0.55
    return Image.fromarray(np.uint8(np.clip(rgb * (1-a) + np.array(color) * a, 0, 255)))


def main():
    ap = argparse.ArgumentParser()
    for name in ('photo', 'baseline', 'segface', 'facer', 'weights', 'output'):
        ap.add_argument('--'+name, type=Path, required=True)
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    torch.set_num_threads(4)
    torch.manual_seed(0)
    device = torch.device('cpu')  # CPU gives a portable reference, not an iPhone speed prediction.
    photo = ImageOps.exif_transpose(Image.open(args.photo)).convert('RGB')
    original_hash = hashlib.sha256(args.photo.read_bytes()).hexdigest()
    analysis = json.loads((args.baseline/'analysis.json').read_text())
    baseline = Image.open(args.baseline/'skin-mask.png').convert('L').resize(photo.size, Image.Resampling.BILINEAR)
    crops, masks, rects = [], [], []
    for face in analysis['faces']:
        box = face['boundingBox']; x, y = box['origin']; w, h = box['size']
        cx, cy = (x+w/2)*photo.width, (y+h/2)*photo.height
        side = max(w*photo.width, h*photo.height)*1.65
        rect = (max(0,int(cx-side/2)),max(0,int(cy-side/2)),
                min(photo.width,int(cx+side/2)),min(photo.height,int(cy+side/2)))
        rects.append(rect); crops.append(photo.crop(rect)); masks.append(baseline.crop(rect))
    report = {'source_sha256': original_hash, 'source_size': photo.size, 'device': str(device),
              'torch': torch.__version__, 'face_crops': rects, 'models': {},
              'note': 'Visual trial, no hand-labeled ground truth. Skin includes nose; neck/ears excluded. No beard class. Timing includes one cold inference, not loading.'}
    outputs = {'Original': crops, 'Current heuristic': [overlay(c,m/255,(235,40,200)) for c,m in zip(crops,map(np.asarray,masks))]}
    sys.path.insert(0,str(args.segface))
    import network.models.segface_celeb as sc
    # Complete parsing checkpoints supply backbone weights; avoid an unused ImageNet download.
    for name in ('swin_b','mobilenet_v3_large'):
        fn = getattr(sc,name)
        def bare(*a, _fn=fn, **kw):
            kw.pop('pretrained',None); kw['weights']=None
            return _fn(*a,**kw)
        setattr(sc,name,bare)
    normalize = transforms.Compose([transforms.Resize((512,512)), transforms.ToTensor(),
        transforms.Normalize([.485,.456,.406],[.229,.224,.225])])
    for title,backbone,folder in [('SegFace Swin-B','swin_base','swinb_celeba_512'),
                                  ('SegFace MobileNet','mobilenet','mobilenet_celeba_512')]:
        try:
            model = sc.SegFaceCeleb(512,backbone).eval().to(device)
            weight = args.weights/folder/'model_299.pt'
            checkpoint = torch.load(weight,map_location=device,weights_only=True)
            state = checkpoint['state_dict_backbone']
            model.load_state_dict(state,strict=True)
            result=[]; timings=[]
            for i,crop in enumerate(crops):
                tensor=normalize(crop).unsqueeze(0).to(device)
                start=time.perf_counter()
                with torch.inference_mode():
                    logits=model(tensor,{},torch.zeros(1,dtype=torch.long,device=device))
                    probs=F.interpolate(logits,size=(512,512),mode='bilinear',align_corners=False).softmax(1)[0]
                timings.append(time.perf_counter()-start)
                labels=probs.argmax(0).cpu().numpy().astype('uint8')
                save_labels(args.output,title,i,labels)
                labels=np.asarray(Image.fromarray(labels).resize(crop.size,Image.Resampling.NEAREST))
                skin=np.isin(labels,[2,10]); glasses=labels==15; hair=labels==14
                result.append(overlay(overlay(overlay(crop,skin,(235,40,200)),glasses,(0,230,255)),hair,(255,185,0)))
            outputs[title]=result
            report['models'][title]={'seconds_per_face':timings,'checkpoint_sha256':hashlib.sha256(weight.read_bytes()).hexdigest(),'strict_load':True}
            del model,checkpoint,state
        except Exception as e:
            report['models'][title]={'error':repr(e)}
        print(title,report['models'][title],flush=True)
    sys.path.insert(0,str(args.facer))
    try:
        import facer
        parser=facer.face_parser('farl/celebm/448',device=device,model_path=str(args.weights/'farl-celebm.pt'))
        detector=facer.face_detector('retinaface/mobilenet',device=device,
                                    model_path=str(args.weights/'retinaface-mobilenet.pth'))
        result=[];timings=[]
        for i,crop in enumerate(crops):
            resized=crop.resize((768,768),Image.Resampling.BILINEAR)
            tensor=torch.from_numpy(np.array(resized)).permute(2,0,1).unsqueeze(0).to(device)
            start=time.perf_counter()
            with torch.inference_mode():
                faces=detector(tensor)
                if len(faces['rects'])!=1: raise RuntimeError(f'Expected one face in crop {i}, got {len(faces["rects"])}')
                faces=parser(tensor,faces)
                labels=faces['seg']['logits'][0].argmax(0).cpu().numpy().astype('uint8')
            timings.append(time.perf_counter()-start)
            save_labels(args.output,'FaRL',i,labels)
            labels=np.asarray(Image.fromarray(labels).resize(crop.size,Image.Resampling.NEAREST))
            skin=np.isin(labels,[2,10]);glasses=labels==15;hair=labels==14
            result.append(overlay(overlay(overlay(crop,skin,(235,40,200)),glasses,(0,230,255)),hair,(255,185,0)))
        outputs['FaRL']=result
        report['models']['FaRL']={'seconds_per_face_including_detection':timings,'checkpoint_sha256':hashlib.sha256((args.weights/'farl-celebm.pt').read_bytes()).hexdigest()}
    except Exception as e: report['models']['FaRL']={'error':repr(e)}
    print('FaRL',report['models']['FaRL'],flush=True)
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',22)
    titles=list(outputs)
    for i in range(len(crops)):
        grid=Image.new('RGB',(480*len(titles),550),(245,245,245));draw=ImageDraw.Draw(grid)
        for j,title in enumerate(titles):
            image=outputs[title][i].resize((480,480),Image.Resampling.LANCZOS)
            grid.paste(image,(j*480,45));draw.text((j*480+12,12),title,fill='black',font=font)
        draw.text((12,527),'Magenta: skin + nose | Cyan: glasses | Gold: hair',fill='black',font=font)
        grid.save(args.output/f'face-{i+1}-comparison.jpg',quality=95)
    report['source_unchanged']=hashlib.sha256(args.photo.read_bytes()).hexdigest()==original_hash
    (args.output/'report.json').write_text(json.dumps(report,indent=2))
    print('Saved',args.output,flush=True)


def save_labels(folder,title,i,labels):
    Image.fromarray(labels).save(folder/(title.lower().replace(' ','-')+f'-face-{i+1}-labels.png'))


if __name__=='__main__': main()
