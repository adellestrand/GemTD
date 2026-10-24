# Grafik som går att byta under utvecklingen

[Kvalitetspass för skadevisning och MVP](quality-pass-stats-mvp.md): panelens
skada inkluderar stöd, rena skadeauror visar sina tickvärden och MVP 10 har
guldkrona, räckviddsring och mottagarmarkering.

[Inspektion av påverkan på valt torn](tower-effects-inspection.md) visar MVP,
stödkällor, tillfälliga bonusar och avväpning i sidopanelen.

[Specialtornens effekter](special-tower-effects.md) följer nu verkliga
auraskadetick, gift, kedjehopp, splash, kritiska träffar och stödbonusar.
Grafikverkstadens nya **Abilities**-flik visar samtliga 43 torn i isolerade
förmågedemonstrationer.

Senaste grafikpasset: [43 egna kombinationstorn](special-towers-art-v1.md), med
Dota-inspirerade väktarmotiv i den befintliga byggnadsstilen. Separata PNG-filer i
`assets/graphics/specials-v1/`; tidigare bilder finns kvar. Samma mittankare och
0,94-rutorsgräns används.

Grafiken är ett separat presentationslager. En bildändring ska inte kräva ändringar i placering, tornvärden, RNG, strid eller sparformat. Tre egna genererade PNG-ark ger totalt 44 bilder: åtta grundtyper med varsin bild för I–III, specialtorn, tio fiender, checkpoint och dekorationer.

