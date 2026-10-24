# AI-ark för egna fiendekroppar, v2 (2026-10-24)

Mål: ge de 32 fiender som specificeras nedan och i dag har pxl-ritade kroppar (`tools/art/anims/creatures.px.js`) samma AI-förfinade utseende som refined-v3. Samma metod som `assets/graphics/PROMPTS.md` (enemies-v1): ett genererat ark per 4×3 rutor, därefter `refine.py`-rekonstruktion av pixelrutnätet. Endast presentation; inga regler eller värden ändras.

## Status

De tre arken är **genererade 2026-10-24** med Codex inbyggda `image_gen`, med v1 som stilreferens och respektive referensark som layoutguide. Slutversionerna ligger oförändrade i `assets/graphics/generated/enemies-v2a.png`, `enemies-v2b.png` och `enemies-v2c.png`. Exakta prompter, layoutjusteringar och källfilnamn finns i `assets/graphics/generated/enemies-v2-generation.json`. De angivna rutorna innehåller 12 + 12 + 8 = **32** fiender; den tidigare inledningen angav felaktigt 34.

Råarken är RGBA, 1447×1087 px (nära 4:3), med 4×3 rutor. Layouten har justerats för att undvika klippta figurer: inga pixlar med alfa ≥128 ligger på rutgränserna. Marginaler och fotlinjer är ungefärliga; promptens minst 15 % marginal uppnås inte av varje figur. Svaga rester med alfa 1 finns i bakgrunden, även i v2c:s tomma nedersta rad (1785 pixlar, högst 1/255 opacitet); `refine.py` tar bort dessa med sitt befintliga alfatröskelvärde. Råarken är alltså inte helt fria från alfabrus.

`python tools/art/refine_v2.py` har skapat samtliga 32 separata PNG-bilder i `assets/graphics/refined-v4/` (34–62 px breda, 36–56 px höga; rapporterat pixelrutnät 4,60–4,65). Alla har verifierats som icke-tomma RGBA-bilder med enbart alfa 0/255. Råarken har verifierats byte-identiska med bildverktygets slutresultat. Rapport: `assets/graphics/generated/enemies-v2-validation.json`.

Kontroller 2026-10-24: `python tools/redesign_guard.py` → `RED_ZONE_OK files=69`; `python tools/check.py` → `CHECKS_OK`. Efter att alla 32 bilder var färdiga kördes även `python tools/godot.py --headless --editor --path . --import` utan `ERROR:` (logg i `output/enemy-v2-import.log`). Dessa kontroller verifierar inte framtida animation eller storlek vid inkoppling i spelet.

Animering och inkoppling är klara (2026-10-24): alla 32 refined-v4-bilder animeras i `tools/art/anims/walk.px.js` (`V4`-tabellen, `walk4`) och byggs av `python tools/art/build_anims.py` till `assets/graphics/refined-v3/anims/<fiende>_<walk|flap>_v3.png`, som manifestet nu pekar på. Markfigurer: benområden från fötterna upp till en ledrad (`tools/art/leg_regions.py` ger förslag), parvis växlande steg (`STEP_A`/`STEP_B`), zombien hoppar med båda fötterna (`HOP`). Flygare: vingar/fenor som skjuvas (`BEAT`, `UPRIGHT_WING`), stjärtfenor som svajar (`SWAY`), pandans rotor snurrar (`spin`), ballongerna guppar (`shift`), flygmattan och spökets kåpa böljar (`wave`). Duken har 4 px marginal så att fötter och vingar inte klipps, och små lösa pixelgrupper som en flyttad del lämnar efter sig tas bort (`despeckle`). De pxl-ritade `_v2`-remsorna ligger kvar som reserv; manifestet före bytet finns i `output/pxl/manifest_before_v3.json` (git-ignorerad).

