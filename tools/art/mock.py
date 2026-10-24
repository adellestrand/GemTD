"""Full-window style sketch at 1360x900 using the v3 sprites. Presentation mock only."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, str(Path(__file__).parent))
import pixelgen as pg

OUT = Path(sys.argv[1]); REPORT = sys.argv[2]
F = '/usr/share/fonts/opentype/inter/'
def font(w, s): return ImageFont.truetype(F + f'Inter-{w}.otf', s)

BG, PANEL, LINE = '#0d1512', '#15211c', '#26362e'
INK, MUTED, GOLD = '#e8e4d4', '#8fa398', '#e8c46a'

W, H = 1360, 900
img = Image.new('RGBA', (W, H), BG)
d = ImageDraw.Draw(img)

# --- board: native 16 px/cell, sharp-scaled to 22 px/cell
board = pg.render_board(REPORT)
scale = 21 / 16
b = pg.sharp_scale(board, scale)
bx, by = 24, 62
img.alpha_composite(b, (bx, by))

# --- top bar
d.text((24, 16), 'GEMTD', font=font('Bold', 22), fill=GOLD)
d.text((112, 23), 'Solo · The seven checkpoints', font=font('Regular', 13), fill=MUTED)

def icon(sprite, x, y, k=2):
    img.alpha_composite(sprite.resize((sprite.width * k, sprite.height * k), Image.NEAREST), (x, y))

def pix_icon(rows, pal):
    cv = pg.Canvas(len(rows[0]), len(rows))
    for yy, r in enumerate(rows):
        for xx, ch in enumerate(r):
            if ch in pal: cv.set(xx, yy, pal[ch])
    return cv.image()

HEART = pix_icon([".oo.oo.", "orroRro", "orrrrro", ".orrro.", "..oro..", "...o..."],
                 {'o': '#3a0a10', 'r': '#e0384a', 'R': '#ff9a9a'})
COIN = pix_icon([".ooo.", "oyYyo", "oyyyo", "oyyDo", ".ooo."], {'o': '#4a3008', 'y': '#e8b62c', 'Y': '#fff088', 'D': '#ad7810'})
x = 760
for spr, label, val in ((HEART, 'Lives', '100'), (COIN, 'Gold', '35'), (None, 'Wave', '10 / 100')):
    if spr: icon(spr, x, 20, 3); x += spr.width * 3 + 8
    d.text((x, 14), val, font=font('Bold', 20), fill=INK)
    d.text((x, 38), label.upper(), font=font('Medium', 10), fill=MUTED)
    x += max(70, int(d.textlength(val, font=font('Bold', 20)))) + 26
for i, t in enumerate(('Waves', 'Recipes', 'Run')):
    tx = 1124 + i * 74
    d.rounded_rectangle((tx, 16, tx + 66, 46), 6, outline=LINE, fill=PANEL)
    d.text((tx + 33, 31), t, font=font('Medium', 13), fill=INK, anchor='mm')

# --- right panel
px0 = bx + b.width + 20
d.rounded_rectangle((px0, by, W - 20, by + b.height), 10, fill=PANEL, outline=LINE)
cx = px0 + 18
d.text((cx, by + 16), 'BUILD  ·  5 / 5 PLACED', font=font('SemiBold', 12), fill=MUTED)
picks = [('sapphire', 1), ('emerald', 1), ('emerald', 1), ('topaz', 0), ('amethyst', 1)]
for i, (k, q) in enumerate(picks):
    x0 = cx + i * 64
    sel = i == 1
    d.rounded_rectangle((x0, by + 40, x0 + 56, by + 112), 8, fill='#1d2c25' if not sel else '#24382e',
                        outline=GOLD if sel else LINE, width=2 if sel else 1)
    icon(pg.tower_sprite(k, q), x0 + 12, by + 46, 2)
    d.text((x0 + 28, by + 100), 'I' if q == 0 else 'II', font=font('SemiBold', 11), fill=MUTED, anchor='mm')

y = by + 132
d.line((cx, y, W - 38, y), fill=LINE)
icon(pg.tower_sprite('emerald', 1), cx, y + 14, 4)
d.text((cx + 80, y + 22), 'Emerald', font=font('Bold', 22), fill=INK)
d.text((cx + 80, y + 52), 'Flawed · quality II', font=font('Medium', 13), fill='#6cdc88')
d.text((cx + 80, y + 72), 'Poison · ground + air', font=font('Regular', 13), fill=MUTED)

y += 116
stats = [('Damage', '10 physical'), ('Attack', '0.80 s'), ('Range', '4.7 cells'), ('Poison', '4 / s · 3 s')]
for i, (k, v) in enumerate(stats):
    sx = cx + (i % 2) * 168; sy = y + (i // 2) * 44
    d.text((sx, sy), k.upper(), font=font('Medium', 10), fill=MUTED)
    d.text((sx, sy + 14), v, font=font('SemiBold', 15), fill=INK)
y += 100
d.text((cx, y), 'Values in this sketch are placeholders, not game data.', font=font('Regular', 11), fill='#6d7f75')

y += 30
def action(y, title, sub, primary, sprite=None):
    fill = '#2f5a3e' if primary else '#1d2c25'
    d.rounded_rectangle((cx, y, W - 38, y + 64), 8, fill=fill, outline='#4f8a62' if primary else LINE)
    if sprite: icon(sprite, cx + 12, y + 10, 2)
    d.text((cx + 56, y + 14), title, font=font('Bold', 16), fill=INK)
    d.text((cx + 56, y + 38), sub, font=font('Regular', 12), fill='#b9d4c0' if primary else MUTED)
action(y, 'Combine 2 → Emerald III', 'Starts wave 10 · other 3 become stones', True, pg.tower_sprite('emerald', 2))
action(y + 76, 'Keep Emerald II', 'Starts wave 10 · other 4 become stones', False, pg.tower_sprite('emerald', 1))
d.text((cx, y + 160), 'Demolish selected', font=font('Medium', 13), fill=MUTED)
d.text((W - 38, y + 160), 'Improve odds · 250', font=font('Medium', 13), fill=MUTED, anchor='ra')

# --- footer legend
fy = by + b.height + 12
d.text((24, fy), 'Style sketch v3 · real wave-10 board from a natural campaign run (maze-12) · towers drawn at their recorded quality',
       font=font('Regular', 12), fill='#6d7f75')
img.save(OUT / 'mock-1360x900.png')

# --- comparison crop at true game scale and 4x zoom
crop = board.crop((0, 0, 12 + 18 * 16, 12 + 12 * 16))
crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST).save(OUT / 'detail-x4.png')
# late-game illustration: same maze, every tower +3 quality
late = pg.render_board(REPORT, tier_bonus=3)
pg.sharp_scale(late, scale).save(OUT / 'board-late-illustration.png')
print('mock ok')
