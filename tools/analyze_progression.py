"""Compare economy options without changing the playable catalog.

Synthetic reward sequences only: no combat, elites, Greed, theft or hero bonuses.
The result describes affordability, not difficulty or a human winning strategy.
"""
from pathlib import Path
import json
import random

ROOT=Path(__file__).resolve().parents[1]
THRESHOLDS=[0,250,650,1200,1900]
CURRENT=[250,400,550,700]
FIXED=[250,350,500,550]


def compare(kills):
    states={name:dict(level=0,gold=0,discount=0,builds=[]) for name in ['source_xp','current','fixed_lower','boss_discount']}
    for wave in range(1,51):
        boss=wave%10==0
        reward=5+5*((wave-1)//10)
        for _ in range(1 if boss else kills[wave-1]):
            source=states['source_xp']
            source['gold']+=300 if boss else reward
            while source['level']<4 and source['gold']>=THRESHOLDS[source['level']+1]:
                source['level']+=1
                source['builds'].append(wave+1)
            for name in ['current','fixed_lower','boss_discount']:
                state=states[name]
                state['gold']+=150 if boss else reward
                if boss and name=='boss_discount':state['discount']+=150
                costs=FIXED if name=='fixed_lower' else CURRENT
                while state['level']<4:
                    base=costs[state['level']]
                    credit=min(base,state['discount'])
                    cost=base-credit
                    if state['gold']<cost:break
                    state['gold']-=cost
                    state['discount']-=credit
                    state['level']+=1
                    state['builds'].append(wave+1)
    return {name:state['builds'] for name,state in states.items()}


def analyze():
    cases=[dict(ordinary_kills_per_wave=n,first_usable_build=compare([n]*50)) for n in [5,8,10,12,15]]
    rng=random.Random(470619917)
    for _ in range(1000):
        case=compare([rng.randrange(0,21) for _ in range(50)])
        assert case['source_xp']==case['boss_discount'],case
    report=dict(reference_date='2026-08-01',source_xp_thresholds=THRESHOLDS,
                current_prices=CURRENT,fixed_price_option=FIXED,boss_discount_option=150,
                units='first building phase where each odds improvement can be used after immediate affordable purchases',
                limits='Economy-only synthetic sequences. All bosses defeated. No adaptive path simulation, Greed, theft, elites, other spending or human delay. This is not a playtest.',
                randomized_bookkeeping_cases=1000,boss_discount_matches_source_in_all_bookkeeping_cases=True,cases=cases)
    destination=ROOT/'docs/reports/progression-options.json'
    destination.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    lines=['# Geminköp – jämförelse och valt alternativ','',
           'Beräkning av när fyra oddsinköp blir överkomliga. Alla bossar antas besegrade. Spelaren köper direkt när pengarna räcker; gemchanserna används först i nästa byggfas. Inga strider eller mänskliga strategier simuleras. Greed, stöld, eliter och hjältebonusar ingår inte.','',
           '| Vanliga kills/våg | Originalets XP | Nuvarande priser | Lägre fasta priser | Bossrabatt |',
           '| --- | --- | --- | --- | --- |']
    for row in cases:
        v=row['first_usable_build']
        lines.append('| '+str(row['ordinary_kills_per_wave'])+' | '+' | '.join('/'.join(map(str,v[name])) for name in ['source_xp','current','fixed_lower','boss_discount'])+' |')
    lines+=['','Siffrorna är byggfasernas vågnummer. De beskriver ekonomiska möjligheter, inte garanterade tornkvaliteter eller vinst.','',
            '**Alternativ A – bossrabatt (rekommenderat):** behåll grundpriserna 250/400/550/700 och originalets bossguld 150. Varje besegrad grundboss ger dessutom 150 i rabatt på kommande geminköp. Rabatten förbrukas vid köp; överskott sparas till nästa köp. Den kan inte användas till annat och ger ingen extra guldbelöning. Det behåller manuella köp och motsvarar originalets extra boss-XP i denna basmodell.','',
            '**Alternativ B – lägre fasta priser:** 250/350/500/550. Enklare att visa. Matchar originalets byggfaser i tiokillsfallet, men inte lika bra om antalet besegrade fiender ändras.','',
            '**Alternativ C – behåll nuvarande priser:** 250/400/550/700 tills fler mänskliga omgångar finns.','',
            '1000 varierande syntetiska killsekvenser kontrollerades: bossrabattens överkomlighet följer XP-trösklarna i samtliga fall under de angivna begränsningarna. Det bevisar bokföringen, inte spelbalansen. Greeds extra guld skulle fortfarande kunna påskynda manuella inköp, och guldstöld försena dem; originalets XP påverkas inte på samma sätt.','',
            'Användaren valde alternativ A: bossrabatt. Den är implementerad i kampanj 1.2.2-dev; jämförelsen ovan visar den tidigare ekonomin och alternativen. Maskinläsbart underlag: `reports/progression-options.json`.']
    (ROOT/'docs/progression-options.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
    print('PROGRESSION_ANALYSIS_OK cases=5 bookkeeping_sequences=1000')
    for row in cases:print(row)


if __name__=='__main__':analyze()