Pixelstorlek i spelet: 2,02–3,02 skärmpixlar per bildpixel för vanliga fiender (refined-v3: 1,76–2,60; rabbit 3,02 och young_demon 2,84 ligger över) och 2,98–3,56 för bossarna (boss_hound 2,47), eftersom arket ritade bossarna i samma storlek som övriga figurer. Grövre bosspixlar kan rättas genom att generera bossarna i större ruta.

## Arbetsflöde

1. Generera tre ark med prompterna nedan. Bifoga bilderna i angiven ordning:
   - bild 1: `assets/graphics/generated/enemies-v1.png` (stil, pixelstorlek, ljus, konturer),
   - bild 2: `tools/art/ai-reference/<ark>-reference.png` (vilken fiende i vilken ruta, kroppsform och pose; våra pxl-kroppar, inte stilmall).
2. Spara oförändrade PNG:er som `assets/graphics/generated/enemies-v2a.png`, `-v2b.png`, `-v2c.png` (transparent bakgrund, 4×3 lika rutor).
3. `python tools/art/refine_v2.py` → en ren PNG per fiende i `assets/graphics/refined-v4/`.
4. Animering: lägg till ben-/vingområden i `tools/art/anims/walk.px.js` och rader i `ANIMS` (`tools/art/build_anims.py`) på samma sätt som för refined-v3-familjerna; peka manifestets sprite på den nya remsan (`_v3`). pxl-kropparna (`_v2`) ligger kvar som reserv.
5. Kontroller: Godot-import, `python tools/redesign_guard.py`, `python tools/check.py`.

## Gemensam prompt (inleder alla tre)

```text
Use case: stylized-concept. Asset type: ONE production enemy sprite atlas PNG for an original Godot GemTD-inspired game. Image 1 is our approved ENEMY ATLAS v1 and determines pixel scale, lighting, outlines and limited palette: match it exactly so the new creatures sit beside it. Image 2 is a LAYOUT AND IDENTITY GUIDE ONLY: it shows which creature goes in which cell and its rough body shape and pose; do not copy its simpler rendering, redraw every creature in the style of image 1. Create a perfectly regular 4-column by 3-row sprite sheet, aspect ratio 4:3, ideally 1280x960. Each cell contains exactly ONE complete isolated creature, centered with lots of transparent padding (at least 15% cell width each side), ground creatures' feet on the same local baseline, flying creatures hovering slightly above it with wings spread. Genuine transparent alpha background. No backdrop, checkerboard, text, labels, borders, numbers, ground tiles or scenery. Same chunky crisp pixel-art technique as image 1: dark near-black outlines, solid pixel clusters, top-left light, warm highlights and rich restrained colors. Camera viewed down at top/front; creatures face diagonally down-right. Roughly 40x40 logical pixel density, enlarged crisp edges, no smooth painting, blur or photorealism. Tiny gameplay silhouettes must be distinct. All creatures are original designs inspired by the descriptions, not copied Dota models. Empty cells stay fully transparent.
```

## enemies-v2a

```text
READING ORDER EXACTLY: Row1 col1 walking tree stump with a cut top showing rings, moss clumps on the rim, a small two-leaf sprout, big amber eyes and a toothy grin on the trunk, four root legs; col2 small walking mushroom, big red cap with cream spots, pale stalk body with a cute face, stubby feet; col3 blue-gray shark walking on four small fin-feet, white belly, tall dorsal fin, forked tail, toothy open grin; col4 round fluffy coral-pink furry fish with fur tufts, small fins as feet, big eyes. Row2 col1 pink flamingo standing on a wooden skateboard, long legs, S-shaped neck, white and black bent beak; col2 chubby teal flightless dodo-dragon bird with a heavy orange beak, small crest and stubby legs; col3 white hen with a red comb and wattle wearing a golden champion belt, yellow legs; col4 small red imp demon on two legs with curved horns, small bat wings, spade tail, glowing yellow eyes and fangs. Row3 col1 skeletal raptor bonejack: dark iron ribcage, bone skull with a huge toothed jaw, green soul glow in the chest, two clawed legs, spiky spine; col2 cream llama with long neck and banana ears wearing a red and blue livery blanket with gold trim; col3 forest faun child: goat legs with hooves, green vest, pointed ears, small horns, curly light-brown hair, backpack with bedroll, playing bagpipes; col4 tan rabbit with long upright ears, pink inner ears, white puff tail, hopping.
```

