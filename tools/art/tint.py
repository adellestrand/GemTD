"""Gentle per-gem roof tint: shift dark, low-saturation slate pixels toward the gem hue."""
import colorsys
import numpy as np
from PIL import Image

GEMHEX = {'sapphire': '#3480e4', 'diamond': '#c8d6e4', 'aquamarine': '#28c4b8', 'opal': '#e0a8e0',
          'emerald': '#20a258', 'topaz': '#ecaa1e', 'ruby': '#d4263a', 'amethyst': '#8c4edc',
          'silver': '#b8c3d2', 'malachite': '#1b8f5e', 'asteriated_ruby': '#d4263a'}

def tint(img, gem, amount=0.38, sat=0.32):
    h = GEMHEX[gem].lstrip('#'); gr, gg, gb = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    gh, _, _ = colorsys.rgb_to_hsv(gr, gg, gb)
    a = np.asarray(img.convert('RGBA')).copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b, al = a[y, x]
            if al < 128: continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # slate roof: dark, desaturated, bluish
            if v < .50 and s < .40 and (b >= r):
                ns = s + (sat - s) * amount * 2 if gem not in ('diamond', 'silver') else s
                nh = gh if gem not in ('diamond', 'silver') else hh
                nv = v * (1 + .10 * amount)
                rr, gg2, bb = colorsys.hsv_to_rgb(nh, min(1, ns), min(1, nv))
                a[y, x, :3] = [int(rr * 255), int(gg2 * 255), int(bb * 255)]
    return Image.fromarray(a, 'RGBA')
