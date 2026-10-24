"""Build enemy animation strips from pxl sources (presentation only).

For every entry in ANIMS: convert the approved refined-v3 sprite into a pxl part
(tools/art/png2pxl.py), render tools/art/anims/walk.px.js with pxl (claude-pxl skill),
copy the horizontal strip to assets/graphics/refined-v3/anims/<source>_<suffix>.png and
recolour the same strip for every variant of that source (tools/art/variants.py). Then render
the natively drawn bodies in tools/art/anims/creatures.px.js and copy them as <anim>_v2.png.
Previews (upscaled PNG + GIF) land in output/pxl/ (git-ignored).
Usage: python tools/art/build_anims.py   (all walk cycles live in tools/art/anims/walk.px.js)
Afterwards: python tools/godot.py --headless --editor --path . --import
pxl is looked up in .claude/skills/pxl-pixel-art (override with the PXL environment variable).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

import png2pxl
import variants

ROOT = Path(__file__).resolve().parents[2]
REFINED = ROOT / 'assets/graphics/refined-v3'
OUT = REFINED / 'anims'
REFINED_V4 = ROOT / 'assets/graphics/refined-v4'
SOURCES = Path(__file__).resolve().parent / 'anims'
PREVIEW = ROOT / 'output/pxl'
PXL = Path(os.environ.get('PXL', ROOT / '.claude/skills/pxl-pixel-art/bin/pxl.js'))

SCRIPT = SOURCES / 'walk.px.js'
# source sprite: (anim name in SCRIPT, strip suffix, frame count)
ANIMS = {
    'boar': ('boar_walk', 'walk_v1', 4),
    'yak': ('yak_walk', 'walk_v1', 4),
    'hound': ('hound_walk', 'walk_v1', 4),
    'lizard': ('lizard_walk', 'walk_v1', 4),
    'frog': ('frog_walk', 'walk_v1', 4),
    'spider': ('spider_walk', 'walk_v1', 4),
    'robot': ('robot_walk', 'walk_v1', 4),
    'boss_hound': ('boss_hound_walk', 'walk_v1', 4),
    'bat': ('bat_flap', 'flap_v1', 4),
    'griffin': ('griffin_flap', 'flap_v1', 4),
}

# Bodies drawn natively in pxl (tools/art/anims/creatures.px.js, docs/enemy-silhouettes.md):
# every anim there is copied as <anim>_v2.png (v1 strips of the same enemies stay untouched).
CREATURES = SOURCES / 'creatures.px.js'


def main():
    if not PXL.exists():
        print(f'pxl not found at {PXL}; clone https://github.com/crsolver/claude-pxl there or set PXL')
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    for source in ANIMS:
        _, _, rows = png2pxl.read_png(REFINED / f'{source}.png')
        part = SOURCES / f'{source}_part.px.js'
        part.write_text(png2pxl.to_pxl(rows, source, part=True), encoding='utf-8', newline='\n')
    # refined-v4 bodies (AI sheets v2) are animated in the same SCRIPT as "<id>_<walk|flap>_v4".
    for src in sorted(REFINED_V4.glob('*.png')):
        _, _, rows = png2pxl.read_png(src)
        part = SOURCES / f'v4_{src.stem}_part.px.js'
        part.write_text(png2pxl.to_pxl(rows, f'v4_{src.stem}', part=True), encoding='utf-8', newline='\n')
    target = PREVIEW / 'walk'
    subprocess.run(['node', str(PXL), 'build', str(SCRIPT), '--out', str(target)], check=True)
    for source, (anim, suffix, frames) in ANIMS.items():
        strip = Image.open(target / 'anims' / f'{anim}.png')
        if strip.width % frames:
            raise ValueError(f'{anim}: strip width {strip.width} is not {frames} equal frames')
        dest = OUT / f'{source}_{suffix}.png'
        shutil.copyfile(target / 'anims' / f'{anim}.png', dest)
        print(f'{source}: {frames} frames -> {dest.relative_to(ROOT)}')
    made = variants.build_strips(OUT, {s: (a[1], a[2]) for s, a in ANIMS.items()})
    for name, img in made.items():
        print(f'  variant {name}: {img.width}x{img.height}')
    # refined-v4 strips are copied as <id>_<walk|flap>_v3.png; the pxl-drawn _v2 strips stay as a fallback.
    for strip in sorted((target / 'anims').glob('*_v4.png')):
        if Image.open(strip).width % 4:
            raise ValueError(f'{strip.stem}: strip width is not 4 equal frames')
        dest = OUT / f'{strip.stem[:-3]}_v3.png'
        shutil.copyfile(strip, dest)
        print(f'refined-v4 {strip.stem}: 4 frames -> {dest.relative_to(ROOT)}')
    target = PREVIEW / 'creatures'
    subprocess.run(['node', str(PXL), 'build', str(CREATURES), '--out', str(target)], check=True)
    for strip in sorted((target / 'anims').glob('*.png')):
        if Image.open(strip).width % 4:
            raise ValueError(f'{strip.stem}: strip width is not 4 equal frames')
        dest = OUT / f'{strip.stem}_v2.png'
        shutil.copyfile(strip, dest)
        print(f'creature {strip.stem}: 4 frames -> {dest.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
