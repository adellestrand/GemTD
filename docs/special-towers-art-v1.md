# Kombinationstorn – grafikpass 1

Alla **43 kombinationstorn** har egna bilder. Grundtorn, stentavlor, recept,
balansvärden och sparformat behålls. Motiven är egna tolkningar av Dota-versionens
väktare: ögon, rustningar, drakar, fågelvingar, korall, portaler och mekanik.
GemTD:s befintliga stenbyggnader, skiffertak, gulddetaljer, mörka konturer och
ljus från övre vänster är stilankaret.

## Referenser

- [GemTD:s Workshop-sida](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917).
- [Dota GemTD:s historiska tornbilder](https://clementbera.github.io/Website/advancedTowers.html):
  Silver, Silver Knight, Pink Diamond, Jade och Gold granskades visuellt.
- Den lokalt installerade förlagans `units.json` anger respektive `source_id` och
  ward-modell. Denna modellista gav motiv även för de senare tornen. Vi kopierar
  inga Dota-texturer eller modeller till spelet. Äldre referensbilder är inspiration,
  inte bevis på hur varje modell ser ut i den senaste utgåvan.

## Filer och ändringar framöver

- `assets/graphics/generated/specials-v1-1.png` till `specials-v1-4.png`: fyra
  ursprungliga transparenta bildark, skapade med det inbyggda imagegen-verktyget.
- `assets/graphics/generated/specials-v1-generation.json`: exakta prompter och
  genereringsursprung. Ingen API- eller CLI-baserad reservgenerator användes.
- `assets/graphics/specials-v1/<torn-id>.png`: separata spelbilder.
- `assets/graphics/specials-v1/catalogue.json`: namn, käll-id, ark/ruta,
  beskärningsrektangel och tidigare bildkoppling för varje torn.
- `tools/art/import_specials_v1.py`: återupprepa det befintliga pixelimportflödet,
  återskapa bilderna och koppla manifestet. Importen hittar transparenta mellanrum
  mellan sprites så att ojämna ark inte kapar detaljer.

För att byta ett torn: lägg en ny versionsmärkt PNG bredvid den gamla och ändra
dess `special_v1_<id>`-post i `manifest.json`. Hela arket behöver inte göras om.
En omkörning av importskriptet återställer bilderna från v1-arken.

## Rutregler och granskning

Alla nya poster använder `size: [0.94, 0.94]`, `anchor: [0.5, 0.5]` och noll
offset. Proportionerna bevaras; hela stillbilden ryms och centreras i en ruta.
Befintlig tornrörelse och effekter använder samma presentationskod som tidigare.
Detta pass lägger inte till separata bildruteanimationer.

`python tools/art/import_specials_v1.py` skapar även
`output/special-towers-v1-review.png` med samtliga torn förstorade och i
15/32/45 px-rutor. Godots befintliga `check_cell_fit.gd` provar även 21 px.
Grafikverkstaden visar bilderna via samma manifest som spelet.

Verifierat lokalt 2026-10-24:

- `python tools/check.py`: `CHECKS_OK`, hela befintliga sviten passerar.
- `python tools/godot.py --headless --path . --script res://tests/check_cell_fit.gd -- --campaign --smoke`:
  **372 layoutfall, 0 fel**, inklusive alla 43 kombinationstorn.
- Separat inventering: **43 unika sprite-id och 43 olika PNG-innehåll**.
- Kontrollsummor för **74 regel-, data- och testfiler** är oförändrade jämfört
  med början av detta grafikpass (äldre accepterade mekanikändringar ingår i utgångsläget).
- Samtliga torn visuellt granskade i Godots riktiga renderer vid 15/21/32/45 px;
  bild `output/special-native/frame00000002.png`.
- Windows och webb exporterade med `tools/export.ps1 -Release`. Windows
  release startad och renderad, attackljud verifierat via `smoke_windows.py --campaign --attack`.
- Grafikverkstaden öppnad i Chrome med `?view=art&profile=campaign`, nya torn
  synliga och alla bildkopplingar giltiga: **0 konsolfel och 0 varningar**.
  Bild `output/playwright/special-art-web-towers.png`.
