# Redesign – överlämning till Claude Code (2026-10-24)

Den här filen sammanfattar design-/grafikarbetet som gjordes i en Claude-session (molnmiljö) så att arbetet kan fortsätta i Claude Code direkt i repot. Inga commits har gjorts; allt ligger som ändringar i arbetskatalogen.

## Grundregel
Var SUPER försiktig med själva spelet så att balanseringen inte förstörs. Ändra bara presentation (grafik, UI, animation). Röd zon = `game/core/`, `data/`, bygg-/verifieringsskript och befintliga tester.

- Skyddskontroll: `python tools/redesign_guard.py` ska ge `RED_ZONE_OK`. `--baseline` sparar ny baslinje (bara när användaren godkänt ändringar i röd zon – senast godkänt 2026-10-24 efter vågtäthets-/fällarbetet, och igen samma dag efter det andra verktygets regel-/dataändringar i `data/`, `game/core/`, bygg-/verifieringsskript och `check_boss_discount.gd`, och igen samma kväll när användaren godkände att Diamond och Ruby även anfaller flygande fiender, och igen när användaren beställde att två lika traps var som helst på brädet uppgraderas, och igen när användaren beställde guldförmågorna i paket A: Gem/Quality Pray och Heal, se `docs/gold-spells.md`; baslinjen sparades efter commit, inklusive det andra verktygets leaderboardändringar i `game/core/catalog.gd` och `tests/check_leaderboard.gd`).
- Full testsvit: `python tools/check.py` (30 kontroller inkl. `check_cell_fit.gd`, `check_trap_placement.gd`, `check_enemy_frames.gd` och `check_spells.gd`).
- Separat test (ingår inte i `check.py`, enligt användarens val): `python tools/godot.py --headless --path . --script res://tests/check_recipe_hover.gd -- --campaign --smoke` ska ge `RECIPE_HOVER_CHECK_OK` (receptbokens ingrediensnamn vid hovring).
- Separat test (ingår inte i `check.py`): `python tools/godot.py --headless --path . --script res://tests/check_recipe_lines.gd -- --campaign --smoke` ska ge `RECIPE_LINES_CHECK_OK` (receptbokens uppgraderingslinjer och grön/gul-markering).
- Separat test (ingår inte i `check.py`): `python tools/godot.py --headless --path . --script res://tests/check_maze_tips.gd -- --smoke` ska ge `MAZE_TIPS_CHECK_OK` (maze-tips-vyn och överlägget).
- Separat test (ingår inte i `check.py`): `python tools/godot.py --headless --path . --script res://tests/check_route_toggle.gd -- --smoke` ska ge `ROUTE_TOGGLE_CHECK_OK` (kryssrutan "Show routes" för fiendernas väglinjer).
- Efter nya bildfiler: `python tools/godot.py --headless --editor --path . --import` (annars `.ctex`-fel vid start; `.godot/` är git-ignorerad).
- Repot använder LF-radslut.

## Vad som är gjort
**Grafik**
- `assets/graphics/refined-v3/`: 44 förfinade sprites (från de godkända AI-arken, dolt pixelrutnät rekonstruerat med `tools/art/refine.py`). Användaren avvisade helt ny pixelstil (B) – behåll den här stilen.
- `assets/graphics/refined-v3/variants/`: 43 fiendevarianter (färg + små tillbehör) skapade av `tools/art/variants.py`. Alla 50 kampanjfiender har nu egen bild via `bindings.enemies` i `assets/graphics/manifest.json`, mappat efter Dota-versionens courier-modeller.
- Torn/stenar passar och centreras i sin ruta (manifest-storlekar 0.94, test `tests/check_cell_fit.gd`).

