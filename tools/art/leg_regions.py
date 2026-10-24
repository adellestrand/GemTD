"""Suggest leg regions for a standing sprite, for walk.px.js (presentation only).

Scans upward from the feet: the leg zone is the band of rows where the silhouette is split into
two or more separate runs (gaps between legs). Each connected part inside that band is one leg;
the band's top row is the pivot. Prints a walk.px.js-style leg list (rects, top, len) per sprite,
far legs first; review the result visually, since tails, skirts or sacks can look like legs.
Usage: python tools/art/leg_regions.py <sprite.png> [...]
"""
import sys
from pathlib import Path

from PIL import Image


def runs(alpha, y, w):
    out, x = [], 0
    while x < w:
        if alpha[x, y] > 0:
            x0 = x
            while x < w and alpha[x, y] > 0:
                x += 1
            out.append((x0, x - 1))
        x += 1
    return out


def legs(path, min_rows=3):
    img = Image.open(path).convert('RGBA')
    w, h = img.size
    a = img.getchannel('A').load()
    bottom = max(y for y in range(h) if any(a[x, y] for x in range(w)))
    top = bottom
    while top > 0 and len(runs(a, top - 1, w)) >= 2:
        top -= 1
    if bottom - top + 1 < min_rows:
        return None
    # connected parts inside the band
    seen, parts = set(), []
    for y in range(top, bottom + 1):
        for x in range(w):
            if a[x, y] and (x, y) not in seen:
                stack, pts = [(x, y)], []
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and top <= ny <= bottom and (nx, ny) not in seen and a[nx, ny]:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                if len(pts) >= 6:
                    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                    parts.append((min(xs), max(xs), min(ys), max(ys)))
    return top, bottom, sorted(parts)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        r = legs(p)
        name = Path(p).stem
        if not r:
            print(f'{name}: no separate legs found')
            continue
        top, bottom, parts = r
        print(f'{name}: band {top}-{bottom}; legs {parts}')
