# Mekanikuppföljning 1.4.0-dev

Beställd 2026-10-24: genomför de fyra rekommendationerna i mekanikgranskningens svar. Innehållsversion **9**, med separat `run_campaign_v9.json`. Tidigare sparfiler och arkiverade distributionspaket bevaras. Tornskador och grund-HP har inte ändrats för att hjälpa teststrategin vinna.

## Nedgradering och kombinationer

Efter fem placeringar kan en ny grundgem av kvalitet II–VI väljas med **Downgrade randomly & start**. Typ och plats behålls. En lägre kvalitet slumpas; övriga nya gems blir sten och vågen börjar direkt. Knappens verktygstips visar fördelningen före valet. Äldre torn kan inte nedgraderas.

| Ny kvalitet | Möjliga resultat och chanser |
| --- | --- |
| II | I: 100 % |
| III | I: 34 %, II: 66 % |
| IV | I: 20 %, II: 30 %, III: 50 % |
| V | I: 10 %, II: 15 %, III: 25 %, IV: 50 % |
| VI | I–V: 20 % vardera |

Detta följer `gemtd_downgrade_stone`, inklusive första uniformsdraget före källans viktade undantag. Garanterad hjältenedgradering införs inte.

Vanliga tornrecept med enbart äldre material kan nu skapas under strid, även pausad strid. Fiender och vågklocka startas inte om. Vid nästa simuleringssteg uppdateras torn, auror, räckvidd, stöd och MVP-bonus. Kvarvarande torn behåller sina attackklockor, tillfälliga buffs och avväpning. Flygande skott från förbrukade torn förkastas; de omvandlas inte till det nya tornets attacker. Detta är ett uttryckligt fristående motorval, inte uppmätt Dota-paritet.

Placering och rivning är fortsatt låsta under strid. **Traprecept och trapflytt görs före strid**; Dotas hjältebaserade trapbyggande nära pågående fiender ingår inte här. Traprecept med nya material behåller placeringssteget före **Start wave**.

## Korrigerade grundregler

- Faktisk läcka drar av `3 × livskadan` från serien, utöver kontrollpunktsavdrag. Tröskeln 50 poäng och lägst fem vanliga fiender behålls. Framtida antal och möjlig killinkomst kan minska efter läckor.
- Natural Emerald använder källans 72 tillåtna förmågor, ranged-donatorer inom 220 källenheter och högst tre olika förmågor inom 100 dragförsök. Andra Natural Emerald-torn undantas. Samma förmåga hos flera donatorer får större vikt; True sight kan inte längre kopieras genom den gamla namnfiltreringen.

## Prövningarna 51–100

Våg 50 är sista vanliga byggomgången. Därefter tillkommer inga fem gemplaceringar och ingen rivningsfas. Nästa prövning startar efter **tre simulerade sekunder**. Paus och öppna hjälp-/receptdialoger stoppar nedräkningen; 2× skalar den. Tresekundersmellanrummet är vår visade anpassning, inte originalets exakta timerschema.

Äldre tornrecept är tillgängliga under strid. Sparpunkter före varje prövning återladdas som ett mellanrum före samma våg, utan nya gems. RNG, kalender och valda vågvarianter sparas. Rapporter kan återspela delvis förflutna mellanrum och automatisk vågstart.

Alla prövningsfiender har fem grundguld i stället för återanvända grundvågsband/bossbelöningar. Greed kan påverka faktisk inkomst. Oddsinköp stängs efter 50 eftersom inga nya gems placeras. Manuella inköp, priser och bossrabatt under grundomgången behålls. Bossläcka innebär fortsatt omedelbar förlust enligt tidigare val.

## Berserk och alternativ

Vågpanelen räknar ned mot 180 sekunders simulerad stridstid. När gränsen överskrids får alla fiender **+100 % rörelsehastighet och magiimmunitet**, även senare spawns. Berserk försvinner vid nästa våg. Paus förbrukar ingen tid.

17 alternativa vågdefinitioner och fem alternativa bossdefinitioner används med källans slump-/kalendervillkor. Individvarianterna på 35/36/38 finns kvar. Kalenderns månad/dag fångas när omgången skapas och sparas; senare återladdning ändrar inte datumvillkoren. Grundomgångens val återanvänds i motsvarande prövningar.

Waves visar möjliga alternativ och valt alternativ när det är känt. 21 nya manifestkopplingar återanvänder befintliga familjebilder; unika bilder för samtliga varianter ingår inte. Varianternas faktiska HP, hastighet, flygförmåga, armor, resistens och förmågor kommer från respektive källenhet. Slumpeliter, hjältesystem och veckoteman är fortsatt exkluderade.

## Verifiering

Slutkörning: **850 godkända GDScript-kontroller**, 5 256 referenskontroller, inga motorfel eller motorvarningar. De nya mekaniktesten omfattar 92 kontroller. Windows- och webbexporterna är ombyggda; Windows har renderat 20 bildrutor med verifierat attackljud och ordinarie webbexport har startats i Chrome som 1.4.0-dev utan konsolfel eller varningar.

`tests/check_mechanics_parity.gd` täcker seriegränser, Emeralds urval, nedgradering med 1 500 reproducerbara drag, stridskombinationer, paus, berserk, kalender, alla 22 alternativ, bilder, sparvalidering och oberoende återspelning. En syntetisk stark fixture klarar övergångarna 50–100 utan nya gems; det är inget naturligt balansspeltest.

Fem nya naturliga botomgångar finns separat i `output/campaign-1.4`. Alla förlorar vid boss tio med den enkla strategin och har återspelats oberoende med samma utfall: [rapport](reports/mechanics-replays-v1.4.json). Detta mäter inte mänsklig svårighet eller naturlig vinstchans i prövningarna. Äldre rapporter skrivs inte över.

Den renderade webbfixturen på separat origin har provat nedgraderingsknappen, kombination av äldre torn under pausad strid, pausad prövningsnedräkning, automatisk start och berserk. Fixturen är ett konstruerat scenario, inte en intjänad omgång. Windows- och webbexport verifieras separat.

```powershell
python tools/check.py
python tools/godot.py --headless --path . --script res://tests/check_mechanics_parity.gd -- --campaign --smoke
python tools/godot.py --headless --path . --script res://tools/audit_campaign.gd -- --campaign --smoke --runs=5 --output=res://output/campaign-1.4
python tools/verify_reviews.py --campaign --folder=output/campaign-1.4 --result=docs/reports/mechanics-replays-v1.4.json
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Release
python tools/smoke_windows.py --campaign --attack
```

Full Dota-motorparitet är fortfarande inte uppmätt. Native-modifierordning, reservtolkad true-sight-radie, attackanimationens attack point och tillståndens livslängd mellan vågor är kvarstående begränsningar. Mänsklig granskning behövs särskilt för berserk och slutspelsförsvaret.
