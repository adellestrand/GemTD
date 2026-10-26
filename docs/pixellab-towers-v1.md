# PixelLab – tornens ljusanimationer v1

Genomfört 2026-10-26 efter användarens beställning att fortsätta med alla torn efter fiendeanimationerna.

**67 unika tornbilder** har nu åttabildsloopar: den tidigare godkända Sapphire I och **66 nya** PixelLab-loopar. De täcker 48 grundtornsvarianter (åtta typer, kvalitet I–VI) och 43 specialtorn. Kvalitet IV–VI behåller sin befintliga återanvändning av III-bilden med kvalitetsmarkeringar. De 24 stentavlorna är markfällor med kodritade symboler och ingår inte i detta bildpass; deras reservporträtt är fortfarande sten.

## Utförande

Kristaller och energikärnor får lugna ljuspulser eller små reflexer. Byggnadernas geometri och silhuetter står stilla. Spelet använder befintlig `GemArt.idle_frame` med 5,25 bilder/s och simuleringens presentationsklocka. Porträtt använder fortsatt bildruta 0.

Varje ursprungsbild placeras utan omskalning på en transparent duk med marginal. PixelLab `animate_image` genererar åtta rutor med samma start- och slutreferens. Leverantörens ingångsruta och genererade rutor 1–7 packas till remsan; den sista återgångsposen utelämnas, som i Sapphire-piloten.

Importen överför bara leverantörens ljusintensitet inom en sparad mask för kristaller/kärnor. Intensiteten begränsas till 0,82–1,25 gånger referensens; referensens färgförhållanden och alpha behålls. **Alla pixlar utanför masken är exakt oförändrade.** Heiyaoshi och Huguoshenyishi har särskilda masker för ögon respektive energikärna, eftersom en generell färgmask inte fångade rätt ytor.

Manifestets bildsökväg, `frames` och `idle_fps` uppdateras. Storlek, ankare, färgkopplingar, spelregler, skada, RNG och sparformat behålls. Sapphire I och fiendeanimationerna är oförändrade.

## Filer och granskning

- `assets/graphics/pixellab-towers-v1/<id>_idle_v1.png`: nya remsor.
- `<id>_reference.png`, `<id>_mask.png`: exakta källor och tillåtna ljusytor.
- `<id>.generation.json`: tidigare manifestpost, rörelsebeskrivning, seed, leverantörskvitto med jobb-/asset-ID, bearbetning, validering och SHA-256.
- Tidigare tornbilder bevaras i sina ursprungliga mappar.
- Råbilder, arbetsplan, jobbkvitton, kontaktark, filkontroller, renderade kontrollbilder och loggar finns lokalt i `output/pixellab-towers-v1/` (Git-ignorerat).

Alla kvaliteter och specialtorn kan granskas under **Towers & quality**. Bilderna är nu levande även där och i **Combat & motion**; Space pausar och återupptar.

```powershell
powershell -ExecutionPolicy Bypass -File tools/art_preview.ps1 -Towers
```

`tools/art/pixellab_towers.py prepare` skapar referenser/plan och vägrar skriva över en befintlig plan. `build` validerar och packar; `build --activate` ändrar manifestet först när samtliga 66 nya loopar är klara. Redan beställda jobb hämtas med `download_pixellab_enemies.py --work output/pixellab-towers-v1 <id> ...`, som använder den befintliga lokala nyckeln utan att spara den i projektet.

## Faktisk verifiering

- Alla 66 nya remsor är färdiga: åtta rutor, 4–8 unika ljusbilder per torn.
- Oberoende filkontroll av **528 packade rutor**: exakt samma alpha och oförändrade pixlar utanför respektive ljusmask; bildruta 0 matchar referensen.
- Kontaktark granskade och renderad Godot-granskning genomförd. Paus och återupptagning av tornförhandsvisningarna verifierade: `TOWER_GALLERY_CAPTURE_OK pause_resume=passed`.
- `python tools/check.py`: `CHECKS_OK`.
- Kampanjens `tests/check_art.gd`: `ART_CHECK_OK`, 130 sprites och 273 centrerade tornlayouter.
- `tools/export.ps1`: Windows- och webbexport lyckades utan motorfel. Windows-exportens kampanjstart med `--headless --quit-after 8 -- --campaign --smoke`: `SMOKE_READY`, utan motorfel.

**Inga tornbilder återstår i detta pass.** Det kostade 66 PixelLab-genereringar; efter fiende- och tornpassen är 4 883 av 5 000 kvar i den aktuella abonnemangsperioden.
