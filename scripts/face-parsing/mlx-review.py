#!/usr/bin/env python3
"""Audit saved masks and show same-input comparisons without quality rankings."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--root',type=Path,required=True)
    a=ap.parse_args()
    models=['sam3-bf16','sam3.1-bf16','sam3-8bit']
    audits=[]
    for folder in sorted(a.root.glob('mlx-*')):
        model=folder.name.removeprefix('mlx-')
        if not (folder/'report.json').exists():
            continue
        report=json.loads((folder/'report.json').read_text())
        assert report['source_unchanged']
        for row in report['runs']:
            stem=row['case']+'-'+row['prompt']
            data=np.load(folder/(stem+'-instances.npz'))
            mask=np.asarray(Image.open(folder/(stem+'-mask.png')))>0
            assert mask.shape==data['masks'].shape[1:]
            assert np.array_equal(mask,np.any(data['masks']>0,axis=0))
            assert int(mask.sum())==row['pixels']
            assert np.isfinite(data['scores']).all()
            keep=data['scores']>.5
            high=np.any(data['masks'][keep]>0,axis=0)
            audits.append({'model':model, 'case':row['case'], 'prompt':row['prompt'],
                           'valid_prompt':row.get('valid_prompt',True),'queries_03':row['count'],'pixels_03':int(mask.sum()),
                           'queries_05':int(keep.sum()),'pixels_05':int(high.sum())})
    for case,prompt in [('decorated','rhinestones'),('control','eyeglasses')]:
        panels=[]
        for model in models:
            p=a.root/('mlx-'+model)/(case+'-'+prompt+'-overlay.jpg')
            if p.exists():panels.append(Image.open(p).convert('RGB'))
        if panels:
            canvas=Image.new('RGB',(550*len(panels),600),'#202020')
            for i,p in enumerate(panels):canvas.paste(p,(550*i,0))
            canvas.save(a.root/('mlx-'+case+'-'+prompt+'-comparison.jpg'))
    panels=[]
    for model in models:
        p=a.root/('mlx-'+model+'-details')/'decorated-glitter-cheek-overlay.jpg'
        if p.exists():panels.append(Image.open(p).convert('RGB').crop((0,0,550,370)))
    if panels:
        canvas=Image.new('RGB',(550*len(panels),370),'#202020')
        for i,p in enumerate(panels):canvas.paste(p,(550*i,0))
        canvas.save(a.root/'mlx-glitter-detail-comparison.jpg')
    (a.root/'mlx-mask-audit.json').write_text(json.dumps({'runs':audits,'note':'Query counts may include overlapping masks; not physical object counts or accuracy.'},indent=2))
    print('Audited',len(audits),'saved outputs')

if __name__=='__main__':main()
