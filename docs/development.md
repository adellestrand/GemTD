# Utveckling och verktyg

## Teknisk grund

Trapuppföljning 1.3.1-dev: `python tools/godot.py --headless --path . --script res://tests/check_trap_placement.gd -- --campaign --smoke` provar 21 fall för nya/gamla receptmaterial, förbrukat tornval, ogiltig flytt, automatisk uppgradering vid annan mittruta, frivillig flytt, explicit vågstart, UI och oberoende rapportåterspelning. Ordinarie `python tools/check.py` inkluderar testet. Webb/Windows är återexporterade; Windows grafik/ljud och webbstarter i Chrome kontrollerades. Innehållsversion 8 använder en ny byggsparfil; omladdning återgår som tidigare till byggfasens början, även under trapplacering.

Godot **4.7.2-stable**, GDScript och Compatibility-renderaren. Samma projekt exporteras till Windows x64 och WebGL 2. Webben använder en tråd. C#, native extensions och externa servrar behövs inte för prototypen.

Motor och mallar installeras i `.tools/`. Bootstrap kontrollerar fasta SHA-256-värden från den officiella releasen. `tools/godot.py` ger endast barnprocessen en lokal APPDATA-sökväg; Windows inställningar och föräldraprocessens miljö ändras inte. Direktstartad exe och vanlig Godot-editor använder annars Godots normala användardata.

| Del | Ansvar |
| --- | --- |
| `data/catalog.json` | Versionsmärkt innehåll: karta, torn, recept, effekter, ekonomi och vågor |
| `game/core/catalog.gd` | Innehållsuppslag och presentation av tornvärden |
| `game/core/board.gd` | Ockupation och AStarGrid2D genom alla kontrollpunkter |
| `game/core/run_state.gd` | Byggregler, kombinationer, ekonomi, RNG och fasövergångar |
| `game/core/combat.gd` | Fast simulering, rörelse, målval och tidsbestämda effekter |
| `game/core/damage.gd` | Skadetyper, armor, motstånd, immuniteter och skadefilter |
| `game/core/save_store.gd` | JSON-inläsning och byte av färdigskriven sparfil |
| `game/board_view.gd` | Rita spelplanen och hantera kameran |
| `game/presentation/art.gd` | Cache, bildkatalog, per-kvalitetsbilder, atlasregioner och visuell storlek |
| `game/presentation/effects.gd` | Begränsade visuella händelser, träffglimt och effektlivslängd utan speltillstånd |
| `game/presentation/build_guide.gd` | Skrivskyddad placerings-/materialförhandsvisning och kortlivad vägcache |
| `game/presentation/recipe_guide.gd` / `recipe_book.gd` | Receptlager, exakta kvaliteter, receptkort och signaler för Locate/Track |
| `game/presentation/tower_info.gd` / `tooltips.gd` | Skrivskyddade tornvärden, effekter per kvalitet, resultatjämförelse och radbrutna temastyrda verktygstips |
| `game/presentation/wave_guide.gd` / `wave_book.gd` | Vågprogression, fiendeförsvar, måltyp per torn och skrivskyddad vågöversikt |
| `assets/graphics/manifest.json` / `ui_theme.tres` | Utbytbar grafik, palett, ankare och Godot UI-tema |
| `game/art_gallery.tscn` | Förhandsvisning av allt bildinnehåll utan en spelomgång |
| `game/main.gd` | Koppla UI, modell, ljud och sparpunkter |
| `tests/run_tests.gd` | Regeltester, numeriska effektfall och tiovågssimulering utan UI |
| `tests/check_presentation.gd` | Händelsers betydelse, paus/rensning och samma RNG/utfall med grafiklyssnare |
| `tests/check_build_guide.gd` / `check_build_ui.gd` | Förhandsvisat kontra verkligt utfall, cacheinvalidering och UI-signaler för val/recept/omstart |
| `tests/check_recipe_guide.gd` / `check_recipe_ui.gd` | Lagerräkning, dubbla krav, oförändrat RNG/tornval, Locate-cykling, markeringar och återställt pausläge |
| `tests/check_tower_info.gd` / `check_tower_ui.gd` | Verkligt attackintervall, stöd som försvinner vid slutval, visat kontra faktiskt resultat samt uppdatering/rensning i tornpanelen |
| `tests/check_wave_guide.gd` / `check_wave_ui.gd` | Oförändrad katalog/RNG, mark-/luftmål, vinst/förluststatus, dialogstorlek och paus vid byte mellan hjälp/recept/vågor |
| `tools/audit_runs.gd` | Utforskande naturliga omgångar med vanlig ekonomi och enkel automatisk strategi |

