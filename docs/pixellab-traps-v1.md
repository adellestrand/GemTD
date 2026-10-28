# PixelLab – fällor, pilot v1

Genomfört 2026-10-26 på användarens beställning (experiment 3 i bildgranskningen): ge fällorna riktiga bilder. Kopplat i spelet samma dag på användarens beställning (se Inkoppling).

## Utgångsläge

Fällorna (8 familjer × brons/silver/guld = 24 sorter) saknar bild. `GemReadability.trap` ritar en mörk ruta med en tunn färgad kant, en liten symbol och ett–tre streck för graden. Manifestet binder dem till stenbilden, som inte används för fällor på vägen.

## Vad som gjordes

Ett enda `create_1_direction_object`-anrop (top-down, 32×32 px) med 24 beskrivningar, en per sort. Stilreferens: checkpointens stenplatta (`refined-v3/checkpoint.png`) nedskalad till 32 px. Kostnad: **10 generationer**. Alla 24 valdes ur granskningspaketet och sparades som egna objekt i PixelLab (tagg `gemtd-traps-v1`).

| Familj | Symbol |
| --- | --- |
| Howl | ylande varghuvud, mintgrön |
| Torrent | vattenvirvel, turkos |
| Dread | dödskalle, lila |
| Paralysis | tunna med blixtar, gul |
| Acid | bubblande syrapöl, gulgrön |
| Ethereal | spöklik spiral, blekt vit |
| Entangle | rotknut, grön |
| Venom | giftvind med huggtänder, grön |

Graden syns på kanten: enkel brons, polerat silver, guld med hörnstenar.

Filer: `assets/graphics/pixellab-traps-v1/<sort>_v1.png` (samma namn som fällans id, t.ex. `mabishiban_jin_v1.png`) och `traps_v1.generation.json` med objekt-id, inställningar och hashar. Råfiler i `output/pixellab-traps-v1/raw/`.

## Resultat i 26 px per ruta

21 fällor lades längs fiendernas väg på ett riktigt bräde och renderades två gånger: med dagens rutor och med plattorna ritade ovanpå, i samma storlek som tornen (0,94 ruta).

- Plattorna syns tydligt mot gräset och smälter in i samma stil som checkpointen och tornen.
- Familjen syns på symbolens form och färg; graden syns på kantens metall utan extra streck.
- Svagast i v1: Entangle (grön knut på grå sten) och Howl (ljus symbol) hade lägre kontrast än övriga; ersatta med v2, se nedan.

## Inkoppling (2026-10-26)

- `assets/graphics/manifest.json`: sprites `trap_<sort>` och bindningen `bindings.traps` (sort → sprite), storlek 0,94 ruta som tornen.
- `game/presentation/readability.gd`: `trap()` ritar bilden när en bindning finns; annars ritas dagens ruta med symbol och gradstreck som reserv. Grafikverkstadens Clarity-flik använder samma funktion.
- Test: `python tools/godot.py --headless --path . --script res://tests/check_trap_art.gd -- --campaign --smoke` ska ge `TRAP_ART_CHECK_OK` (separat, ingår inte i `check.py`). `python tools/check.py` ger `CHECKS_OK`.
- Kontrollerat i en riktig Godot-rendering av brädet. Regler, data och sparformat är oförändrade.

## Entangle och Howl v2 (2026-10-28)

Användaren bad om bättre kontrast för de två svagaste familjerna. Nytt `create_1_direction_object`-anrop (10 generationer) med 12 beskrivningar i två riktningar och `kongheshiban_v1.png` som stilreferens:

- **A (vald):** mörk skifferplatta med starkt ljus symbol och tjock mörk kontur: limegrön rotknut respektive mintgrön varg.
- B: grå platta med mörkgröna rötter respektive turkos varg med ljudvågor. Läste sämre i 24 px.

Valda bilder: `youbushiban*_v2.png` och `haojiaoshiban*_v2.png` i samma mapp, med `traps_v2.generation.json`. Manifestet pekar nu på v2; v1-filerna finns kvar. Övriga sex familjer är oförändrade. Samma dag gjordes även övriga sex familjer om med mörk platta (se nedan), så alla 24 hör ihop.

Kontroller: `TRAP_ART_CHECK_OK`, `python tools/check.py` ger `CHECKS_OK`, och brädet är granskat i en Godot-rendering.

## Alla mörka (2026-10-28)

Användaren valde riktning A för alla. Ett tredje anrop (10 generationer, stilreferens `haojiaoshiban_v2.png`) gav Torrent, Dread, Paralysis, Acid, Ethereal och Venom med mörk platta, ljus symbol och tjock kontur i brons, silver och guld. Manifestet pekar nu på `*_v2.png` för alla 24 sorter; v1-filerna finns kvar. Herkomst i `traps_v2.generation.json`.

Paralysis (tunna med liten blixt) är minst tydlig i v2 men läsbar. Övriga symboler är tydligare än i v1.

Kontroller: `TRAP_ART_CHECK_OK`; brädet granskat i Godot-rendering. `python tools/check.py` hade ett fel i `tests/check_sidebar.gd` ("changing tabs and resizing preserve the run"), ett nytt otrackat test från ett annat verktygs pågående sidopanelsarbete; testet ändrar själv guld och kvalitet efter sin ögonblicksbild. Det rör inte fällorna och ändrades inte här.
