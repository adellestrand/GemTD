# Balansgranskning av kampanjprofilen mot Dota 2 GemTD (2026-10-28)

> **Uppföljning 2026-10-28:** användaren godkände paket 1. #2 (läckband) och #5 (Torrent-skada) är rättade i innehållsversion 11. Därefter godkändes paket 2: #1, #3 och #4 är rättade. Proben visar nu 1 kvarvarande uppmätt avvikelse (#6). Se slutet av filen.

Uppdrag: fullständig review av kampanjens balans (1.4.1-dev, innehållsversion 10) mot förlagan. **Inga regler, data eller balansvärden har ändrats.** Allt nedan är förslag som kräver användarens godkännande. Inget är committat.

## Underlag och metod

- Källa: lokala `.tools/reference/` (`abilities.json`, `units.json`, `mode.lua`, `chain.lua`, `shock.lua`, `multishot.lua`), ögonblicksbild 2026-08-01. Det installerade Workshop-paketet (474619917, publicerat 2026-10-19) har jämförts igen med `audit_mechanics_reference.audit()`. Resultatet är identiskt med `docs/reports/mechanics-audit-reference.json`: nio centrala tabeller är oförändrade, liksom 185 enheter och 109 förmågor. Referensen är alltså fortfarande aktuell. (Skriptet kördes till scratch, så rapportfilen skrevs inte över.)
- Lua körs inte. Varje förmåga lästes sida vid sida med vår kompilerade `data/campaign.json` (107 förmågor), och motorns hantering lästes i `game/core/campaign_combat.gd`, `campaign_rules.gd`, `damage.gd` och `run_state.gd`.
- Ny kontroll: `tests/check_balance_review.gd`, som bara läser och inte ingår i `check.py`. Den bekräftar källbeteenden som stämmer och mäter avvikelserna i den riktiga motorn. Den ändrar inga regler.

```powershell
python tools/godot.py --headless --path . --script res://tests/check_balance_review.gd -- --campaign --smoke
```

Ger `BALANCE_REVIEW_CHECK_OK checks=9 failures=0 deviations=10`. Varje `DEVIATION:`-rad anger vårt värde och källans.

### Körda verktyg (2026-10-28)

| Verktyg | Resultat |
| --- | --- |
| `python tools/verify_campaign.py` | 1949 kontroller, 0 fel |
| `python tools/verify_full_reference.py` | 3129 kontroller, 0 fel |
| `python tools/verify_balance.py` | `BALANCE_REFERENCE_OK checks=180` |
| `audit_mechanics_reference` mot installerat Workshop-paket | Alla tabeller oförändrade, 0 ändrade enheter/förmågor |
| `python tools/check.py` | `CHECKS_OK` (exit 0). Även `SIDEBAR_CHECK_OK` passerar nu. |
| `tests/check_balance_review.gd` (ny) | 9 PASS, 10 uppmätta avvikelser |
| `python tools/redesign_guard.py` | `RED_ZONE_VIOLATION`: bara `CHANGED tests/check_leaderboard.gd`. Det kommer från det andra verktygets redan committade leaderboardarbete; baslinjen är inaktuell. Den här granskningen har inte rört röd zon (den nya testfilen är en tillåten ny test). |

## Sammanfattning: prioriterade avvikelser och buggar

Ordnade efter bedömd balanspåverkan. Ingen av dem finns dokumenterad som avsiktlig avvikelse.