Modellerna är `RefCounted` och kan köras utan grafik eller scen. Signaler meddelar UI; stridsmodellen skapar inga UI-noder. Ingen global autoload behövs ännu. Publika modellgränser, signaler och API:er är typade; Dictionary-innehåll valideras separat.

Simuleringen körs i **30 fasta steg per sekund**. Paus stoppar stegen; 2× kör dubbelt så många. Build- och stridsslump har separata generatorer, så stridens träffslag påverkar inte framtida gemtyper. Ogiltiga placeringar valideras före RNG-anrop.

`GemCatalog.attack_timing` är gemensam för simuleringen och tornpanelen: Aquamarines egen bonus, en Opal-aura per kvalitet och räckviddskontroll beräknas på ett ställe. Auratornets tickintervall är separat och påverkas inte av attackhastighet. `GemTowerInfo.result_profile` använder bygghjälpens faktiska plan och en kopia av cellsamlingen för att räkna bort förbrukat stöd. Ingen av presentationsberäkningarna använder RNG, tillämpar handlingar eller ändrar sparningen.

Stridseffekterna avanceras med samma fasta steg som simuleringen. Bygg-/slutskärmens återstående effekter använder bildrutans tid. Modellsignaler rapporterar löst skada/miss/död/läcka och grafiken lyssnar utan att ändra modellen. Attackljudet har separat spelare och högst ett nytt ljud per 100 ms så att multiskott inte avbryter fas-/byggljud.

Tornens ritrektangel beräknas centralt i `GemArt.sprite_rect`; alla 27 tornbilder använder mittankare i manifestet. Bildkontrollen provar dem vid tre skalor. Andra bildtyper behåller individuella ankare. Vågsammanfattningen i huvudvyn jämför modellens kills/leaks/liv före och efter en våg, inte hela omgångens totalsiffror. Den nollställs vid omstart/återladdning och lagras inte i byggsparpunkten.

Reproducerbarhet kräver samma motor-/innehållsversion och handlingar. Sparfiler har versionsnummer och RNG-tillstånd som strängar för att undvika JSON-precisionstapp. Endast början av byggfasen sparas automatiskt. Efter en distribuerad version ska ändrade innehållsregler höja `content_version` eller ha migrering.

`.godot/`, verktyg, exporter, testbilder och referensrådata ignoreras av Git. `.gd.uid` följer med koden. `.gdignore` hindrar dokument/verktygsfiler från att importeras som speltillgångar.

## Skills och MCP

