"""Extract full solo content facts without evaluating or copying reference Lua.

This builds a staging library, not the active ten-wave balance profile. Unsupported
effects remain explicit, so new units cannot silently masquerade as finished towers.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / '.tools/reference'
CODES = dict(zip('bdqegyrp', ('sapphire', 'diamond', 'aquamarine', 'opal',
                            'emerald', 'topaz', 'ruby', 'amethyst')))


def table(text, name):
    # All imported tables are literal maps/lists. Only scan the named balanced
    # braces; never evaluate Lua, import functions, or inspect runtime globals.
    match = re.search(r'_G\.' + re.escape(name) + r'\s*=\s*\{', text)
    if not match:
        raise ValueError(f'Missing table {name}')
    start = match.end()
    depth = 1
    for end in range(start, len(text)):
        depth += (text[end] == '{') - (text[end] == '}')
        if depth == 0:
            return text[start:end]
    raise ValueError(f'Unclosed table {name}')


def unit_facts(key, units):
    u = units[key]
    fields = ('AttackDamageMin', 'AttackDamageMax', 'AttackRate', 'AttackRange', 'ProjectileSpeed', 'AttackAnimationPoint',
              'StatusHealth', 'MovementSpeed', 'ArmorPhysical', 'MagicalResistance')
    return dict(source_id=key, values={f: float(u[f]) for f in fields if f in u},
                abilities=[u[f] for f in sorted(u) if re.fullmatch(r'Ability\d+', f) and u[f]],
                movement=u.get('MovementCapabilities', ''),
                attack_capabilities=u.get('AttackCapabilities', ''),
                combat_class=u.get('CombatClassAttack', ''),
                combat_class_defend=u.get('CombatClassDefend', ''),
                ancient=u.get('IsAncient', '0') == '1')


def build():
    # Strip comments first: commented historical bosses must not overwrite the
    # actual wave 20/30/40 assignments. These source tables contain no braces
    # inside strings; reject duplicate keys rather than guessing their meaning.
    source = (REF / 'mode.lua').read_text(encoding='utf8')
    text = re.sub(r'--\[\[.*?\]\]', '', source, flags=re.S)
    text = re.sub(r'--[^\n]*', '', text)
    units = json.loads((REF / 'units.json').read_text(encoding='utf8'))
    wave_map = {}
    for number, key in re.findall(r'\[(\d+)\]\s*=\s*"([^"]+)"', table(text, 'guai')):
        if int(number) in wave_map:
            raise ValueError(f'Duplicate wave {number}')
        wave_map[int(number)] = key
    wave_abilities = {int(n): re.findall(r'"([^"]+)"', values)
                      for n, values in re.findall(r'\[(\d+)\]\s*=\s*\{([^{}]*)\}', table(text, 'guai_ability'))}
    waves = []
    for n in range(1, 51):
        key = wave_map[n]
        wave = dict(index=n, **unit_facts(key, units), boss='boss' in key,
                    air='FLY' in units[key].get('MovementCapabilities', ''),
                    added_abilities=wave_abilities[n],
                    variants=[unit_facts(key+'1', units)] if n in (35, 36, 38) else [])
        waves.append(wave)
    towers = [dict(kind=kind, tier=tier, **unit_facts('gemtd_'+code+'1'*tier, units))
              for code, kind in CODES.items() for tier in range(1, 7)]
    recipes = []
    for family, name in [('standard', 'gemtd_merge'), ('secret', 'gemtd_merge_secret'),
                         ('slab', 'gemtd_merge_shiban')]:
        for result, ingredients in re.findall(r'(gemtd_\w+)\s*=\s*\{([^{}]*)\}', table(text, name)):
            ingredients = re.findall(r'"(gemtd_\w+)"', ingredients)
            if not ingredients:
                raise ValueError(f'Empty recipe {result}')
            recipes.append(dict(id=family+':'+result, family=family, result=result,
                                ingredients=ingredients, effect_status='pending'))
    # Slab upgrade is a distinct mechanic in the source; a target mapping is
    # not evidence for an ordinary two/four-gem recipe or a free upgrade.
    upgrades = [dict(source=a, result=b, mechanic_status='pending') for a, b in
                re.findall(r'(gemtd_\w+)\s*=\s*"(gemtd_\w+)"', table(text, 'gemtd_merge_shiban_update'))]
    results = sorted({r['result'] for r in recipes} | {r['result'] for r in upgrades})
    specials = {key: unit_facts(key, units) for key in results}
    slab_abilities = dict(re.findall(r'(gemtd_\w+)\s*=\s*"([^"]+)"', table(text, 'shiban_ability_list')))
    for key, ability in slab_abilities.items():
        if key in specials:
            specials[key]['activated_ability'] = ability
    all_towers = {t['source_id'] for t in towers} | set(specials)
    for recipe in recipes:
        if not set(recipe['ingredients']) <= all_towers:
            raise ValueError(f'Unresolved ingredient: {recipe}')
    quality_odds = []
    for level, values in re.findall(r'\[(\d+)\]\s*=\s*\{([^{}]*)\}', table(text, 'gem_gailv')):
        thresholds = sorted((int(n), len(tier)) for n, tier in re.findall(r'\[(\d+)\]\s*=\s*"(1+)"', values))
        counts = [0] * 6
        for roll in range(1, 101):
            tier = 1
            for threshold, result in thresholds:
                if roll > threshold:
                    tier = result
            counts[tier-1] += 1
        quality_odds.append(dict(level=int(level), weights=counts))
    abilities=json.loads((REF/'abilities.json').read_text(encoding='utf8'))
    random_events={}
    for key in ['tower_baoji1','tower_aojiao','enemy_bukeqinfan']:
        for modifier in abilities[key]['Modifiers'].values():
            for event in ['OnAttackStart','OnAttacked']:
                roll=modifier.get(event,{}).get('Random',{})
                if roll.get('PseudoRandom') == key:
                    random_events[key]=dict(chance=float(roll['Chance'])/100,event=event,
                                            owner='defender' if event=='OnAttacked' else 'attacker',
                                            model='pseudo_random',source_id=key)
        if key not in random_events:raise ValueError('Missing explicit PseudoRandom source '+key)
    result = dict(schema=1, reference_date='2026-08-01',
                  source_hashes={f: hashlib.sha256((REF/f).read_bytes()).hexdigest()
                                 for f in ('mode.lua', 'units.txt', 'abilities.txt')},
                  implementation_status='staging-not-active-gameplay',
                  progression=dict(base_waves=50, trial_waves=50, trial_base_offset=50,
                                   trials_random_abilities=2, solo_hp_multiplier=.69,
                                   solo_speed_multiplier=.69, source_starting_lives=100,
                                   source_default_wave_count=10,
                                   trial_ability_pool=re.findall(r'"([^"]+)"', table(text, 'guai_50_ability'))),
                  base_towers=towers, special_towers=specials, recipes=recipes, random_events=random_events,
                  slab_upgrades=upgrades, quality_odds=quality_odds, waves=waves,
                  alternate_waves=[dict(index=n, **unit_facts(key, units))
                                   for n, key in sorted(wave_map.items()) if n > 100])
    target = ROOT / 'data/full_reference.json'
    target.write_text(json.dumps(result, indent=2, ensure_ascii=False)+'\n', encoding='utf8')
    print(f'FULL_REFERENCE_BUILT basic={len(towers)} specials={len(specials)} recipes={len(recipes)} '
          f'slab_upgrades={len(upgrades)} base_waves={len(waves)} trials=50')


if __name__ == '__main__':
    build()
