"""Verify the campaign against the separately extracted full source facts."""
from pathlib import Path
import json
import math

ROOT=Path(__file__).resolve().parents[1]


def verify():
    c=json.loads((ROOT/'data/campaign.json').read_text())
    f=json.loads((ROOT/'data/full_reference.json').read_text())
    checks=0
    errors=[]
    def equal(label,actual,expected):
        nonlocal checks
        checks+=1
        ok=math.isclose(actual,expected,rel_tol=1e-9,abs_tol=1e-9) if isinstance(expected,(int,float)) and not isinstance(expected,bool) else actual==expected
        if not ok: errors.append(dict(field=label,actual=actual,expected=expected))
    equal('wave count',len(c['waves']),100)
    equal('recipe alternatives',len(c['recipes']),59)
    equal('special units',len(c['specials']),67)
    equal('original starting lives',c['starting_lives'],100)
    equal('documented standard total attack speed cap',c['combat']['maximum_attack_speed'],700)
    equal('base attack speed',c['combat']['base_attack_speed'],100)
    equal('explicit source PRD events',set(c['random_models']),set(f['random_events']))
    for key,model in c['random_models'].items():
        for field,value in f['random_events'][key].items():equal(key+'.'+field,model[field],value)
        survival=1.0
        expected_attempts=0.0
        for n in range(1,100001):
            expected_attempts+=survival
            survival*=1-min(1.0,n*model['coefficient'])
            if survival < 1e-15:break
        equal(key+'.calibrated long-run rate',1/expected_attempts,model['chance'])
    equal('MVP source parameters',c['mvp'],dict(last_award_wave=50,maximum_level=10,damage_percent_per_level=10,max_level_aura_radius=290/128,max_level_aura_percent=100,damage_percent_cap=500))
    basic={t['source_id']:t for t in f['base_towers']}
    result_units={t['source_id']:kind for kind,t in c['specials'].items()}
    for kind,g in c['gems'].items():
        equal('qualities '+kind,len(g['levels']),6)
        for t in g['levels']:
            original=basic[t['source_id']]['values']
            for key,source,scale in [('damage','AttackDamageMin',1),('interval','AttackRate',1),('range','AttackRange',128)]:
                equal(t['source_id']+'.'+key,t[key],original[source]/scale)
            equal(t['source_id']+'.projectile speed',t['projectile_speed'],original['ProjectileSpeed']/128)
    for kind,t in c['specials'].items():
        original=f['special_towers'][t['source_id']]
        bonus=sum(e['properties'].get('damage_bonus',0) for a in t['abilities'] for e in c['ability_effects'][a] if e['type']=='passive')
        equal(kind+'.damage incl passive',t['damage'],original['values'].get('AttackDamageMin',0)+bonus)
        equal(kind+'.interval',t['interval'],original['values'].get('AttackRate',1))
        equal(kind+'.range',t['range'],original['values'].get('AttackRange',0)/128)
        equal(kind+'.projectile speed',t['projectile_speed'],original['values']['ProjectileSpeed']/128)
    for r in f['recipes']:
        actual=c['recipes'][r['id']]
        equal(r['id']+'.result',actual['result'],result_units[r['result']])
        expected=[[basic[i]['kind'],basic[i]['tier']] if i in basic else [result_units[i],1] for i in r['ingredients']]
        equal(r['id']+'.exact material list',actual['ingredients'],expected)
    for i,w in enumerate(c['waves'],1):
        original=f['waves'][(i-1)%50]
        equal(f'wave {i} identity',w['source_id'],original['source_id'])
        equal(f'wave {i} base hp',w['hp'],original['values']['StatusHealth']*.69)
        equal(f'wave {i} base speed',w['speed'],original['values']['MovementSpeed']*.69/128)
        equal(f'wave {i} armor',w['armor'],original['values']['ArmorPhysical'])
        equal(f'wave {i} magic resist',w['magic_resist'],original['values']['MagicalResistance']/100)
        equal(f'wave {i} flight',w['air'],original['air'])
        equal(f'wave {i} trial flag',w['trial'],i>50)
        equal(f'wave {i} boss flag',w['boss'],i%10==0)
        equal(f'wave {i} abilities',w['abilities'],list(dict.fromkeys(original['abilities']+original['added_abilities'])))
    equal('slab upgrade graph',c['slab_upgrades'],{result_units[r['source']]:result_units[r['result']] for r in f['slab_upgrades']})
    equal('trial ability pool',c['trial_pool'],f['progression']['trial_ability_pool'])
    equal('manual odds prices from XP differences',c['quality_costs'],[b-a for a,b in zip(c['economy']['source_xp_thresholds'],c['economy']['source_xp_thresholds'][1:])])
    equal('approved boss odds discount',c['economy']['boss_odds_discount'],150)
    equal('discount stops after base bosses',c['economy']['boss_discount_last_wave'],50)
    equal('documented aura linger',c['combat']['default_aura_linger'],.5)
    equal('checkpoint proximity from source 64 units',c['combat']['checkpoint_radius'],.5)
    for effects in c['ability_effects'].values():
        for effect in effects:
            if effect['type'] in ['support','enemy_aura'] and effect['id'] != 'tower_true_sight': equal(effect['id']+' aura linger',effect['linger'],.5)
    supported={'cosmetic','passive','support','enemy_aura','on_hit','slab','split','stun','crit','splash','burst','chain','shock','petrify','self_disarm','slab_echo'}
    for name,effects in c['ability_effects'].items():
        equal(name+' translated actions',bool(effects),True)
        for effect in effects:
            equal(name+' supported runtime effect',effect['type'] in supported,True)
            if effect['type'] in ['crit','self_disarm']:
                equal(name+' PRD model',effect['random_model'],name)
    return dict(checks=checks,failures=len(errors),errors=errors,
                limits='Numeric source verification and standalone mechanics checks do not establish full Dota engine parity or human win rate.')


if __name__=='__main__':
    result=verify()
    destination=ROOT/'docs/reports/campaign-reference.json'
    destination.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    raise SystemExit(bool(result['failures']))
