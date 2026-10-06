"""Audit real renderer outputs and build comparison sheets without altering source files."""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont


def main():
    ap=argparse.ArgumentParser();ap.add_argument('folder',type=Path);ap.add_argument('--photo',type=Path,required=True);args=ap.parse_args()
    p=args.folder;report=json.loads((p/'mask-report.json').read_text())
    source=Image.open(p/'source.png').convert('RGB');rgb=np.asarray(source)
    core=np.asarray(Image.open(p/'detail-seeds.png'))>0
    skin=np.asarray(Image.open(p/'segmentation-mask.png').convert('L'))>0
    region=(round(source.width*.25),round(source.height*.27),round(source.width*.75),round(source.height*.72))
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',22)
    titles={'segmentation':'Skin only','gaussian_unlocked':'Gaussian feather','locked_feather':'Locked + feather','guided_locked':'Guided + locked','sam_locked':'SAM2 + locked'}
    audit={};masks={'Original':source};rendered={'Original':source};diff={'Original':source}
    for name in report['variants']:
        mask=np.asarray(Image.open(p/f'{name}-mask.png').convert('L'))
        edited=mask.astype(float)/255
        protect=np.where(skin,1-edited,0)
        amount=(edited*.35+protect*.55)[...,None]
        tint=np.zeros_like(rgb,dtype=float);tint[:]=[235,40,200]
        tint[protect>.5]=[0,230,255]
        masks[titles[name]]=Image.fromarray(np.uint8(rgb*(1-amount)+tint*amount))
        audit[name]={'core_nonzero_mask_pixels':int(np.count_nonzero(mask[core])),'outside_skin_nonzero_mask_pixels':int(np.count_nonzero(mask[~skin]))}
        for strength in ['standard','stress']:
            image=Image.open(p/f'{name}-{strength}.png').convert('RGB');after=np.asarray(image);delta=np.abs(after.astype(int)-rgb.astype(int))
            changed=np.any(delta>0,axis=2)
            audit[name][strength]={'core_changed_pixels':int(changed[core].sum()),'core_max_channel_delta':int(delta[core].max()),
                'outside_skin_changed_pixels':int(changed[~skin].sum()),'all_changed_pixels':int(changed.sum())}
            if name in ['locked_feather','guided_locked','sam_locked']:
                assert not changed[core].any(), 'Protection cores must remain byte-identical'
                assert not changed[~skin].any(), 'Feathering must not spill outside skin'
            if strength=='stress':
                rendered[titles[name]]=image
                diff[titles[name]]=Image.fromarray(np.uint8(np.clip(delta*8,0,255)))
    def sheet(images,filename,caption):
        grid=Image.new('RGB',(1260,920),'white');draw=ImageDraw.Draw(grid)
        for i,(title,image) in enumerate(images.items()):
            x=(i%3)*420;y=(i//3)*440
            patch=image.crop(region).resize((420,400),Image.Resampling.LANCZOS)
            grid.paste(patch,(x,y+36));draw.text((x+8,y+6),title,fill='black',font=font)
        draw.text((8,890),caption,fill='black',font=font);grid.save(p/filename,quality=96)
    sheet(masks,'mask-comparison.jpg','Magenta: editable | Cyan: protected | Experimental detection')
    sheet(rendered,'render-comparison.jpg','SkinRenderer v2 stress: strength 0.85 / texture 0.15')
    sheet(diff,'difference-comparison.jpg','RGB absolute difference x8; black means unchanged')
    assert hashlib.sha256(args.photo.read_bytes()).hexdigest()==report['source_sha256']
    (p/'audit.json').write_text(json.dumps({'core_pixels':int(core.sum()),'source_unchanged':True,'variants':audit,
        'limitation':'Core checks cover detected bright seeds only, not all actual decorations; not a detection accuracy score.'},indent=2))
    print(json.dumps(audit,indent=2))


if __name__=='__main__':main()
