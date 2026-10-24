"""Compare installed GemTD facts with our frozen source, without executing Lua.

Pass the Workshop VPK path explicitly. Keeps both source snapshots unchanged.
The report covers content definitions, not Dota engine behavior.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from build_full_reference import table, unit_facts
from inspect_reference import entries
from reference_data import parse_kv

ROOT = Path(__file__).resolve().parents[1]


def read_entry(path, name):
    entry = next(e for e in entries(path) if e[0] == name)
    _, archive, offset, size, preload = entry
    if archive != 32767:
        raise ValueError('External VPK archive is unsupported')
    with path.open('rb') as source:
        source.seek(offset)
        return preload + source.read(size)


def clean_lua(text):
    return re.sub(r'--[^\n]*', '', re.sub(r'--\[\[.*?\]\]', '', text, flags=re.S))


def audit(vpk):
    raw = {
        'mode.lua': read_entry(vpk, 'scripts/vscripts/addon_game_mode.lua'),
        'units.txt': read_entry(vpk, 'scripts/npc/npc_units_custom.txt'),
        'abilities.txt': read_entry(vpk, 'scripts/npc/npc_abilities_custom.txt'),
    }
    current = clean_lua(raw['mode.lua'].decode('utf-8-sig'))
    old = clean_lua((ROOT/'.tools/reference/mode.lua').read_text(encoding='utf8'))
    units = next(iter(parse_kv(raw['units.txt'].decode('utf-8-sig')).values()))
    abilities = next(iter(parse_kv(raw['abilities.txt'].decode('utf-8-sig')).values()))
    reference = json.loads((ROOT/'data/full_reference.json').read_text(encoding='utf8'))
    campaign = json.loads((ROOT/'data/campaign.json').read_text(encoding='utf8'))
    tables = {}
    for key in ['guai', 'guai_ability', 'guai_50_ability', 'gemtd_merge', 'gemtd_merge_secret',
                'gemtd_merge_shiban', 'gemtd_merge_shiban_update', 'gem_gailv', 'stealable_ability_pool']:
        tables[key] = re.sub(r'\s+', '', table(current, key)) == re.sub(r'\s+', '', table(old, key))
    facts = reference['base_towers'] + list(reference['special_towers'].values())
    for wave in reference['waves']:
        facts.append(wave)
        facts.extend(wave['variants'])
    facts.extend(reference['alternate_waves'])
    fields = ['values', 'abilities', 'movement', 'attack_capabilities', 'combat_class',
              'combat_class_defend', 'ancient']
    changed_units = []
    for fact in facts:
        key = fact['source_id']
        if key not in units:
            changed_units.append({'unit': key, 'missing': True})
            continue
        actual = unit_facts(key, units)
        changed = [field for field in fields if actual[field] != fact[field]]
        if changed:
            changed_units.append({'unit': key, 'changed_fields': changed})
    old_abilities = json.loads((ROOT/'.tools/reference/abilities.json').read_text(encoding='utf8'))
    relevant = sorted(set(campaign['ability_effects']) | {'enemy_crazy', 'gemtd_downgrade_stone'})
    changed_abilities = [key for key in relevant if abilities.get(key) != old_abilities.get(key)]
    pool = re.findall(r'"([^"]+)"', table(current, 'stealable_ability_pool'))
    # Current implementation uses every non-e-prefixed ability on nearby donors.
    donor_ids = set()
    for definition in list(campaign['specials'].values()) + [level for gem in campaign['gems'].values() for level in gem['levels']]:
        if definition.get('slab', False):
            continue
        donor_ids.update(key for key in definition.get('abilities', []) if not key.startswith('e'))
    return {
        'installed_source_sha256': {key: hashlib.sha256(value).hexdigest() for key, value in raw.items()},
        'baseline_reference_date': reference['reference_date'],
        'tables_unchanged': tables,
        'unit_definitions_checked': len(facts), 'changed_units': changed_units,
        'ability_definitions_checked': len(relevant), 'changed_abilities': changed_abilities,
        'natural_emerald_pool': {'source_count': len(pool), 'source_not_in_current_donors': sorted(set(pool)-donor_ids),
                                'current_donor_ids_outside_source_allowlist': sorted(donor_ids-set(pool))},
        'limits': 'Static source comparison. Does not verify live Dota engine order, external native modifiers, runtime server data or human balance.',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('vpk', type=Path)
    args = parser.parse_args()
    result = audit(args.vpk)
    target = ROOT/'docs/reports/mechanics-audit-reference.json'
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n', encoding='utf8')
    print(json.dumps(result, indent=2, ensure_ascii=True))