**UI (`game/main.gd`, `assets/graphics/ui_theme.tres`, temat genereras av `python tools/art/theme_gen.py assets/graphics/ui_theme.tres`)**
- Kartan fyller hela fönstret med skog runt rutnätet (`board_view.gd: draw_surroundings`). Paneler är halvgenomskinliga overlays. Kartans yta (`safe_rect`) räknas bara om vid fönsterändring (`update_map_area`) – inget hopp vid hover.
- Stor karta: `VISIBLE_ROWS = 34` i `board_view.gd`. Minsta zoom = den storleken; hjul zoomar in; panorera med höger-/mittenknapp, piltangenter eller WASD; F centrerar.
- Fast designyta 1600×900 (16:9) som skalar till 1080p/1440p/4K. Run ▾ → Display: helskärm (F11) eller fönster 1920×1080 / 2560×1440 / 3840×2160; sparas i `user://settings.cfg`.
- Sidopanel: vågkort med taggar, tornkort med statbrickor, tydlig knapphierarki, odds som stapel. Dolda gamla etiketter (`detail_label`, `wave_label`, `odds_label`) finns kvar eftersom testerna läser dem.
- Dialoger har riktig ram och dimmad bakgrund.
- Receptbok (`game/presentation/recipe_book.gd`): helskärm, alla 59 kampanjrecept syns utan scroll vid 1080p. Tornrecept grupperade per uppgraderingslinje (`chain_groups()`, härledd ur receptträdet = Dotas `_G.gemtd_merge`: varje Top-torn med alla kombinerade torn som leder dit, bas först; sidotorn som Sea Jewel/Egypt Gold följer linjen de byggs av), därefter hemliga recept i två grupper. Linjerna fördelas jämnt på 4 kolumner utan att delas. Nivåfärg (Basic/Intermediate/Advanced/Top från Dota-hjälptexterna) i toppraden, fällor i egen kolumn, kort beskrivning per rad (`SUMMARY`), detaljpanel vid hover. Ingredienschips: grön = placerad i tidigare runda, gul = finns bara bland rundans nya gems, brons = delvis, grå = saknas; kort med "Ready" får samma grön/gul-ram.
- Fiendernas väglinjer (mark/luft) visas bara när kryssrutan **Show routes** under kartan är ikryssad (även i byggfasen); R växlar den, valet sparas i `user://settings.cfg` (`map/routes`, standard på). Byggförhandsvisningen av vägen visas alltid.
- Maze-tips (`game/presentation/maze_book.gd`, `maze_tips.gd`, genererad `maze_tip_layouts.gd`): knappen **Mazes** visar Dota-versionens åtta labyrintförslag (`maze_coop1..8` ur `mode.lua`, egna namn) med minikarta; valt förslag ritas som rosa överlägg i `board_view.gd` tills det stängs (länk under brädet, knapp i vyn eller G). Se `docs/maze-tips.md`.

**Animation**
- Fiender interpoleras mellan 30 Hz-simuleringssteg (`capture_positions`, `tick_alpha`, `render_position`), mjuk vändning (`facing`), träffrekyl, ny gång-/flygcykel i `GemArt.enemy_motion`.
- Tornanimationer i `game/presentation/tower_motion.gd`.
- Animationsremsor för fiender (`"frames": n` i manifestet, `GemArt.frame_texture`/`enemy_frame`). Alla tio fiendefamiljer plus deras varianter (53 sprites) har 4-rutorscykel: gång för de åtta markfamiljerna, vingslag för bat och griffin, byggd med pxl (`tools/art/build_anims.py`, alla cykler i `tools/art/anims/walk.px.js`). 32 fiender har dessutom egen kropp i stället för omfärgning: AI-förfinade bilder i `assets/graphics/refined-v4/` (ark v2, `docs/ai-enemy-sheets-v2.md`) animerade i `walk.px.js` som `_v3`-remsor; pxl-ritade reserver i `tools/art/anims/creatures.px.js` (`_v2`). Se `docs/graphics.md` → Animationsremsor. Test: `tests/check_enemy_frames.gd`.

## Kvar / idéer
- Bossarna i refined-v4 (shagbark, carpet_rider, ghost, baby_roshan) har grövre pixlar än boss_hound eftersom AI-arket ritade dem i normal storlek; generera dem i större ruta om det stör.
- Egen konst för kvalitet IV–VI (återanvänder III).
- Innehållet i Help/Summary-dialogerna är fortfarande löptext.
- Inte testat på riktig Windows-maskin eller webbexport ännu (`tools/export.ps1`).

## Observera
Ett annat verktyg har parallellt ändrat regler/data (vågtäthet, fällplacering: `run.awaiting_trap_placement`). Användaren har godkänt dessa. Kontrollera alltid filers aktuella innehåll innan du skriver över dem.
