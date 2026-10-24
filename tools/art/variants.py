"""Enemy variants derived from the approved refined sprites (presentation only).

Each variant recolours one base sprite in HSV space - only pixels inside the chosen
source-hue band are changed, so outlines, eyes, tusks and metal trims stay intact -
and can add a small pixel accessory or a ghostly translucency.
Usage: python tools/art/variants.py <refined-v3 dir> [preview.png]
"""
import colorsys
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

# name: (base, recolours, extras)
#   recolour = (hue_from, hue_to, new_hue or None, sat_mul, val_mul)  hues in degrees
VARIANTS = {
    'pig_princess':   ('boar',   [(0, 45, 340, 0.75, 1.25)], ['crown']),
    'bajie':          ('boar',   [(0, 45, 300, 0.45, 1.15)], ['headband']),
    'sheep':          ('yak',    [(15, 60, 45, 0.25, 1.45), (200, 250, 120, 0.8, 1.0)], []),
    'alpaca':         ('yak',    [(15, 60, 20, 0.55, 1.3), (200, 250, 330, 0.8, 1.1)], []),
    'jumo':           ('yak',    [(15, 60, 95, 0.8, 1.0), (200, 250, 30, 0.9, 1.0)], []),
    'boooofus':       ('yak',    [(15, 60, 275, 0.6, 0.85), (200, 250, 50, 0.9, 1.1)], []),
    'crummy':         ('yak',    [(15, 60, 30, 0.15, 1.05)], ['wizard_hat']),
    'invisible_spider': ('spider', [(0, 90, 270, 0.8, 1.1)], ['ghost']),
    'ripper':         ('spider', [(0, 90, 355, 1.0, 0.9)], []),
    'stump':          ('spider', [(0, 90, 35, 0.7, 0.8)], []),
    'young_demon':    ('lizard', [(60, 140, 285, 0.9, 0.9), (0, 40, 50, 1.0, 1.1)], []),
    'lockjaw':        ('lizard', [(60, 140, 175, 0.9, 1.0)], []),
    'trapjaw':        ('lizard', [(60, 140, 28, 1.0, 1.05), (0, 40, 200, 0.9, 1.0)], []),
    'bookwyrm':       ('lizard', [(60, 140, 325, 0.65, 1.0), (0, 40, 45, 1.0, 1.1)], []),
    'azuremir':       ('lizard', [(60, 140, 205, 1.0, 1.1), (0, 40, 190, 0.6, 1.3)], []),
    'machjaw':        ('robot',  [(15, 60, 210, 0.35, 1.0)], []),
    'bulldog':        ('hound',  [(0, 360, 28, 0.6, 1.05, 0.38)], []),
    'rabbit':         ('hound',  [(0, 360, 0, 0.0, 1.45)], []),
    'baekho':         ('hound',  [(0, 360, 210, 0.25, 1.5)], []),
    'zombie':         ('hound',  [(0, 360, 100, 0.45, 0.9, 0.22)], []),
    'dusky':          ('hound',  [(0, 360, 260, 0.35, 0.65)], []),
    'shark':          ('frog',   [(60, 160, 205, 0.45, 0.95)], []),
    'lilnova':        ('frog',   [(60, 160, 275, 0.75, 1.0)], []),
    'furry_fish':     ('frog',   [(60, 160, 22, 1.0, 1.1)], []),
    'shroomy':        ('frog',   [(60, 160, 355, 0.85, 1.0)], []),
    'panda_flyer':    ('griffin', [(190, 250, 0, 0.0, 0.55)], []),
    'flamingo':       ('griffin', [(190, 250, 330, 0.7, 1.25)], []),
    'huntling':       ('griffin', [(190, 250, 150, 0.8, 0.95)], []),
    'mermaid':        ('griffin', [(190, 250, 185, 0.55, 1.3)], []),
    'chicken':        ('griffin', [(190, 250, 0, 0.08, 1.5)], ['comb']),
    'kupu':           ('griffin', [(190, 250, 300, 0.65, 1.2)], []),
    'chirpy':         ('griffin', [(190, 250, 50, 1.0, 1.3)], []),
    'drodo':          ('griffin', [(190, 250, 110, 0.7, 0.9)], []),
    'carpet_rider':   ('griffin', [(190, 250, 270, 0.9, 0.9)], []),
    'corsair':        ('bat',    [(330, 30, 225, 0.8, 0.75)], []),
    'goldfish':       ('bat',    [(330, 30, 45, 1.0, 1.35)], []),
    'ig_dragon':      ('bat',    [(330, 30, 120, 0.9, 0.9)], []),
    'fox':            ('bat',    [(330, 30, 22, 1.0, 1.15)], []),
    'jinyin_fox':     ('bat',    [(330, 30, 0, 0.0, 1.5)], []),
    'wabbit':         ('bat',    [(330, 30, 265, 0.35, 1.45)], []),
    'ghost':          ('bat',    [(330, 30, 195, 0.35, 1.6)], ['ghost']),
    'shagbark':       ('boss_hound', [(0, 360, 95, 0.55, 1.05)], []),
    'baby_roshan':    ('boss_hound', [(0, 360, 28, 0.55, 1.2)], []),
}


