# GemTD Solo

Fristående solospel inspirerat av Dota 2 GemTD. Bygg en labyrint, placera fem
slumpade gems och välj torn att behålla och kombinera. Godot 4.7.2, GDScript
och pixelgrafik; samma projekt för Windows och webb.

**Aktuell utvecklingsversion: 1.4.1-dev · innehållsversion 12.** Kampanjen är
spelbar och automatiskt verifierad. Mänskliga kampanjtester och slutbalansering
återstår; full likhet med Dotas motor är inte uppmätt.

## Dela webbversionen

Spela och dela: [GemTD Solo på GitHub Pages](https://adellestrand.github.io/GemTD/).
Publicering startas manuellt under **Actions → Publish web beta → Run workflow**.
Workflow kör tester och exporterar innan sidan ersätts. Den publika länken väljer
kampanjen direkt. `build.json` visar vilken commit och innehållsversion som körs.
Se [publiceringsflödet](docs/web-beta-and-leaderboard.md).

Gemensam topplista finns under **Run → Leaderboard**. Skicka en avslutad, ny
kampanjomgång med valfritt visningsnamn; ingen e-post behövs. Bästa resultat per
spelare sorteras på avklarade vågor och liv, separat för varje balansversion.
Resultat märks **unverified**. Se [leaderboard: användning och drift](docs/leaderboard.md).

## Innehåll

- 37×37 rutor, sju kontrollpunkter, 50 grundvågor och 50 prövningsvågor.
- Åtta gemtyper med sex kvaliteter, 43 kombinationstorn, 59 receptalternativ och
  24 stentavlor inklusive uppgraderingar.
- Källbaserade torn-/fiendevärden, adaptivt fiendeantal, alternativa fiender och
  bossar, verklig projektilflygtid, skadetyper, försvar, mark/luft och MVP.
- Gift, splash, multiskott, stun, förstening, auror och trapförmågor.
- Manuella gemchansköp med 150 sparad rabatt per besegrad grundboss.
- Fem tornflyttar **per hel omgång** under byggfasen, inklusive byte med sten.
- Receptbok med Locate/Track, vågöversikt, labyrintförslag, målprioritet, paus,
  2× hastighet, zoom, ljud, seeds och återspelbara testrapporter.
- Egna bilder för alla 43 kombinationstorn, animerade fiender och effekter som
  följer verkliga träffar, skadetick och tillstånd.
- Tornpanel med stödpåverkad skada/DPS, separata auravärden och listan
  **AFFECTING THIS TOWER** för MVP, stödkällor och tillfälliga effekter.
- MVP 10 med guldkrona, räckviddsring och markering av berörda torn.

Högerpanelen använder flikarna **Tower / Wave / Upgrades / Effects**, med fasta
byggkontroller utan menyskroll. Rundans nya gems markeras med gula hörn och
nummer 1–5 på både kartan och bildknapparna. Se [panel och gemmarkeringar](docs/sidebar-and-fresh-gems.md).

## Starta från källkod

Kräver Windows x64, Python 3.10+ och PowerShell. Kör från repots rot:

```powershell
powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Campaign
```

Bootstrap hämtar **Godot 4.7.2-stable** och exportmallar från den officiella
releasen med fasta SHA-256-kontroller. Verktygen placeras i `.tools/`.
`-SkipTemplates` hoppar över exportmallarna om du bara vill köra från källkod.
Öppna editorn med `python tools/godot.py --editor --path .`.

## Exportera och spela

```powershell
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Release
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Web -Campaign
```

Öppna [kampanjen](http://127.0.0.1:8060/?profile=campaign). Webben använder WebGL 2
och en tråd utan krav på COOP/COEP-headers. Öppna genom webbservern, inte genom
att dubbelklicka på HTML-filen.

Exporterna skapas i `builds/windows/` och `builds/web/`. Behåll `GemTD.pck` bredvid
`GemTD.exe`. Välj kampanj via Run-menyn eller starta Windows-exporten med:

```powershell
builds/windows/GemTD.exe -- --campaign
```

`.tools/`, `builds/` och `output/` följer inte med i Git. En ny klon behöver
bootstrap/import och export enligt ovan. En GitHub-push publicerar inga spelbyggen.

## Spela

1. Under grundvågornas byggfas placerar du fem gems och avslöjar deras typer och
   kvaliteter. Placeringarna är bindande.
2. Behåll en ny gem, uppgradera lika gems, nedgradera en gem eller skapa en
   kombination. Tornvalet startar striden och gör övriga nya gems till sten.
   Traprecept med nya gems ger ett placeringssteg före **Start wave**.
3. Äldre material kan kombineras utan att förbruka rundans tornval. Äldre vanliga
   torn kan även kombineras under strid. Traprecept, trapflytt, tornflytt och
   rivning görs före strid.
4. Prövningarna 51–100 ger inga nya gems eller byggfaser. Nästa våg startar efter
   tre simulerade sekunder; paus fryser nedräkningen. Gemchansköp stängs efter 50.

Mest skadegörande berättigade torn får en MVP-nivå efter varje avklarad grundvåg:
+10% egen skada per nivå. MVP 10 ger dessutom +100% skada till andra torn inom
290/128 rutor. Samlad MVP-bonus har +500%-tak. Maxade torn undantas från nya
MVP-belöningar; kombinationer för över nivåer med tak tio.

Bossläcka innebär omedelbar förlust. Efter 180 sekunders strid utlöses berserk:
fiender får +100% rörelsehastighet och magiimmunitet under resten av vågen.
Se [mekanikuppdateringen](docs/mechanics-update-1.4.md),
[tornflyttarna](docs/tower-relocation.md) och [kampanjgranskningen](docs/campaign-review.md).

| Styrning | Funktion |
| --- | --- |
| Vänsterklick | Placera eller välj; inspektera påverkan i sidopanelen |
| Mushjul | Zoom |
| Höger-/mittenknapp + dra, WASD eller piltangenter | Panorera |
| F / R | Anpassa kameran / visa stridsrutter |
| X / Delete | Riv vald sten eller valt torn (som Demolish selected) |
| Mellanslag / M | Paus / mute |
| 1 / 2 / 3 / 5 | Hastighet 1× / 2× / 3× / 5× (hastighetsknappen växlar mellan dem) |
| F11 | Helskärm |
| Run-menyn | Profil, omstart, seed, sparpunkt, rapport och visningsinställningar |

**Recipes** visar ingredienser, Locate och Track. **Waves** visar fiendestatistik
och progression. **Mazes** visar labyrintförslag. Översikterna pausar striden och
återställer föregående pausläge när de stängs.

Attack-DPS gäller vanliga primärträffar före försvar; kritiska träffar, gift,
splash och extra mål redovisas separat. Rena skadeauror visar tickskada,
intervall, DPS per fiende och auraradie. Hybrider visar attack och skadeauror
separat. [Skadevisning och MVP-markeringar](docs/quality-pass-stats-mvp.md).

Sparning sker i början av byggfasen och mellan prövningsvågorna. Omladdning
återgår till senaste sparpunkten, inte till en pågående strid. Kampanjen använder
`run_campaign_v12.json`; äldre innehållsversioner migreras inte. Webben sparar per
origin i IndexedDB. Windows använder Godots `user://` under AppData;
utvecklingsskripten isolerar sina sparfiler i `.tools/userdata/`.

## Grafik

Vald markstil är **A – grönt spelbräde**: PixelLab-gräs med en enkel separat
linje per rutgräns, utan extra innerkanter, hörnmärken eller schacktoning.
Sapphire I använder den godkända åttarutors ljuspulsen; vildsvinet har sin
åttarutors gång. Material och färger ligger i grafikmanifestet.

[Grafikverkstaden](http://127.0.0.1:8060/?view=art&profile=campaign) visar bilder,
spelstorlek, rörelse och läsbarhet. [Abilities](http://127.0.0.1:8060/?view=art&profile=campaign&abilities=1)
visar alla 43 kombinationstorn med riktiga förmågekörningar mot tåliga
testfiender. Det är en visuell demonstration, inte ett balansprov. Space pausar.

`assets/graphics/manifest.json` styr bilder, ankare, storlekar och kopplingar.
`ability-effects.json` styr effektfärger och projektilprofiler; `ui_theme.tres`
styr gränssnittet. Tornen centreras i sin ruta med maximal bildstorlek 0,94 rutor.
Separata versionsmärkta bilder gör det enkelt att byta ett torn åt gången.

Se [grafikflödet](docs/graphics.md), [tornbilderna](docs/special-towers-art-v1.md),
[förmågeeffekterna](docs/special-tower-effects.md) och [effektinspektionen](docs/tower-effects-inspection.md).
Färdiga bilder och animationsremsor ingår. För att återskapa grafik med `tools/art/`
behövs även Pillow/NumPy och för pxl-animationer separat
[claude-pxl](https://github.com/crsolver/claude-pxl) samt Node ≥22.18.
Ange miljövariabeln `PXL` som sökväg till dess `bin/pxl.js`. Lokala
skillinstallationer och arbetskopior under `.claude/` följer inte med i Git
och behövs inte för att spela.

## Tester

```powershell
python tools/check.py
# Efter export: prova även den fristående Windows-filen
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Exports
# Verklig Windows-rendering och verifierat attackljud
python tools/smoke_windows.py --campaign --attack
# Alla kampanjtorn vid fyra cellstorlekar
python tools/godot.py --headless --path . --script res://tests/check_cell_fit.gd -- --campaign --smoke
# Bildkopplingar och animationsremsor efter byte av grafik
python tools/godot.py --headless --path . --script res://tests/check_art.gd -- --campaign
python tools/godot.py --headless --path . --script res://tests/check_enemy_frames.gd -- --campaign
# Verklig pixelkontroll av rutlinjer vid fyra upplösningar (utan --headless)
python tools/godot.py --path . --script res://tests/check_terrain_grid.gd -- --campaign
```

Den ordinarie sviten innehåller mekanik, projektiler, skada, reproducerbarhet,
tornflytt, förmågeeffekter och UI. Senaste verifieringen passerar hela sviten,
inklusive 17 kvalitetskontroller, 208 effektkontroller och 12 kontroller av
mottagna effekter. Separat kampanjkontroll passerar 372 layoutfall. Windows har
renderats och webben startats i Chrome utan konsolfel eller varningar.
Automatiska kontroller bevisar inte mänsklig vinstchans.

## Underlag och äldre versioner

- [Utveckling och arkitektur](docs/development.md)
- [Kampanjens innehåll, referenser och begränsningar](docs/campaign-review.md)
- [Prototypplan](docs/prototypplan.md) och [bekräftade beslut](docs/prototyp-beslutsunderlag.md)
- [Grafisk stilreferens](docs/referenser/pixelgrafik.png)

Den äldre tiovågsprofilen startas utan `-Campaign`. Den utökade gemprofilen väljs
med `-ExpandedGems` eller `?profile=expanded-gems`. Historiska lokala paket för
1.0.0 och kampanj 1.2.x/1.3.0 är äldre ögonblicksbilder; de innehåller inte
ändringarna i den här utvecklingsversionen.

Spelet använder egen kod, egna genererade bilder, syntetiska ljudeffekter och
typsnitt med licenser i `assets/fonts/OFL.txt`. Dota-installation krävs inte för
att köra eller exportera spelet. Referenspaketets Lua, modeller och texturer
distribueras inte. Vissa verktyg för att återskapa referensdata kräver separat
tillgång till det granskade lokala paketet.

Alla fiendeanimationer i PixelLab-passet kan granskas med `powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1 -Enemies` (51 unika figurer, Space pausar). Bilder och genereringsunderlag: `assets/graphics/pixellab-enemies-v1/`; se [dokumentationen](docs/pixellab-enemies-v1.md).
Tornens ljusanimationer granskas med `powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1 -Towers`; se [tornpasset](docs/pixellab-towers-v1.md).
