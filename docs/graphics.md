# Grafik som går att byta under utvecklingen

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

`recipe_guide.gd` beräknar skrivskyddat lager/framskridande. `recipe_book.gd` bygger kort och skickar Locate/Track-signaler. `board_view.gd` visar markeringarna. Räkningen uppdateras efter placering, kombination eller rivning. Fäst recept och Locate-ordning är sessionsinställningar; de nollställs vid ny omgång/återladdning och ändrar inte sparformatet. Befintliga bildbindningar/tema används; inga nya PNG-filer krävs.

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