- Den officiella **Playwright-skillen** har installerats för riktiga webbläsartester. En ny Codex-session/omstart kan behövas för automatisk skillupptäckt. Under implementationen lästes och användes den direkt.
- **skill-installer**, **openai-docs** och plugin management användes vid inventeringen. Ingen Godot-skill fanns i den officiella kuraterade listan vid kontrollen.
- Ingen Godot-plugin hittades i den anslutna plugin-katalogen. Ingen ytterligare community-MCP installerades: Godots CLI täcker import, parsning, modelltester, export och renderad körning; Playwright täcker webbens inmatning och sparning. Om scenredigering/liveinspektion senare kräver mer väljs en specifik MCP mot det behovet.
- [Source 2 Viewer / ValveResourceFormat](https://github.com/ValveResourceFormat/ValveResourceFormat) CLI 20.1 användes lokalt för kartinventering. Verktyget behövs inte för att bygga eller spela.
- Imagegen-skillen användes med det inbyggda bildverktyget för tre transparenta spriteark: första grafikpasset och 16 kvalitetsvarianter för II/III. Bilder, metod och prompter är sparade i projektet. Se [grafikflödet](graphics.md). Separata kvalitetsbilder finns; färdiga animerade sprites återstår.

Utveckling kräver Godot och Python. Node/npx behövs endast för Playwright. Spelets runtime har inga Python-/Node-beroenden.

## Arbetsflöde

Kör `tools/test.ps1` efter ändrade regler. Verktyget stoppar även vid `ERROR:` i motorloggen om Godot returnerar noll. Presentation kräver dessutom visuell kontroll. Efter ändrad exportkonfiguration eller plattformskänslig kod: exportera båda målen, starta exe-filen och kör webben i en riktig webbläsare.

Testbilder och loggar ligger i `output/`; Playwright-sessioner i `.playwright-cli/`. Använd en namngiven lokal session och aktuell snapshot/skärmbild före musklick. Godot ritar på canvas, så DOM-lokatorer ser inte dess knappar. Lägg inte till en parallell HTML-implementation av spelreglerna för testningens skull.

## Officiella riktlinjer som använts

- [Godot best practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html) och [scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html): tydliga ansvar och löst kopplade delar.
- [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html): filstruktur, namngivning och `.gdignore`.
- [Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) och [command-line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html): typade API:er, headless-tester, import och export.
- [Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): Compatibility/WebGL 2 och webbläsarens lagrings-/ljudförutsättningar.

## Granskningsverktyg 1.0

- `powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Release`: båda produktionsbyggena.
- `python tools/godot.py --headless --path . --script res://tools/audit_v1.gd -- --runs=10`: naturliga omgångar med accepterade handlingar och rapporter.
- `python tools/verify_balance.py`: 180 låsta numeriska referenskontroller.
- `python tools/verify_reviews.py`: återspela 20 journalförda omgångar.
- `python tools/package_release.py`: paketera exporter och granskning, kontrollera Windows release-start, SHA och ZIP-integritet.

`review_journal.gd` lagrar accepterade handlingar och vågutfall utan modellreferenser. `review_replay.gd` återspelar kända handlingar och verifierar slutbräde/ekonomi/utfall. `run_summary.gd` visar den skrivskyddade rapporten; release.json innehåller versions- och balansprofil. Läs testguide-v1.md innan manuell granskning.

Utbyggnad efter 1.0: se full-content-plan.md. `data/expanded_gems.json` aktiveras uttryckligen med `--expanded-gems` eller webbparametern `?profile=expanded-gems`; standardprofilen använder fortfarande `data/catalog.json`. Båda finns i samma exporter, med egna sparfiler och rapportidentiteter. Regenerera endast utvecklingsfilen med `tools/build_expanded_gems.py`, inte den äldre kataloggeneratorn.

## Kampanj 1.2.0-dev

`--campaign` eller `?profile=campaign` aktiverar `data/campaign.json`. Run-menyn byter profil; separat sparfil och innehållshash skyddar granskningarna från sammanblandning. Grundprofilen 1.0 och den äldre gemprofilen är fortfarande tillgängliga.

| Del | Ansvar |
| --- | --- |
| `tools/build_full_reference.py` / `data/full_reference.json` | Läs numeriska fakta och recept ur den lokala källögonblicksbilden utan att köra Lua. |
| `tools/build_campaign.py` / `data/campaign.json` | Härled 100 vågor, receptalternativ, 107 förmågedefinitioner och soloprogression. |
| `game/core/campaign_rules.gd` | Gemensam tolkning av kampanjförmågor, stöd, intervall och MVP-bonusar. |
| `game/core/campaign_combat.gd` | Kampanjens fiendeförmågor, effekter, stentavlor, skaderapportering och MVP. |
| `tests/check_campaign.gd` / `check_campaign_edges.gd` | Alla recept/enheter/vågor samt riktade regelgränsfall och en separat 100-vågig fasfixtur. |
| `tools/audit_campaign.gd` | Naturliga spelhandlingar med enkel automatisk labyrintstrategi; ingen vinstgaranti. |
| `tools/verify_campaign.py` | 1593 kontroller av härledda värden och runtime-kopplingar. |
| `tools/package_campaign.py` | Separat releasepaket med launcher, webbserver, dokument och återspelade rapporter. Vägrar skriva över en bevarad version. |

Efter dataändring: bygg om med `python tools/build_campaign.py` och kör `tools/test.ps1`. Innehållshashen ändras och tidigare rapporter kan då avvisas; samla nya naturliga omgångar och återspela dem före paketering. Referensrådata ligger lokalt i `.tools/reference` och ingår inte i spelet.

Ytterligare körkommandon:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Campaign
python tools/godot.py --headless --path . --script res://tests/check_art.gd -- --campaign
python tools/verify_reviews.py --campaign
python tools/smoke_windows.py --campaign --attack
python tools/package_campaign.py
```

Uppföljningen 1.2.1-dev har innehållsversion 4, separat kampanjsparfil, verkliga projektilpositioner i `campaign_combat.gd` och en gemensam begränsning av attackhastighet i `GemCampaignRules.timing_from_bonus`. `tests/check_campaign_flight.gd` provar bland annat träfftid, slow-start, rörliga/döda/utläckta mål, multiskott, cap och visad DPS.

Den fullständiga testkedjan innehåller nu 614 GDScript-fall och 5013 numeriska referenskontroller. Kampanjens bildkontroll provar 273 centrerade tornlayouter. Tre av de nya fallen skickar verkliga tangenthändelser genom Godots UI för att säkerställa att Space pausar en gång utan att återaktivera en fokuserad hastighetsknapp och utan att påverka en öppen modal. Se `docs/teststatus.md` för faktiskt genomförda plattforms- och spelkontroller, och `docs/campaign-review.md` för uttryckliga skillnader mot Dota-motorn.

## Utjämnad slump och bossrabatt – 1.2.2-dev

Innehållsversion 6 använder `run_campaign_v6.json` och separat v6-rapport; äldre kampanjsparpunkter bevaras. `GemProcRandom` äger algoritmen för de tre explicit märkta källhändelserna. Modeller/koefficienter härleds av `build_campaign.py`; räknare lagras på enheten. `tests/check_proc_random.gd` testar frekvenser, oberoende, sparning och återspelning samt skriver `output/prd-distribution.json`.

`GemRun.quality_price()` är gemensamt prisuppslag för UI, köp och botar. `GemCatalog.boss_discount_for_wave()` begränsar belöningen till grundbossarna. `GemCampaignCombat.deal()` betalar rabatten en gång vid bossdöd. Sparning och journaler innehåller rabattbank och bosslista; återspelning verifierar även faktiskt betalt pris. `tests/check_boss_discount.gd` har 49 fall för ekonomi, kampanj-/legacygränser, återspelning och UI. `python tools/analyze_progression.py` regenererar jämförelsen i `docs/progression-options.md` utan att skriva speldata.

Aktuell testkedja: 689 GDScript-fall och 5042 referenskontroller (180 + 3129 + 1733), utöver bildkontroller. Se teststatus.md för faktiskt körda plattformsprov och deras begränsningar. Grundprofilen 1.0 behåller sin version, katalog och sparning.

## Femstegsuppföljning 1.3.0-dev

Innehållsversion 7 och separat v7-sparning. `GemCombatAudit` mäter effektiv skada och bossens skjut-/effektfönster utan RNG. Rapporten och återspelningen inkluderar diagnostik; förlustsignalen får slutliga projektilräknare innan UI-kallbacken skriver rapporten. `GemCampaignCombat` lagrar aura-instansers efterverkan, källa och egen intervallklocka. Aura-frågor cachas inom ett delsteg, med ny revision efter rörelse. Cache av/på jämförs för samma täta förlopp.

Ny kontrollkedja: 737 GDScript-fall, 5067 referenskontroller samt befintliga bild-/ankarkontroller. Nya testfiler: check_combat_audit.gd, check_movement_detection.gd, check_aura_lifecycle.gd, check_readability.gd.

`python tools/godot.py --headless --path . --script res://tools/audit_late_game.gd -- --campaign --smoke` skapar output/late-game-audit.json. Fixture, spawnschema och begränsningar finns uttryckligen i rapporten. `python tools/build_stress_web.py` skapar en isolerad webbfixture i builds/web-stress med byte-identiska produktionsfiler och separat testscen; ordinarie webbexport/sparning ändras inte. Testkopian ligger under output/stress-project. Exportera slutligen ordinarie Windows/Web och paketera med tools/package_campaign.py.
