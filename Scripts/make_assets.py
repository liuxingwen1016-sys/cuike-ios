"""Generate original geometric brand assets and an OCR test label; requires Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]/'Resources'
assets = ROOT/'Assets.xcassets'
assets.mkdir(parents=True, exist_ok=True)
info = {'info': {'author': 'xcode', 'version': 1}}
(assets/'Contents.json').write_text(json.dumps(info), encoding='utf-8')
colors = {'Paper': ('F6F2EB', '211B18'), 'Card': ('FFFCF6', '302621'), 'Ink': ('3C2923', 'F6EFE3'),
          'AccentColor': ('B75E36', 'E6A47C'), 'ButtonText': ('FFFAF1', '2D221D')}
for name, pair in colors.items():
    directory = assets/(name+'.colorset')
    directory.mkdir(exist_ok=True)
    entries = []
    for index, color in enumerate(pair):
        components = {channel: f'{int(color[offset:offset+2],16)/255:.6f}' for channel, offset in [('red', 0), ('green', 2), ('blue', 4)]}
        entry = {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': dict(components, alpha='1.000')}}
        if index: entry['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
        entries.append(entry)
    (directory/'Contents.json').write_text(json.dumps(dict(info, colors=entries), indent=2), encoding='utf-8')

icon = Image.new('RGB', (1024, 1024), '#3C2923')
d = ImageDraw.Draw(icon)
d.ellipse((157, 157, 867, 867), outline='#B75E36', width=12)
d.rounded_rectangle((292, 389, 690, 688), radius=94, fill='#F6F2EB')
d.arc((615, 410, 791, 589), -95, 95, fill='#F6F2EB', width=42)
d.rounded_rectangle((246, 721, 739, 748), radius=13, fill='#E6A47C')
d.arc((367, 242, 490, 375), 60, 255, fill='#E6A47C', width=18)
d.arc((515, 211, 638, 344), 60, 255, fill='#E6A47C', width=18)
directory = assets/'AppIcon.appiconset'
directory.mkdir(exist_ok=True)
icon.save(directory/'AppIcon.png')
(directory/'Contents.json').write_text(json.dumps(dict(info, images=[{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}]), indent=2), encoding='utf-8')

def font(size):
    for path in ['C:/Windows/Fonts/arial.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']:
        if Path(path).exists(): return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)

label = Image.new('RGB', (1000, 1300), '#F6F2EB')
d = ImageDraw.Draw(label)
d.rounded_rectangle((105, 60, 895, 1240), radius=28, fill='#DCC9AC')
d.rectangle((155, 205, 845, 1090), fill='#FFFCF6')
d.rectangle((155, 205, 845, 242), fill='#B75E36')
d.text((200, 296), 'CUIKE COFFEE', font=font(45), fill='#3C2923')
d.text((200, 384), 'SAMPLE LABEL', font=font(25), fill='#71605A')
for index, text in enumerate(['Name: CITRUS MORNING', 'Origin: Ethiopia', 'Process: Washed', 'Roast: Light', 'Weight: 200g']):
    d.text((200, 505 + index*92), text, font=font(35), fill='#3C2923')
d.text((200, 1030), 'BREW MOMENTS', font=font(24), fill='#B75E36')
label.save(ROOT/'sample-bean.png')
print('Created adaptive colors, app icon, and original OCR sample image.')
