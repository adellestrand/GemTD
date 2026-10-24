# Specialtornens effekter och animationer

Implementerat 2026-10-24. Alla 43 kombinationstorn har ett presentationsprofilval
och stöd för sina modellerade förmågetyper. Effekter följer faktisk strid; inga
skadevärden, sannolikheter, radier, intervall eller innehållsversioner ändras.

## Vad spelaren ser

- **Asteriated Ruby, Volcano och andra skadande auror:** diskret områdesmarkering,
  utåtgående puls vid verkliga skadetick och flammor på skadade fiender.
  Ruby använder modellens radie **3,90625 rutor** och tick **0,25 sekunder**.
  Immunitet, blockering och utebliven skada ger inga falska skadeflammor.
- **Gift:** gröna bubblor vid faktisk applicering och vid följande skadetick;
  kvarvarande gift syns på fienden så länge modifieraren finns.
- **Bromsning och försvarssänkning:** frost respektive sprick-/sköldmotiv och
  bestående markeringar från aktiva modifierare och auraminne. Aurans verkliga
  efterverkan respekteras; en radiering innebär inte i sig att skada har skett.
- **Stun och förstening:** stjärn-/stenmarkering vid faktisk applicering och medan
  tillståndet kvarstår. Befintlig rörelse använder fortsatt stridens gångklocka.
- **Kedjeblixt och shock:** taggiga länkar vid verklig skada. Kedjelänkar går från
  föregående träffade fiende till nästa, medan shock utgår från källtornet.
- **Splash och burst:** områdespuls med rätt radie vid träff samt individuella
  träffeffekter för fienderna som verkligen skadas.
- **Kritiska träffar:** särskild träffburst och `CRIT`, först vid en förstärkt
  projektilträff som faktiskt gör skada. Missar och blockerade träffar märks inte
  som lyckade kritiska träffar.
- **Multiskott:** de riktiga separata projektilerna ritas med riktning, spår och
  färg/form från tornets profil. Uranium får inte en påhittad skadeaura; den
  implementerade förmågan är multiskott.
- **Stöd:** diskreta ringar och markering på mottagare med verklig cachelagrad
  bonus, inklusive skydd, hastighet, räckvidd, skada och detektion. Befintliga
  markeringar för avväpnade torn behålls. Passiva skadebonusar ändrar inte
  träfftakten och får ingen falsk aktiv besvärjelse.
- **Natural Emerald:** kopierade förmågor skickar samma händelser som originalen;
  utseendet låses inte till ett hårdkodat standardpaket av kopierade förmågor.

Källans rena `cosmetic`-poster får ingen påhittad spelmekanisk aktivering. Det
befintliga tornets glöd/rörelse är kvar. Detta är procedurella pixelanpassade
effekter, inte nya bitmapark eller en kopia av Dotas partikelsystem.

## Ändra grafiken

- `assets/graphics/ability-effects.json`: färger, projektilprofiler för alla torn
  och gräns för samtidiga auramarkeringar.
- `game/presentation/ability_art.gd`: eld, bubblor, frost, blixtar, pulser,
  statuseffekter och stödmarkeringar. Läser modellens faktiska radier/tillstånd.
- `game/presentation/effects.gd`: tidsstyrning och begränsat effektminne.
- `GemCampaignCombat.ability_visual`: skrivskyddad presentationshändelse vid
  löst skada eller applicerad modifierare. Skadevägen anropar samma `deal`
  med samma argument som tidigare. Ingen extra slump konsumeras.

Paus fryser tiden. 2× följer samma simuleringssteg som spelet. Globala
`effects.enabled` och `max_events` i grafikmanifestet gäller även dessa effekter.
Aurapulser för flera fiender samlas per källa/förmåga så att samma tick inte
ritar en full områdesring för varje fiende.

## Granska

