"""Compile locally inspected numeric facts into the standalone solo campaign.

Only recognized effects are translated; source Lua is never evaluated. Cosmetic
abilities are omitted explicitly. Engine adaptations are documented in the data.
"""
from pathlib import Path
import json
import re
from reference_data import parse_kv
from build_full_reference import table, unit_facts

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT/'.tools/reference'


def prd_rate(coefficient):
    survival=1.0
    attempts=0.0
    for n in range(1,100001):
        attempts+=survival
        survival*=1-min(1.0,n*coefficient)
        if survival < 1e-15:break
    return 1/attempts


def prd_coefficient(chance):
    # Calibrate a linear increasing hazard to the requested long-run rate.
    # This is our standalone reconstruction, not Valve's private RNG code.
    low,high=0.0,chance
    for _ in range(64):
        middle=(low+high)/2
        if prd_rate(middle)>chance:high=middle
        else:low=middle
    return (low+high)/2


def build():
    source = json.loads((ROOT/'data/full_reference.json').read_text(encoding='utf8'))
    expanded = json.loads((ROOT/'data/expanded_gems.json').read_text(encoding='utf8'))
    abilities = json.loads((REF/'abilities.json').read_text(encoding='utf8'))
    raw_units = json.loads((REF/'units.json').read_text(encoding='utf8'))
    raw = (REF/'english.txt').read_bytes()
    english = parse_kv(raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8-sig'))['lang']['Tokens']
    basics = {t['source_id']: [t['kind'],t['tier']] for t in source['base_towers']}
    names = {'gemtd_baiyin':'silver','gemtd_kongqueshi':'malachite',
             'gemtd_xingcaihongbaoshi':'asteriated_ruby','gemtd_yu':'jade'}
    # Local readable English labels where the snapshot has no English token.
    labels = {'feicuimoxiang':'Emerald Golem','geluanshi':'Geluan Stone','haibao':'Sea Jewel',
              'haiyangqingyu':'Ocean Jade','heiwangzihuangguanhongbaoshi':"Black Prince's Ruby",
              'heiyaoshi':'Obsidian','hongshanhu':'Red Coral','huaguoshanxiandan':'Huaguo Elixir',
              'huguoshenyishi':'Guardian Stone','jingangshikulinan':'Cullinan Diamond',
              'keyinuoerguangmingzhishan':'Koh-i-Noor','manao':'Agate','ranshaozhishi':'Burning Stone',
              'shenhaizhenzhu':'Deep Sea Pearl','shuaibiankaipayou':'Depleted Uranium',
              'sililankazhixing':'Star of Sri Lanka','tianranzumulv':'Natural Emerald',
              'xiameishi':'Sunstone','xingguanglanbaoshi':'Star Sapphire','yijiazhishi':'Armor Stone'}
    for key,label in dict(youbushiban='Entangle',zhangqishiban='Venom',hongliushiban='Torrent',
                          haojiaoshiban='Howl',suanwushiban='Acid',mabishiban='Paralysis',
                          kongheshiban='Dread',xuwushiban='Ethereal').items():
        for suffix,rank in [('', 'Bronze'),('_yin','Silver'),('_jin','Gold')]: labels[key+suffix]=rank+' '+label+' Trap'
    for key in source['special_towers']:
        names.setdefault(key,key.removeprefix('gemtd_'))

    def number(value, ability=None, level=1):
        if isinstance(value,dict):
            value = value['value']
        value = str(value)
        if value.startswith('%'):
            return number(abilities[ability]['AbilityValues'][value[1:]],ability,level)
        parts = value.split()
        return float(parts[min(level-1,len(parts)-1)])

    def values(key,level=1):
        return {k:number(v,key,level) for k,v in abilities[key].get('AbilityValues',{}).items()}

    # Property names are retained as a small semantic vocabulary, not executable
    # KV actions. Unsupported properties fail compilation instead of disappearing.
    props = {'MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE':'damage_bonus',
             'MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT':'attack_speed',
             'MODIFIER_PROPERTY_ATTACK_RANGE_BONUS':'range_bonus',
             'MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE':'outgoing_percent',
             'MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS':'armor',
             'MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS':'magic_resist',
             'MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT':'move_constant',
             'MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE':'move_percent',
             'MODIFIER_PROPERTY_DISABLE_HEALING':'no_healing',
             'MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE':'incoming_percent',
             'MODIFIER_PROPERTY_MAGICAL_RESISTANCE_DECREPIFY_UNIQUE':'magic_resist'}

    def modifiers(key,mod,level=1):
        result = {}
        for k,v in mod.get('Properties',{}).items():
            if k not in props:
                raise ValueError(f'Unsupported property {key}: {k}')
            result[props[k]] = number(v,key,level)
        for k,v in mod.get('States',{}).items():
            if v != 'MODIFIER_STATE_VALUE_ENABLED':
                continue
            result[k.removeprefix('MODIFIER_STATE_').lower()] = True
        return result

    def compile_ability(key):
        a = abilities.get(key,{})
        result = []
        if key.startswith('e') and (key.startswith('e100') or key == 'e301'):
            return [dict(type='cosmetic',id=key)]
        if key == 'tower_true_sight':
            return [dict(type='support',id=key,radius=900/128,properties={'true_sight':True})]
        if key == 'tower_chain_frost':
            return [dict(type='slab_echo',id=key,radius=500/128,damage=12000,bounces=10,jump_radius=1000/128,interval=.2,duration=5,properties={'move_percent':-60},stun=.1)]
        if key == 'tower_shihua_new':
            return [dict(type='petrify',id=key,chance=.01,cooldown=5,count=5,duration=2.5,radius=9999/128)]
        if key == 'tower_ranjin':
            return [dict(type='burst',id=key,chance=.14,multiplier=20,damage_type='magical',radius=400/128)]
        if key in ('tower_shandianlian','tower_chazhuangshandian'):
            return [dict(type='chain' if key == 'tower_shandianlian' else 'shock',id=key,
                         chance=.30 if key == 'tower_shandianlian' else .25,
                         damage=500 if key == 'tower_shandianlian' else 4000,
                         count=5,radius=1000/128,interval=.2 if key == 'tower_shandianlian' else 0)]
        if key == 'tower_baoji1':
            return [dict(type='crit',id=key,chance=source['random_events'][key]['chance'],multiplier=5,random_model=key)]
        if key == 'tower_aojiao':
            return [dict(type='self_disarm',id=key,chance=source['random_events'][key]['chance'],duration=4,random_model=key)]
        if key.startswith('tower_jianshe'):
            tier=int(key[-1])-1
            return [dict(type='splash',id=key,fraction=expanded['effects']['ruby']['fraction'][tier],
                         radius=expanded['effects']['ruby']['radius'][tier])]
        if key.startswith('tower_fenliejian'):
            return [dict(type='split',id=key,count=12 if key.endswith('_you') else 6 if key.endswith('_xianyan') else 3)]
        if key == 'tower_10jiyun':
            return [dict(type='stun',id=key,chance=.1,duration=2)]
        if key.startswith('new_'):
            return compile_slab(key)
        mods=a.get('Modifiers',{})
        for mod_id,m in mods.items():
            if 'Aura' in m:
                target=mods.get(m['Aura'],{})
                action=dict(type='enemy_aura' if 'ENEMY' in m.get('Aura_Teams','') else 'support',
                            id=m['Aura'],radius=number(m['Aura_Radius'],key)/128,linger=number(m.get('Aura_Duration',.5),key),
                            properties=modifiers(key,target),
                            not_ancient='NOT_ANCIENTS' in m.get('Aura_Flags',''),
                            magic_targets='MAGIC_IMMUNE_ENEMIES' in m.get('Aura_Flags',''),
                            stacks='MULTIPLE' in target.get('Attributes',''))
                if m['Aura'] == 'modifier_tower_huichun_aura':
                    action['properties']['rejuvenation']=True
                if m['Aura'] == 'modifier_tower_tanlan':
                    action['properties']['greed']=True
                damage=target.get('OnIntervalThink',{}).get('Damage')
                if damage:
                    action.update(damage=number(damage['Damage'],key),interval=number(target['ThinkInterval'],key),
                                  damage_type=damage['Type'].removeprefix('DAMAGE_TYPE_').lower())
                result.append(action)
            if m.get('Passive') == '1' and m.get('Properties'):
                result.append(dict(type='passive',id=mod_id,properties=modifiers(key,m)))
            event=m.get('OnAttackLanded',{})
            if 'ApplyModifier' in event:
                apply=event['ApplyModifier']; target=mods[apply['ModifierName']]
                action=dict(type='on_hit',id=apply['ModifierName'],properties=modifiers(key,target),
                            duration=number(apply.get('Duration',target.get('Duration','0')),key),
                            multiple='MULTIPLE' in target.get('Attributes',''),
                            magic_targets='MAGIC_IMMUNE_ENEMIES' in str(apply.get('Target','')),
                            radius=number(apply['Target'].get('Radius',0),key)/128 if isinstance(apply.get('Target'),dict) else 0)
                damage=target.get('OnIntervalThink',{}).get('Damage')
                if damage:
                    action.update(damage=number(damage['Damage'],key),interval=number(target['ThinkInterval'],key),
                                  damage_type=damage['Type'].removeprefix('DAMAGE_TYPE_').lower())
                result.append(action)
        if not result:
            raise ValueError('Untranslated gameplay ability '+key)
        return result

    def compile_slab(key):
        stage=3 if key.endswith('3') else 2 if key.endswith('2') else 1
        v=values(key,4)
        action=dict(type='slab',id=key,cooldown=10,trigger_radius=1,stage=stage)
        mods=abilities[key].get('Modifiers',{})
        if mods:
            action['modifier_id']=next(iter(mods))
        if 'youbu' in key:
            action.update(mode='stun',count=[1,8,64][stage-1],radius=[192,1024,9999][stage-1]/128,duration=6,magic_targets=True)
        elif 'venomous' in key:
            action.update(mode='line_slow',duration=v['duration'],radius=v['radius']/128,
                          distance=v['distance']/128,properties={'move_percent':v['movement_slow']})
        elif 'torrent' in key:
            action.update(mode='torrent',radius=v['radius']/128,duration=v['slow_duration'],
                          delay=v['delay'],stun=v['stun_duration'],properties={'move_percent':v['movespeed_bonus']})
        elif 'haojiao' in key:
            action.update(mode='support',radius=v['aura_radius']/128,duration=v['howl_duration'],properties={'outgoing_percent':v['unit_bonus_damage']})
        elif 'acid' in key:
            action.update(mode='field',radius=v['radius']/128,duration=v['duration'],properties={'armor':v['armor_reduction']},magic_targets=True,modifier_id=abilities[key]['Modifiers']['modifier_acid_spray_thinker']['Aura'])
        elif 'cask' in key:
            action.update(mode='cask',count=[1,3,9][stage-1],duration=stage,radius=[0,512,1024][stage-1]/128,
                          bounces=12,jump_radius=1000/128,interval=.2)
        elif 'konghe' in key:
            mod=next(iter(abilities[key]['Modifiers'].values()))
            target=abilities[key]['OnProjectileHitUnit']['ApplyModifier']['Target']
            action.update(mode='modifier',radius=number(target['Radius'],key,4)/128,duration=v['konghe_duration'],properties=modifiers(key,mod,4),magic_targets=True)
        elif 'xuwu' in key:
            mod=next(iter(abilities[key]['Modifiers'].values()))
            target=abilities[key]['OnSpellStart']['ApplyModifier']['Target']
            action.update(mode='modifier',radius=number(target['Radius'],key,4)/128,duration=v['xuwu_duration'],properties=modifiers(key,mod,4))
        else:
            raise ValueError('Unknown slab '+key)
        return [action]

    specials={}
    compiled={}
    for source_id,fact in source['special_towers'].items():
        ids=fact['abilities']+([fact['activated_ability']] if fact.get('activated_ability') else [])
        for ability in ids:
            compiled.setdefault(ability,compile_ability(ability))
        v=fact['values']
        key=names[source_id]
        specials[key]=dict(name=labels.get(key,english.get(source_id,source_id.removeprefix('gemtd_').replace('_',' ').title()).title()),
                           source_id=source_id,color='#83d6b0',damage=v.get('AttackDamageMin',0),
                           interval=v.get('AttackRate',1),range=v.get('AttackRange',0)/128,targets='both',
                           projectile_speed=v['ProjectileSpeed']/128,
                           ranged=fact['attack_capabilities']=='DOTA_UNIT_CAP_RANGED_ATTACK',
                           abilities=ids,slab=bool(fact.get('activated_ability')),
                           effect='; '.join(ids).replace('tower_','').replace('_',' '))
        if source_id == 'gemtd_tianranzumulv':
            specials[key]['steal_abilities']=3
        if source_id == 'gemtd_huguoshenyishi':
            specials[key]['random_damage']=dict(mean=512,deviation=128,minimum=30,max_sigma=4)
        for ability in ids:
            for action in compiled[ability]:
                if action['type']=='passive':
                    specials[key]['damage']+=action['properties'].get('damage_bonus',0)
    # Basic units participate in the same campaign effect implementation.
    gems=expanded['gems']
    for kind,g in gems.items():
        for level in g['levels']:
            raw=raw_units[level['source_id']]
            ids=[raw[f] for f in raw if re.fullmatch('Ability\\d+',f) and raw[f]]
            level['abilities']=ids
            level['ranged']=raw.get('AttackCapabilities')=='DOTA_UNIT_CAP_RANGED_ATTACK'
            level['projectile_speed']=next(t['values']['ProjectileSpeed'] for t in source['base_towers'] if t['source_id']==level['source_id'])/128
            for ability in ids:
                compiled.setdefault(ability,compile_ability(ability))
    recipes={}
    for r in source['recipes']:
        recipes[r['id']]=dict(result=names[r['result']],family=r['family'],
                              ingredients=[basics[i] if i in basics else [names[i],1] for i in r['ingredients']])
    waves=[]
    def enemy(fact,index):
        v=fact['values']; base=index if index<=50 else index-50
        return dict(name=english.get(fact['source_id'],fact['source_id'].removeprefix('gemtd_').replace('_',' ').title()),
                    source_id=fact['source_id'],hp=round(v['StatusHealth']*.69,4),speed=v['MovementSpeed']*.69/128,
                    armor=v['ArmorPhysical'],magic_resist=v['MagicalResistance']/100,
                    air='FLY' in fact['movement'],boss=base%10==0,ancient=fact['ancient'],
                    count=1 if base%10==0 else 10,leak=100 if base%10==0 else 1,
                    leak_max=100 if base%10==0 else 3+4*((index-1)//10),
                    reward=5 if index>50 else 150 if base%10==0 else 5+5*((base-1)//10),
                    completion=0,spawn_interval=1.0,evasion=0,
                    abilities=list(dict.fromkeys(fact['abilities']+fact.get('added_abilities',[]))),variants=[],trial=index>50)
    for index in range(1,101):
        fact=source['waves'][(index-1)%50]
        wave=enemy(fact,index)
        wave['variants']=[enemy(v,index) for v in fact.get('variants',[])]
        waves.append(wave)
    alternatives = {}
    for fact in source['alternate_waves']:
        index = fact['index']-100
        value = enemy(fact,index)
        value['abilities'] = list(dict.fromkeys(value['abilities']+source['waves'][index-1]['added_abilities']))
        alternatives[str(index)] = [value]
    boss_ids = {20:['gemtd_yuediyang_boss'],30:['gemtd_zard_boss_fly'],40:['gemtd_gugubiao_boss_fly'],50:['gemtd_roushan_boss_fly_jin','gemtd_roushan_boss_fly_bojin']}
    for index,ids in boss_ids.items():
        alternatives[str(index)] = [enemy(dict(**unit_facts(key,raw_units),added_abilities=source['waves'][index-1]['added_abilities']),index) for key in ids]
    stealable = source['progression']['stealable_abilities']
    random_models={key:dict(**fact,coefficient=prd_coefficient(fact['chance'])) for key,fact in source['random_events'].items()}
    payload=dict(version=10,profile='full-solo-dev',gems=gems,specials=specials,recipes=recipes,random_models=random_models,
                 mechanics=dict(tower_moves_per_run=5,stealable_abilities=stealable,downgrade_weights={'2':[100],'3':[34,66],'4':[20,30,50],'5':[10,15,25,50],'6':[20,20,20,20,20]},berserk_seconds=180,berserk_move_percent=100,trial_intermission_seconds=3),
                 wave_alternatives=alternatives,
                 combat=dict(minimum_movement_speed=100,checkpoint_radius=64/128,detection_radius_fallback=900/128,default_aura_linger=.5,base_attack_speed=100,minimum_attack_speed=20,maximum_attack_speed=700,
                             attack_speed_reference='Valve gameplay update 7.20: total maximum attack speed 700; standalone adopts this documented default, not an in-match GemTD measurement.',
                             projectiles='tracking; source ProjectileSpeed / 128 cells per second; damage and on-hit at impact'),
                 ability_effects=compiled,effects=expanded['effects'],quality_odds=expanded['quality_odds'],
                 quality_costs=[250,400,550,700],waves=waves,starting_lives=100,
                 economy=dict(source_xp_thresholds=[0,250,650,1200,1900],boss_odds_discount=150,boss_discount_last_wave=50,
                              odds_purchase='Base gold prices equal source XP threshold differences. Each defeated base boss grants 150 gold and 150 banked odds-only discount. Unused discount carries forward; purchases remain manual.'),
                 slab_upgrades={names[r['source']]:names[r['result']] for r in source['slab_upgrades']},
                 trial_pool=source['progression']['trial_ability_pool'],
                 mvp=dict(last_award_wave=50,maximum_level=10,damage_percent_per_level=10,max_level_aura_radius=290/128,max_level_aura_percent=100,damage_percent_cap=500),
                 balance_note='Solo campaign: source snapshot 2026-08-01, 50 base waves plus 50 trials. '
                 'Gold odds purchases are an adaptation; hero abilities, weekly themes and random elites are excluded. '
                 'Tracking attacks use source projectile speeds and a documented Dota total attack-speed cap of 700. '
                 'Explicit source PRD events use calibrated standalone smoothing; exact Valve RNG and engine event ordering are not match-verified.')
    (ROOT/'data/campaign.json').write_text(json.dumps(payload,indent=2)+'\n',encoding='utf8')
    print(f'CAMPAIGN_BUILT waves={len(waves)} recipes={len(recipes)} effects={len(compiled)}')


if __name__=='__main__':
    build()
