"""Labelled review sheet of the v3 sprites. Usage: python review_sheet.py <out_dir>"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, str(Path(__file__).parent))
import pixelgen as pg

OUT = Path(sys.argv[1])
F = '/usr/share/fonts/opentype/inter/'
def f(w, s): return ImageFont.truetype(F + f'Inter-{w}.otf', s)

K = 5; kinds = list(pg.GEM)
cw, ch = pg.TW * K + 28, pg.TH * K + 10
W = 150 + cw * 6 + 20; H = 70 + ch * len(kinds) + 210
img = Image.new('RGBA', (W, H), '#0d1512'); d = ImageDraw.Draw(img)
d.text((20, 18), 'Style sample v3 · towers, quality I–VI (shown 5× native 16 px)', font=f('SemiBold', 18), fill='#e8e4d4')
for q, name in enumerate(pg.QUALITIES):
    d.text((150 + q * cw + cw // 2, 56), f'{["I","II","III","IV","V","VI"][q]} · {name}', font=f('Medium', 12), fill='#8fa398', anchor='mm')
for r, k in enumerate(kinds):
    y = 70 + r * ch
    d.text((20, y + ch // 2), k.capitalize() + (' (special)' if k in ('silver', 'malachite') else ''), font=f('Medium', 14), fill='#e8e4d4', anchor='lm')
    d.text((20, y + ch // 2 + 18), pg.CUT[k] + ' cut', font=f('Regular', 11), fill='#6d7f75', anchor='lm')
    for q in range(6):
        x = 150 + q * cw
        d.rounded_rectangle((x + 4, y + 2, x + cw - 4, y + ch - 4), 6, fill='#44683c')
        s = pg.tower_sprite(k, q); img.alpha_composite(s.resize((s.width * K, s.height * K), Image.NEAREST), (x + 14, y + 4))
y = 70 + ch * len(kinds) + 20
d.text((20, y), 'Creatures (2 walk/flap frames) and checkpoints', font=f('SemiBold', 14), fill='#e8e4d4')
x = 20
for i in range(2):
    for spr in (pg.boar_frame(i), pg.bat_frame(i)):
        bg = Image.new('RGBA', spr.size, '#44683c'); bg.alpha_composite(spr)
        img.alpha_composite(bg.resize((spr.width * 5, spr.height * 5), Image.NEAREST), (x, y + 30)); x += spr.width * 5 + 10
for n in range(1, 8):
    spr = pg.checkpoint_sprite(n); bg = Image.new('RGBA', spr.size, '#44683c'); bg.alpha_composite(spr)
    xx = 20 + (n - 1) % 7 * 54
    img.alpha_composite(bg.resize((48, 48), Image.NEAREST), (xx, y + 130))
img.save(OUT / 'review-sheet.png'); print('sheet', img.size)
