# Guldförmågor – paket A (2026-10-24)

Användarens beställning: guld blir liggande när kvalitetsköpen är klara. Inför Dota-hjältarnas **Gem Pray**, **Quality Pray** och **Heal** som guldförmågor under byggfasen, med källans nivå 1-värden, och kontrollera balansen med replays.

## Källa

`.tools/reference/abilities.json` (`AbilityValues`, första nivån) och `mode.lua` (snapshot 2026-08-01). Lua körs inte; värdena förs in av `tools/build_campaign.py` som `spells` i `data/campaign.json` och kontrolleras av `tools/verify_campaign.py`.

| Förmåga | Källa | Kostnad | Effekt nivå 1 |
| --- | --- | --- | --- |
| Gem Pray (8 st: Sapphire, Diamond, Aquamarine, Opal, Emerald, Topaz, Ruby, Amethyst) | `gemtd_hero_lanse/baise/fense/danbai/lvse/huangse/hongse/zise` | 200 | `gailv` 40: nästa gem blir den typen om `RandomInt(1,100) < 40`, alltså **39 %**. Annars vanlig typslump (1/8). |
| Quality Pray III (Common) | `gemtd_hero_putong`, nivå `"111"` | 200 | 50 → **49 %** att nästa gem blir kvalitet III |
| Quality Pray IV (Flawless) | `gemtd_hero_wuxia`, nivå `"1111"` | 200 | 29 → **28 %** kvalitet IV |
| Quality Pray V (Perfect) | `gemtd_hero_wanmei`, nivå `"11111"` | 400 | 6 → **5 %** kvalitet V |
| Heal | `gemtd_hero_huichun` (`gemtd_jidihuixue`) | 300 | `RandomInt(1,10)` liv, högst upp till slottets max (100) |

Typerna följer `pray_color` i `mode.lua` mot `_G.gem_tower_basic` (b/d/q/e/g/y/r/p).

## Regler som följer källan

- Slumpordning vid placering: kvalitetsslag → quality pray → typslag → type pray. Utan aktiva prays dras exakt samma två slag som tidigare, så gamla seeds och replays ger samma gems.
- En pray gäller bara nästa gem och förbrukas då, oavsett utfall.
- En lyckad quality pray **ersätter** det slumpade värdet, även om gemmen redan blev bättre (t.ex. V → III). Det är källans beteende (`stone_level = pray_level`).
- Högst en quality pray kan lyckas per runda (källans `_G.perfected`, som nollställs vid vågstart).
- Prays nollställs vid vågstart.
- Heal når högst 100 liv (källans `GetMaxHealth`).

## Avvikelser och anpassningar

- **Ingen hjälte:** alla tolv förmågor finns för alla. I Dota har varje hjälte bara några av dem och nivån höjs med XP. Vi använder alltid nivå 1.
- **Inga cooldowns:** källans 3 s (prays) och 10 s (heal) betyder inget i en byggfas utan klocka.
- **Skydd mot bortkastat guld:** en andra pray av samma slag nekas medan en väntar, liksom quality pray efter en lyckad i samma runda, prays efter femte placeringen och heal vid fulla liv. I källan dras guldet ändå.
- **Tidpunkt:** prays bara i byggfasen före en placering och bara i våg 1–50 (prövningarna saknar nya gems). Heal i byggfasen och i prövningarnas mellanrum, aldrig under strid.
- **Bara kampanjen:** profilerna review-v1 och expanded-gems har inga förmågor.
- Heal och lyckade prays drar från samma byggslump (`rng`) som gemmen, likt källans gemensamma `RandomInt`. Sparfilens format är oförändrat: sparpunkten ligger i början av byggfasen, före eventuella köp.

## Gränssnitt

Kortet **Gold spells** i sidopanelen under gemoddsen: åtta gemikoner, tre kvalitetsknappar (III/IV/V med pris) och **Heal 1–10 lives · 300 gold**. Hovring visar verklig chans och pris, och skälet när en knapp är låst. En väntande pray lyser och visas under knapparna. Help → Gem purchases → Gold spells beskriver reglerna.

