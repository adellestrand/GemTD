# GemTD – referensinventering och avvikelser

Undersökt 2026-10-23. Ett lokalt installerat paket från [Dota 2 GemTD, Workshop 474619917](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917) kunde läsas. Dess `publish_data.txt` anger **2026-08-01**. Det är den faktiskt granskade ögonblicksbilden, **inte ett bevis på att paketet är den senaste Workshop-versionen den 23 oktober**.

## Granskade primärdata

Paketet ligger under `<SteamLibrary>/steamapps/workshop/content/570/474619917/474619917.vpk`. Följande lästes utan att köra referensens Lua:

| Fil i paketet | Verifierat |
| --- | --- |
| `scripts/vscripts/addon_game_mode.lua` | 37×37 rutnät, 128 världs-enheter/ruta, solokartans 32 startstenar, typer, recept, kvalitetschanser och skadefilter |
| `scripts/npc/npc_units_custom.txt` | 24 grundtorns skade-/hastighets-/räckviddsvärden, specialtorn och valda fienders grundvärden |
| `scripts/npc/npc_abilities_custom.txt` | Slow, poison, armor debuff, attack speed, auras, splash och evasion |
| `scripts/vscripts/lua_ability/fenliejian.lua` | Huvudattack plus tre närmaste sekundärmål; sekundärprojektiler gör fysisk ApplyDamage |
| `maps/gemtd_1p.vpk` → `entities/default_ents.vents_c` | Ordning och ursprungskoordinater för sju kontrollpunkter |

Råfilernas SHA-256 finns i `data/catalog.json`, `source.file_hashes`. `tools/inspect_reference.py` läser VPK; `tools/reference_data.py` läser KeyValues; `tools/build_reference_catalog.py` skapar innehållskatalogen. Source 2 Viewer CLI 20.1 avkodade kartans entity-lump. Råfiler och inventeringsverktyg ligger i ignorerade `.tools/`. Dota-kod, modeller och texturer följer inte med spelet.

## Verifierat innehåll

Grundtyper: **Sapphire, Diamond, Aquamarine, Opal, Emerald, Topaz, Ruby och Amethyst**. Kvalitet I–III motsvarar referenssuffixen `1`, `11`, `111`.

| Torn | Verifierade material | Referensvärden |
| --- | --- | --- |
| Silver | Sapphire I + Topaz I + Diamond I | 40 fysisk, 1 s, räckvidd 600, slow −90 i 3 s |
| Malachite | Opal I + Aquamarine I + Emerald I | 15 fysisk, 0,8 s, räckvidd 600; huvudmål + tre sekundärmål |
| Asteriated Ruby | Ruby II + Ruby I + Amethyst I | 20 magisk var 0,25 s, auraradie 500; grundattack 0 |

Räckvidder divideras med 128 till cellavstånd. Kartans Y-led speglas till skärmen. Kontrollpunkterna är `(4,2) → (4,18) → (32,18) → (32,4) → (18,4) → (18,32) → (33,32)` med nollbaserade koordinater.

Grundeffekter: Sapphire −60/−90/−120 hastighet i 3 s; Amethyst −2/−4/−8 armor i 3 s; Emerald 2/4/8 magisk skada per sekund i 10 s; Aquamarine +200 attack speed på alla tre inkluderade nivåer; Opal +20/+30/+40 inom 664; Ruby 30/40/50 % ren stänkskada inom 300/350/400. Splash-funktionen inkluderar huvudmålet. Topaz/Malachite skjuter tre extra mål, inte tre mål totalt. Sekundär ApplyDamage gör ingen attack-evasion-roll.

Solofaktorn för HP och hastighet är **0,69**. Den använda hound-vågens `guai_shanbi` ger **50 % evasion**. Fiendernas HP, hastighet, armor och magic resistance i katalogen utgår från referensvärdena.

## Skademodellens faktiska status