Stilen utgår från användarens [pixelreferens](referenser/pixelgrafik.png). Dota GemTD:s juveler, socklar och magiska uttryck används som inspiration; inga originalmodeller eller speltexturer ingår. [Workshop-sidan](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917) och [visuella spelbilder hos Dotas kinesiska utgivare](https://maps.dota2.com.cn/maps/custommap?id=41) användes som kompletterande visuellt underlag, inte som versionsbevis för reglerna.

## Här ändrar vi vad

| Önskad ändring | Fil/plats |
| --- | --- |
| Byta en bild eller ett helt spriteark | `assets/graphics/manifest.json`: `sprites` eller `sheets` |
| Egen bild för kvalitet II/III | `bindings.gems` har separata nycklar `1`, `2`, `3` samt `default` |
| Storlek och visuell förankring | Bildens `size`, `anchor` och `offset` i manifestet |
| Skottfärg och glöd | Bildens `effect_color` |
| Skottets uttryck, varaktighet, träffglimt, skadetal och effektgräns | Manifestets `effects` |
| Studs, gungning och deformation | Manifestets `motion`; enskild fiende kan ange egen `sprites.<id>.motion` |
| Gräs, ram, rutnät/markering och effektfärger | Manifestets `palette` och `terrain` |
| Knappar, paneler, typsnitt, textstorlek | `assets/graphics/ui_theme.tres`, ett vanligt Godot Theme som kan redigeras visuellt i editorn |
| Vilken fiende som använder vilken bild | `bindings.enemies`, kopplad till stabilt innehålls-ID |
| Ny animerings-/effektfunktion | `game/presentation/` och `game/board_view.gd`, utan ändringar i `game/core/` |
| Placeringsmarkör, förhandsvisad väg och materialmarkering | Manifestets `palette`: `placement_ok`, `placement_blocked`, `route_preview`, `material`, `will_be_stone` |
| Markering av fäst recept | Manifestets `palette.recipe_tracking`; receptkort/länkar använder `ui_theme.tres` |

Kvalitet I använder `towers-v1.png`. II och III har individuella bilder i `qualities-v2.png`, kopplade per typ/nivå i manifestet. II har förstärkta former; III har högre sockel och större kristallkrona. Gemfärgen bevaras och spelets kvalitetsmarkeringar finns kvar. Varje variant går att byta oberoende av de andra. Fiender rör sig med procedurstyrd studs, gungning och lätt deformation kring fotpunkten. Det är ännu inte individuellt tecknade gång-/vingrutor.

## Läsa byggandet

Fem valknappar ovanför spelplanen samlar den aktuella rundans avslöjade gems. Klick väljer samma ruta som ett klick på spelplanen, utan att göra en ny placering. Tomma platser visar nummer och blir valbara först efter placering.

Peka på en tom ruta: en neutral romb visar giltig placering och guldlinjen visar hur markrutten skulle gå. Gemtyp och kvalitet avslöjas fortfarande först vid klick. En blockerad ruta får ett rött kryss och en förklaring under spelplanen. Kontrollen gäller hela vägen genom samtliga checkpoints. Förhandsvisningen lagras per ruta och räknas om efter ändrad spelplan.

Lika nya gems markeras när en sådan gem väljs. Peka på Keep, Combine, recept eller Demolish för en förhandsvisning: cyan ramar/linjer visar materialen, guld visar resultatplatsen och gråtonade rutor blir stenar. Borttagning visar ett rött kryss. Resultatets namn och fasövergång står längst ned; otillgängliga val förklarar varför de är låsta. Klick genomför fortfarande valet direkt utan extra bekräftelse. Bara gamla receptmaterial lämnar byggfasen öppen; nya material startar vågen.

Bygghjälpen ligger i `game/presentation/build_guide.gd`. Den läser modellens faktiska materialurval och använder `GemBoard.placement_preview`, samma vägkontroll som placeringens validering. Den varken förbrukar RNG eller ändrar spelplanen. Bildspråket styrs av paletten; ingen ny PNG behövs för dessa markeringar.

## Receptboken och ingrediensmarkeringar

**Recipes** visar tre receptkort med resultatporträtt, rollbeskrivning, ingrediensernas exakta kvaliteter och antal ägda exemplar uppdelat på tidigare behållna respektive nya gems. Totala framsteget räknar högst det antal som receptet kräver, även när flera lika gems finns. Upprepade krav måste ha separata exemplar.

**Locate on board** väljer och fokuserar kameran på en ägd ingrediens utan att placera något. Upprepade besök växlar mellan matchande gems, äldre först. **Track on board** fäster ett recept och visar alla ägda matchningar med lila ramar samt löpande framsteg/Unpin under spelplanen. Exakt vilka material som förbrukas visas fortfarande av kombinationsknappens förhandsvisning, som har företräde framför receptmarkeringarna.

Receptboken kan användas under strid för planering. Den pausar spelet och återställer tidigare pausläge vid stängning eller Locate/Track. Inget av dessa val kombinerar, förbrukar eller avslöjar gems. Boken beskriver om bara äldre material räcker, om fem placeringar först behövs och om nya material innebär omedelbar vågstart. Faktisk kombination sker via de befintliga tornkontrollerna.

**Ordning och färger (2026-10-24).** Receptboken visar tornen per uppgraderingslinje som i Dota-versionen: varje Top-torn (Koh-i-Noor, Depleted Uranium, …) med alla kombinerade torn som leder dit, bas först. Linjerna härleds ur receptdatan (samma träd som Dotas `_G.gemtd_merge` i `mode.lua`); sidotorn som inte leder till ett Top-torn (Sea Jewel, Lucky Chinese Jade, Egypt Gold, Emerald Golem, Natural Emerald) placeras i linjen för ett torn de byggs av. Hemliga recept kommer sist i två grupper (en gemtyp i fem kvaliteter / övriga), som källans egna kommentarer delar dem. Hur Dotas Panorama-panel exakt ritar listan finns inte i referensdatan; grupperingen bygger på receptträdet. Ingredienschips: grön = finns bland gems från tidigare rundor, gul = finns bara bland den här rundans nya gems (kombination blir då rundans slutval), brons = delvis, grå = saknas.

`recipe_guide.gd` beräknar skrivskyddat lager/framskridande. `recipe_book.gd` bygger kort och skickar Locate/Track-signaler. `board_view.gd` visar markeringarna. Räkningen uppdateras efter placering, kombination eller rivning. Fäst recept och Locate-ordning är sessionsinställningar; de nollställs vid ny omgång/återladdning och ändrar inte sparformatet. Befintliga bildbindningar/tema används; inga nya PNG-filer krävs.

## Maze-tips

**Mazes** öppnar Dota-versionens labyrintförslag som en vy i receptbokens stil; **Show on board** ritar valt förslag som rosa rutor (att bygga) och orange kryss (startstenar att riva) på spelplanen tills det stängs med länken under brädet, knappen i vyn eller G. Färgen kan ändras med paletten `maze_guide` i manifestet (standard `#ff7ad9` i koden; nyckeln finns inte i manifestet än). Källa, egna tolkningar och filer: [maze-tips.md](maze-tips.md).

## Tornvärden och resultatjämförelse

Valt torn visar den valda kvalitetens effekt och nuvarande attackintervall inklusive Aquamarines egen bonus och närliggande Opal-auror. Lika Opal-kvalitet räknas en gång; olika kvaliteter kan bidra samtidigt och Opal påverkar sig själv. **Attack DPS** är rå grundattack mot ett mål före armor/evasion, med gift/splash/multiskott beskrivna separat. Det är inte uppmätt total skada per sekund mot aktuell våg. Asteriated Ruby visar magisk tickskada, auraradie och aura-DPS; dess oanvända målprioritet döljs.

Verktygstips på Keep/Combine/recept visar **AFTER THIS CHOICE**, resultatets värden och ändring av attack-DPS/räckvidd där två grundattacker kan jämföras. Beräkningen tar bort förbrukade Opals och nya stödgems som skulle bli stenar. Ingen placering eller kombination genomförs av att läsa informationen. Uppgifterna räknas om efter ändrad spelplan. 1×/2× ändrar hur snabbt simuleringen körs, inte intervallens visade simuleringssekunder.

`tower_info.gd` formaterar presentationen från innehållskatalogen. `tooltips.gd` skapar radbrutna verktygstips med samma `ui_theme.tres` som övriga gränssnittet. Paneler, textfärger och bilder kan fortsätta bytas utan att ändra dessa beräkningar. Inga nya bildfiler krävs.

## Vågöversikt

**Waves** använder befintliga fiendebindningar och UI-temat. Vänster lista visar alla tio vågor med mark/luft/boss och om de är avklarade, nästa, pågående eller ännu inte nådda. Ett markerat listval byter bara visad information. Spelomgångens våg och tornval påverkas inte.

Detaljpanelen visar liv, hastighet i celler/sekund, spawnintervall, försvar, belöningar och läckregel. Jämförelsen från 100 rå skada använder `GemDamage.resolve` för fysisk/magisk/ren träff mot grundförsvaret. Evasion redovisas separat; tillfälliga debuffs ingår inte. Detta är träffskada, inte uppskattad total DPS eller chans att klara vågen.

Antal torn med rätt måltyp delas upp i behållna och nya gems. Stenar räknas inte. Även support- och auratorn har rätt måltyp enligt aktuell modell, men antalet säger inget om räckviddstäckning eller skadeförmåga. Nya gems som ännu inte behållits räknas därför aldrig som permanent försvar.

`wave_guide.gd` beräknar skrivskyddad information; `wave_book.gd` visar och pausar genom huvudvyns gemensamma dialogkoppling. Listan och detaljpanelen kan rullas oberoende. Deras yta räknas om efter fönsterstorlek och ändrad minimistorlek på radbruten text, med en separat rad för Close. Inga nya PNG-filer krävs.

## Rörelse och stridseffekter

`effects.shots.<gemtyp>` väljer `style` (`beam`, `shard`, `bolt` eller `ember`) och `duration` i sekunder. Färgen följer fortfarande tornbildens `effect_color`. `effects.hit_flash` styr träffglimtens längd, `damage_colors` skiljer fysisk/magisk/ren träff och `area_color` används för områdespulser. `damage_numbers` är avstängt som standard för att hålla striden läsbar; missar och läckor visas med kort text. `max_events` begränsar samtidiga effekter till 240. `enabled: false` stänger av detta effektlager.

`motion.ground` och `motion.air` har `frequency`, `bounce`, `squash`, `sway` och `lift`. Frekvensen avser fas per tillryggalagd cell för markfiender, och per sekund för flyg. Studs och höjd anges i celler; gungning i radianer och deformation som proportion. Robot, spindel och boss har individuella överstyrningar i sina spriteposter. `motion.enabled: false` tar bort rörelsen men behåller flyghöjden.

Effekterna lagras i `game/presentation/effects.gd`. Stridsmodellen skickar neutrala händelser om faktisk skada, död, miss, läcka och områdesattack; den skapar ingen grafik. Immunitet ger ingen falsk träffglimt, medan en undviken attack får MISS. Bilderna ändrar inte när skadan sker: denna prototyp applicerar fortfarande skadan direkt. Det finns ingen simulerad projektilflygtid.

Paus fryser stridens effekter och fiender. 2× följer simuleringstiden. Omstart tömmer gamla effekter. Byggfasens nya/uppgraderade torn får en kort ring; rivning ger ett litet dammuttryck. Ingen kameraskakning används.

## Byt en enskild gem utan att rita om arket

1. Lägg en transparent PNG i exempelvis `assets/graphics/custom/sapphire-ii-v3.png`.
2. Lägg till en egen post i manifestets `sprites`:

```json
"sapphire_ii_v3": {
  "texture": "res://assets/graphics/custom/sapphire-ii-v3.png",
  "size": [1.22, 1.95],
  "anchor": [0.5, 0.5],
  "offset": [0.0, 0.0],
  "trim_alpha": true,
  "effect_color": "#62c8ff"
}
```

3. Ändra bara `bindings.gems.sapphire`:

```json
"sapphire": {
  "default": "sapphire",
  "2": "sapphire_ii_v3",
  "3": "sapphire_3_v2"
}
```

Kvalitet I och III behåller sina nuvarande bilder. Övriga torn, data och sparningar påverkas inte. V3-filen är ett instruktionsexempel och finns inte i projektet.

`size` är maximal ritbredd/-höjd i cellstorlekar; bildens proportioner bevaras. `anchor` är punkten i bilden som fästs vid cellens centrum, från `[0,0]` i övre vänster till `[1,1]` i nedre höger. `offset` flyttar bilden i cellstorlekar. Visuell storlek ändrar aldrig den logiska byggytan på en ruta.

Efter användarens återkoppling om för högt placerade torn använder alla 27 tornbilder nu `anchor: [0.5, 0.5]`: själva tornbilden centreras i rutan. Det tidigare värdet `[0.5, 0.85]` drog bilden uppåt. Stenar, fiender och dekorationer behåller sina separata ankare. `GemArt.sprite_rect` är den gemensamma beräkningen för ritning och kontroll; bildkontrollen provar alla torn vid 15, 32 och 45 pixlar per cell (81 layoutfall). **Board scale** visar även en rutram och centrumkors för visuell kontroll.

`effects.muzzle_height` (0,35 celler) placerar skott/glimt vid det centrerade tornets juvel. En viss skottprofil kan överstyra `muzzle_height`. Detta är en visuell startpunkt; det påverkar inte modellens räckvidd eller träffberäkning.

För ett ark anges `sheet` och nollbaserat `index`, räknat från vänster till höger, uppifrån nedåt. Arkets sökväg/rader/kolumner står under `sheets`. Vid ojämna marginaler kan en post ange exakt `region: [x,y,bredd,höjd]`. Automatisk transparent beskärning sker i minnet via AtlasTexture; original-PNG ändras inte.

## Animationsremsor för fiender

En spritepost kan ange `"frames": n`. Bilden (eller `region`) är då en horisontell remsa med n lika breda rutor. Alla rutor beskärs med samma ram (unionen av rutornas synliga pixlar), så fienden hoppar inte mellan rutorna. `GemArt.texture(id)` ger ruta 0, så porträtt, galleri och bildkontroller fungerar som förut; `GemArt.frame_texture(id, i)` ger ruta i. Ruta väljs av `GemArt.enemy_frame`, som följer samma gångklocka som `motion`: markfiender byter ruta efter tillryggalagd sträcka (en saktad fiende rör benen långsammare) och ruta 0 och n/2 sammanfaller med att studsen landar; flygfiender följer tid. `motion.enabled: false` fryser på ruta 0. Poster utan `frames` beter sig exakt som tidigare.

```json
"boar": { "texture": "res://assets/graphics/refined-v3/anims/boar_walk_v1.png", "frames": 4,
          "trim_alpha": true, "size": [1.25, 1.3], "anchor": [0.5, 0.72] }
```

Källor och bygge:

- Gångcykler skrivs i pxl ([claude-pxl](https://github.com/crsolver/claude-pxl), installerad som projektskill i `.claude/skills/pxl-pixel-art`, kräver Node ≥ 22.18). Alla gångcykler står i `tools/art/anims/walk.px.js`: en rad per familj med benens rektanglar, ledrad och förskjutning per ruta (`NEAR_FRONT`, `FAR_FRONT`, `HIND`; `HIND_FROM_REAR` och `FAR_FRONT_FROM_FORWARD` för ben som redan når bildkanten och bara kan svinga åt ett håll; `SPIDER_A`/`SPIDER_B` för spindelns två växlande bengrupper). Vingar: en utsträckt vinge anges med `pivotX` (axelkolumn), `reach` och `flap` (`WING_DOWN`, hur långt spetsen sjunker per ruta); en uppåtriktad vinge använder benskjuvningen med negativ `len` (`UPRIGHT_WING`). Flygremsor heter `<namn>_flap_v1.png`. Benrektanglarna måste täcka hela foten ner till konturen, annars blir en rad kvar när benet flyttas. Kroppen kommer oförändrad från den godkända refined-v3-bilden och bara benen flyttas. Ny familj: lägg till `include("<namn>_part.px.js")` + `walk(...)` där och en rad i `ANIMS` i `build_anims.py`.
- `tools/art/png2pxl.py` gör om en PNG till en pxl-del. Refined-bilderna har tusentals nästan lika färger, så den reducerar till 48 färger (boar: max kanalfel 14/255, medel 4).
- `python tools/art/build_anims.py` bygger alla remsor i `ANIMS`, kopierar dem till `assets/graphics/refined-v3/anims/<namn>_walk_v1.png` och färgar om samma remsa för varje variant av grundbilden via `variants.py` (kräver Pillow). Förhandsvisningar (uppskalad PNG + GIF) hamnar i `output/pxl/`. Kör därefter `python tools/godot.py --headless --editor --path . --import`.
- Egna kroppar (24 fiender, se `docs/enemy-silhouettes.md`): ritade direkt i pxl i `tools/art/anims/creatures.px.js` med gemensamma hjälpfunktioner (`ball`, `tube`, `cyl`, `fan`, `eye`, `rim`; ljus från övre vänster, mörk skarv mellan delar, en mörkare ton innanför konturen) och `creature(namn, w, h, draw, scale)` som ger 4 rutor med samma gångfaser som `walk.px.js`. `scale` ritar om formerna på en större duk så att pixelstorleken i spelet matchar refined-v3 (mål cirka 2,1 skärmpixlar per bildpixel, bossar 2,47); `fur`, `scallops` och `curls` lägger päls, fjädrar/fjäll och ull i slutupplösningen. `tone()` blandar tonerna med mjukt värdebrus (penselkluster, inte Bayer-rutmönster), `seam()` ger en kontaktskugga på delen under, och `facet()` fyller plana ytor (kistor, brädor) med tonövergång. Varje familj börjar med `use(["#050304"])` eftersom pxl:s `ramps()` ackumuleras. `build_anims.py` kopierar dem som `<anim>_v2.png`.
- refined-v4 (AI-ark v2, 32 fiender med egen kropp): animeras i `walk.px.js` via `V4`-tabellen och `walk4` (marginal på duken, `despeckle`), med rörelsetyperna ben (`swing`), vinge (`pivotX`/`flap`), `shift`, `spin` och `wave`; byggs till `<fiende>_<walk|flap>_v3.png`. pxl-kropparna (`_v2`) är reserv.
- Nu animerade (53): alla fiendefamiljer med deras varianter. Mark: boar (pig_princess, bajie), yak (sheep, alpaca, jumo, boooofus, crummy), hound (bulldog, rabbit, baekho, zombie, dusky), lizard (young_demon, lockjaw, trapjaw, bookwyrm, azuremir), frog (shark, lilnova, furry_fish, shroomy), spider (invisible_spider, ripper, stump), robot/`courier_robot` (machjaw) och boss_hound (shagbark, baby_roshan). Flyg (vingslag): bat/`red_courier` (corsair, goldfish, ig_dragon, fox, jinyin_fox, wabbit, ghost) och griffin/`blue_courier` (panda_flyer, flamingo, huntling, mermaid, chicken, kupu, chirpy, drodo, carpet_rider). Rutvalet använder fiendens egen `motion.frequency` när den finns (spider, robot, boss); flygfiender byter ruta efter tid, och ruta 1 (mitt i nedslaget) sammanfaller med att kroppen är högst. Chickens kam placeras av `variants.py` på den högsta punkten i högra tredjedelen, vilket är vingspetsen (som i stillbilden), så den följer vingslaget. `tests/check_enemy_frames.gd` (ingår i `tools/check.py`) kontrollerar lika rutstorlek, att beskärningen inte skär bort pixlar, att rutvalet bara beror på sträckan och att ojämna remsor avvisas.

## Granska innan vi byter allt

Webb: [grafikförhandsvisning](http://127.0.0.1:8060/?view=art), efter export och start av lokal server. Där finns alla grundtyper och kvaliteter, specialtorn, fiender och miljöbilder samlade. **Board scale** visar samma ritstorlek/ankare som spelplanen vid 15 respektive 32 pixlar per cell. **Combat & motion** har levande loopar för alla elva torn och tio fiender, med pausknapp/Space. Looparna är visuella exempel utan balanssimulering eller ljud. Detta är en förhandsvisning, inte en bildeditor i webbläsaren.

Lokal Godot-förhandsvisning:

```powershell
powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1
# Börja direkt med levande effekter:
powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1 -Motion
```

Det kommandot importerar först ändrade bilder. I förhandsvisningen läser **R** om manifestet och tömmer bildcachen. Godot måste ha importerat om ändrade PNG-filer; starta om förhandsvisningen eller ha editorn öppen. Ett syntaxfel i JSON behåller tidigare grafik och visar felmeddelande. Ändrat UI-tema granskas säkrast efter omstart av förhandsvisningen.

Kontrollera både porträttstorlek, hela spelplanen, zoom och tätt placerade torn. En stor detaljrik bild kan behöva en enklare liten silhuett. Alfakanal, mörk kontur och tydlig juvelfärg är viktiga. Godots nearest-filter och avstängda mipmaps används för dessa 2D-bilder.

Kör `tools/test.ps1` och exportera båda plattformarna efter ändringar. Utöver regel- och UI-tester verifieras att bilderna är läsbara, regionerna giltiga, varje gemkvalitet och våg har bild, samt att en enda kvalitet kan kopplas till en separat bildfil. Kampanjens utökade bildkontroll körs med `python tools/godot.py --headless --path . --script res://tests/check_art.gd -- --campaign`. Webbändringar kräver ny export och omladdning; webbförhandsvisningen redigerar inte packade filer. Se [kampanjens grafikgranskning](graphics-review-campaign.md) för prioritering och animationsstruktur.

## Versionshantering och källfiler

Nya bildförslag sparas som `-v2`, `-v3` och kopplas in i manifestet. Behåll föregående bild tills ersättningen är bedömd. Originalen från genereringen ligger dessutom kvar hos Codex; de projektbundna kopiorna ligger i repot. En framtida Aseprite/Krita/PSD-källfil kan sparas separat från exporterad PNG utan att spelets gränssnitt ändras.

Aktuella arbetsfiler är [towers-v1.png](../assets/graphics/generated/towers-v1.png), [qualities-v2.png](../assets/graphics/generated/qualities-v2.png), [enemies-v1.png](../assets/graphics/generated/enemies-v1.png), [manifest.json](../assets/graphics/manifest.json) och [ui_theme.tres](../assets/graphics/ui_theme.tres). Metod och slutliga genereringsprompter finns i [PROMPTS.md](../assets/graphics/PROMPTS.md).

## Kartmärken i 1.3

`assets/graphics/readability.json` styr kvalitetsfärger/-texter, specialtornens kortkoder, zoomgräns, stentavlornas familjesymboler, gradfärger och tillståndsfärger. `game/presentation/readability.gd` ritar märken och läser stridstillstånd utan att ändra dem. Ett rent bildbyte kräver fortfarande bara manifest/PNG; ett märke kan ändras utan ingrepp i kampanjdata. Grafikverkstadens Clarity-flik visar tre riktiga kartskalor. Denna statiska JSON laddas vid start; starta om för att se ändrade märkesdefinitioner.
