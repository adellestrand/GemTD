# PixelLab – torn i kartskala, pilot v1

Genomfört 2026-10-26 på användarens beställning (experiment 1 i bildgranskningen): pröva om grundtornen går att läsa bättre i minsta zoom, cirka 26 px per ruta. Endast förslag; inget är kopplat i manifestet och spelet är oförändrat.

## Utgångsläge

I 26 px per ruta ritas dagens torn (64–88 px höga) i ungefär 24 px. Alla grundtyper har samma mörka sockel med färgad juvel, så typen syns nästan bara på färgen och kvaliteten bara på brickan.

## Vad som provades

Tre typer, två riktningar, ritade direkt i 32×32 px med PixelLab Pro Flash. Dagens tier I-bild, nedskalad till 32 px, användes som stilreferens för palett, kontur och skuggning, inte form.

| Typ | A: egen silhuett | B: stor juvel |
| --- | --- | --- |
| Sapphire | smal isspira | högt sexkantigt prisma |
| Ruby | låg flamskål | runt rubinklot med lågor |
| Topaz | tre guldpipor som en treudd | stor triangulär juvel |

Filer: `assets/graphics/pixellab-maptowers-v1/<typ>_map_<a|b>_v1.png` med `.generation.json` (jobb-id, prompt, seed och stilinställningar). Råfiler finns i `output/pixellab-maptowers-v1/raw/`. Saldot gick från 4 900 till 4 853 generationer under passet. Den uppskattade kostnaden var 5 per bild.

## Resultat i 26 px per ruta

Samma bräde med 69 torn och stenar renderades tre gånger i spelets egen ritkod: nuvarande bilder, A och B. Bara de tre pilottyperna byttes; övriga fem grundtyper och stenarna är som förut.

- **B** läses bäst: blått prisma, rött klot och guldtriangel syns direkt, även utan bricka.
- **A** fungerar för Ruby (bred skål) och delvis Sapphire (spira). Topaz A smälter ihop med guldet och blir otydlig.
- De nya bilderna är ljusare och enklare än dagens torn. Blandat med gamla typer sticker de ut. Ett helt byte kräver alla åtta typer.
- Kvalitetsnivån syns fortfarande bara på brickan; ingen av riktningarna löser den.

## Beslut

2026-10-26: användaren gillade inte riktningarna. Kartskaletornen förs inte vidare; filerna finns kvar som avvisat förslag.

## Möjliga nästa steg (inte beställda)

1. Göra B (eller en blandning: Ruby A, övriga B) för alla åtta grundtyper.
2. Visa kartbilden bara när rutan är liten och dagens detaljerade torn vid inzoomning och i porträtt. Kräver en växling i ritkoden, utan regeländring.
3. Pröva kvalitet som storlek eller glöd på juvelen i stället för bara bricka.
