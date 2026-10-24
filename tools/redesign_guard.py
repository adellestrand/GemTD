"""Grafikomdesignens vakt: röd zon får inte ändras.

Röd zon = spelregler, innehållsdata, byggskript för data, verifierings- och regeltester.
  python tools/redesign_guard.py --baseline   # spara kontrollsummor (görs en gång, före omdesignen)
  python tools/redesign_guard.py              # jämför; exit 1 om något i röd zon ändrats/tagits bort
Nya testfiler under tests/ är tillåtna; ändrade eller borttagna befintliga är det inte.
Baslinjen sparas i output/redesign/red-zone-baseline.json (gitignorerad, ingen commit behövs).
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'output/redesign/red-zone-baseline.json'
PATTERNS = ['game/core/**/*', 'data/**/*', 'tools/build_*.py', 'tools/verify_*.py',
            'tools/reference_data.py', 'tools/replay_review.gd', 'tests/*.gd']

def snapshot():
    files = {}
    for pattern in PATTERNS:
        for path in ROOT.glob(pattern):
            if path.is_file():
                rel = path.relative_to(ROOT).as_posix()
                files[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    return dict(sorted(files.items()))

if __name__ == '__main__':
    current = snapshot()
    if '--baseline' in sys.argv:
        BASELINE.parent.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(json.dumps(current, indent=1) + '\n', encoding='utf8')
        print(f'RED_ZONE_BASELINE_SAVED files={len(current)}')
        raise SystemExit(0)
    base = json.loads(BASELINE.read_text(encoding='utf8'))
    changed = [f for f in base if f in current and current[f] != base[f]]
    removed = [f for f in base if f not in current]
    added = [f for f in current if f not in base]
    bad_added = [f for f in added if not f.startswith('tests/')]
    for f in changed: print('CHANGED', f)
    for f in removed: print('REMOVED', f)
    for f in bad_added: print('ADDED', f)
    for f in added:
        if f.startswith('tests/'): print('new test (allowed)', f)
    ok = not (changed or removed or bad_added)
    print(('RED_ZONE_OK' if ok else 'RED_ZONE_VIOLATION') + f' files={len(base)}')
    raise SystemExit(0 if ok else 1)
