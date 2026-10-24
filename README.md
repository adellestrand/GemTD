# GemTD Solo

En spelbar, fristående Godot-prototyp inspirerad av Dota 2 GemTD. Bygg en labyrint, placera fem slumpade gems och välj ett torn att behålla. Slutvalet startar vågen direkt.

37×37 rutor och sju kontrollpunkter. Kampanjprofilen har åtta grundtyper med sex kvaliteter, 50 grundvågor plus 50 prövningar, 59 receptalternativ och 24 stentavlor. Mark/luft, receptsökning, målprioritet, gemchansköp, MVP-progression, rivning, paus, dubbel hastighet, zoom, ljud och lokala sparpunkter ingår. Den äldre tiovågsprofilen finns kvar som jämförelse.

**Version 1.0.0 är paketerad för lokal granskning:** `builds/release/GemTD-1.0.0-local-review.zip`. Packa upp och starta `Windows/GemTD.exe`, eller `Web/Start-Web.cmd` (Python behövs för webbservern). Se [testguiden](docs/testguide-v1.md), [release notes](docs/release-notes-v1.md) och [balansunderlaget](docs/balance-v1.md). Originalets torn-/fiendegrundvärden är kontrollerade; ekonomi och vågföljd är tiovågsanpassningar. Full skadeparitet och mänsklig balansgranskning återstår.