## enemies-v2b

```text
READING ORDER EXACTLY: Row1 col1 shaggy dark brown-purple lion cub wearing a silver-blue helmet with two glowing cyan eye slits, silver bands on its legs, pale blue claws; col2 small jiangshi hopping-vampire child in a navy Qing official robe and round hat with a blue bead, yellow paper talisman hanging over the face, blue-green skin, rosy cheeks, tongue out, arms stretched straight forward, both feet together; col3 tiny grim reaper in a blue hooded robe with a skull face, red rope belt, a big scythe and a cloth sack; col4 little elf girl with plum hair bun, two green leaf sprouts on her head, pointed ears, orange top and red skirt, carrying a small glowing lantern. Row2 col1 golden treasure chest on two metal legs, the open lid is a biting jaw with teeth, gold coins inside, two white viking horns and one big blue eye on top; col2 purple treasure chest with black iron trim on thin black legs, open toothy lid, green gems inside, curved black horns, a brown hair tuft and one big orange eye on top; col3 riveted steel treasure chest on metal legs, open toothy lid with gold coins inside, a small periscope box head with pipes and one big red eye; col4 flying golden fancy goldfish with bulging eyes, flowing veil tail and large orange fins spread like wings. Row3 col1 flying wooden pirate ship with a red-and-white striped sail and feathered white wings on its hull; col2 flying red fox with a black eye mask and red cape, small white wings, bushy tail; col3 flying black-and-white fox spirit with black ears and paws, black wings, two-tone tail; col4 flying white rabbit hero with a red cape, small golden crown band and white wings.
```

## enemies-v2c

```text
READING ORDER EXACTLY: Row1 col1 flying panda with a bamboo propeller on its head and a bamboo pack on its back; col2 small green amphibian kid with fin ears riding a teal flying fish whose fins beat like wings; col3 flying orange butterfly with a segmented purple caterpillar body and antennae, wing spots; col4 badger with a white-striped head and green saddle cloth hanging under two green-and-orange patchwork balloons with a big sack and a small tail rotor. Row2 col1 BOSS: hunched shaggy tree beast with a mossy leaf canopy on its back, bark body, mossy beard, glowing green eyes, thick knuckled limbs, larger than other cells' creatures but inside its cell; col2 BOSS: green goblin-like smeevil with big ears sitting on a waving purple magic carpet with gold tassels, waving a gold coin; col3 BOSS: hooded teal wraith with a dark face hollow, glowing green eyes, tattered robe streaming down-back, bony claws reaching forward, floating; col4 BOSS: chubby flying baby Roshan, gray rocky skin, cream belly, two curved horns, tusks, small wings. Row3: all four cells empty, fully transparent.
```

## Kontroll efter generering

- Varje ruta ska innehålla exakt en figur som inte korsar rutgränsen (annars skär `refine_cell` fel).
- Jämför `refine.py`-rapportens rutnät (cirka 4,6–5,3 källpixlar per bildpixel) med v1; avvikande värden betyder att arket har annan pixeltäthet och bör genereras om.
- Pixelstorlek i spelet ska hamna i refined-v3:s intervall (1,76–2,60 skärmpixlar per bildpixel vid manifestets storlek; bossar cirka 2,5).

## Bossar i större ruta (enemies-v2-bosses)

