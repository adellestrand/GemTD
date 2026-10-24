# Fullt innehåll efter 1.0

**Aktuell status:** kampanj 1.3.0-dev har 100 spelbara vågor, alla 59 receptalternativ, stentavlor, fiendeförmågor och MVP-progression. Se [aktuell granskning och begränsningar](campaign-review.md). Den ursprungliga planen nedan bevarar utvecklingsordningen. Den påbörjade [grafikgranskningen](graphics-review-campaign.md) är nästa produktionsunderlag.

Beställt 2026-10-24. Fortsätt utan rutinfrågor; bevara 1.0 som separat granskning. Den aktuella källögonblicksbilden är fortfarande 2026-08-01, inte ett verifierat påstående om senaste Workshop-version.

## Genomfört

- Lokal 1.0-leverans: `builds/release/GemTD-1.0.0-local-review.zip`. Paketeraren vägrar nu skriva över en redan bevarad version.
- `data/full_reference.json` innehåller numeriska fakta och referens-ID:n för 48 grundgems, 67 special-/slabenheter, 59 receptalternativ (38 vanliga, 13 hemliga, 8 slabs), 16 slabuppgraderingar, 50 grundvågor och strukturen för prövningsvåg 51–100. Inga Lua-funktioner körs eller distribueras.
- Källans kommenterade gamla bossar filtreras bort. Alternativa recept med samma resultat behåller skilda ID:n. Alla materialkedjor är nåbara utan cirklar.
- Motorn och UI använder katalogens gränser för kvalitet, oddsinköp och sista våg. Receptingredienser kan vara specialtorn; deras namn slås inte längre bara upp bland grundgems.
- Ett separat utvecklingsläge `expanded-gems` har sex kvaliteter, fem oddsprofiler och Jade utöver de tre tidigare recepten. Högre nivåers faktiska slow, poison, armorvaraktighet, Opal-bonus, Ruby-splash och Aquamarine VI-bonus har förts in. Jade använder samma fjärde poison-effekt som i källan.
- Sparfiler och speltestrapporter skiljs åt mellan 1.0 och utvecklingsläget. Innehållsversion och innehållshash hindrar återspelning mot fel profil.

## Prova pågående utveckling

Webb efter export: `http://127.0.0.1:8060/?profile=expanded-gems`.

Windows från källa:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -ExpandedGems
```

Den senaste Windows-exporten kan också startas med `builds/windows/GemTD.exe -- --expanded-gems`. Den bevarade 1.0-zippen innehåller inte denna senare utbyggnad.

Utvecklingsläget heter **1.1.0-dev**. Det har ännu tio kuraterade vågor och fyra spelbara recept. Kvalitet VI fås genom kombinationer; högsta slumpnivån ger I–V enligt originaltabellen. Inköpspriserna 20/45/80/125 guld är uttryckligen provisoriska anpassningar. Originalet använder hjältenivå/XP. Grafik för IV–VI och Jade använder utbytbara reservbilder tills egna bilder tas fram.

## Nästa arbete i ordning

1. Fler vanliga specialrecept med deras verkliga effekter, därefter avancerade/hemliga alternativ. Skilj recept-ID från resultat-ID så att alternativa material inte skriver över varandra.
2. Slabmekanik med effektmodell, separat placering och originalets tre lika i linje för silver/guld. Uppgraderingsmappningen ensam är inte ett vanligt två-/fyragemrecept.
3. Fiendeegenskaper för alla grundvågor: bland annat auras, refraction, evasion, blink och riktade försvar. Källans Ancient- och CombatClass-flaggor är bevarade och måste ingå i effekt-/målförståelsen.
4. Aktivera 50 grundvågor i originalordning med solofaktorer, rätt bossar och varianter på 35/36/38. Grundvåg åtta är `gemtd_mengzhu`; 1.0:s flygande åttondevåg är en tidigare kuratering.
5. Inför prövningsvåg 51–100: återanvänd grundvågor med källans förstärkningar och reproducerbara slumpförmågor. Veckoteman, elit-/hjältebonusar och dynamisk fiendemängd ska granskas uttryckligen; en enda grund-HP-tabell beskriver inte hela originalbalansen.
6. Naturliga omgångar, meningsfulla gränsfall och båda exporter. Högre torn får inte aktiveras som rena grundattacker när deras specialförmåga saknas.

## Kontroller och regenerering

`tools/build_full_reference.py` och `tools/build_expanded_gems.py` behöver de lokala ignorerade källfilerna. De skriver bara faktabibliotek respektive utvecklingsprofil; de skriver inte över `data/catalog.json` eller 1.0-paketet.

`python tools/verify_full_reference.py` kontrollerar bibliotekets integritet, materialgraf och numeriska källvärden. `tools/test.ps1` inkluderar både den vanliga 1.0-profilen och separat `check_expanded_gems.gd` med `--expanded-gems --smoke`. Full Dota-effektparitet är fortsatt ett arbete som pågår.

## Kampanjleverans 1.2.0-dev, 2026-10-24

Den efterföljande beställningen om hela progressionen är implementerad som en separat kampanjprofil: 100 vågor, 59 receptalternativ, 24 stentavlor, alla sex gemkvaliteter, fiendeegenskaper, MVP och källbaserad längre ekonomi. Öppna Run → Solo campaign · 100 waves eller ?profile=campaign. Se campaign-review.md för faktiska skillnader mot Dota och graphics-review-campaign.md för den påbörjade grafikgranskningen. Äldre statusavsnitt nedan bevaras som historik; de är inte längre taket för innehållet.
