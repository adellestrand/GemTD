"""Refine the approved AI sprite sheets into clean pixel art without changing their look.

1. find each cell's logical pixel grid (~4.9 source px per art pixel) and phase
2. sample every logical pixel with the median of its block (no blur), binary alpha
3. restore a 1 px dark outline where the source had one
Output: one clean PNG per sprite at native art resolution (~45-60 px).
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image


def grid_score(rgb, a, k, px, py):
    h, w = a.shape
    xs = np.round(np.arange(px, w - 1, k)).astype(int)
    ys = np.round(np.arange(py, h - 1, k)).astype(int)
    dx = (np.abs(np.diff(rgb, axis=1)).sum(-1) > 40) & (a[:, 1:] > 128)
    dy = (np.abs(np.diff(rgb, axis=0)).sum(-1) > 40) & (a[1:, :] > 128)
    return dx[:, xs[xs < w - 1]].sum() / max(1, dx.sum()) + dy[ys[ys < h - 1], :].sum() / max(1, dy.sum())


def refine_cell(cell, k=None):
    cell = np.asarray(cell).astype(int)
    rgb, a = cell[..., :3], cell[..., 3]
    best = None
    for kk in ([k] if k else np.arange(4.6, 5.3, 0.05)):
        for px in np.arange(0, kk, 0.5):
            for py in np.arange(0, kk, 0.5):
                s = grid_score(rgb, a, kk, px, py)
                if best is None or s > best[0]:
                    best = (s, kk, px, py)
    _, k, px, py = best
    h, w = a.shape
    nx, ny = int((w - px) // k), int((h - py) // k)
    out = np.zeros((ny, nx, 4), dtype=np.uint8)
    for j in range(ny):
        for i in range(nx):
            x0, y0 = int(round(px + i * k)), int(round(py + j * k))
            x1, y1 = int(round(px + (i + 1) * k)), int(round(py + (j + 1) * k))
            # inner block avoids anti-aliased borders between logical pixels
            ix0, iy0, ix1, iy1 = x0 + 1, y0 + 1, max(x0 + 2, x1 - 1), max(y0 + 2, y1 - 1)
            blk_a = a[iy0:iy1, ix0:ix1]
            if blk_a.size == 0 or np.median(blk_a) < 128:
                continue
            blk = rgb[iy0:iy1, ix0:ix1][blk_a >= 128]
            out[j, i, :3] = np.median(blk, axis=0)
            out[j, i, 3] = 255
    img = Image.fromarray(out, 'RGBA')
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img, (k, px, py)


def refine_sheet(path, cols, rows, out_dir, names):
    sheet = Image.open(path).convert('RGBA')
    cw, ch = sheet.width / cols, sheet.height / rows
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {}
    for idx, name in enumerate(names):
        if not name:
            continue
        c, r = idx % cols, idx // cols
        cell = sheet.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
        img, grid = refine_cell(cell)
        img.save(out_dir / f'{name}.png')
        report[name] = dict(size=img.size, grid=[round(float(g), 2) for g in grid])
        print(name, img.size, report[name]['grid'], flush=True)
    return report


if __name__ == '__main__':
    src = Path(sys.argv[1]); out = Path(sys.argv[2])
    refine_sheet(src / 'towers-v1.png', 4, 4, out / 'towers', [
        'sapphire_1', 'diamond_1', 'aquamarine_1', 'opal_1', 'emerald_1', 'topaz_1', 'ruby_1', 'amethyst_1',
        'silver', 'malachite', 'asteriated_ruby', 'stone', 'checkpoint', 'grass_tuft', 'fern', 'tree'])
    refine_sheet(src / 'qualities-v2.png', 4, 4, out / 'towers', [
        'sapphire_2', 'sapphire_3', 'diamond_2', 'diamond_3', 'aquamarine_2', 'aquamarine_3', 'opal_2', 'opal_3',
        'emerald_2', 'emerald_3', 'topaz_2', 'topaz_3', 'ruby_2', 'ruby_3', 'amethyst_2', 'amethyst_3'])
    refine_sheet(src / 'enemies-v1.png', 4, 3, out / 'enemies', [
        'boar', 'frog', 'yak', 'robot', 'griffin', 'spider', 'lizard', 'bat', 'hound', 'boss_hound', 'rocks', 'meadow'])