Implementerat och numeriskt testat: fysisk/magisk/ren skada, positiv/negativ armor, magiskt motstånd, typimmuniteter och osårbarhet, attack-evasion, tidsbestämda debuffs, poison, pure splash, multiskott, attack speed och de inkluderade aurorna. Kärnan stöder även referensfiltrets Inspired-halvering och Stone Gaze-dubblering av fysisk skada; de modifierarna delas inte ut i de tio prototypvågorna.

Prototypens armorformel är `1 − 0,06a / (1 + 0,06|a|)`. Attack speed räknas som `grundintervall / (1 + bonus/100)`. Olika namngivna kvalitetseffekter får samexistera; samma slow-/armor-/auranamn staplas inte. Poison tolkar `MODIFIER_ATTRIBUTE_MULTIPLE` som separata instanser per träff.

**Full skadeparitet är inte klar.** Katalogvärdena är granskade, men exekveringsdetaljerna är ännu inte jämförda sida vid sida i en körande Dota-match. Följande återstår:

- Motorns stapling för samma respektive olika caster, aura-linger och ordningen mellan DamageFilter och reduktioner.
- CombatClass-multiplikatorer, attack speed-/movement-gränser samt avrundning av HP/skada.
- MVP-skadebonusar/-aura. Referensfiltret innehåller bonusar +10…+100 %, aura och tak +500 % med avrundning nedåt. Detta progressionssystem är inte implementerat.
- Projektilers flygtid och effekter utanför det inkluderade innehållet. Prototypen applicerar träffar direkt och visar korta skott-/träff-/områdeseffekter. Ingen simulerad projektilflygtid ingår ännu.

Beslut 40 kvarstår som mål. Denna version är en testbar grund, inte en verifierad exakt kopia av hela Dota-skademodellen.

## Medvetna prototypval

| Område | Referens/underlag | Prototyp och skäl |
| --- | --- | --- |
| Kvalitetschanser | Första tre steg: 100/0/0, 80/20/0, 60/30/10 | Samma tre steg; stopp efter två köp eftersom högre referenssteg kräver fler kvaliteter |
| Ekonomi | Exakt ekonomiprogression ej verifierad | Start 0 gold; köp 20/45; kill 2/3 gold; clear 12+2×våg. Testvärden |
| Liv | Originalets läckskada kan slumpas | 30 startliv, fasta kostnader 1–4 per typ, boss omedelbar förlust. Fasta kostnader är beslutade; siffrorna testvärden |
| Vågor | Valda enheters grundvärden × solofaktor 0,69 | Egen ordning/antal, wave 8 en tidigare air-variant; inga slumpeliter. Tio kuraterade vågor är beslutat |
| Luftmål | Fastställt 2026-10-24 | Alla torn (även Diamond/Ruby) attackerar mark och luft. Dota-enheterna (`units.json`: `gemtd_d1`, `gemtd_r1` m.fl.) har identiska attackinställningar och ingen luftbegränsning; inget luftfilter i `mode.lua`/`chain.lua`/kartfilen. Tidigare tillfällig uppdelning (Diamond/Ruby bara mark) är borttagen på användarens begäran. |
| Checkpoints | Ursprungliga world coordinates | Snappas till cellcentrum; själva checkpointcellerna reserveras. Start-/målskyddets exakta område behöver kontroll |
| Rörelse | Dota-motor och kartskript | Beslutade åtta riktningar utan hörnpassage; air raka etapper; minsta hastighet 100/128 cell/s behöver originalkontroll |
| Grafik/ljud | Originaltillgångar används inte | Första egna genererade pixelbilderna, procedurritad terräng och syntetiska ljudeffekter; fortsatt grafisk bearbetning/animering återstår |

Tiovågstestet använder en förberedd stark försvarsfixture. Det bevisar fasflöde och bossavslut, **inte** att naturlig slump och ekonomi är välbalanserade. Nästa speltest ska bedöma läsbarhet, svårighet och möjligheten att bygga recepten.

## Historiskt planeringsunderlag

Nedan bevaras den tidigare webbinventeringen. Dess preliminära status har ersatts av primärdata och begränsningar ovan.

## Referensen vi vill återskapa

