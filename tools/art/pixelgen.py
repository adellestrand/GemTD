"""GemTD pixel art v3 - "Juvelen forst".

All sprites are drawn in code on a fixed palette at native 16 px per board cell.
Run: python pixelgen.py <out_dir> [board_report.json]
Nothing here reads or changes game rules; it only produces PNG files.
"""
from __future__ import annotations
import json, math, sys
from pathlib import Path
from PIL import Image, ImageDraw

CELL = 16
TW, TH = 16, 22          # tower canvas; bottom 16 rows = the logical cell

def hexc(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

# ---------------------------------------------------------------- palette
# ramp = outline, dark, mid, light, highlight
GEM = {
    'sapphire':   ['#0e1c46', '#1d4aa8', '#3480e4', '#7cc0ff', '#e8f6ff'],
    'ruby':       ['#360914', '#8a1226', '#d4263a', '#ff6868', '#ffe2dc'],
    'emerald':    ['#062818', '#0f6236', '#20a258', '#6cdc88', '#e0ffe4'],
    'diamond':    ['#283240', '#8a9eb4', '#c8d6e4', '#eef6ff', '#ffffff'],
    'aquamarine': ['#063434', '#11867f', '#28c4b8', '#88eee2', '#eafffa'],
    'topaz':      ['#382204', '#aa6a0c', '#ecaa1e', '#ffdc64', '#fffade'],
    'amethyst':   ['#200f3c', '#57289c', '#8c4edc', '#c696ff', '#f6ecff'],
    'opal':       ['#3c2c4c', '#a88cc4', '#dcc4ec', '#f6eaff', '#ffffff'],
    'silver':     ['#262e3a', '#7d8a9c', '#b8c3d2', '#e6ecf4', '#ffffff'],
    'malachite':  ['#05261c', '#0d5a40', '#1b8f5e', '#4cc98a', '#c8ffe0'],
}
OPAL_FLECKS = ['#6fd0ff', '#ff8fcc', '#9cf58e', '#ffd25e']
STONE = ['#1b1f23', '#474c50', '#696e72', '#8f9498', '#b6babd']
PED = ['#14181f', '#2c3240', '#414a5b', '#5b6577', '#7a869a']      # tower pedestal: cool slate
WALL = ['#1f1b18', '#4d453e', '#71685e', '#978c80', '#bcb2a4']     # maze stones: warm grey
MOSS = ['#3f5a2e', '#56763a']
METAL = {
    'stone':  None,
    'bronze': ['#3a210c', '#8a5822', '#c28a42', '#e8ba74'],
    'silver': ['#29313c', '#8a96a6', '#c6ced9', '#f0f4f8'],
    'gold':   ['#3c2804', '#ad7810', '#e8b62c', '#fff088'],
}
GRASS = ['#2c4628', '#385733', '#44683c', '#517a45', '#5f8a4f']
SHADOW = (8, 14, 10, 110)

# Dota GemTD quality names
QUALITIES = ['Chipped', 'Flawed', 'Normal', 'Flawless', 'Perfect', 'Great']
CUT = {'sapphire': 'octa', 'ruby': 'round', 'emerald': 'step', 'diamond': 'brilliant',
       'aquamarine': 'baguette', 'topaz': 'pear', 'amethyst': 'cluster', 'opal': 'cabochon',
       'silver': 'crown', 'malachite': 'crown'}
GEM_H = [6, 7, 8, 9, 10, 12]                       # gem height per quality
PEDESTAL = [  # width, top-face height, front thickness, rim metal
    (10, 4, 2, 'stone'), (12, 4, 2, 'bronze'), (12, 5, 3, 'silver'),
    (14, 5, 3, 'gold'), (14, 5, 3, 'gold'), (14, 6, 3, 'gold')]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = hexc(c) if isinstance(c, str) else c

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def image(self):
        img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    img.putpixel((x, y), self.px[y][x])
        return img


def outline_mask(mask, w, h):
    """pixels outside mask but 4-adjacent to it"""
    out = set()
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in mask and 0 <= p[0] < w and 0 <= p[1] < h:
                out.add(p)
    return out


# ---------------------------------------------------------------- gem shapes
def poly_mask(points, ox, oy, gw, gh):
    """rasterize a normalized polygon into a pixel set using pixel-centre tests"""
    pts = [(ox + px * gw, oy + py * gh) for px, py in points]
    mask = set()
    for y in range(int(oy) - 1, int(oy + gh) + 2):
        for x in range(int(ox) - 1, int(ox + gw) + 2):
            cx, cy = x + 0.5, y + 0.5
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]; xj, yj = pts[j]
                if (yi > cy) != (yj > cy) and cx < (xj - xi) * (cy - yi) / (yj - yi + 1e-9) + xi:
                    inside = not inside
                j = i
            if inside:
                mask.add((x, y))
    return mask