| # | Prio | Område | Källa (Dota) | Vi | Förslag |
| --- | --- | --- | --- | --- | --- |
| 1 | **Hög** | Magiskt motstånd staplas | Dota staplar magiskt motstånd multiplikativt: `1 − Π(1 − rᵢ)`. Det gäller även negativa reduktioner (aurorna bixi/zheyi, jihan −100, xuwu-fällan −60/−120/−180, Black Prince, enemy_momian). | `refresh_defenses`: `bas + Σ/100`, alltså additivt. Exempel: bas 25 % med −80 och −100 ger skadefaktor 2,55 hos oss mot 2,70 i källan. Med flera stora reduktioner och bas 0 växer skillnaden kraftigt: −100, −80, −20 och −180 ger 4,8× hos oss mot cirka 12× i källan. Med positiv bas och små reduktioner kan vi i stället ge *mer* skada. | Införa multiplikativ stapling i `damage.gd`/`refresh_defenses`. Påverkar alla magiska torn sent och kräver en ny balanskörning. Motorregel: Valves stapling är inte verifierad i matchmiljö här, men den är dokumenterad Dota-standard. |
| 2 | **Hög** | Läckskada i prövningar 51–100 | Spawnkoden: 51–59 → 1–27, 61–69 → 1–35, 71–79 → 1–43, 81–89 → 1–51, 91–99 → 1–59 (+8 per band efter 50). | `leak_max = 3+4·((index−1)//10)`: 23/27/31/35/39. `build_campaign.py` förlänger formeln från våg 1–50 linjärt. | Rätta i `build_campaign.py` och `verify_campaign.py`. Prövningarna blir då klart hårdare vid läckor: maxskadan per fiende ökar 17–51 %. |
| 3 | **Medel** | Bloodstone/Sunstone (`tower_shandianlian`) mot ensam fiende | `chain.lua`: när inget nytt mål finns behåller repeat-slingan den senast poppade, redan träffade enheten. Kedjan gör därför alltid `Count` = 5 träffar och studsar fram och tillbaka. Mot en ensam boss blir det 5 × 500 magisk skada per utlösning. | 1 träff. Vi kräver obesökta mål. | Följ källan: tillåt återbesök när inga obesökta finns (som cask/chain frost redan gör). Avgör om källans buggbeteende ska följas. Det påverkar främst bossar och glesa vågor. |
| 4 | **Medel** | Emerald Golem (`tower_shihua_new`) | `gazeNew`: antal mål = 5 + floor(MVP-nivå/2), alltså upp till 10. Mål väljs `FIND_CLOSEST` från tornet. Ormprojektil med 2000 i hastighet. | Alltid 5. Målen tas i fiendelistans ordning (spawnordning), inte närmast först. Effekten är omedelbar. | Använd MVP-nivån och närmast först. Projektilfördröjningen är en mindre detalj. |
| 5 | **Låg–medel** | Torrent-fällan (`new_torrent*`) | DelayedAction gör `%AbilityDamage / 2` magisk skada. På nivå 4 är det 300/2 = **150** utöver stun och slow. | 0 skada. Stun 2/4/8 s och slow stämmer. | Lägg till `damage: 150, damage_type: magical` i torrent-läget. Liten påverkan eftersom fiende-HP är stort sent. |
| 6 | **Låg** | Framgångsserien (fiendeantal) | `WinStreakAdjust` flyttar antalet ett steg per anrop; resten ligger kvar till nästa kill eller kontrollpunkt. | `adjust_streak` tar alla steg direkt (`while`). Efter en läcka på −177 blir det 7 i stället för 9 fiender tills nya händelser kommer. | Byt `while` mot `if` för att följa källan exakt. Testet `check_campaign.gd` förväntar sig dagens beteende och måste uppdateras samtidigt (röd zon). Slutresultatet blir oftast detsamma efter några kills. |
| 7 | **Låg** | Sea Jewel (`tower_chain_frost`), flera i närheten | `TriggerShiban`: det n:te tornet i radien har chansen p/n (`RandomInt(1,100·count) ≤ p`). | Varje Sea Jewel får fullt p (15/30/60 %). | Följ källans avtagande chans. Påverkar bara labyrinter med flera Sea Jewels. |
| 8 | **Låg** | Chain frost-detaljer | Ministun 0,1 s bara vid första målet (`OnSpellStart`). Studsar även på magiimmuna mål (slow fastnar, skadan blir 0). Lichs `ChainFrost`-skript väljer studsmål (troligen slumpvis i radien; skriptet finns inte lokalt). | Ministun vid varje studs. Magiimmuna utesluts. Närmaste mål väljs. | Liten påverkan. Ta med vid nästa fällpaket. |
| 9 | **Låg** | Venom-fällan (`new_venomous_gale*`) | `LinearProjectile` med 600/400/200 i hastighet över 1200/1600/2000 enheter. Fiender som går in i banan under färden träffas. Guld färdas cirka 10 s. | Omedelbar linjekontroll vid utlösningen. Bara fiender som redan står i linjen påverkas. | Simulera projektilens rörelse. Påverkar främst guldnivån, som i källan träffar fler. |
| 10 | **Låg** | Dread-/Entangle-fällor, fördröjning | Dread: projektil 1500. Entangle: varje mål får en slumpad fördröjning på 0,01–0,5 s (`Timers:CreateTimer(RandomInt(1,50)/100)`). | Omedelbart. | Försumbart. Dokumentera som anpassning. |

