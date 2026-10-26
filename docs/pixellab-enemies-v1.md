# PixelLab – fiendeanimationer v1

Genomfört 2026-10-26 på användarens beställning efter godkänd vildsvinspilot och aktivering av Tier 2.

Alla **51 unika fiendebilder som är kopplade i manifestet** har nu åtta bildrutor. Vildsvinets godkända PixelLab-loop behålls. Övriga **50** har nya, individuellt beskrivna rörelseloopar från PixelLabs `animate_image`. Två äldre, okopplade reservbilder (`hound`, `spider`) behåller sina gamla remsor.

## Bilder och spårbarhet

- `assets/graphics/pixellab-enemies-v1/<id>_move_v1.png`: nya horisontella remsor.
- `<id>_reference.png`: exakt första spelpose, beskuren och centrerad på en större transparent duk utan omskalning.
- `<id>.generation.json`: källa, tidigare manifestpost, rörelsebeskrivning, seed, PixelLab-kvitto med jobb-/asset-ID, valda bildrutor och filhash.
- Vildsvinet finns fortsatt i `assets/graphics/pixellab-v1/boar_walk_v1.png`.
- Tidigare remsor i `refined-v3/anims` bevaras.

Bilderna är 56–96 pixlar breda och 56–88 pixlar höga per ruta, med marginal för lemmar. PixelLab levererar ingångsrutan plus åtta genererade rutor. Ruta 0–7 packas till loopen; den sista, fastnålade återgångsposen utelämnas som i den godkända vildsvinspiloten. Ingen individuell omcentrering mellan rutor görs. Spelets gemensamma alpha-beskärning används fortsatt.

Rörelsen följer figurens kropp: gång/trav, hopp, vingslag, simmande fenor, svävande ballonger/matta, rotor eller skateboard. Roshan fick ett andra försök för tydligare vingslag. Den första versionen finns i de lokala arbetsfilerna. Totalt debiterades **51 genereringar**; saldot var **4 949 av 5 000 kvar** efter körningen.

PixelLab gjorde den osynliga spindelns genererade rutor ogenomskinliga. Importen återställer referensens alpha-nivå i dessa rutor, så att figuren inte blinkar mellan genomskinlig och ogenomskinlig.

## Integration och granskning

Manifestet pekar på de nya remsorna. Varje figur behåller `size`, `anchor`, eventuellt eget rörelsetempo och övriga kopplingar. Extra procedurstyrd studs, squash och svaj sätts till noll eftersom rörelsen nu finns i bildrutorna. Markfiendernas animation följer fortfarande tillryggalagd sträcka; flygande följer spelets tid. Balans, RNG, sparformat, kartans grid och tornbilder ändras inte av detta pass.

**Enemies & scenery** i grafikgalleriet visar nu alla 51 unika kopplade figurer som levande loopar, med rörelsetyp och antal rutor. Space pausar.

```powershell
powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1 -Enemies
```

Arbetsfiler, nio råbilder per jobb, kontaktark, animerade GIF-översikter, renderade Godot-bilder och loggar finns lokalt under `output/pixellab-enemies-v1/` (Git-ignorerat).

Verktyg:

- `prepare_pixellab_enemies.py` förbereder referenser och rörelseplan. En befintlig plan skrivs inte över.
- `download_pixellab_enemies.py <id> ...` hämtar redan beställda jobb med den befintliga lokala PixelLab-nyckeln. Nyckeln sparas inte i projektet.
- `import_pixellab_enemies.py` validerar och packar; `--activate` uppdaterar manifestet först när alla 50 finns. Fel storlek, tomma rutor, för få unika rutor och möjlig klippning stoppar aktivering.

## Genomförd verifiering

- Samtliga 50 nya remsor: åtta unika rutor, rätt dimensioner, ingen bild når dukkanten; första rutan matchar referensen.
- Alla bildrutor granskade i kontaktark; renderad granskning i Godot av det integrerade galleriet.
- `python tools/check.py`: `CHECKS_OK`, inklusive animationernas gemensamma beskärning, sträckstyrning och spelregressioner.
- `python tools/godot.py --headless --path . --script res://tests/check_art.gd -- --campaign --smoke`: `ART_CHECK_OK`, 130 sprites, 273 tornlayouter och alla kampanjfiender upplösta.
- `powershell -ExecutionPolicy Bypass -File tools/export.ps1`: Windows- och webbexport lyckades utan motorfel.
- Windows-exporten startad med `--headless --quit-after 8 -- --campaign --smoke`: `SMOKE_READY`, utan motorfel.