Användaren har valt den aktuella Dota 2-versionen som referens för kartlayout och full skademodell. [Workshop-sidan](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917) identifierar kartan, men dess beskrivning specificerar inte recept, skademodell eller rutnät. En öppningsbar eller nyligen indexerad sida bevisar inte att innehållets speldata är aktuella.

## Kandidater till prototypens tre recept

Användaren valde preliminärt **Silver, Malachite och Asteriated Ruby** i beslut 57. Jade i tabellen nedan är jämförelsematerial, inte ett valt fjärde recept.

[Dota 2-wikins Gem TD-sida](https://dota2.fandom.com/wiki/Gem_TD) och [Gem TD Helper](https://gemtd.top/) ger följande kandidatunderlag. Wikins information är inte en bekräftelse av den aktuella kartversionen. Recepten måste verifieras innan de blir slutliga innehållsdefinitioner.

| Kandidat | Material enligt kandidatunderlaget | Roll |
| --- | --- | --- |
| Silver | Chipped Diamond, Chipped Sapphire, Chipped Topaz | Slow |
| Malachite | Chipped Emerald, Chipped Opal, Chipped Aquamarine | Flera mål |
| Asteriated Ruby / Star Ruby | Chipped Ruby, Flawed Ruby, Chipped Amethyst | Skada över tid i närområdet |
| Jade | Normal Emerald, Normal Opal, Flawed Sapphire | Gift |

Detta ger kandidater för tre prototypnivåer om Chipped, Flawed och Normal mappas till nivå ett, två och tre. Namn, effekter och mappning behöver kontrolleras mot aktuell spelversion. Exakta skadevärden, räckvidder och materialnivåer är inte fastställda.

## Fortsatt inventering

- Identifiera versionsnummer och datum för aktuella speldata.
- Dokumentera byggytor, rutstorlek, hinder och kontrollpunkternas ordning från aktuell karta.
- Fastställ grundtyper, luft-/markmål och respektive effekt.
- Verifiera de tre valda receptens material och resultat.
- Kartlägg skadetyper, rustning, motstånd, immuniteter och effektstapling enligt beslut 40.
- Märk varje uppgift med källa och säkerhetsgrad. Använd inte andra fristående GemTD-versioners värden som verifiering av Dota-kartan.

## Källbegränsningar

En [Workshop-diskussion från 2015–2016](https://steamcommunity.com/workshop/filedetails/discussion/474619917/527273452872593755/) beskriver historiska egenskaper, men är inte aktuell versionsdata. Andra webbläsarversioner och hjälpsidor kan ha egna recept och balansvärden. De är jämförelsematerial när deras versionskoppling inte kan fastställas.

## Utökad inventering 2026-10-24

Hela källans faktabibliotek ligger nu i data/full_reference.json: 48 grundgems, 67 special-/slabenheter, 59 receptalternativ, 16 slabuppgraderingar och 50 grundvågor. Källan fortsätter med prövningar 51–100, två slumpförmågor och förstärkningsregler. Alternativa våg-ID:n över 100 är separata varianter, inte ytterligare grundvågor. Ancient och båda CombatClass-flaggorna bevaras för kommande målimmunitets-/effektarbete.

De tidigare okända ekonomifakta är delvis verifierade: originalet startar med 100 liv och 0 lagguld. Tidiga vanliga fiender ger fem belöningsenheter; bossgrenens 300 blir 150 guld genom sin särskilda konvertering. 1.0:s 30 liv, belöningar och inköpspriser är uttryckliga anpassningar, inte originalvärden. Se balance-v1.md.

Sex kvaliteter finns i det separata utvecklingsläget. Källans högsta slumpnivå ger 10/30/30/20/10 procent I–V; VI kräver uppgradering. Aquamarine VI har +500 attack speed, Amethyst VI har fem sekunders varaktighet och Sapphire VI ger -480 konstant rörelsehastighet. Effekterna hämtas från respektive faktiska ability; oanropade modifierdefinitioner aktiveras inte bara för att de förekommer i filen. Jade använder tower_du4. Vidare arbete och återstående effektparitet beskrivs i full-content-plan.md.