### Osäkra punkter (behöver källverifiering eller matchmätning)

- **Splash och burst efter crit:** `jianshe*` och `ranjin` får `Damage = %attack_damage` från `OnAttackLanded`. Om värdet innehåller crit gör Koh-i-Noor och Huge Pink Diamond 5× splash vid kritiska träffar. Vi använder skadan utan crit (`raw`). Kan ge stor skillnad för Koh-i-Noor. Bör mätas i en riktig Dota-match.
- **`DAMAGEOUTGOING_PERCENTAGE` (Cat's Eye +30 %, Howl):** vi lägger det på grundattack, splash och multiskott. Källans multiskott använder `GetAverageTrueAttackDamage` + `ApplyDamage`, vilket troligen *inte* tar med utgående procent. Liten effekt.
- **Refraction** (`refraction.lua`) och **Lichs chain frost-skript** finns inte lokalt. Våra 7 laddningar, 60 s och 5 s cooldown kan inte kontrolleras här.

## Område för område

Teckenförklaring: ✅ stämmer med källan och fungerar i motorn · ⚠️ avvikelse (se tabellen ovan) · 📄 dokumenterad, godkänd avvikelse.

### 1. Grundtorn, kvaliteter och odds

| Del | Källa | Vi | Status |
| --- | --- | --- | --- |
| 8 typer × 6 kvaliteter: skada, intervall, räckvidd, projektilhastighet | `units.json` (AttackDamageMin, AttackRate, AttackRange/128, ProjectileSpeed/128) | Identiskt (`verify_campaign`, 48 × 4 fält) | ✅ |
| Passiva förmågor per kvalitet (gift `tower_du1–6`, slow `tower_slow1–6`, armor `tower_jianjia1–6`, splash `tower_jianshe1–6`, speed/Opal-auror, Aquamarine +200/+500 AS, Diamond `tower_attack1/2/5`, Topaz multiskott, Emerald true sight) | `abilities.json` | Alla värden lika (genomläst sida vid sida). Splash: radie 300/350/400/450/500/700 och 30–100 % ren skada, inklusive huvudmålet (PASS i proben). | ✅ |
| Gift staplas (`MULTIPLE`), slow uppdateras | Attribut | Samma (PASS) | ✅ |
| Kvalitetsodds per oddsnivå | `_G.gem_gailv`, `ran > per` med `RandomInt(1,100)` | 100 / 80-20 / 60-30-10 / 40-30-20-10 / 10-30-30-20-10 | ✅ |
| Oddsinköp | Hjälte-XP 0/250/650/1200/1900 | Guldpris 250/400/550/700, manuellt köp | 📄 |
| Nedgradering | `gemtd_downgrade_stone`-vikter | Lika (`check_mechanics_parity`) | ✅ |
| Flygmål | Diamond/Ruby kan inte anfalla flygande i källan | Alla typer anfaller flygande | 📄 (användarbeslut 2026-10-24) |
| Attackhastighet | Dota-standard 20–700 | 20–700 | ✅/📄 (Valve-standard, inte uppmätt i GemTD) |

Oanvända källmodifierare `modifier_tower_poisonN` (−2…−20 % magiskt motstånd) definieras i giftförmågorna men appliceras aldrig i källan. Vi tar inte med dem. ✅

### 2. Specialtornen (43) och deras förmågor

Alla 43 kombinationstorns grundvärden (skada inklusive passiv `tower_attackN`, intervall, räckvidd, projektil) och alla 59 recept stämmer (`verify_campaign`). Förmågorna per typ:

| Förmågetyp | Torn (exempel) | Källvärde | Vi | Status |
| --- | --- | --- | --- | --- |
| Skadande auror `tower_huiyao/2/3` | Asteriated Ruby, Volcano, Antique Bloodstone, Burning Stone, Black Prince | 20 per 0,25 s / 250 per 0,5 s / 5000 per 2 s, radie 500/800/1000, `MULTIPLE` | Lika, staplas per källa | ✅ |
| Armor-/MR-/slowauror `bixi`, `bixi2`, `zheyi1-3`, `lanbaoshi1-2` | Paraiba, Geluan, Quartz, Lazurite, Yellow/Star Sapphire | −10…−30 armor, −10…−80 MR, −250/−500 konstant, −70/−80 % | Lika. Not-ancient och magiimmun-flaggor följer `Aura_Flags`. | ✅ värden · ⚠️ #1 MR-stapling |
| Gift `tower_du4–6`, `tower_jihan` | Jade, Ocean Jade, Sri Lanka | 16/32/128 per s i 10 s. Jihan: 400-radie, −50 %, −100 MR, ingen läkning, 128/s i 5 s | Lika | ✅ |
| Armorsänkning `tower_jin/jin2/jianjia6` | Gold, Egypt Gold, Koh-i-Noor | −32/−48 (2 s), −64 (5 s) | Lika | ✅ |
| Stun `tower_10jiyun` | Dark Emerald, Emerald Golem, Carved Tourmaline | 10 %, 2 s | Lika | ✅ |
| Petrifiering `tower_shihua_new` | Emerald Golem | 1 %, 5 s cooldown, 2,5 s, fysisk ×2 (DamageFilter), **5 + MVP/2 mål, närmast först** | 5 mål, listordning, ×2 fysisk | ⚠️ #4 |
| Crit `tower_baoji1` | Pink/Huge Pink, Cullinan, Koh-i-Noor | 10 % PRD, 5× | Lika (kalibrerad PRD) | ✅/📄 PRD-rekonstruktion |
| Kedja `tower_shandianlian` | Bloodstone, Sunstone | 30 %, 500 magisk, 5 träffar, 1000, 0,2 s | Lika, men stoppar utan nya mål | ⚠️ #3 |
| Shock `tower_chazhuangshandian` | Antique Bloodstone, Black Prince, Sunstone | 25 %, 4000 till målet + 4 längst bort inom 1000 (`FIND_FARTHEST`), magiimmuna utesluts | Lika | ✅ |
| Burst `tower_ranjin` | Guardian Stone | `RandomInt(1,100) < 15` → 14 %, 20× magisk, radie 400 | Lika | ✅ (osäker om crit, se ovan) |
| Multiskott `tower_fenliejian/_xianyan/_you` | Malachite, Vivid Malachite, Agate, U-235/238, Depleted | 3/6/12 extra, närmast först inom räckvidd, kan inte missa, fysisk | Lika | ✅ |
| Stöd: `maoyan` +30 %, `shechengguanghuan` +300 räckvidd (`MULTIPLE`), `jingzhun` kan inte missa, `chenmoguanghuan` magiimmunitet, `speed_aura_guichu` +160 AS | Cat's Eye, Red Coral, Ocean Jade, Huaguo, Cullinan, Armor Stone, Deep Sea Pearl | Radier 500/362/300/600/200 | Lika | ✅ |
| Greed `tower_tanlan` / Rejuvenation `tower_huichun_aura` | Egypt Gold / Lucky Chinese Jade | 5 % → 10× guld; 3 % → + fiendens läckvärde i liv | Lika | ✅ |
| Självavväpning `tower_aojiao` | Sunstone | 2 % PRD, 4 s | Lika | ✅ |
| Chain frost (`tower_chain_frost`) | Sea Jewel | 15/30/60 % per fällnivå inom 500, 12000 magisk, 10 studsar, −60 % i 5 s | Värden lika | ⚠️ #7, #8 |
| Natural Emerald | 72 tillåtna förmågor, ranged-donatorer inom 220, 3 olika, viktat | Lika (1.4.0) | ✅ |
| Guardian Stone, slumpad attack | N(512, 128), min 30 | Lika, återspelbar | ✅ |
| Kosmetiska `e100xx`/`e301` | Ingen spelverkan | Ingen | ✅ |
| True sight | Extern modifier, radie okänd | 900 (reservtolkning) | 📄 |
| MVP | +10 %/nivå, nivå 10 ger +100 % aura inom 290 (`MULTIPLE`), tak +500 %, `floor` i DamageFilter, bara våg ≤ 50 | Lika (PASS, `check_tower_effects`) | ✅ |

### 3. Fällorna (8 familjer × brons/silver/guld)

| Del | Källa | Vi | Status |
| --- | --- | --- | --- |
| Utlösning | `start_shiban_timer`: närmaste fiende inom 128 (1 ruta), även magiimmuna och flygande | 1 ruta, alla | ✅ |
| Cooldown | 10 s efter utlösning | 10 s | ✅ |
| Förmågenivå | `a_level = 5 − antal spelare` = 4 i solo | Nivå 4-värden för alla 24 | ✅ (PASS) |
| Entangle 1/8/64 mål, 192/1024/9999, 6 s stun | `Youbu1-3` + `new_youbu_sub` nivå 4 | Lika, utan 0–0,5 s fördröjning | ✅ / ⚠️ #10 |
| Venom −50/−80/−99 %, 18/21/24 s, linje 1200/1600/2000 | `new_venomous_gale*` | Värden lika, omedelbar linje | ⚠️ #9 |
| Torrent stun 2/4/8 s, slow −40/−60/−80 % i 14/16/18 s, radie 256, 1,6 s fördröjning, **150 magisk** | `new_torrent*` | Allt utom skadan | ⚠️ #5 |
| Howl +25/+75/+225 % utgående i 10 s, radie 384/512/768 | `new_haojiao*` | Lika | ✅ |
| Acid −14/−42/−126 armor i 10/15/20 s, 625 | `new_acid_spray*` | Lika (PASS) | ✅ |
| Paralysis 1/3/9 kaggar, 1/2/3 s stun, 12 studsar | `new_cask`, `Cask2/3`, `new_cask_sub2/3` | Lika (PASS) | ✅ |
| Dread +80/+160/+240 % mottagen skada, +25 % *snabbare* fiender, 12 s, 256/512/1024 | `new_konghe*` | Lika (även den positiva hastigheten följer källan) | ✅ |
| Ethereal −60/−120/−180 MR (decrepify unique), −50/−70/−90 %, 8/12/16 s | `new_xuwu*` | Lika | ✅ värden · ⚠️ #1 |
| Uppgradering | Tre lika i rak linje (även diagonalt) | Två lika var som helst | 📄 (användarbeslut 2026-10-24) |
| Placering | Hjältebyggd nära fiender är förbjuden inom 192 | Före strid / i byggfas | 📄 |

### 4. Guldförmågorna (paket A)

| Förmåga | Källa nivå 1 | Vi | Status |
| --- | --- | --- | --- |
| Gem Pray × 8 | 200 guld, `RandomInt(1,100) < 40` → 39 % | Lika (`check_spells` över 2000 seeds) | ✅ |
| Quality Pray III/IV/V | 200/200/400, 49/28/5 %, ersätter slumpad kvalitet, högst en lyckad per runda (`_G.perfected`) | Lika | ✅ |
| Heal | 300, `RandomInt(1,10)`, tak 100 | Lika | ✅ |
| Hjältebundenhet, nivåer, cooldowns, skydd mot bortkastat guld | Se `gold-spells.md` | Anpassat | 📄 |

### 5. Vågor, fiender och bossar

| Del | Källa | Vi | Status |
| --- | --- | --- | --- |
| 50 grundvågor: ID, HP × 0,69, hastighet × 0,69, armor, MR, flyg, förmågor | `guai`, `guai_ability`, `gem_difficulty[1]` | Lika (`verify_campaign`, 100 vågor) | ✅ |
| Alternativa vågor (17) och bossar (5), slump/kalender | `start_shuaguai` | Lika | ✅ |
| Prövningar: HP /3 flyg, 2 slumpförmågor (momian /5, wumian /3), >10000 → 999999999 annars ×100000, hastighet ×1,8 | Spawnkoden 3402–3485 | Lika | ✅ |
| Läckskada våg 1–50 | 1–3, 1–7, 1–11, 1–15, 1–19; boss 100 | Lika | ✅ |
| Läckskada våg 51–100 | 1–27 … 1–59 | 1–23 … 1–39 | ⚠️ **#2** |
| Bossläcka | `AdjustBossAttackDamage`: kvarvarande HP-procent | Omedelbar förlust | 📄 (beslut 45) |
| Fiendeförmågor: evasion 50 %, wumian ×0,25 fysisk, momian, high armor +4 (`MULTIPLE`, 500, även på sig själv), disarm-aura 150, recharge 0,3 %/s, jili 20 % (10 % flyg) vid kontrollpunkt, thief 1 %, blubber 80000/10 s, bulwark 70/30 %, windrun +50 % i 20 s, bukeqinfan 50 % PRD 1 s | `abilities.json` / `mode.lua` | Lika | ✅ |
| Blink | `ceil(n/35)` vägpunkter framåt | 925 världsenheter | 📄 |
| Refraction | `refraction.lua` saknas lokalt | 7 laddningar | osäker |
| Berserk | 180 s, +100 % och magiimmunitet | Lika | ✅ |
| Slumpeliter (1/400), veckoteman | Finns | Saknas | 📄 |

### 6. Ekonomi, serie, MVP och bossrabatt

| Del | Källa | Vi | Status |
| --- | --- | --- | --- |
| Killguld 5/10/15/20/25, boss 300 XP → 150 guld, prövningar 5 | `OnEntityKilled` | Lika | ✅ |
| Serie: +0,75 kill, +10 boss, −3 × läckskada, kontrollpunkter 0/.05/.10/.20/.40 × läckvärde, ±50 ger ±1 fiende, minst 5 | `WinStreakAdjust`, `OnThink` | Värden lika, men alla steg tas på en gång | ✅ / ⚠️ #6 |
| Startliv 100, startguld 0 | — | Lika | ✅ |
| Bossrabatt 150 per grundboss 10–50, bara för oddsköp | Ingen motsvarighet (XP) | Godkänd anpassning | 📄 |
| Prövningsflöde: ingen byggfas efter 50, kombinationer under strid | `start_build` | Lika; 3 s mellanrum | ✅ / 📄 |

## Förslag till åtgärdspaket (kräver godkännande, röd zon)

1. **Paket 1 – datafel:** prövningarnas läckband (#2) och Torrent-skadan (#5). Ändras i `tools/build_campaign.py`, `tools/verify_campaign.py` och `data/campaign.json`. Kräver höjd innehållsversion och ny sparfil.
2. **Paket 2 – motorregler:** multiplikativt magiskt motstånd (#1), kedjans återbesök (#3), Emerald Golems MVP-antal och närmast först (#4). Ändras i `game/core/`. Kräver nya replays med `tools/audit_campaign.gd` och `verify_reviews.py`, eftersom gamla rapporter inte längre återspelas likadant.
3. **Paket 3 – detaljparitet:** serie-steg per anrop (#6), Sea Jewels p/n (#7), chain frost-detaljer (#8), Venom-projektil (#9), fördröjningar (#10).
4. **Mätning:** avgör om splash/burst ska använda crit-skadan med en riktig Dota-match eller en Valve-dokumenterad källa innan något ändras.

Efter godkända ändringar: kör `python tools/redesign_guard.py --baseline` (bara efter godkännande), `python tools/check.py` och den nya proben. Proben ska då visa färre `DEVIATION`-rader.

## Genomfört: paket 1 (2026-10-28, godkänt av användaren)

- `tools/build_campaign.py`: `leak_max` följer källans band (våg 51–99: 27/35/43/51/59, även för varianter). Torrent-läget får `damage` = `AbilityDamage` nivå 4 / 2 = 150, magisk. Innehållsversion 10 → **11**, ny sparfil `run_campaign_v11.json`, ny leaderboardidentitet (content_version 11).
- `game/core/campaign_combat.gd` (`execute_delayed`): Torrent gör skadan en gång vid nedslaget, på samma mål som får stun och slow (magiimmuna undantas, som i källan). Skadan blir inte en DoT-modifierare.
- `tools/verify_campaign.py`: kontrollerar läckintervallet för alla 100 vågor och Torrent-skadan (2052 kontroller, 0 fel). `tools/test_prepare_web_beta.py` förväntar version 11.
- Kontroller: `python tools/check.py` → `CHECKS_OK`. Proben → `BALANCE_REVIEW_CHECK_OK checks=15 failures=0 deviations=4` (kvar: #1, #3, #4, #6). Fem naturliga botomgångar (`output/campaign-v11`) ger exakt samma ticks som före ändringen (14538/13698/13417/12897/15135, förlust vid boss 10) och återspelas oberoende 5/5 (`output/campaign-v11-replays.json`). Boten når inte prövningarna eller bygger Torrent, så ändringarnas balanseffekt är inte speltestad.

## Genomfört: paket 2 (2026-10-28, godkänt av användaren)

- **#1 Magiskt motstånd:** `GemCampaignRules.merge_properties` för nu även `magic_factor` = Π(1 − rᵢ/100) för varje `magic_resist`-källa. `refresh_defenses` sätter motståndet till `1 − (1 − bas) · magic_factor`. Den summerade `magic_resist` behålls för visning. Samma modifiernamn staplas fortfarande inte, och unika decrepify-källor (Ethereal) skriver över varandra som förut.
- **#3 Kedjeblixt:** när inga obesökta synliga mål finns tar `execute_delayed` den sista enheten i källans närmast-först-sökning inom 1000, det nuvarande målet inräknat, och fortsätter tills fem träffar har gjorts. Gäller bara `tower_shandianlian` (Bloodstone, Sunstone och Natural Emeralds kopia); cask och chain frost är oförändrade.
- **#4 Emerald Golem:** antal mål = 5 + floor(MVP/2), sorterat närmast tornet. Tooltipen säger "+1 per 2 MVP levels".
- Innehållsversionen är kvar på **11**: `data/` är oförändrad i paket 2, och version 11 har inte distribuerats. Motoridentiteten ändras ändå, så rapporter som gjorts med paket 1-motorn ska inte jämföras med nya.
- Kontroller: `python tools/check.py` → `CHECKS_OK`. Proben → `BALANCE_REVIEW_CHECK_OK checks=19 failures=0 deviations=1` (kvar: #6). 20 naturliga botomgångar (`output/campaign-v11-pkg2`) förlorar alla vid boss 10 och återspelas oberoende 20/20 (`output/campaign-v11-pkg2-replays.json`). Seed 1–5 ger samma ticks som före paketen, eftersom boten inte använder de berörda tornen före våg 10.
- **Inte mätt:** balanseffekten sent i spelet. `tools/audit_late_game.gd` kördes (alla förbyggda fall förlorar eller är kvar i byggfasen, som tidigare), men den enda sparade jämförelsen kommer från 1.3.0-dev och är inte ett rent före/efter-mått. Multiplikativt motstånd ger mindre magisk skada mot fiender med positivt grundmotstånd och få reduktioner, men betydligt mer när flera stora reduktioner staplas (Sri Lanka + Geluan/Guardian + Ethereal-fälla). Speltest behövs.

### Ny iakttagelse vid genomförandet (inte åtgärdad)

`chain.lua` stoppar kedjan om det *föregående* målet har dött (`ShanDian` kräver `old:IsAlive()`). Vår kedja hoppar vidare från ett dödat mål. Det gör källans kedja svagare mot svaga fiender. Föreslås som en del av paket 3.
