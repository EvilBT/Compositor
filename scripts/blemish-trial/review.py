"""Create diagnostic crops from saved Swift detector output; never write the source photo."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
report = json.loads((root / 'report.json').read_text())
source = Image.open(root / 'source.png').convert('RGB')
for face in report['faces']:
    x, y = face['boundingBox']['origin']
    w, h = face['boundingBox']['size']
    iw, ih = source.size
    box = (max(0, int(x * iw) - 12), max(0, int(y * ih) - 12),
           min(iw, int((x + w) * iw) + 12), min(ih, int((y + h) * ih) + 12))
    raw = source.crop(box)
    marked = raw.copy()
    draw = ImageDraw.Draw(marked)
    candidates = [p for p in report['pixels'] if p['face'] == face['index']]
    for i, p in enumerate(candidates, 1):
        cx, cy = p['x'] - box[0], p['y'] - box[1]
        radius = p['radius'] + 2
        draw.ellipse((cx-radius, cy-radius, cx+radius, cy+radius), outline=(255, 200, 0), width=2)
        draw.text((cx+radius, cy-radius), str(i), fill=(255, 200, 0))
    result = Image.new('RGB', (1600, 835), 'white')
    result.paste(raw.resize((800, 800)), (0, 35))
    result.paste(marked.resize((800, 800)), (800, 35))
    ImageDraw.Draw(result).text((10, 10),
        f'{root.name} face {face["index"]}: source / {len(candidates)} review candidates (not repairs)', fill='black')
    result.save(root / f'face-{face["index"]}.jpg', quality=95)
