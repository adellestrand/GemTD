"""Build an opt-in six-quality profile from reviewed numeric source facts."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def build():
    original = json.loads((ROOT/'data/catalog.json').read_text(encoding='utf8'))
    full = json.loads((ROOT/'data/full_reference.json').read_text(encoding='utf8'))
    abilities = json.loads((ROOT/'.tools/reference/abilities.json').read_text(encoding='utf8'))
    units = json.loads((ROOT/'.tools/reference/units.json').read_text(encoding='utf8'))
    mode = (ROOT/'.tools/reference/mode.lua').read_text(encoding='utf8')
    gems = original['gems']
    effects = original['effects']
    for kind in gems:
        gems[kind]['levels'] = []
        for fact in [t for t in full['base_towers'] if t['kind'] == kind]:
            v = fact['values']
            gems[kind]['levels'].append(dict(source_id=fact['source_id'],damage=v['AttackDamageMin'],
                                            interval=v['AttackRate'],range=v['AttackRange']/128,
                                            source_ability=units[fact['source_id']].get('Ability8','')))
    def linked(kind, tier):
        ability = abilities[gems[kind]['levels'][tier-1]['source_ability']]
        modifiers = ability['Modifiers']
        event = next(m['OnAttackLanded'] for m in modifiers.values() if 'OnAttackLanded' in m)
        return modifiers[event['ApplyModifier']['ModifierName']]

    def prop(kind, tier, name):
        ability = abilities[gems[kind]['levels'][tier-1]['source_ability']]
        return next(float(m['Properties'][name]) for m in ability['Modifiers'].values()
                    if name in m.get('Properties', {}))

    effects['sapphire']['slow'] = [-float(linked('sapphire',t)['Properties']['MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT']) for t in range(1,7)]
    effects['sapphire']['duration'] = [float(linked('sapphire',t)['Duration']) for t in range(1,7)]
    effects['amethyst']['armor_reduction'] = [-float(linked('amethyst',t)['Properties']['MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS']) for t in range(1,7)]
    effects['amethyst']['duration'] = [float(linked('amethyst',t)['Duration']) for t in range(1,7)]
    effects['emerald']['damage'] = [float(linked('emerald',t)['OnIntervalThink']['Damage']['Damage']) for t in range(1,7)]
    effects['emerald']['duration'] = [float(linked('emerald',t)['Duration']) for t in range(1,7)]
    effects['opal']['attack_speed'] = [prop('opal',t,'MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT') for t in range(1,7)]
    effects['aquamarine']['attack_speed'] = [prop('aquamarine',t,'MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT') for t in range(1,7)]
    fractions, radii = [], []
    for t in range(1,7):
        body = mode.split(f'function jianshe{t}(',1)[1].split('\nfunction ',1)[0]
        radius = re.search(r'target:GetAbsOrigin\(\),\s*nil,\s*(\d+)',body)
        damage = re.search(r'local damage = attack_damage(?:\s*\*\s*([\d.]+))?\s*\n',body)
        if not radius or not damage:
            raise ValueError(f'Unrecognized ruby tier {t}')
        radii.append(float(radius[1])/128)
        fractions.append(float(damage[1] or 1))
    effects['ruby'].update(fraction=fractions,radius=radii)
    specials = original['specials']
    jade = full['special_towers']['gemtd_yu']
    values = jade['values']
    specials['jade'] = dict(name='Jade',source_id='gemtd_yu',color='#60d4a0',
                           ingredients=[['emerald',3],['opal',3],['sapphire',2]],
                           damage=values['AttackDamageMin'],interval=values['AttackRate'],
                           range=values['AttackRange']/128,targets='both',
                           effect_kind='emerald',effect_tier=4,
                           effect='Poison: 16 magic damage per second for 10 seconds.')
    payload = dict(version=2,profile='expanded-gems-dev',gems=gems,effects=effects,specials=specials,
                   quality_odds=[o['weights'] for o in full['quality_odds']],
                   quality_costs=[20,45,80,125],
                   balance_note='Development profile: original six-quality tower facts; ten curated waves. '
                   'Gold prices 20/45/80/125 are provisional adaptations, not Dota hero-XP progression. '
                   'Quality VI comes from combinations. Higher-tier art uses replaceable fallback sprites.')
    (ROOT/'data/expanded_gems.json').write_text(json.dumps(payload,indent=2)+'\n',encoding='utf8')
    print('EXPANDED_GEMS_BUILT qualities=6 odds_levels=5 waves=10 (development profile)')


if __name__ == '__main__':
    build()
