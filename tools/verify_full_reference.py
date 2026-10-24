"""Portable integrity checks for the full-content staging library."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[1]


def verify():
    data = json.loads((ROOT/'data/full_reference.json').read_text(encoding='utf8'))
    checks = 0
    errors = []

    def check(ok, message):
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(message)

    check(data['schema'] == 1, 'schema')
    for key,row in data['random_events'].items():
        check(0 < row['chance'] < 1 and row['model']=='pseudo_random','explicit PRD event '+key)
        raw_abilities=ROOT/'.tools/reference/abilities.json'
        if raw_abilities.exists():
            raw=json.loads(raw_abilities.read_text(encoding='utf8'))
            rolls=[m[row['event']]['Random'] for m in raw[key]['Modifiers'].values() if row['event'] in m]
            check(any(r.get('PseudoRandom')==key and float(r['Chance'])/100==row['chance'] for r in rolls),'raw PRD declaration '+key)
    check(data['implementation_status'] == 'staging-not-active-gameplay', 'staging status')
    check(len(data['base_towers']) == 48, '48 basic gems')
    kinds = Counter(t['kind'] for t in data['base_towers'])
    check(len(kinds) == 8 and set(kinds.values()) == {6}, 'six qualities per kind')
    towers = {t['source_id']: t for t in data['base_towers']}
    towers.update(data['special_towers'])
    check(len(towers) == 115, '115 distinct tower units')
    for key, tower in towers.items():
        check(key == tower['source_id'], f'unit identity {key}')
        for name, value in tower['values'].items():
            check(math.isfinite(value), f'finite {key}.{name}')
    waves = data['waves']
    check([w['index'] for w in waves] == list(range(1, 51)), 'contiguous base waves')
    check([w['index'] for w in waves if w['boss']] == [10, 20, 30, 40, 50], 'boss order')
    check(waves[7]['source_id'] == 'gemtd_mengzhu', 'original wave eight, not curated flying replacement')
    check(waves[19]['source_id'] == 'gemtd_huxiaotao_boss', 'ignore commented old boss')
    check(waves[29]['source_id'] == 'gemtd_mofafeitanxiaoemo_boss_fly', 'wave 30 current assignment')
    for wave in waves:
        check(wave['values']['StatusHealth'] > 0, f'positive hp wave {wave["index"]}')
        check(wave['values']['MovementSpeed'] > 0, f'positive speed wave {wave["index"]}')
        check(wave['air'] == ('FLY' in wave['movement']), f'air wave {wave["index"]}')
        check(bool(wave['variants']) == (wave['index'] in (35, 36, 38)), f'variants wave {wave["index"]}')
    recipes = data['recipes']
    check(Counter(r['family'] for r in recipes) == dict(standard=38, secret=13, slab=8), 'recipe families')
    check(len({r['id'] for r in recipes}) == len(recipes), 'unique recipe IDs including alternatives')
    # A dependency cycle would make a recipe family unreachable. Alternatives
    # for the same result are retained as separate recipes, not overwritten.
    reachable = {t['source_id'] for t in data['base_towers']}
    pending = recipes.copy()
    while pending:
        ready = [r for r in pending if set(r['ingredients']) <= reachable]
        if not ready:
            break
        for recipe in ready:
            reachable.add(recipe['result'])
            pending.remove(recipe)
    check(not pending, 'all recipe alternatives reachable without circular materials')
    for recipe in recipes:
        check(recipe['result'] in towers, 'known result '+recipe['id'])
        check(set(recipe['ingredients']) <= towers.keys(), 'known ingredients '+recipe['id'])
        check(recipe['effect_status'] == 'pending', 'unimplemented effects explicit '+recipe['id'])
    check(len(data['slab_upgrades']) == 16, '16 slab upgrade transitions')
    for row in data['slab_upgrades']:
        check(row['source'] in towers and row['result'] in towers, 'slab references '+row['source'])
        check(row['mechanic_status'] == 'pending', 'no invented free slab upgrade')
    check([o['weights'] for o in data['quality_odds']] ==
          [[100,0,0,0,0,0], [80,20,0,0,0,0], [60,30,10,0,0,0],
           [40,30,20,10,0,0], [10,30,30,20,10,0]], 'exact source roll boundaries; VI from upgrades')
    check(data['progression']['base_waves'] + data['progression']['trial_waves'] == 100, 'full progression')
    # Compare raw numeric facts independently when the optional local source is
    # available. The committed library remains usable without Dota installed.
    raw_path = ROOT/'.tools/reference/units.json'
    if raw_path.exists():
        raw = json.loads(raw_path.read_text(encoding='utf8'))
        facts = list(towers.values()) + waves + data['alternate_waves']
        facts += [variant for w in waves for variant in w['variants']]
        for fact in facts:
            for field, value in fact['values'].items():
                check(float(raw[fact['source_id']][field]) == value, 'source value '+fact['source_id']+'.'+field)
    for name, sha in data['source_hashes'].items():
        path = ROOT/'.tools/reference'/name
        if path.exists():
            check(hashlib.sha256(path.read_bytes()).hexdigest() == sha, 'source hash '+name)
    return dict(checks=checks, failures=len(errors), errors=errors,
                playable_content='1.0 review profile unchanged; the derived solo campaign is verified separately')


if __name__ == '__main__':
    result = verify()
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(result['failures']))
