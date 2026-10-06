#!/usr/bin/env python3
"""Verify the actual versioned renderer preserves locked semantic protection."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def main():
    ap=argparse.ArgumentParser();ap.add_argument('root',type=Path);a=ap.parse_args()
    summary=[];font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
    for folder in sorted(a.root.iterdir()):
        if not folder.is_dir():continue
        report=json.loads((folder/'report.json').read_text())
        rgb=np.asarray(Image.open(folder/'source.png').convert('RGB'))
        core=np.asarray(Image.open(folder/'core.png'))>0
        skin=np.asarray(Image.open(folder/'skin.png'))>0
        checks={};panels=[]
        for title in ['baseline','whole','permissive','optimized']:
            mask=np.asarray(Image.open(folder/(title+'-mask.png')).convert('L'))
            assert not mask[~skin].any()
            if title=='optimized':assert not mask[core].any()
            checks[title]={}
            for strength in ['standard','stress']:
                edited=np.asarray(Image.open(folder/(title+'-'+strength+'.png')).convert('RGB'))
                assert edited.shape==rgb.shape
                delta=np.abs(edited.astype(np.int16)-rgb.astype(np.int16))
                changed=np.any(delta>0,axis=2)
                outside=int(changed[~skin].sum());locked=int(changed[core].sum())
                assert outside==0
                if title=='optimized':
                    assert locked==0
                    if not core.any():
                        baseline=np.asarray(Image.open(folder/('baseline-'+strength+'.png')).convert('RGB'))
                        assert np.array_equal(edited,baseline), 'No protection must preserve baseline render'
                checks[title][strength]={'outside_skin_changed_pixels':outside,
                    'locked_core_changed_pixels':locked,'locked_core_max_delta':int(delta[core].max(initial=0)),
                    'all_changed_pixels':int(changed.sum())}
                if strength=='stress':
                    image=Image.fromarray(edited);image.thumbnail((500,500))
                    panel=Image.new('RGB',(500,545),'#202020');panel.paste(image,(0,40))
                    ImageDraw.Draw(panel).text((10,10),title+' | stress v2',font=font,fill='white');panels.append(panel)
        grid=Image.new('RGB',(2000,545),'#202020')
        for i,p in enumerate(panels):grid.paste(p,(500*i,0))
        grid.save(folder/'render-comparison.jpg',quality=96)
        photo=Path('/Users/xiaoman/Developer/assets')/('0229_95_1.jpg' if folder.name.startswith('decorated') else '20261005.jpg')
        assert hashlib.sha256(photo.read_bytes()).hexdigest()==report['source_sha256']
        audit={'case':folder.name,'core_pixels':int(core.sum()),'source_unchanged':True,'renders':checks,
               'limitation':'Byte lock proves protection of accepted cores, not detection recall or correct semantics.'}
        (folder/'audit.json').write_text(json.dumps(audit,indent=2));summary.append(audit)
    (a.root/'render-audit.json').write_text(json.dumps(summary,indent=2))
    print('Verified',len(summary)*8,'actual SkinRenderer v2 outputs')

if __name__=='__main__':main()