def ellipse_mask(cx, cy, rx, ry):
    m = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                m.add((x, y))
    return m


SHAPES = {
    'octa':      dict(aspect=0.78, pts=[(.5, 0), (1, .42), (.5, 1), (0, .42)]),
    'brilliant': dict(aspect=1.25, pts=[(.18, 0), (.82, 0), (1, .34), (.5, 1), (0, .34)]),
    'step':      dict(aspect=0.82, pts=[(.24, 0), (.76, 0), (1, .2), (1, .8), (.76, 1), (.24, 1), (0, .8), (0, .2)]),
    'baguette':  dict(aspect=0.62, pts=[(.5, 0), (1, .22), (1, .78), (.5, 1), (0, .78), (0, .22)]),
    'pear':      dict(aspect=0.85, pts=None),
    'round':     dict(aspect=1.0, pts=None),
    'cabochon':  dict(aspect=1.3, pts=None),
    'cluster':   dict(aspect=1.0, pts=None),
    'crown':     dict(aspect=1.15, pts=None),
}


def gem_mask(cut, ox, oy, gw, gh):
    s = SHAPES[cut]
    if s['pts']:
        return poly_mask(s['pts'], ox, oy, gw, gh)
    if cut == 'round':
        return ellipse_mask(ox + gw / 2, oy + gh / 2, gw / 2, gh / 2)
    if cut == 'cabochon':
        return ellipse_mask(ox + gw / 2, oy + gh * .55, gw / 2, gh * .45)
    if cut == 'pear':
        m = ellipse_mask(ox + gw / 2, oy + gh * .66, gw / 2, gh * .34)
        return m | poly_mask([(.5, 0), (.92, .6), (.08, .6)], ox, oy, gw, gh)
    if cut == 'cluster':      # amethyst: tall centre point + two side points
        m = poly_mask([(.5, 0), (.72, .25), (.72, 1), (.28, 1), (.28, .25)], ox, oy, gw, gh)
        m |= poly_mask([(.14, .3), (.36, .5), (.34, 1), (0, 1), (0, .5)], ox, oy, gw, gh)
        m |= poly_mask([(.86, .38), (1, .58), (1, 1), (.66, 1), (.64, .58)], ox, oy, gw, gh)
        return m
    if cut == 'crown':        # special towers: three points on a band
        m = poly_mask([(.04, .72), (.96, .72), (.9, 1), (.1, 1)], ox, oy, gw, gh)
        for cx, top, hw in ((.5, 0, .2), (.2, .25, .15), (.8, .25, .15)):
            m |= poly_mask([(cx, top), (cx + hw, top + .22), (cx + hw, .76), (cx - hw, .76), (cx - hw, top + .22)], ox, oy, gw, gh)
        return m
    raise KeyError(cut)


def shade_gem(cut, x, y, ox, oy, gw, gh):
    """0=dark 1=mid 2=light 3=highlight; simple facet model lit from top-left"""
    u = (x + .5 - ox) / gw; v = (y + .5 - oy) / gh
    if cut in ('octa', 'baguette'):
        left = u < .5; upper = v < (.42 if cut == 'octa' else .5)
        if cut == 'baguette' and abs(u - .5) < .17:
            return 2 if upper else 1
        return {(True, True): 2, (False, True): 1, (True, False): 1, (False, False): 0}[(left, upper)]
    if cut == 'brilliant':
        if v < .34:
            return 3 if .3 < u < .7 and v < .2 else 2
        return 1 if u < .5 else 0
    if cut == 'step':
        ring = min(u, 1 - u, v, 1 - v)
        if ring > .28:
            return 2
        if ring > .14:
            return 1 if (u + v) > 1 else 2
        return 0 if (u + v) > 1 else 1
    if cut == 'round':
        if v < .38:
            return 3 if (u < .45 and v < .22) else 2 if u < .62 else 1
        return 1 if u < .5 - (v - .38) * .35 else 0
    if cut in ('cabochon', 'pear'):
        d = (u - .35) ** 2 + (v - .4) ** 2
        return 3 if d < .02 else 2 if d < .1 else 1 if d < .3 else 0
    if cut in ('cluster', 'crown'):
        band = cut == 'crown' and v > .72
        if band:
            return 1 if u < .5 else 0
        frac = (u * 3) % 1 if cut == 'crown' else (u * 3.2) % 1
        return 2 if frac < .5 else 1
    return 1