## Verifiering

- `tests/check_spells.gd` (30 fall, ingår i `python tools/check.py`): data, oförändrad RNG utan prays, kostnader, nekade lägen, frekvenser över 2 000 seeds (Ruby ≈ 39 % + 61 %/8, III ≈ 49 %, V ≈ 5 %), ersatt kvalitet, en lyckad per runda, heal 1–10 med tak 100, oberoende replay med förfalskad heal som avvisas, samt sidopanelens kort.
- `python tools/godot.py --headless --path . --script res://tests/check_spells.gd -- --campaign --smoke` ska ge `SPELLS_CHECK_OK`.

## Balanskontroll med replays

Automatisk bot (`tools/audit_campaign.gd`, girig labyrint, verklig RNG och ekonomi). Alla rapporter är oberoende återspelade med `tools/verify_reviews.py`.

| Körning | Seeds | Klarade boss 10 | Medelvåg | Prays (lyckade IV) | Heals | Replays |
| --- | --- | --- | --- | --- | --- | --- |
| Utan förmågor (ordinarie) | 1–5 | 0/5 | 10 | – | – | 5/5 OK, `docs/reports/campaign-replays.json` |
| `--spells` (bara överskott över nästa oddspris) | 1–5 | 0/5 | 10 | 0 | 0 | 5/5 OK, `docs/reports/campaign-replays-spells.json` |
| `--spells-first` (Flawless pray varje runda före oddsköp) | 1–5 | 2/5 | 13,4 | 12 (2) | 0 | 5/5 OK, `docs/reports/campaign-replays-spells-first.json` |
| Utan förmågor | 1–20 | 0/20 | 10 | – | – | `output/spells-compare-base/` |
| `--spells-first` | 1–20 | 8/20 | 13,6 | 58 (19) | 0 | 20/20 OK, `output/spells-compare-first-replays.json` |
| Kontroll `--late-odds`: inga förmågor, inga oddsköp före våg 11 | 1–20 | 5/20 | 11,8 | – | – | `output/spells-compare-late-odds/` |

Slutsatser:

- **Oförändrat spel utan förmågor:** de ordinarie fem omgångarna gav exakt samma ticks och utfall som före ändringen (14538/13698/13417/12897/15135).
- **Prayens egen effekt är liten i underlaget:** av de 8 spells-first-omgångar som klarade bossen hade bara 2 fått en lyckad IV-pray före våg 10, och de flesta omgångar med tidig IV-träff dog ändå vid våg 10. Kontrollen utan prays men med senare oddsköp når 5/20. Den största delen av skillnaden kommer alltså av att boten inte köper odds tidigt, inte av prayen. Skillnaden 8/20 mot 5/20 ryms i slumpen vid 20 seeds.
- **Sidofynd (ej åtgärdat):** boten klarar sig bättre när den skjuter upp oddsköpen. Det säger något om botens tornval, inte nödvändigtvis om spelbalansen.
- **Heal användes aldrig:** boten förlorar på bossläckor (omedelbar förlust) och kommer inte långt nog för att få guldöverskott. Heal kan aldrig rädda en bossläcka.
- **Ekonomi (data, ungefärligt):** inkomsten är ungefär 75/120/165/210/255 guld per våg i vågintervallen 1–10/…/41–50 och 46 per våg i prövningarna. Efter oddsköpen (1 900 minus bossrabatt) räcker överskottet i våg 20–50 till ungefär en pray per runda; i prövningarna ungefär en heal var sjätte–sjunde våg.
- **Ej mätt:** sent spel med mänsklig strategi. Boten når aldrig våg 20+, så hur Gem Pray påverkar receptjakten sent i spelet måste speltestas.

Kommandon:

```powershell
python tools/godot.py --headless --path . --script res://tools/audit_campaign.gd -- --campaign --smoke --runs=20 --spells-first --output=res://output/spells-compare-first
python tools/verify_reviews.py --campaign --folder=output/spells-compare-first --result=output/spells-compare-first-replays.json
```