Syfte: bossarna shagbark, carpet_rider, ghost och baby_roshan visas i spelet med storlek 1,85 rutor men ritades i v2c i samma storlek som vanliga fiender (52–61 bildpixlar breda), vilket ger 3,0–3,6 skärmpixlar per bildpixel. boss_hound i v1 är 75×64 bildpixlar (2,47). Ett nytt ark med större rutor ska ge bossarna cirka 75 bildpixlar i bredd med samma pixelblock (cirka 4,6 källpixlar per bildpixel) som v1 och v2.

Status: **inte genererat**. Endast prompt, referensark och förfiningsstöd är förberedda.

Bifoga i ordning:
- bild 1: `assets/graphics/generated/enemies-v1.png` (stil och pixelstorlek; boss-vargen i rad 3, kolumn 2 visar exakt den önskade bosstorleken i logiska pixlar),
- bild 2: `tools/art/ai-reference/enemies-v2-bosses-reference.png` (2×2-layout, 1448×1086; varje boss förstorad till målstorleken, cirka 75 logiska pixlar bred, som identitet, pose och storleksguide),
- bild 3 (valfri): `assets/graphics/generated/enemies-v2c.png` (våra nuvarande bossdesigner i AI-stil, att behålla).

Spara oförändrat som `assets/graphics/generated/enemies-v2-bosses.png`. `python tools/art/refine_v2.py` förfinar det då till `assets/graphics/refined-v4/bosses/` (de nuvarande refined-v4-bossarna ligger kvar). Därefter: nya ben-/vingområden i `V4`-tabellen i `tools/art/anims/walk.px.js` (koordinaterna ändras med storleken), bygg och peka om manifestet.

```text
Use case: stylized-concept. Asset type: ONE production BOSS sprite atlas PNG for an original Godot GemTD-inspired game. Image 1 is our approved ENEMY ATLAS v1: match its pixel-art technique, logical pixel size, lighting, outlines and palette exactly; its BOSS war hound (row 3, column 2) shows the exact boss size: about 75 logical pixels wide and 64 tall, each logical pixel the same size as in image 1. Image 2 is a LAYOUT, IDENTITY AND SIZE GUIDE: four bosses in a 2x2 grid, each shown enlarged to the target size; redraw each one at that size with the extra detail a boss deserves (more logical pixels, NOT bigger pixels), keeping its design, colors and pose. Image 3, if attached, shows the same four bosses in our AI style at a smaller size: keep these designs. Create a perfectly regular 2-column by 2-row sprite sheet, aspect ratio 4:3, ideally 1448x1086, each cell exactly a quarter of the sheet. Each cell contains exactly ONE complete isolated boss, centered, about 75 logical pixels wide (roughly half the cell width), with transparent padding all around and no part touching or crossing the cell boundary; ground boss feet on a baseline at about 86% of the cell height, flying bosses hovering slightly above it. Genuine transparent alpha background. No backdrop, checkerboard, text, labels, borders, numbers, ground tiles, shadows or scenery. Chunky crisp pixel art: dark near-black outlines, solid pixel clusters, top-left light, warm highlights, rich restrained colors; no smooth painting, blur or photorealism. Camera viewed down at top/front, creatures facing diagonally down-right. All creatures are original designs inspired by the descriptions, not copied Dota models.
READING ORDER EXACTLY: Row1 col1 BOSS: hunched shaggy tree beast walking on four thick bark limbs, a mossy leaf canopy with two twigs on its back, mossy beard, glowing green eyes in a bark face; col2 BOSS: green goblin-like smeevil with big pointed ears sitting on a flying purple magic carpet with gold trim and gold tassels, waving a gold coin, a red sack beside him; Row2 col1 BOSS: floating hooded teal wraith with a dark face hollow and glowing green eyes, tattered robe streaming down and back, bony white claws reaching forward; col2 BOSS: chubby flying baby Roshan with gray rocky skin, cream belly, two large curved ivory horns, small tusks, red eyes and small leathery bat wings.
```
