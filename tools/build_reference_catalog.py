"""Extract numerical facts from a user's local reference; never run or redistribute Lua.

Requires ignored .tools/reference/{units,abilities}.json and mode.lua from inspect_reference.py.
The generated catalog is checked in, so development does not require Dota or Steam.
"""
from pathlib import Path
import hashlib
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / '.tools/reference'
units = json.loads((REF / 'units.json').read_text(encoding='utf8'))
mode = (REF / 'mode.lua').read_text(encoding='utf8')
definitions = [
    ('sapphire', 'b', '#62c8ff', 'Slow: -60 / -90 / -120 world units/s for 3 seconds.'),
    ('diamond', 'd', '#e1edf7', 'High physical attack damage.'),
    ('aquamarine', 'q', '#5bf0d4', 'Rapid attacks: +200 attack speed.'),
    ('opal', 'e', '#f2afdc', 'Nearby towers: +20 / +30 / +40 attack speed. Different quality auras stack; identical quality does not.'),
    ('emerald', 'g', '#83d46a', 'Poison: 2 / 4 / 8 magic damage per second for 10 seconds.'),
    ('topaz', 'y', '#f4ce65', 'Primary attack plus up to three nearest secondary targets. Secondary hits bypass evasion.'),
    ('ruby', 'r', '#f1757b', 'Pure splash: 30% / 40% / 50% in radius 300 / 350 / 400.'),
    ('amethyst', 'p', '#b79afa', 'Armor reduction: -2 / -4 / -8 for 3 seconds.'),
]
gems = {}
for name, code, color, effect in definitions:
    levels = []
    for tier in range(1, 4):
        key = 'gemtd_' + code + '1' * tier
        u = units[key]
        levels.append(dict(source_id=key, damage=float(u['AttackDamageMin']),
                           interval=float(u['AttackRate']), range=float(u['AttackRange']) / 128,
                           source_ability=u.get('Ability8', '')))
    gems[name] = dict(name=name.title(), color=color, effect=effect, levels=levels,
                      targets='ground' if name in ('diamond', 'ruby') else 'both')
specials = {}
for key, source, title, color, ingredients, effect in [
    ('silver', 'gemtd_baiyin', 'Silver', '#c5e4e7', [['sapphire', 1], ['topaz', 1], ['diamond', 1]], 'Physical attack; -90 movement speed for 3 seconds.'),
    ('malachite', 'gemtd_kongqueshi', 'Malachite', '#86e1a7', [['opal', 1], ['aquamarine', 1], ['emerald', 1]], 'Primary attack plus up to three nearest secondary targets. Secondary hits bypass evasion.'),
    ('asteriated_ruby', 'gemtd_xingcaihongbaoshi', 'Asteriated Ruby', '#ff9ab1', [['ruby', 2], ['ruby', 1], ['amethyst', 1]], 'Burning aura: 20 magic damage every 0.25 seconds in radius 500.'),
]:
    u = units[source]
    specials[key] = dict(name=title, source_id=source, color=color, ingredients=ingredients,
                         damage=float(u['AttackDamageMin']), interval=float(u['AttackRate']),
                         range=float(u['AttackRange']) / 128, effect=effect, targets='both')
stones_text = mode.split('_G.default_stone = {', 1)[1].split('\n\t\t[2] = {', 1)[0]
stones = [[int(x)-1, 37-int(y)] for x, y in re.findall(r'x = (\d+), y = (\d+)', stones_text)]
entities = (REF / 'entities.txt').read_text(encoding='utf-8-sig')
checkpoints = []
for i in range(1, 8):
    section = entities.split(f'"[PR#]path{i}"', 1)[1][:1000]
    coordinates = re.search(r'origin\s*=\s*"([^"]+)"', section).group(1)
    x, y, _ = map(float, coordinates.split())
    checkpoints.append([math.floor((x+64)/128)+18, 36-(math.floor((y+64)/128)+18)])
waves = []
for index, (source, name, count, leak) in enumerate([
    ('gemtd_kuangbaoyezhu', 'Wild boars', 8, 1),
    ('gemtd_kuaidiqingwatiaotiao', 'Courier frogs', 10, 1),
    ('gemtd_zhongchenggaoshanmaoniu', 'Mountain yaks', 10, 2),
    ('gemtd_moluokedejixiezhushou', 'Mechanical couriers', 10, 2),
    ('gemtd_wuweizhihuan_fly', 'Flying couriers', 10, 2),
    ('gemtd_shudunziranzhizhu', 'Woodland spiders', 10, 3),
    ('gemtd_chaomengjuxi', 'Giant lizards', 12, 3),
    ('gemtd_xiaohongmao_fly', 'Scarlet flying couriers', 16, 3),
    ('gemtd_dashiqi', 'Guard hounds', 12, 4),
    ('gemtd_buquzhanquan_boss', 'Unyielding war hound', 1, 30),
], 1):
    u = units[source]
    waves.append(dict(name=name, source_id=source, count=count, leak=leak, boss=index==10,
                      hp=round(float(u['StatusHealth'])*0.69, 4),
                      speed=float(u['MovementSpeed'])*0.69/128,
                      armor=float(u['ArmorPhysical']), magic_resist=float(u['MagicalResistance'])/100,
                      air='FLY' in u['MovementCapabilities'], reward=2 if index<6 else 3,
                      completion=12+index*2, spawn_interval=0.85,
                      evasion=0.5 if index==9 else 0.0))
effects = dict(
    sapphire=dict(slow=[60,90,120],duration=3),
    silver=dict(slow=[90],duration=3),
    amethyst=dict(armor_reduction=[2,4,8],duration=3),
    emerald=dict(damage=[2,4,8],duration=10,interval=1),
    aquamarine=dict(attack_speed=200),
    opal=dict(attack_speed=[20,30,40],radius=664/128),
    ruby=dict(fraction=[.3,.4,.5],radius=[300/128,350/128,400/128]),
    topaz=dict(secondary_count=3),malachite=dict(secondary_count=3),
    asteriated_ruby=dict(damage=20,interval=.25,radius=500/128))
catalog = dict(version=1, source=dict(workshop_id='474619917', installed_publish_date='2026-08-01',
                file_hashes={f:hashlib.sha256((REF/f).read_bytes()).hexdigest() for f in ['mode.lua','units.txt','abilities.txt','entities.txt']}),
               gems=gems, specials=specials, map=dict(size=37, checkpoints=checkpoints, stones=stones),
               quality_odds=[[100,0,0],[80,20,0],[60,30,10]], quality_costs=[20,45], effects=effects, waves=waves)
(ROOT/'data').mkdir(exist_ok=True)
(ROOT/'data/catalog.json').write_text(json.dumps(catalog,indent=2)+'\n', encoding='utf8')
print(f'Wrote 24 base gems, 3 recipes, {len(stones)} stones, checkpoints {checkpoints} and 10 waves.')
