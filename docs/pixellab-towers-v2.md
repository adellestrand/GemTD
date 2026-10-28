# PixelLab – nya torndesigner, pilot v2

Genomfört 2026-10-28 på användarens beställning: iterera fram nya tornbilder där alla bastorn har samma grunddesign och där uppgraderingar (kvalitet och kombinationstorn) syns som en vidareutveckling av föregående version. Kopplat i spelet 2026-10-28 på användarens beställning (se Inkoppling).

## Metod

1. **Mall.** Sapphire I skapades med Pro Flash (64×80 px) med dagens Sapphire I som stilreferens: rund stenfot, kort stentorn, skiffertak och en juvel i bronsklo, med tom yta ovanför för senare steg.
2. **Samma kropp för alla bastorn.** De sju andra grundtyperna är redigeringar av mallen där bara juvelen byts: spetsig diamant, smal akvamarin, rund opal, rektangulär smaragd, kuddslipad topas, rund rubin och ametistkluster.
3. **Kvalitet som utbyggnad.** Varje steg är en redigering av föregående bild:
   - II: guldband och något större juvel.
   - III: en våning till och sidokristaller.
   - IV: guldpelare och en krona av tre kristaller.
   - V: spetsigt guldtak och glödande krona.
   - VI: svävande juvel i en ljusring och vimplar.
4. **Kombinationstorn ur sina ingredienser.** Silver (safir + topas + diamant) är mallen i silverplåt med topas och diamant bredvid kronjuvelen. Silver Knight är en redigering av Silver: en våning till och riddarhjälm med rubin och akvamarinplym.

15 bilder, 5 generationer styck = 75 generationer (saldo 4 823 → 4 748). Filer: `assets/graphics/pixellab-towers-v2/<namn>_v1.png` och `towers_v2.generation.json` med jobb-id, bild-id och vilken bild varje steg är redigerat från. Råfiler finns i `output/pixellab-towers-v2/raw/`.

## Resultat

- Bastornen är nu tydligt en familj; typen syns på juvelens färg och form.
- Kvalitetslinjen I–VI läses som samma torn som byggs ut, och Silver → Silver Knight som en uppgradering.
- På brädet i 26 px per ruta, med dagens skalning (varje bild fyller rutan), ser bastornen enhetliga ut. III–VI blir smalare eftersom de är högre. De nya bastornen har färre egna detaljer än dagens (t.ex. Rubys lågor och Topaz pipor), så typen bärs mest av juvelen.
- Med gemensam skala (alla bilder på samma duk, så att VI faktiskt blir högre än I) blev tier I för liten i 26 px. Det förkastades.

## Full körning (2026-10-28)

Användaren valde att köra upplägget på alla torn. Nu finns **91 bilder**: 8 grundtyper × kvalitet I–VI (48) och alla 43 kombinationstorn. Den fulla körningen kostade 380 generationer (saldo 4 748 → 4 368), totalt 455 med piloten. Inget är kopplat i manifestet.

**Namn:** `<grundtyp>_<kvalitet>_v1.png` (t.ex. `ruby_4_v1.png`) och `<specialtornets id>_v1.png` (t.ex. `baiyinqishi_v1.png` för Silver Knight). `towers_v2.generation.json` anger för varje bild jobb-id, bild-id, redigeringssteg och `derived_from`, alltså vilken bild den är redigerad ur.

**Grundtyper:** alla sju följer Sapphires steg (II guldband, III andra våning, IV pelare och tre-juvelskrona, V guldtak, VI svävande juvel), med samma text och juvelens färg utbytt.

**Kombinationstorn:** varje torn redigeras ur det torn i receptet som det bygger vidare på. Torn som bara görs av grundgems utgår från grundtornet i kvaliteten receptet kräver (t.ex. Jade ur Emerald III, Bloodstone ur Ruby V). Ingrediensernas juveler syns som små accenter. Kedjor:

| Kedja |
| --- |
| Sapphire I → Silver → Silver Knight; Pink Diamond (ur Diamond V) → Huge Pink Diamond → Koh-i-Noor |
| Emerald I → Malachite → Vivid Malachite; Topaz V → Uranium-238 → Uranium-235 → Depleted Uranium |
| Ruby II → Asteriated Ruby → Volcano; Ruby V → Bloodstone → Antique Bloodstone → Black Prince's Ruby |
| Emerald III → Jade → Ocean Jade → Huaguo Elixir → Cullinan Diamond; Jade → Lucky Chinese Jade |
| Emerald IV → Quartz → Charming Lazurite → Guardian Stone |
| Aquamarine IV → Deep Sea Pearl → Natural Emerald |
| Emerald V → Dark Emerald → Emerald Golem |
| Sapphire V → Yellow Sapphire → Sea Jewel / Star Sapphire |
| Aquamarine V → Paraiba Tourmaline → Carved Tourmaline → Star of Sri Lanka |
| Opal V → Cat's Eye → Red Coral → Armor Stone |
| Amethyst V → Gold → Egypt Gold |
| Hemliga: Obsidian (Sapphire V), Agate (Aquamarine V), Sunstone (Ruby V), Burning Stone (Amethyst V), Geluan Stone (Emerald V) |

**Granskning:** alla rendrerade på ett riktigt bräde i 26 px per ruta bredvid dagens bilder. Bastornen är enhetliga och kvalitetsstegen syns; IV–VI har nu egna bilder. Svagare skillnader: Uranium-238 → 235 och Yellow → Star Sapphire är ganska lika, Uranium-238 fick inte den tänkta blyplåten, Topaz V–VI smälter något ihop med guldet, och Huge Pink Diamond tappade silverrustningen. De kan göras om enskilt (5 generationer per bild).

## Inkoppling (2026-10-28)

- `assets/graphics/manifest.json`: 91 nya sprites `towers2_<namn>` (storlek 0,94, ankare mitt). `bindings.gems` pekar nu på dem: `default` och `2`–`6` för de åtta grundtyperna och `default` för alla 43 kombinationstorn. Dagens sprites ligger kvar i manifestet; de tidigare bindningarna är sparade i `output/pixellab-towers-v2/previous_bindings.json` för enkel återgång.
- De nya tornen är stillbilder. Dagens torn hade en åttarutors idle-loop; den procedurella tornrörelsen (`tower_motion.gd`) gäller fortfarande. Idle-animation kan läggas till senare (cirka 1 generation per bild).
- Kontroller: `python tools/check.py` ger `CHECKS_OK`; grafikverkstaden rapporterar "All bindings valid"; brädet och fliken Towers & quality granskade i Godot-rendering. `redesign_guard.py` flaggar röda filer från två senare commits av ett annat verktyg (`152bdf5` tornflyttskostnad, `ccfef9c` nytt slumpfrö), inte från detta pass; baslinjen behöver sparas om när användaren godkänt dem.
- Regler, data och sparformat är oförändrade.