def in_band(h, a, b):
    return a <= h <= b if a <= b else (h >= a or h <= b)


def recolour(img, rules):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # keep outlines, eye whites and highlights so the sprite still reads the same
            if v < 0.16 or (s < 0.12 and v > 0.85):
                continue
            hd = h * 360
            for rule in rules:
                a0, a1, new_h, smul, vmul = rule[:5]
                sat_add = rule[5] if len(rule) > 5 else 0.0
                if in_band(hd, a0, a1) and (s > 0.1 or (a0 == 0 and a1 == 360)):
                    h = (new_h / 360) if new_h is not None else h
                    s = min(1.0, s * smul + sat_add * (1.0 - s))
                    v = min(1.0, v * vmul)
                    break
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return img


def head_box(img):
    """Approximate head position: topmost opaque pixels in the right third (sprites face right)."""
    w, h = img.size
    a = img.getchannel('A').load()
    for y in range(h):
        xs = [x for x in range(int(w * 0.55), w) if a[x, y] > 0]
        if xs:
            return (sum(xs) // len(xs), y)
    return (int(w * 0.75), 2)


def pad_top(img, amount):
    out = Image.new('RGBA', (img.width, img.height + amount), (0, 0, 0, 0))
    out.alpha_composite(img, (0, amount))
    return out


def accessory(img, kind):
    if kind == 'ghost':
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (min(255, r + 20), min(255, g + 30), min(255, b + 45), 175)
        return img
    if kind in ('crown', 'wizard_hat', 'comb'):
        img = pad_top(img, {'crown': 11, 'wizard_hat': 14, 'comb': 5}[kind])
    cx, top = head_box(img)
    d = ImageDraw.Draw(img)
    O = (32, 20, 12, 255)
    if kind == 'crown':
        y = top + 1
        pts = [(-7, 0), (-7, -7), (-4, -4), (0, -9), (4, -4), (7, -7), (7, 0)]
        d.polygon([(cx + x, y + yy) for x, yy in pts], fill=(240, 196, 64, 255), outline=O)
        d.line([(cx - 6, y - 1), (cx + 6, y - 1)], fill=(255, 236, 140, 255))
        d.point([(cx, y - 5), (cx + 1, y - 5), (cx, y - 4)], fill=(230, 60, 90, 255))
        d.point([(cx - 4, y - 2), (cx + 4, y - 2)], fill=(120, 200, 255, 255))
    elif kind == 'comb':
        y = top + 1
        d.polygon([(cx - 4, y), (cx - 3, y - 4), (cx - 1, y - 2), (cx + 1, y - 5), (cx + 3, y - 2), (cx + 4, y)], fill=(222, 52, 52, 255), outline=O)
    elif kind == 'wizard_hat':
        y = top
        d.polygon([(cx - 7, y), (cx + 7, y), (cx + 2, y - 13), (cx - 1, y - 12)], fill=(70, 60, 150, 255), outline=O)
        d.line([(cx - 7, y), (cx + 7, y)], fill=(232, 190, 64, 255), width=1)
        d.point([(cx + 1, y - 7), (cx - 2, y - 4), (cx + 3, y - 3)], fill=(250, 230, 120, 255))
    elif kind == 'headband':
        y = top + 5
        d.line([(cx - 8, y), (cx + 6, y)], fill=O, width=4)
        d.line([(cx - 7, y), (cx + 5, y)], fill=(236, 186, 60, 255), width=2)
        d.line([(cx - 9, y + 1), (cx - 12, y + 5)], fill=(236, 186, 60, 255), width=2)
    return img


def despeckle(img, minimum=8):
    """Drop tiny detached pixel islands left over from the source sheet."""
    img = img.copy()
    a = img.load()
    w, h = img.size
    seen = set()
    for y in range(h):
        for x in range(w):
            if a[x, y][3] == 0 or (x, y) in seen:
                continue
            stack, comp = [(x, y)], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and a[nx, ny][3] > 0:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(comp) < minimum:
                for px in comp:
                    a[px] = (0, 0, 0, 0)
    return img


def build(src_dir: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    made = {}
    for name, (base, rules, extras) in VARIANTS.items():
        img = Image.open(src_dir / f'{base}.png').convert('RGBA')
        img = recolour(img, rules)
        for e in extras:
            img = accessory(img, e)
        img = despeckle(img).crop(despeckle(img).getbbox())
        img.save(out_dir / f'{name}.png')
        made[name] = img
    return made


def build_strip(strip: Image.Image, frames: int, rules, extras) -> Image.Image:
    """Same recolour/accessories as build(), applied per frame of a horizontal animation strip.
    Every frame is cropped to the union of their opaque bounds so the frames stay aligned."""
    width = strip.width // frames
    made = []
    for i in range(frames):
        img = recolour(strip.crop((i * width, 0, (i + 1) * width, strip.height)), rules)
        for e in extras:
            img = accessory(img, e)
        made.append(despeckle(img))
    boxes = [img.getbbox() for img in made]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    w, h = box[2] - box[0], box[3] - box[1]
    out = Image.new('RGBA', (w * frames, h), (0, 0, 0, 0))
    for i, img in enumerate(made):
        out.alpha_composite(img.crop(box), (i * w, 0))
    return out


def build_strips(anims_dir: Path, bases: dict) -> dict:
    """bases: base sprite name -> (strip file stem suffix, frame count), e.g. {'boar': ('walk_v1', 4)}.
    Writes <variant>_<suffix>.png next to the base strips for every variant of those bases."""
    made = {}
    for name, (base, rules, extras) in VARIANTS.items():
        if base not in bases:
            continue
        suffix, frames = bases[base]
        strip = Image.open(anims_dir / f'{base}_{suffix}.png').convert('RGBA')
        out = build_strip(strip, frames, rules, extras)
        out.save(anims_dir / f'{name}_{suffix}.png')
        made[name] = out
    return made


def preview(src_dir: Path, made: dict, path: Path):
    K = 3
    names = list(made)
    cols = 9
    cw, ch = 80 * K // 1 + 10, 80 * K // 1 + 26
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * cw, rows * ch), '#44683c')
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = made[n]
        x, y = (i % cols) * cw, (i // cols) * ch
        big = im.resize((im.width * K, im.height * K), Image.NEAREST)
        sheet.alpha_composite(big, (x + (cw - big.width) // 2, y + (ch - 20 - big.height)))
        d.text((x + 6, y + ch - 18), f'{n} ({VARIANTS[n][0]})', fill='white')
    sheet.save(path)


if __name__ == '__main__':
    src = Path(sys.argv[1])
    made = build(src, src / 'variants')
    if len(sys.argv) > 2:
        preview(src, made, Path(sys.argv[2]))
    print(json.dumps({n: list(im.size) for n, im in made.items()}))
