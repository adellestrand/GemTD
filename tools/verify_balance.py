"""Verify reviewed numerical facts and explicit ten-wave overrides without Dota installed."""
from pathlib import Path
import argparse
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[1]


def verify():
    catalog = json.loads((ROOT/'data/catalog.json').read_text(encoding='utf8'))
    baseline = json.loads((ROOT/'data/balance_baseline.json').read_text(encoding='utf8'))
    failures = []
    count = 0

    def equal(label, actual, expected):
        nonlocal count
        count += 1
        same = math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-9) if isinstance(expected, (float, int)) and not isinstance(expected, bool) else actual == expected
        if not same:
            failures.append(dict(field=label, actual=actual, expected=expected))

    equal('reference identity and hashes', catalog['source'], baseline['reference'])
    towers = [level for gem in catalog['gems'].values() for level in gem['levels']]+list(catalog['specials'].values())
    equal('tower count', len(towers), len(baseline['towers']))
    for tower in towers:
        source = tower['source_id']
        original = baseline['towers'][source]
        for field in ('damage', 'interval'):
            equal(source+'.'+field, tower[field], original[field])
        equal(source+'.range', tower['range'], original['world_range']/baseline['units_per_cell'])
        equal(source+'.fixed_damage', original['damage'], original['damage_max'])
    equal('wave count', len(catalog['waves']), 10)
    for index, wave in enumerate(catalog['waves']):
        original = baseline['enemies'][wave['source_id']]
        equal(f'wave {index+1}.hp', wave['hp'], original['world_hp']*baseline['solo_factor'])
        equal(f'wave {index+1}.speed', wave['speed'], original['world_speed']*baseline['solo_factor']/baseline['units_per_cell'])
        equal(f'wave {index+1}.armor', wave['armor'], original['armor'])
        equal(f'wave {index+1}.magic', wave['magic_resist'], original['magic_resist_percent']/100)
        equal(f'wave {index+1}.air', wave['air'], original['air'])
        equal(f'wave {index+1}.ten_wave_overrides', {key:wave[key] for key in baseline['prototype']['waves'][index]}, baseline['prototype']['waves'][index])
    for field in ('effects', 'map', 'quality_odds'):
        equal(field, catalog[field], baseline[field])
    equal('recipe materials', {key:gem['ingredients'] for key,gem in catalog['specials'].items()}, baseline['recipes'])
    equal('compressed-mode quality prices', catalog['quality_costs'], baseline['prototype']['quality_costs'])
    raw_status = 'not installed; reviewed baseline used'
    reference_dir = ROOT/'.tools/reference'
    if all((reference_dir/name).exists() for name in baseline['reference']['file_hashes']):
        raw_status = 'local reference hashes checked'
        for name, expected in baseline['reference']['file_hashes'].items():
            equal('local reference '+name, hashlib.sha256((reference_dir/name).read_bytes()).hexdigest(), expected)
    return dict(schema=1, checks=count, failures=failures, reference=baseline['reference'],
                local_reference=raw_status, catalog_sha256=hashlib.sha256((ROOT/'data/catalog.json').read_bytes()).hexdigest(),
                profile='dota-solo-10w-v1', prototype_overrides=baseline['prototype'],
                reference_economy=baseline['reference_economy'], notes=baseline['notes'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--report', default='output/balance-reference-check.json')
    args = parser.parse_args()
    result = verify()
    output = ROOT/args.report
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf8')
    print(f"BALANCE_REFERENCE_OK checks={result['checks']} failures={len(result['failures'])}")
    for failure in result['failures']:
        print(failure)
    raise SystemExit(bool(result['failures']))
