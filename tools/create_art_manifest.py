"""Write the initial non-destructive art mapping; does not modify any pixels.

Artist edits belong in assets/graphics/manifest.json after initial creation.
Use --output for a new draft instead of overwriting an existing manifest.
"""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]

def initial_manifest():
    kinds = ['sapphire','diamond','aquamarine','opal','emerald','topaz','ruby','amethyst',
             'silver','malachite','asteriated_ruby','stone','checkpoint','flowers','fern','pine']
    sprites = {}
    for i, kind in enumerate(kinds):
        size = [1.22,1.95] if i < 11 else [1.04,1.0]
        if kind == 'checkpoint': size = [1.75,1.5]
        if kind == 'pine': size = [2.0,3.0]
        sprites[kind] = dict(sheet='towers', index=i,trim_alpha=True,
                             size=size, anchor=[.5,.85] if i<11 else [.5,.65])
    enemies = ['boar','frog','yak','courier_robot','blue_courier','spider','lizard','red_courier','hound','boss_hound','rocks','dry_grass']
    for i, kind in enumerate(enemies):
        sprites[kind] = dict(sheet='enemies',index=i,trim_alpha=True,
                             size=[1.85,1.9] if kind=='boss_hound' else [1.25,1.3],
                             anchor=[.5,.72])
    source_ids = ['gemtd_kuangbaoyezhu','gemtd_kuaidiqingwatiaotiao','gemtd_zhongchenggaoshanmaoniu',
                  'gemtd_moluokedejixiezhushou','gemtd_wuweizhihuan_fly','gemtd_shudunziranzhizhu',
                  'gemtd_chaomengjuxi','gemtd_xiaohongmao_fly','gemtd_dashiqi','gemtd_buquzhanquan_boss']
    catalog=json.loads((ROOT/'data/catalog.json').read_text(encoding='utf8'))
    for category in ['gems','specials']:
        for kind,data in catalog[category].items(): sprites[kind]['effect_color']=data['color']
    return dict(version=1,name='Arcane meadow · first art pass',theme='res://assets/graphics/ui_theme.tres',
        sheets=dict(towers=dict(texture='res://assets/graphics/generated/towers-v1.png',columns=4,rows=4),
                    enemies=dict(texture='res://assets/graphics/generated/enemies-v1.png',columns=4,rows=3)),
        sprites=sprites,
        bindings=dict(gems={k:dict(default=k) for k in kinds[:12]},
                      enemies=dict(zip(source_ids,enemies[:10]))),
        palette=dict(outside='#101e23',grass='#4b6744',grass_light='#536f49',
                     grid='#233b30',border='#9b966a',selection='#ffe3a0',
                     route_ground='#b6e6a7',route_air='#99d5ff',ui_background='#0c161d',ui_accent='#e4d4a4',
                     ui_muted='#829b95',ui_section='#d9c690',ui_footer='#778e8d',
                     health='#a7df83',slow='#77ccff',poison='#9ce85f',quality='#ffdc85'),
        terrain=dict(variation=.035,detail_stride=11,edge_shade=.12))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',default='assets/graphics/manifest.json')
    args=parser.parse_args()
    target=ROOT/args.output
    if target.exists(): raise SystemExit('Refusing to overwrite existing art mappings; choose --output.')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(initial_manifest(),indent=2)+'\n',encoding='utf8')
    print(target)