def draw_gem(cv, kind, ox, oy, gh, quality):
    cut = CUT[kind]
    ramp = GEM[kind]
    gw = max(4, min(14, round(gh * SHAPES[cut]['aspect'])))
    ox = ox - gw / 2
    mask = gem_mask(cut, round(ox), oy, gw, gh)
    ox = round(ox)
    gold = METAL['silver' if kind == 'silver' else 'gold']
    for (x, y) in mask:
        s = shade_gem(cut, x, y, ox, oy, gw, gh)
        if cut == 'crown' and (y + .5 - oy) / gh > .72:
            cv.set(x, y, gold[2] if (x + .5 - ox) / gw < .5 else gold[1])
            continue
        cv.set(x, y, ramp[1 + s] if s < 3 else ramp[4])
    if kind == 'opal':                       # iridescent flecks
        flecks = sorted(mask)[::max(3, len(mask) // (4 + 2 * quality))]
        for i, (x, y) in enumerate(flecks[1:-1]):
            cv.set(x, y, OPAL_FLECKS[(i + x) % 4])
    if kind == 'malachite':                  # banding
        for (x, y) in mask:
            if (y + x // 3) % 3 == 0 and (y + .5 - oy) / gh < .7:
                cv.set(x, y, ramp[1])
    edge = outline_mask(mask, cv.w, cv.h)
    for (x, y) in edge:
        cv.set(x, y, ramp[0] if not (cut == 'crown' and (y + .5 - oy) / gh > .74) else gold[0])
    if quality == 5:   # Great: soft halo just outside the outline
        for (x, y) in outline_mask(mask | edge, cv.w, cv.h):
            if cv.get(x, y) is None and (x + y) % 2 == 0:
                cv.set(x, y, hexc(ramp[3], 120))
    # single bright glint at top-left of the gem
    top = min(mask, key=lambda p: (p[1] + p[0] * .6))
    cv.set(top[0] + (1 if gw > 6 else 0), top[1] + 1, ramp[4])
    return mask, gw


def draw_pedestal(cv, cx, base_y, quality):
    w, h, t, metal = PEDESTAL[quality]
    rx, ry = w / 2, h / 2
    top_cy = base_y - t - ry
    top = ellipse_mask(cx, top_cy, rx, ry)
    front = set()
    for (x, y) in ellipse_mask(cx, top_cy, rx, ry):
        for k in range(1, t + 1):
            front.add((x, y + k))
    front -= top
    rim = METAL[metal]
    for (x, y) in front:
        shade = PED[2] if x < cx - 1 else PED[1]
        cv.set(x, y, shade)
    for (x, y) in top:
        cv.set(x, y, PED[3])
    # inner top face ring for depth
    inner = ellipse_mask(cx, top_cy, rx - 1.6, ry - 1.1)
    for (x, y) in top - inner:
        if y < top_cy:
            cv.set(x, y, PED[4])
    if rim:   # metal band on the front face, light on the left
        band_y = max(y for (_, y) in front) - 1
        for (x, y) in front:
            if y == band_y - (1 if t >= 3 and quality >= 4 else 0) or (quality >= 4 and y == band_y):
                cv.set(x, y, rim[2] if x < cx else rim[1])
        if quality >= 5:  # small set stones on the band
            for sx in (round(cx - rx + 2), round(cx), round(cx + rx - 3)):
                cv.set(sx, band_y - 1, rim[3])
    else:     # moss on plain stone
        pass
    for (x, y) in outline_mask(top | front, cv.w, cv.h):
        cv.set(x, y, PED[0])
    return round(top_cy)


def tower_sprite(kind, quality):
    cv = Canvas(TW, TH)
    cx = TW / 2
    top_cy = draw_pedestal(cv, cx, TH - 1, quality)
    # gem shadow on the pedestal top
    for x in range(round(cx - 2), round(cx + 2)):
        cv.set(x, top_cy, PED[2])
    gh = GEM_H[quality]
    gem_bottom = top_cy - 1
    oy = gem_bottom - gh + 1
    mask, gw = draw_gem(cv, kind, cx, oy, gh, quality)
    if quality == 5:  # Great: a sparse halo of sparkles
        ramp = GEM[kind]
        for sx, sy in ((cx - gw / 2 - 2, oy + 2), (cx + gw / 2 + 1, oy + 4), (cx + gw / 2 - 1, oy - 1)):
            if cv.get(round(sx), round(sy)) is None:
                cv.set(round(sx), round(sy), ramp[4])
    return cv.image()


# ---------------------------------------------------------------- creatures (hand-drawn grids)
BOAR = {
    'o': '#24160c', 'd': '#55301a', 'm': '#87502a', 'l': '#b57c46', 't': '#f2e8cc', 'p': '#d48a7a', 'k': '#0c0c0c',
}
BOAR_FRAMES = [[
    "......oo.o......",
    ".....ommoomoo...",
    "...oommmmmmmmoo.",
    "..ommlllllmmmmoo",
    ".ommllllllmmmkmo",
    "oommlllmmmmmmtpo",
    "odmmmmmmmmmmddto",
    ".oddmmmmmmmddoo.",
    "..oddddddddddo..",
    "..odo..odo.odo..",
    "..oo...oo..oo...",
], [
    "......oo.o......",
    ".....ommoomoo...",
    "...oommmmmmmmoo.",
    "..ommlllllmmmmoo",
    ".ommllllllmmmkmo",
    "oommlllmmmmmmtpo",
    "odmmmmmmmmmmddto",
    ".oddmmmmmmmddoo.",
    "..oddddddddddo..",
    "...odo.odo..odo.",
    "...oo..oo....oo.",
]]
BAT = {'o': '#2a0a0e', 'w': '#5e1418', 'W': '#a42c2c', 'b': '#c8483a', 'c': '#f0d6a6', 'k': '#0c0c0c'}
BAT_HALF = [  # left half; mirrored for the right
    ["o.......", "oWo.....", "oWWo..oo", "oWWWoobb", "owWWWokb", "owwWWobc", ".owwwobc", "..owwobc", "...oo.ob", "......oo"],
    ["........", "........", "......oo", "oo..oobb", "oWWWWokb", "owWWWobc", "owwwwobc", ".owwwobc", "..ooo.ob", "......oo"],
]


def grid_sprite(rows, pal, w=16, h=16, oy=0):
    cv = Canvas(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                cv.set(x, y + oy, pal[ch])
    return cv


def boar_frame(i):
    cv = grid_sprite(BOAR_FRAMES[i], BOAR, oy=3)
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((2, 12, 13, 15), fill=SHADOW)
    img.alpha_composite(cv.image())
    return img


def bat_frame(i):
    rows = [r + r[::-1] for r in BAT_HALF[i]]
    cv = grid_sprite(rows, BAT, oy=0)
    img = Image.new('RGBA', (16, 18), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((5, 15, 10, 17), fill=SHADOW)   # ground shadow well below
    img.alpha_composite(cv.image(), (0, 1 if i else 0))
    return img


# ---------------------------------------------------------------- terrain, rocks, checkpoint
def hash2(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return (n ^ (n >> 16)) / 0xffffffff


def draw_grass(img, ox, oy, cols, rows):
    for cy in range(rows):
        for cx in range(cols):
            base = GRASS[2] if (cx + cy) % 2 == 0 else '#48703f'
            for y in range(CELL):
                for x in range(CELL):
                    gx, gy = cx * CELL + x, cy * CELL + y
                    r = hash2(gx, gy)
                    c = base
                    rc = hash2(gx // 2, gy // 3, 11)
                    if r < .02 or rc < .03: c = GRASS[1]
                    elif r > .985: c = GRASS[4]
                    img.putpixel((ox + gx, oy + gy), hexc(c))
            # occasional tuft
            if hash2(cx, cy, 3) < .28:
                tx, ty = ox + cx * CELL + 3 + int(hash2(cx, cy, 4) * 9), oy + cy * CELL + 5 + int(hash2(cx, cy, 5) * 8)
                for dx, dy, c in ((0, 0, GRASS[4]), (1, -1, GRASS[4]), (2, 0, GRASS[4]), (1, 0, GRASS[1])):
                    img.putpixel((tx + dx, ty + dy), hexc(c))


def draw_rocks(img, ox, oy, cells):
    """stones as one connected wall: union mask, then 3/4 shading (top face light, front face dark)"""
    m = set()
    for (cx, cy) in cells:
        x0, y0 = cx * CELL, cy * CELL
        n = {(dx, dy): (cx + dx, cy + dy) in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))}
        l = 0 if n[(-1, 0)] else 1
        r = 16 if n[(1, 0)] else 15
        t = 0 if n[(0, -1)] else 2
        b = 16 if n[(0, 1)] else 15
        for y in range(t, b):
            for x in range(l, r):
                # round off free corners
                corner = ((x < l + 2 and not n[(-1, 0)]) or (x > r - 3 and not n[(1, 0)])) and \
                         ((y < t + 2 and not n[(0, -1)]) or (y > b - 3 and not n[(0, 1)]))
                if corner and ((x in (l, r - 1)) or (y in (t, b - 1))):
                    continue
                m.add((x0 + x, y0 + y))
    FRONT = 5
    for (x, y) in m:
        below_free = any((x, y + k) not in m for k in range(1, FRONT + 1))
        above_free = (x, y - 1) not in m
        r = hash2(x, y, 7)
        if below_free:   # front face: darker, horizontal mortar lines
            c = WALL[1] if (y % 4 == 0 or r < .12) else WALL[2]
            if (x, y + 1) not in m: c = WALL[1]
        else:            # top face: light, cracked blocks
            c = WALL[3]
            if r < .10: c = WALL[2]
            elif r > .93: c = WALL[4]
            if above_free: c = WALL[4]
            if ((x // 8 + y // 6) % 2 == 0 and x % 8 == 0) or y % 6 == 0 and hash2(x // 8, y // 6, 9) < .5:
                c = WALL[2]
        if r > .985 and not below_free:
            c = MOSS[1]
        img.putpixel((ox + x, oy + y), hexc(c))
    for (x, y) in outline_mask(m, 10 ** 6, 10 ** 6):
        img.putpixel((ox + x, oy + y), hexc(WALL[0]))
    # cast shadow to the lower-right on the grass
    for (x, y) in m:
        for (sx, sy) in ((x + 1, y + 1),):
            if (sx, sy) not in m and (sx, sy - 1) not in outline_mask({(x, y)}, 10**6, 10**6) and (sx, sy) not in outline_mask(m, 10**6, 10**6):
                p = img.getpixel((ox + sx, oy + sy))
                img.putpixel((ox + sx, oy + sy), (int(p[0] * .7), int(p[1] * .7), int(p[2] * .7), 255))


DIGITS = {
    '1': ["010", "110", "010", "010", "111"], '2': ["110", "001", "010", "100", "111"],
    '3': ["110", "001", "010", "001", "110"], '4': ["101", "101", "111", "001", "001"],
    '5': ["111", "100", "110", "001", "110"], '6': ["011", "100", "110", "101", "010"],
    '7': ["111", "001", "010", "010", "010"],
}


def checkpoint_sprite(n):
    cv = Canvas(16, 16)
    plate = ellipse_mask(8, 9, 7.2, 5.6)
    front = {(x, y + k) for (x, y) in plate for k in (1, 2)} - plate
    for (x, y) in front: cv.set(x, y, STONE[1])
    for (x, y) in plate: cv.set(x, y, STONE[3])
    ring = plate - ellipse_mask(8, 9, 5.8, 4.3)
    gold = METAL['gold']
    for (x, y) in ring: cv.set(x, y, gold[2] if x < 8 else gold[1])
    for (x, y) in ellipse_mask(8, 9, 4.6, 3.3) - ellipse_mask(8, 9, 3.6, 2.4):
        if (x + y) % 2 == 0: cv.set(x, y, '#5fd8e8')
    for (x, y) in outline_mask(plate | front, 16, 16): cv.set(x, y, STONE[0])
    for y, row in enumerate(DIGITS[str(n)]):
        for x, b in enumerate(row):
            if b == '1': cv.set(7 + x - 1, 7 + y - 1, '#fff2c8')
    return cv.image()


# ---------------------------------------------------------------- board render
CHECKPOINTS = [(4, 2), (4, 18), (32, 18), (32, 4), (18, 4), (18, 32), (33, 32)]


def route(blocked, size=37):
    """illustrative 4-way BFS through the checkpoints (presentation only)"""
    from collections import deque
    path = []
    for a, b in zip(CHECKPOINTS, CHECKPOINTS[1:]):
        prev = {a: None}; q = deque([a])
        while q:
            p = q.popleft()
            if p == b: break
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (p[0] + d[0], p[1] + d[1])
                if 0 <= n[0] < size and 0 <= n[1] < size and n not in prev and (n not in blocked or n == b):
                    prev[n] = p; q.append(n)
        seg = []; p = b
        while p is not None and p in prev: seg.append(p); p = prev[p]
        path += seg[::-1][(1 if path else 0):]
    return path


def render_board(report, tier_bonus=0):
    data = json.loads(Path(report).read_text())
    stones, towers = set(), []
    for c in data['board']:
        g = c['gem']
        if g['kind'] == 'stone': stones.add((c['x'], c['y']))
        else: towers.append((c['x'], c['y'], g['kind'], min(5, g['tier'] - 1 + tier_bonus)))
    M = 12
    size = 37 * CELL
    img = Image.new('RGBA', (size + 2 * M, size + 2 * M), hexc('#14201b'))
    d = ImageDraw.Draw(img)
    d.rectangle((M - 3, M - 3, M + size + 2, M + size + 2), fill=hexc(STONE[0]))
    d.rectangle((M - 2, M - 2, M + size + 1, M + size + 1), fill=hexc(METAL['bronze'][1]))
    draw_grass(img, M, M, 37, 37)
    blocked = stones | {(x, y) for x, y, *_ in towers}
    path = route(blocked)
    for i, (x, y) in enumerate(path):      # faint dotted route
        if i % 2 == 0:
            px, py = M + x * CELL + 7, M + y * CELL + 7
            for dx in (0, 1):
                for dy in (0, 1):
                    p = img.getpixel((px + dx, py + dy))
                    img.putpixel((px + dx, py + dy), (min(255, p[0] + 40), min(255, p[1] + 34), min(255, p[2] + 18), 255))
    draw_rocks(img, M, M, stones)
    for i, (x, y) in enumerate(CHECKPOINTS):
        img.alpha_composite(checkpoint_sprite(i + 1), (M + x * CELL, M + y * CELL))
    sprites = []
    for (x, y, kind, q) in towers:
        k = kind if kind in CUT else 'diamond'
        sprites.append((y, tower_sprite(k, q), M + x * CELL, M + y * CELL - (TH - CELL)))
    # a few creatures on the route
    for j, idx in enumerate((14, 22, 30, 45, 52, 61, 70)):
        if idx < len(path):
            x, y = path[idx]
            sprites.append((y + .5, boar_frame(j % 2), M + x * CELL, M + y * CELL - 2))
    for (x, y) in ((25, 11), (29, 13)):
        sprites.append((y + 9, bat_frame(x % 2), M + x * CELL, M + y * CELL - 6))
    for _, s, x, y in sorted(sprites, key=lambda t: t[0]):
        img.alpha_composite(s, (x, y))
    return img


def sharp_scale(img, factor):
    """sharp-bilinear: nearest to an integer multiple, then smooth down -> even pixels at any scale"""
    k = math.ceil(factor) * 2
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    return big.resize((round(img.width * factor), round(img.height * factor)), Image.LANCZOS)


if __name__ == '__main__':
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    kinds = list(GEM)
    sheet = Image.new('RGBA', (TW * 6, TH * len(kinds)), (0, 0, 0, 0))
    for r, k in enumerate(kinds):
        for q in range(6):
            sheet.alpha_composite(tower_sprite(k, q), (q * TW, r * TH))
    sheet.save(out / 'towers-v3.png')
    ene = Image.new('RGBA', (16 * 4, 18), (0, 0, 0, 0))
    for i in range(2):
        ene.alpha_composite(boar_frame(i), (i * 16, 2)); ene.alpha_composite(bat_frame(i), (32 + i * 16, 0))
    ene.save(out / 'enemies-v3.png')
    cps = Image.new('RGBA', (16 * 7, 16), (0, 0, 0, 0))
    for i in range(7): cps.alpha_composite(checkpoint_sprite(i + 1), (i * 16, 0))
    cps.save(out / 'checkpoints-v3.png')
    if len(sys.argv) > 2:
        board = render_board(sys.argv[2])
        board.save(out / 'board-native.png')
    print('ok')
