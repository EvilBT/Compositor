"""Compare crop-context sensitivity inside the same Vision face rectangle, not accuracy."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def projected(folder, name, i, report, rect):
    x0,y0,x1,y1=report['face_crops'][i]
    labels=Image.open(folder/f'{name}-face-{i+1}-labels.png').resize((x1-x0,y1-y0),Image.Resampling.NEAREST)
    a,b,c,d=rect
    assert x0<=a<c<=x1 and y0<=b<d<=y1, 'Face region must be contained in both context crops'
    return np.asarray(labels.crop((a-x0,b-y0,c-x0,d-y0)))


def main():
    ap=argparse.ArgumentParser()
    for k in ('first','second','analysis','output'):ap.add_argument('--'+k,type=Path,required=True)
    args=ap.parse_args()
    if args.output.exists():ap.error('output already exists')
    first=json.loads((args.first/'report.json').read_text());second=json.loads((args.second/'report.json').read_text())
    assert first['source_sha256']==second['source_sha256']
    width,height=first['source_size']
    analysis=json.loads(args.analysis.read_text());items=[]
    for i,face in enumerate(analysis['faces']):
        box=face['boundingBox'];x,y=box['origin'];w,h=box['size']
        rect=[round(x*width),round(y*height),round((x+w)*width),round((y+h)*height)]
        for name,skin,glasses in [('segface-swin-b',[2,10],15),('segface-mobilenet',[2,10],15),('farl',[2,10],15),('segformer-b5',[1,2],3)]:
            a=projected(args.first,name,i,first,rect);b=projected(args.second,name,i,second,rect)
            sa,sb=np.isin(a,skin),np.isin(b,skin);ga,gb=a==glasses,b==glasses
            items.append({'model':name,'face':i+1,'face_rect':rect,
                          'skin_changed_fraction':float(np.mean(sa!=sb)),
                          'skin_prediction_agreement_iou':float(np.sum(sa&sb)/max(1,np.sum(sa|sb))),
                          'glasses_changed_fraction':float(np.mean(ga!=gb))})
    args.output.write_text(json.dumps({'meaning':'Prediction stability under crop changes; NOT ground-truth accuracy.',
        'crop_scales':[first['crop_scale'],second['crop_scale']],'results':items},indent=2))


if __name__=='__main__':main()
