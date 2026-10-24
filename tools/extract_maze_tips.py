"""Hämtar Dota 2-GemTD:s labyrintförslag (maze guide) till presentationslagret.

Källa: .tools/reference/mode.lua (lokal, git-ignorerad), tabellerna _G.maze_coop1..8.
Matrisrad i (1..37) och kolumn j (1..37) motsvarar världspunkten
x = (j-19)*128, y = (19-i)*128 (click_maze_guide_coop). Med spelets nollbaserade
rutnät och speglade Y-led blir det cell (j-1, i-1) – inga förslag hamnar på checkpoints.

Egen anpassning: där vår motor (inga diagonala hörnpassager, 32 startstenar) blockerar
vägen med förslaget räknas det minsta antal startstenar fram som måste rivas.

  python tools/extract_maze_tips.py   # skriver game/presentation/maze_tip_layouts.gd
"""
from pathlib import Path
import heapq, json, re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / '.tools/reference/mode.lua'
OUTPUT = ROOT / 'game/presentation/maze_tip_layouts.gd'
SIZE = 37

def layouts():
    text = SOURCE.read_text(encoding='utf8', errors='replace')
    found = {}
    for match in re.finditer(r'^\t_G\.maze_coop(\d)\s*=\s*\{(.*?)\n\t\}', text, re.S | re.M):
        rows = [[int(v) for v in row.split(',') if v.strip()] for row in re.findall(r'\{([0-9,\s]+)\}', match.group(2))]
        assert len(rows) == SIZE and all(len(r) == SIZE for r in rows), match.group(1)
        found[int(match.group(1))] = rows
    return found

def leg(a, b, solid):
    best = {a: 0.0}
    queue = [(0.0, a)]
    while queue:
        cost, p = heapq.heappop(queue)
        if p == b:
            return cost
        if cost > best[p]:
            continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (p[0]+dx, p[1]+dy)
                if (dx, dy) == (0, 0) or not (0 <= q[0] < SIZE and 0 <= q[1] < SIZE) or q in solid:
                    continue
                # Som GemBoard: diagonalt bara om båda grannarna är fria.
                if dx and dy and ((p[0]+dx, p[1]) in solid or (p[0], p[1]+dy) in solid):
                    continue
                step = cost + (1.4142 if dx and dy else 1.0)
                if step < best.get(q, 1e9):
                    best[q] = step
                    heapq.heappush(queue, (step, q))
    return None

def open_route(checkpoints, solid):
    return all(leg(checkpoints[i], checkpoints[i+1], solid) is not None for i in range(len(checkpoints)-1))

def main():
    catalog = json.loads((ROOT / 'data/catalog.json').read_text(encoding='utf8'))
    checkpoints = [tuple(p) for p in catalog['map']['checkpoints']]
    stones = {tuple(p) for p in catalog['map']['stones']}
    lines = ['# Genererad av tools/extract_maze_tips.py – ändra inte för hand.',
             '# Källa: Dota 2 GemTD mode.lua, _G.maze_coop1..8 (37×37, rad = y, kolumn = x).',
             '# "#" = föreslagen ruta. "remove" = startstenar som måste rivas i den här motorn (egen anpassning).',
             'const LAYOUTS = {']
    for number, rows in sorted(layouts().items()):
        cells = {(x, y) for y in range(SIZE) for x in range(SIZE) if rows[y][x]}
        if not cells:
            continue
        assert not cells & set(checkpoints), number
        remove = []
        if not open_route(checkpoints, stones | cells):
            keep = set()
            for stone in sorted(stones - cells):
                if open_route(checkpoints, cells | keep | {stone}):
                    keep.add(stone)
            remove = sorted(stones - cells - keep)
            assert open_route(checkpoints, (stones - set(remove)) | cells), number
        lines.append('\t"maze_coop%d": {' % number)
        lines.append('\t\t"rows": [')
        lines += ['\t\t\t"%s",' % ''.join('#' if v else '.' for v in row) for row in rows]
        lines.append('\t\t],')
        lines.append('\t\t"remove": [%s],' % ','.join('[%d,%d]' % p for p in remove))
        lines.append('\t},')
    lines.append('}')
    OUTPUT.write_text('\n'.join(lines) + '\n', encoding='utf8', newline='\n')
    print('MAZE_TIPS_WRITTEN', OUTPUT.relative_to(ROOT).as_posix())

if __name__ == '__main__':
    main()
