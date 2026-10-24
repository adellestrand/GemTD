"""Import the four original combination-tower atlases; presentation only.

Uses the established refine.py pixel-grid importer. Keeps source atlases,
individual PNGs, source-model inspiration and previous bindings for easy edits
and rollback. No campaign or combat data is written.
Usage: python tools/art/import_specials_v1.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np
from refine import refine_cell

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/graphics/specials-v1'
GENERATED = ROOT / 'assets/graphics/generated'


def occupied_runs(values, minimum):
    runs = []
    start = None
    for i, occupied in enumerate(list(values) + [False]):
        if occupied and start is None:
            start = i
        elif not occupied and start is not None:
            if i-start >= minimum:
                runs.append((start, i))
            start = None
    return runs


def main():
    campaign = json.loads((ROOT / 'data/campaign.json').read_text(encoding='utf8'))
    manifest_path = ROOT / 'assets/graphics/manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf8'))
    kinds = [k for k, v in campaign['specials'].items() if not v.get('slab')]
    assert len(kinds) == 43, 'Review atlas order when the tower catalogue changes'
    report_path = OUT / 'catalogue.json'
    previous = json.loads(report_path.read_text(encoding='utf8')) if report_path.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    preview = Image.new('RGB', (1120, 7 * 210), '#172521')
    draw = ImageDraw.Draw(preview)
    for sheet_index in range(4):
        sheet = Image.open(GENERATED / f'specials-v1-{sheet_index+1}.png').convert('RGBA')
        alpha = np.array(sheet.getchannel('A')) > 128
        # Generated sheets can have unequal outer gutters. Use actual transparent
        # row gaps, rather than cutting a crystal tip at an assumed 1/3 boundary.
        rows = occupied_runs(alpha.any(axis=1), 60)
        assert len(rows) >= (2 if sheet_index == 3 else 3), (sheet_index, rows)
        for local_index in range(12):
            index = sheet_index * 12 + local_index
            if index >= len(kinds):
                break
            kind = kinds[index]
            col, row = local_index % 4, local_index // 4
            y0, y1 = rows[row]
            columns = occupied_runs(alpha[y0:y1].any(axis=0), 50)
            assert len(columns) == (3 if sheet_index == 3 and row == 1 else 4), (sheet_index, row, columns)
            x0, x1 = columns[col]
            box = (x0, y0, x1, y1)
            # Same median-block reconstruction as refined-v3; 60-75 art px tall.
            sprite, grid = refine_cell(sheet.crop(box), k=6.0)
            assert sprite.getbbox(), f'Empty cell for {kind}'
            sprite.save(OUT / f'{kind}.png')
            old = previous.get(kind, {}).get('previous_binding', manifest['bindings']['gems'][kind])
            sprite_id = f'special_v1_{kind}'
            original_id = old.get('default', next(iter(old.values())))
            entry = manifest['sprites'][original_id]
            manifest['sprites'][sprite_id] = {
                'texture': f'res://assets/graphics/specials-v1/{kind}.png',
                'trim_alpha': True, 'size': [0.94, 0.94], 'anchor': [0.5, 0.5],
                'effect_color': entry.get('effect_color', '#edce7a'),
            }
            manifest['bindings']['gems'][kind] = {'default': sprite_id}
            report[kind] = {'name': campaign['specials'][kind]['name'],
                            'source_id': campaign['specials'][kind]['source_id'],
                            'sheet': sheet_index+1, 'cell': local_index,
                            'source_box': list(box),
                            'previous_binding': old, 'pixels': list(sprite.size),
                            'grid': [float(v) for v in grid]}
            x, y = index % 7 * 160, index // 7 * 210
            scale = min(125/sprite.width, 125/sprite.height)
            large = sprite.resize((round(sprite.width*scale), round(sprite.height*scale)), Image.Resampling.NEAREST)
            preview.paste(large, (x+(160-large.width)//2, y+4), large)
            draw.text((x+4, y+132), campaign['specials'][kind]['name'][:25], fill='#e9dfba')
            for j, unit in enumerate((15, 32, 45)):
                cx, cy = x+8+j*49, y+151
                draw.rectangle((cx,cy,cx+unit,cy+unit), outline='#627961')
                factor = unit*0.94/max(sprite.size)
                small = sprite.resize((max(1,round(sprite.width*factor)),max(1,round(sprite.height*factor))), Image.Resampling.NEAREST)
                preview.paste(small,(cx+(unit-small.width)//2,cy+(unit-small.height)//2),small)
    # Preserve LF and existing unrelated manifest entries.
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    (ROOT / 'output').mkdir(exist_ok=True)
    preview.save(ROOT / 'output/special-towers-v1-review.png')
    print(f'SPECIAL_TOWERS_IMPORTED count={len(report)}')


if __name__ == '__main__':
    main()
