"""Refine the AI enemy sheets v2 (presentation only) the same way refine.py made refined-v3.

Input: assets/graphics/generated/enemies-v2a.png, -v2b.png, -v2c.png, each a 4x3 sheet generated
from the prompts in docs/ai-enemy-sheets-v2.md (layout guide: tools/art/ai-reference/).
Output: one clean PNG per enemy in assets/graphics/refined-v4/ (pixel grid reconstructed by
refine.refine_cell). Sheets that are missing are skipped, so they can arrive one at a time.
Usage: python tools/art/refine_v2.py
Next: animate in tools/art/anims/walk.px.js (leg/wing regions) and point the manifest at them.
"""
from pathlib import Path

from refine import refine_sheet

ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / 'assets/graphics/generated'
OUT = ROOT / 'assets/graphics/refined-v4'

# Reading order of each sheet; must match docs/ai-enemy-sheets-v2.md and the reference sheets.
SHEETS = {
    'enemies-v2a': ['stump', 'shroomy', 'shark', 'furry_fish', 'flamingo', 'drodo', 'chicken', 'young_demon',
                    'ripper', 'alpaca', 'sheep', 'rabbit'],
    'enemies-v2b': ['lilnova', 'zombie', 'boooofus', 'jumo', 'lockjaw', 'trapjaw', 'machjaw', 'goldfish',
                    'corsair', 'fox', 'jinyin_fox', 'wabbit'],
    'enemies-v2c': ['panda_flyer', 'mermaid', 'kupu', 'blue_courier', 'shagbark', 'carpet_rider', 'ghost',
                    'baby_roshan', None, None, None, None],
}


# The four bosses again in a 2x2 sheet with larger cells, so they get boss_hound's pixel density
# (about 75 logical pixels wide) instead of the regular enemies' (docs/ai-enemy-sheets-v2.md).
BOSS_SHEET = ('enemies-v2-bosses', 2, 2, ['shagbark', 'carpet_rider', 'ghost', 'baby_roshan'])
BOSS_OUT = OUT / 'bosses'


def main():
    done = 0
    for sheet, names in SHEETS.items():
        path = GENERATED / f'{sheet}.png'
        if not path.exists():
            print(f'skip {sheet}: {path.relative_to(ROOT)} not found')
            continue
        refine_sheet(path, 4, 3, OUT, names)
        done += 1
    sheet, cols, rows, names = BOSS_SHEET
    path = GENERATED / f'{sheet}.png'
    if path.exists():
        refine_sheet(path, cols, rows, BOSS_OUT, names)
        done += 1
    else:
        print(f'skip {sheet}: {path.relative_to(ROOT)} not found')
    print(f'refined {done} of {len(SHEETS) + 1} sheets into {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