**Aktuell kampanj:** [spela 1.3.0-dev](http://127.0.0.1:8060/?profile=campaign), eller välj **Run → Solo campaign · 100 waves**. Native: `tools/run.ps1 -Campaign`. Skott följer nu målen med riktig flygtid; skada och träffeffekter sker vid träff. Strid och tornpanel använder samma tak på 700 total attackhastighet. Tre uttryckliga PRD-händelser använder utjämnad slump. Version 1.3 lägger till stridsdiagnostik, rättade auraklockor och utbytbara kartmärken för kvaliteter, specialtorn, stentavlor och fiendetillstånd. Se [femstegsundersökningen](docs/investigation-five-steps.md). Varje besegrad grundboss ger 150 sparad rabatt på manuella gemchansköp; guld och grundpriser behålls. Se [kampanjens innehåll, tester och avvikelser](docs/campaign-review.md). Mänsklig balansgranskning och faktisk jämförelse med Dota-motorn återstår.

Separat kampanjpaket: `builds/release/GemTD-campaign-1.3.0-dev.zip`. Packa upp och starta **Windows/Start-Campaign.cmd** eller **Web/Start-Web.cmd**. Paketeraren kontrollerar CRC och SHA-256. Äldre 1.0-, 1.2.0-, 1.2.1- och 1.2.2-paket bevaras. Nya kampanjen använder en egen v7-sparfil; gamla sparpunkter migreras inte till ändrade stridsregler.

Den tidigare **1.1.0-dev** med sex kvaliteter och Jade kan fortfarande provas med `tools/run.ps1 -ExpandedGems` eller `?profile=expanded-gems`. Alla profiler har separata sparfiler. [Grafikgranskningen](docs/graphics-review-campaign.md) beskriver nästa steg för identitet och animationer.

## Starta på Windows

Kräver Windows x64, Python 3.10+ och PowerShell. Kör från repots rot:

```powershell
powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1
```

Bootstrap hämtar **Godot 4.7.2-stable** och exportmallar från den officiella releasen och kontrollerar fasta SHA-256-värden. Verktygen ligger i gitignorerade `.tools/`. Använd `-SkipTemplates` om du bara vill köra projektet och hoppa över den stora mallhämtningen.

Godot-editorn kan öppna `project.godot`. Den portabla editorn startas med `python tools/godot.py --editor --path .`.

## Exportera och spela i webbläsaren

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Web
```

Öppna [http://127.0.0.1:8060](http://127.0.0.1:8060). Webbexporten använder WebGL 2 och en tråd utan krav på COOP/COEP-headers. Öppna genom webbservern; dubbelklicka inte på HTML-filen.

Windows-exporten finns i `builds/windows/GemTD.exe`. Behåll `GemTD.pck` bredvid exe-filen. Ingen publik uppladdning görs.

## Ändra och granska grafik

[Grafikförhandsvisning i webbläsaren](http://127.0.0.1:8060/?view=art) samlar torn, kvaliteter och fiender. **Board scale** visar bilder i spelstorlek; **Combat & motion** visar levande skott-, träff- och rörelseloopar med paus. Lokalt öppnas samma vy med `powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1` (lägg till `-Motion` för levande effekter direkt).

Bilder, storlekar, ankare, färger och kopplingar ändras i `assets/graphics/manifest.json`; gränssnittets utseende ligger i `assets/graphics/ui_theme.tres`. Både spriteark och separata PNG-filer stöds, även en egen bild för en enda kvalitetsnivå. Se [instruktioner och exempel](docs/graphics.md).

Även rörelse och stridseffekter styrs från manifestet. Paus och 2× följer simuleringen. Attackljudet är separat och begränsat i frekvens. Se [utforskande speltest med 20 vanliga omgångar](docs/playtest-report.md) för första underlaget om senare vågor; inga balansvärden har ändrats utifrån det.

## Spela

1. Klicka fem lediga rutor. Varje godkänd placering avslöjar en gem. Nya placeringar är bindande.
2. Välj en ny gem och **Keep**, kombinera två/fyra lika eller skapa ett recept med nya material. Valet startar striden direkt; resterna blir stenar.
3. Mellan vågorna kan du riva stenar/äldre torn gratis och kombinera äldre material utan att förbruka rundans tornval.

De fem små knapparna ovanför spelplanen väljer rundans avslöjade gems. Peka på en tom ruta för att se giltighet och förhandsvisad markrutt. Peka på ett byggval för att se material, resultatplats och vad som blir sten innan du klickar. Otillgängliga val förklarar varför. Omgångens seed visas längst ned för återkoppling och reproduktion.

Tornpanelen visar vald kvalitets effekt, aktuell attackhastighet inklusive Aquamarine-/Opal-bonusar, räckvidd och tillåtna mål. **Attack DPS** gäller grundattack mot ett mål före försvar; gift, splash och extra mål redovisas separat. Asteriated Ruby visar i stället aurans tickskada och DPS. Peka på Keep/Combine/recept för resultatets värden och jämförelse. Den förhandsvisningen räknar bort stöd från gems som blir stenar, medan tornpanelen visar den nuvarande spelplanen.

Efter en våg visas dess besegrade fiender, läckor och förlorade liv under spelplanen. Sammanfattningen gäller senaste vågen i den aktuella körningen; återladdning återställer byggsparpunkten och visar inte en tidigare sessions sammanfattning.

**Recipes** visar porträtt, exakta kvaliteter och antal ägda/saknade ingredienser. **Locate on board** väljer och centrerar en ägd gem; upprepning växlar mellan matchande gems. **Track on board** fäster ett recept med markeringar och löpande ingrediensräkning. Avsluta med **Unpin** under spelplanen. Dessa val kombinerar inga torn. Receptboken pausar striden och återställer tidigare pausläge när den stängs.

**Waves** visar profilens samtliga vågor, 100 i kampanjen, med porträtt, mark/luft, liv, hastighet, försvar, belöningar och läckkostnad. Välj en våg för att se hur dess grundförsvar påverkar en träff på 100 rå skada och hur många av dina torn som kan välja dess måltyp. Nya gems räknas separat från behållna torn. Översikten pausar striden och återställer tidigare pausläge när den stängs. Inspektion startar eller byter ingen våg.

Kombinationens resultat hamnar på den valda materialrutan. Gemchanser kan köpas även under strid. Bossläcka innebär omedelbar förlust.

| Styrning | Funktion |
| --- | --- |
| Vänsterklick | Placera eller välj |
| Mushjul / mittersta musknappen + dra | Zoom / panorera |
| F / R | Anpassa kameran / visa stridsrutter |
| Mellanslag / 1 / 2 / M | Paus / normal / dubbel hastighet / mute |
| Run-menyn | Samma/ny seed, byggsparpunkt, eget seed och kopierbar testrapport |

Sparning sker vid **början av byggfasen**, inte mitt i strid. Webben sparar per lokal webbadress i webbläsarens IndexedDB. Direktstartad Windows-export använder Godots `user://` under AppData; utvecklingsskripten isolerar sin sparning i `.tools/userdata/`.

## Tester och projektunderlag

```powershell
powershell -ExecutionPolicy Bypass -File tools/test.ps1
# Efter export: kontrollera även den fristående Windows-filen
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Exports
# Rendera Windows-exporten och verifiera att ljud genereras
python tools/smoke_windows.py
```

- [Utveckling, arkitektur och verktygsval](docs/development.md)
- [Faktiska testresultat](docs/teststatus.md)
- [Källor och avvikelser](docs/referensinventering.md)
- [Prototypplan](docs/prototypplan.md) och [de 61 besluten](docs/prototyp-beslutsunderlag.md)
- [Grafisk stilreferens](docs/referenser/pixelgrafik.png)

Spelet använder egen kod, egna genererade bilder och syntetiska ljudeffekter. Dota-installation krävs inte för att köra eller bygga. Referenspaketets Lua och spelgrafik följer inte med i projektet.
