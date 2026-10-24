# Maze-tips (labyrintförslag)

Status 2026-10-24. Ren presentation: vyn och överlägget läser brädet men ändrar aldrig regler, data eller sparformat.

## Vad spelaren ser
- **Mazes** i toppfältet (bredvid Recipes) öppnar vyn *Maze tips* i receptbokens stil: en lista med åtta namngivna förslag till vänster och en minikarta till höger som visar det förslag pekaren står på. Minikartan visar checkpoints, befintliga stenar/torn, rutor att bygga (rosa) och startstenar att riva (orange).
- **Show on board** stänger vyn och ritar förslaget på spelplanen: halvgenomskinliga rosa rutor med kontur på varje ruta som ännu är tom (svagare under strid), orange streckad ruta med kryss på startstenar som måste rivas (bara i byggfasen). Rutor som redan är bebyggda markeras inte längre, så överlägget krymper medan man bygger.
- Under spelplanen visas `Maze: <namn> byggda/totalt · Hide (G)`. Länken, knappen **Hide maze guide on board** i vyn eller tangenten **G** stänger av överlägget; **G** tar tillbaka senast valda förslag. Valt förslag ligger kvar vid ny omgång (det är en plan för kartan), men sparas inte mellan programstarter.
- Färgen kommer från paletten (`maze_guide`, standard `#ff7ad9`) och skiljer sig från rutter, materialmarkeringar, receptspårning och placeringsmarkeringar (kontrolleras i testet).

## Källa – vad som är verifierat
Verifierat i lokala referensen `.tools/reference/mode.lua` (Dota 2 GemTD, paket 2026-08-01):
- Spelet har en *maze guide*: `show_maze_guide`, `click_maze_guide_coop`, `OnSaveMaze`, nättabellen `game_maze`.
- Layouterna är 37×37-matriser `_G.maze_coop0..8` (1 = byggd ruta). `maze_coop0` är tom; den platsen ersätts av spelarens egen sparade labyrint (`usermaze`). Racekartan har egna 17×17-layouter (`maze_race1..3`), som inte gäller vår karta.
- Vilka layouter som visas beror på antalet spelare: 1 spelare → coop1, coop2, coop4; 2 → coop3, coop2, coop6; 3 → coop5, coop6, coop8; 4 → coop5, coop7, coop8.
- Koordinater: matrisrad *i* och kolumn *j* ritas på världspunkten `x = (j-19)*128`, `y = (19-i)*128`. Med vår nollbaserade, Y-speglade karta (se `docs/referensinventering.md`) blir det cell `(j-1, i-1)`. Kontroll: ingen av layouternas rutor hamnar på någon av de sju checkpoints; med någon annan spegling/rotation gör flera det.

Inte i källan: namn och beskrivningar. Panorama-gränssnittet (bilder/texter för guiden) finns inte i referensdatan och `english.txt` har inga maze-texter.

## Egna tolkningar och anpassningar
- **Namn och korta beskrivningar** (Diagonal Spiral, Twin Spirals, Diamond, Spiral Corridor, Square Spiral, Nested Rings, Twin Diamonds, Grand Labyrinth) är våra, skrivna från formen. Vyn säger det uttryckligen.
- **Alla åtta** layouter visas, inte bara solouppsättningen. Varje kort anger vilken Dota-uppsättning den kommer från (t.ex. "Dota solo guide", "Dota 3/4-player guide"); solouppsättningen har rosa sidostreck och står först.
- **Startstenar att riva.** Fyra layouter (coop2, coop4, coop5, coop7) blockerar vägen i vår motor om alla 32 startstenar står kvar (vår motor tillåter inga diagonala hörnpassager). `tools/extract_maze_tips.py` räknar fram ett minimalt antal startstenar att riva (girigt, i koordinatordning) så att alla sju etapper är öppna. Det är vår anpassning; varför Dota-layouten fungerar där är inte verifierat. Rivning finns redan i spelet (Demolish, utan återbetalning).
- **Byggrundor** i vyn = tomma rutor / 5 placeringar per runda, avrundat uppåt. Rutten när labyrinten är klar räknas med `GemBoard.path_for` på startkartan (skrivskyddat).
- Vilka rutor som ska bli torn och vilka stenar anger källan inte; överlägget säger bara "bygg här".

## Filer
- `tools/extract_maze_tips.py` – läser `mode.lua` och `data/catalog.json`, kontrollerar checkpoints och väg, skriver `game/presentation/maze_tip_layouts.gd` (genererad, ändra inte för hand).
- `game/presentation/maze_tips.gd` (`GemMazeTips`) – namn, beskrivningar, spelaruppsättningar och skrivskyddade hjälpfunktioner (`cells`, `removals`, `progress`, `route_length`).
- `game/presentation/maze_book.gd` (`GemMazeBook`) – vyn.
- `game/board_view.gd` – `set_maze_tip`, `draw_maze_guide`, `draw_maze_removals`.
- `game/main.gd` – knappen Mazes, länken under brädet, tangenten G.
- Test: `python tools/godot.py --headless --path . --script res://tests/check_maze_tips.gd -- --smoke` ska ge `MAZE_TIPS_CHECK_OK`. Ingår inte i `tools/check.py` (lägg bara till efter användarens godkännande).

## Kvar / idéer
- Dotas plats 0 är spelarens egen sparade labyrint (`OnSaveMaze`). En "Save current maze" skulle passa här men kräver lagring i `user://` – inte gjort.
