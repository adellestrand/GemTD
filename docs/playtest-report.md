# Utforskande speltest 2026-10-23

20 automatiska omgångar, seed 1–20, med Godot 4.7.2 och oförändrad innehållskatalog. Alla börjar med vanliga 30 liv, 0 gold och inga extra torn. Fem riktiga bindande placeringar per byggfas, normal RNG, köp av gemchanser för intjänade pengar, lagliga kvalitetsuppgraderingar och specialrecept används.

## Strategins begränsning

Detta är en enkel baslinje, inte en mänsklig spelare eller en optimerad GemTD-bot. Placering värderar täckning av den aktuella rutten; tornval använder en grov DPS-/effektskattning. Botten köper bättre chanser tidigt, kombinerar äldre material när skattningen ger en förbättring och använder tillgängliga nya recept. Den planerar inte en labyrint, sparar inte avsiktligt material till framtida recept, river inte för att omdirigera fiender och planerar inte flera vågor framåt. Tornvalets täckningsskattning använder markrutten även när nästa våg flyger.

Ingen automatisk ändring av tornvärden, ekonomi eller fiender har gjorts efter resultaten.

## Observerat

| Resultat | Antal |
| --- | ---: |
| Vinst | 0/20 |
| Förlust på våg 7 | 3 |
| Förlust på våg 9 | 9 |
| Nådde bossen på våg 10, förlust där | 8 |

Alla 20 klarade våg 1–4 utan livförlust. Våg 5 gav i snitt 0,2 förlorade liv, våg 6 1,05 och våg 7 4,95. De 17 omgångar som nådde våg 8 klarade den utan livförlust; på våg 9 kostade hounds i snitt 19,47 liv bland dessa omgångar. Ingen av de åtta bossomgångarna besegrade bossen.

Det pekar ut **våg 9 och bossen som fokus för mänskligt speltest**, och ett tydligt hopp mellan våg 8 och 9 för denna strategi. Det bevisar inte att spelet är omöjligt eller för svårt: labyrintbyggande, bättre receptplanering och målprioritet kan ändra utfallet mycket. Det ger heller ingen uppskattning av mänsklig vinstchans.

## Reproducera och granska

```powershell
python tools/godot.py --headless --path . --script res://tools/audit_runs.gd -- --runs=20
```

Kommandot skriver alla seed-/vågutfall till `output/balance-audit.json`. Detta är ett utforskande verktyg utanför den automatiska regressionssviten; vinstprocent är ingen testassertion. En utebliven fasövergång eller ogiltig vald handling ger däremot fel.

Den granskade körningens [rårapport](reports/balance-audit-v1.json) bevaras med motorversion och SHA-256 för katalog, kärnmodell och botverktyg. Den gamla förbyggda tiovågs-fixturen finns kvar som separat test av fasflöde och bossvinst.

Nästa användarspeltest behöver bedöma hur lätt typ/kvalitet/effekter går att läsa, vilka val som känns meningsfulla och hur ett avsiktligt labyrintbygge klarar de senare vågorna. Balansändringar bör utgå från detta tillsammans med referensmålet, inte enbart från botresultatet.