[Abilities-fliken](http://127.0.0.1:8060/?view=art&profile=campaign&abilities=1)
visar alla 43 kombinationstorn med verkliga förmågekörningar. Tåliga stillastående
testfiender gör effekterna synliga; detta är inte en balanssimulering. De två
grundtornen visar stöd utan att skjuta. Natural Emerald visar uttryckligen ett
exempelpaket av tillåtna stulna förmågor. Ingen riktig omgång eller sparfil ändras.

## Genomförda kontroller

- `python tools/check.py`: hela sviten passerar, inklusive den nya kontrollen.
- `python tools/godot.py --headless --path . --script res://tests/check_ability_art.gd -- --campaign --smoke`:
  **208 kontroller**, inga fel. Provar aura före/efter första tick, immunitet,
  projektilens träfftid, kedjans faktiska hopp, kritiska/blockerade träffar,
  avstängda effekter, paus och lika utfall/RNG med observatören på/av för samtliga
  43 torn. Befintliga numeriska referenskontroller passerar också.
- Kampanjens rutkontroll: **372 layoutfall**, inga fel.
- Verklig Godot-rendering av en stridsplan med Ruby, Bloodstone, Jade och
  Cat's Eye: `output/ability-board/frame00000089.png`, inga motorfel/varningar.
- Windows och webb återexporterade; Windows release renderad med verifierat
  attackljud. Chrome visar levande auraskada i Abilities-fliken med **0 fel och
  0 varningar**. Paus verifierad med två identiska skärmbilder.
- Samtliga sex innehållsfiler under `data/` är oförändrade från grafikpassets
  utgångsläge. Sparformat och balansdata behöver därför inte migreras.

## Förmågetyper per torn

Tabellen visar modellens förmågetyper. `passive` och `cosmetic` innebär inte
egna skadeaktiveringar; alla profiler använder fortfarande sina riktiga träffar.

| Torn | Modellerade förmågetyper |
| --- | --- |
| Egypt Gold | on_hit, passive, support |
| Silver | on_hit |
| Silver Knight | on_hit, splash |
| Emerald Golem | on_hit, passive, petrify, stun |
| Pink Diamond | crit, passive |
| Quartz | enemy_aura |
| Geluan Stone | cosmetic, enemy_aura, on_hit |
| Antique Bloodstone | enemy_aura, shock |
| Sea Jewel | enemy_aura, slab_echo |
| Ocean Jade | on_hit, support |
| Dark Emerald | stun |
| Chrysoberyl Cat'S Eye | support |
| Black Prince's Ruby | cosmetic, enemy_aura, on_hit, shock |
| Obsidian | cosmetic, on_hit, passive, splash |
| Red Coral | support |
| Huaguo Elixir | on_hit, passive, support |
| Yellow Sapphire | enemy_aura |
| Guardian Stone | burst, cosmetic, enemy_aura |
| Gold | on_hit |
| Cullinan Diamond | cosmetic, crit, passive, support |
| Elaborately Carved Tourmaline | enemy_aura, stun |
| Lucky Chinese Jade | enemy_aura, on_hit, passive, support |
| Bloodstone | chain |
| Huge Pink Diamond | crit, on_hit, passive, splash |
| Koh-i-Noor | cosmetic, crit, on_hit, passive, splash |
| Malachite | split |
| Agate | cosmetic, passive, split |
| Charming Lazurite | enemy_aura |
| Paraiba Tourmaline | enemy_aura |
| Burning Stone | cosmetic, enemy_aura |
| Deep Sea Pearl | support |
| Depleted Uranium | cosmetic, passive, split |
| Star of Sri Lanka | cosmetic, enemy_aura, on_hit |
| Natural Emerald |  |
| Sunstone | chain, cosmetic, passive, self_disarm, shock |
| Vivid Malachite | split |
| Asteriated Ruby | enemy_aura |
| Star Sapphire | cosmetic, enemy_aura, on_hit, support |
| Volcano | enemy_aura |
| Armor Stone | cosmetic, support |
| Uranium-235 | passive, split |
| Uranium-238 | split |
| Jade | on_hit |
