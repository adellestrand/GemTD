# PixelLab – förmågeeffekter v1

Genomfört 2026-10-26 på användarens beställning: gör alla elva förmågeutseenden snyggare och tydligare med PixelLab, och visa hur det blir när en fiende har flera effekter samtidigt. Rent presentationslager; strid, RNG, balans och sparformat är orörda.

## Vad som byttes

Förut ritades förmågorna med 1 px-bågar och streck i `ability_art.gd`. Nu används 19 animerade klipp från PixelLabs `vfx_workbench` (gratis för prenumeranter, inga genereringar debiterades). De är byggda runt vildsvinet nedskalat till 32 px, alltså spelets verkliga skala, och exporterade som spelpaket med separata lager bakom och framför figuren.

| Utseende | Statusloop på fienden | Träffklipp |
| --- | --- | --- |
| fire | `status_burn` (lågor, kvar 0,6 s efter verklig eldskada) | `hit_fire` |
| poison | `status_poison` (bubblor) | `hit_poison` |
| frost | `status_frost` (iskristaller) + blå ton | `hit_frost` |
| fracture | `status_fracture` (pilar nedåt) | `hit_fracture` |
| stun | `status_stun` (stjärnor över huvudet) | `hit_stun` |
| stone | gråskalepass av figuren | `hit_stone` |
| shield | `status_shield` (bubbla) | `hit_shield` |
| lightning | `status_shock` (gnistor, kvar 0,5 s) | `hit_lightning` |
| critical | – | `hit_critical` + `CRIT` |
| blast | – | `hit_blast` |
| support | `status_support` (guldpilar på torn med verklig stödbonus) | `hit_support` |

Aura- och dot-tick (t.ex. Asteriated Ruby var 0,25 s) får inget nytt träffklipp per tick; de håller i stället statusloopen igång. Kedjelänkar, auraringar och MVP-markeringar är oförändrade procedurella linjer.

## Flera effekter samtidigt

- Ritordning per fiende: bakre lager för alla aktiva statusar, figuren, främre lager, sedan träffklipp riktade mot just den fienden. Livsmätare och statusikoner ritas sist.
- Lagerordning (`status_layer_order`): shield, fracture, frost, burn, poison, shock, stun.
- Tak: högst `max_statuses` = **4** loopar per fiende, valda efter `status_priority` (stun, stone, frost, burn, poison, shock, fracture, shield). Statusikonerna över huvudet visar fortfarande alla tillstånd.
- Grafikverkstadens nya flik **Status effects** visar 1–7 staplade statusar i spelskala (26 px/ruta) och förstorat (52 px/ruta), samma fiender med taket på fyra, samt alla träffklipp i loop.

Utan tak blir fem eller fler statusar röriga i spelskala; med taket på fyra går det att läsa. Användaren bekräftade taket på fyra 2026-10-26. Taket och prioriteringen ändras i `ability-effects.json`.

## Filer

- `assets/graphics/pixellab-vfx-v1/<klipp>_<behind|front>_v1.png`: horisontella remsor, alla lager utfyllda till effektens hela längd.
- `<klipp>.generation.json`: PixelLab-del, My effects-id (öppnas på pixellab.ai med reglage), export-id, paketmanifest och filhashar.
- `assets/graphics/ability-effects.json`: `clips` (skrivs av importen), samt handredigerade `hit_clips`, `status_clips`, `status_priority`, `status_layer_order`, `max_statuses`, `status_tints`, `status_overlays`, `status_memory`, `support_clip`, `support_clip_alpha`.
- `tools/art/import_pixellab_vfx.py`: hämtar spelpaketen (cache i `output/pixellab-vfx-v1/`) och skriver remsor och `clips`.
- `game/presentation/ability_art.gd`: klippritning, statuslogik och tak; `effects.gd`: brinn-/chockminne och träffindex per fiende; `art.gd`: gråskalekopia för sten; `status_stack_preview.gd`: verkstadsfliken.

Ett klipp justeras i PixelLab (My effects-länken i `.generation.json`), exporteras igen med `--replace` och `--game-pack`, och ID:t uppdateras i importskriptet. Kör sedan:

```powershell
python tools/art/import_pixellab_vfx.py
python tools/godot.py --headless --editor --path . --import
```

## Kontroller (2026-10-26)

- `python tools/check.py`: `CHECKS_OK`.
- `python tools/godot.py --headless --path . --script res://tests/check_ability_clips.gd -- --campaign --smoke`: `ABILITY_CLIPS_CHECK_OK checks=68` (separat test, ingår inte i `check.py`).
- `check_ability_art.gd`: `ABILITY_ART_CHECK_OK checks=208`, inklusive samma strid och RNG med och utan effekter för alla 43 torn.
- `python tools/redesign_guard.py`: flaggar bara `tests/check_leaderboard.gd`, som redan var ändrad i arbetskatalogen före detta pass.
- Godot-rendering av flikarna Status effects och Abilities granskad. Inte provat i webbexport eller på en annan Windows-maskin.
