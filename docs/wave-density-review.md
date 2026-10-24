# Antal fiender och vågtäthet – 2026-10-24

Användaren upplever för få fiender och vill jämföra med Dota 2 GemTD. Den här undersökningen ändrar inga spelregler eller exporter.

## Nyare primärunderlag

Det installerade Workshop-paketet `E:/SteamLibrary/steamapps/workshop/content/570/474619917/474619917.vpk` lästes utan att exekvera dess Lua. Intilliggande `publish_data.txt` anger 19 oktober 2026, `publish_time=1792413746`. Detta ersätter inte automatiskt hela kampanjens tidigare balansreferens från 1 augusti: endast nedanstående spawn-/serieregler har jämförts här. [Workshop-sidan](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917) visar också en uppdatering 19 oktober. Ingen körande originalmatch har mätts.

Den nyare `scripts/vscripts/addon_game_mode.lua` har SHA-256 `8b478303a9704e4806f0576722ebca67c79ee19bbcc4c0b0b88cbdaf7c5ce644`. Den sparades separat i ignorerade `.tools/reference/mode-installed-wave-audit.lua`; den äldre råreferensen behålls. Funktionen `WinStreakAdjust` är textidentisk med den äldre referensen.

## Mappning för solo

| Regel | Dota-paketet 19 oktober | Vår kampanj |
| --- | --- | --- |
| Vanlig startvåg | 10 fiender (`wave_enemy_count`, rad 800) | 10 |
| Spawnintervall | En spawn per `OnThink`, som returnerar 1 sekund (3279–3862) | 1 sekund |
| Boss | Spawnräknaren töms efter första bossen (3583–3594) | En boss var tionde våg |
| Vanlig kill | +0,75 seriepoäng (6486) | +0,75 |
| Bosskill | +10 seriepoäng (6482) | +10 |
| Ökning | Vid +50 poäng: +1 fiende och förbruka 50 poäng (12034 ff.) | Samma tröskel |
| Minskning | Vid −50 poäng: −1 fiende, lägst 5 | Samma tröskel och golv |
| Kontrollpunkter | Avdrag beroende på fiendens läckskada och passerad kontrollpunkt (3635 ff.) | Implementerat |
| Faktisk läcka | −3 × skadan på slottet (3802) | **Saknas**; endast kontrollpunktsavdrag görs |
| Antal låses vid vågstart | `guai_count = wave_enemy_count` (6353) | Samma princip i `GemCampaignCombat.start` |

`SetThink` anger 0,5 s inledande anrop; återkommande intervall kommer från `OnThink`-returen 1 s. Vår första fiende kommer vid första simuleringssteget, så exakt startfördröjning är inte matchverifierad. Både 1× och 2× i vår motor skalar simuleringstiden, inklusive spawns.

Antalet är alltså inte en fast stege på exempelvis 20/30/40 fiender. Bra försvar ger fler fiender och mer möjlig killinkomst; sena kills och läckor bromsar serien. 20 i källans questkontroll är ingen maxgräns. Slumpeliter ersätter en vanlig spawn och ger +1,5 poäng vid kill; de ingår inte i vår beslutade kampanj.

Som en teoretisk övre gräns utan kontrollpunktsavdrag, läckor eller eliter blir antalet 10 på våg 1–7, 11 på 8–9, 12 på 14–19, 13 på 21–24, 15 på 31–33 och 19 på 46–49. Bossvågorna har fortfarande en fiende. Detta är en räkneillustration, inte ett uppmätt Dota-spelförlopp.

## Varför vår version kan kännas gles

1. `http://127.0.0.1:8060/` väljer fortfarande den äldre `review-v1`-profilen. Den har 10 egna vågor, 8 fiender i första vågen och senare 10/12/16. Kampanjen kräver `?profile=campaign` eller menyn **Run → Solo campaign · 100 waves**. URL ensam bevisar inte vilken profil användaren faktiskt spelat i en native-körning.
2. Våra tolv bevarade naturliga kampanjrapporter innehåller tio fiender på samtliga vanliga vågor 1–9. Ingen av teststrategierna driver upp serien där. Detta visar rapporternas faktiska spawnantal, inte användarens senaste omgång.
3. Antal per våg och antal samtidigt på skärmen är olika saker. Tio fiender med en sekund mellan dem släpps ut över cirka nio sekunder; snabba kills kan hålla skärmen gles trots korrekt totalantal. Kartutsnitt, zoom och tid till första tornkontakt påverkar också upplevelsen.

## Rekommendation

Använd kampanjprofilen som standard i nästa leverans och behåll den gamla som uttryckligt granskningsval. Behåll tills vidare Dota-reglerna 10 startfiender/1 sekund/dynamisk serie. Rätta separat det saknade läckavdraget med versionsmärkt balansändring och gränsfallstest; det kommer kunna minska antal efter läckor, så det löser inte önskemålet om tätare vågor. Ändra inte HP eller killguld samtidigt.

Jämför därefter en verklig användaromgångs antal, samtidig topp och spawnperiod med en originalmatch. Om tio ändå känns för glest är ett separat läge med tätare spawns ett tydligare balansval än att beskriva fler fiender som verifierad originalparitet. Tätare spawn gynnar splash/multiskott/auror; fler fiender ökar dessutom möjlig guldinkomst och seriepoäng.

## Utförda kontroller

- Sju riktade textkontroller mot det nyare installerade skriptet samt alla 100 kampanjdefinitioners basantal/bossantal och spawnintervall godkändes. Lokalt kontrollskript: `python output/check_wave_reference.py` (ignorerat undersökningsmaterial).
- Alla tolv bevarade rapporters vanliga vågor 1–9 kontrollerades: tio fiender per våg.
- `python tools/godot.py --headless --path . --script res://tests/check_campaign.gd -- --campaign`: 243 av 244 kontroller godkändes. Det befintliga UI-fallet `demolishing a selected trap clears its move controls` misslyckades i den aktuella arbetskopian, som har andra pågående grafik-/UI-ändringar. Därför rapporteras inte hela testkörningen som grön. Inga sådana filer ändrades i undersökningen.
