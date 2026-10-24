# Faktisk verifiering

Datum: 2026-10-23. Motor: **4.7.2.stable.official.ed1daf0bf**, Windows x64. Chrome testades med Playwright CLI mot lokal server på `127.0.0.1:8060`.

## Genomfört

- **61 automatiska kontroller passerar.** Väg genom alla checkpoints, ingen diagonal hörnpassage, ogiltig placering utan RNG-förbrukning, bindande nya gems, faslås, keep/upgrade/recept, gamla kontra nya material, kvalitetsköp under strid, sparversioner och RNG-återställning.
- Numeriska kontroller för armor, resistans, immunitet, pure, evasion, modifierare, Ruby-splash, poison-instansers tick, slow/armor-stapling, sekundärt multiskott och Opal/Aquamarine-hastighet.
- Verklig filskrivning och ersättning av sparpunkt samt avvisning av ofullständig cellmetadata.
- En isolerad strid från spawn till nästa byggfas och ett förberett försvar genom alla tio vågor till bossvinst. Stark fixture används; detta är inte ett balansbevis.
- Godot-import och huvudscenens headless-start. Testverktyget läser motorfel utöver processens exitkod.
- **Båda exporterna har byggts** med lokala officiella mallar. Exportpaketen innehåller spelscenen och spelkoden; rådata, verktyg och tester exkluderas.
- Fristående Windows-exe har startats med exitkod 0 och `SMOKE_READY`. Den har dessutom renderats på AMD Radeon RX 7900 XT i 1360×900 och skrivit en inspelning med verifierat ljudinnehåll. Det är en kontroll av genererade ljudsamples, inte en subjektiv avlyssning.
- Webbexporten har körts med WebGL 2 i Chrome: fem musklick placerade fem gems, val av Emerald och Keep startade strid, 2× valdes med tangent, alla åtta fiender besegrades, nästa byggfas gav 30 gold/30 liv, och omladdning återställde byggfas två.
- Browser-testet identifierade saknade symbolglypher och en felaktig dialogsignal; dessa har rättats. Senaste webbstartens konsol visar noll fel och noll varningar.
- Hjälp- och receptdialogerna har öppnats och stängts; ägda receptmaterial markeras. Köp av gemchanser har klickats och webbläsarens ljudkontext bekräftats som `running` efter användarklick.

## Reproducera

```powershell
powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1
powershell -ExecutionPolicy Bypass -File tools/test.ps1
powershell -ExecutionPolicy Bypass -File tools/export.ps1
powershell -ExecutionPolicy Bypass -File tools/test.ps1 -Exports
python tools/smoke_windows.py
python tools/smoke_windows.py --attack
python tools/serve.py
```

Loggar/bilder i `output/checks.log`, `output/export.log`, `output/native-export/` och `output/playwright/` är lokala, gitignorerade körresultat. För browser-automation: använd installerad Playwright-skill och en namngiven session. Canvas kräver skärmbild före koordinatklick.

## Kvar att prova

Användarens fulla omgångar på båda plattformarna: naturlig ekonomi och receptprogression, alla kamerakontroller, läsbarhet vid olika fönsterstorlekar, ljudupplevelse och långvarig prestanda. En headless-fixture ersätter inte dessa tester.

Återstående originaltrohet beskrivs i [referensinventeringen](referensinventering.md). Tester bevisar den implementerade modellens beteende, inte att alla Dota-motorns detaljer redan är korrekta. Inga Safari-/Firefox-, mobil- eller publika distributionstester har gjorts.

## Grafikpass 0.2

- 61 regelkontroller passerar även med det separata grafiklagret. Inga spelregler, balansvärden eller sparformat ändrades i grafikpasset.
- `tests/check_art.gd` verifierar 28 bilder, läsbara texturer/regioner, alla gemkvaliteter och tio vågkopplingar samt det fristående UI-temat. Den provar också en separat bild för en enda kvalitet med bibehållen standardbild för övriga kvaliteter.
- Bildfilerna kopierades oförändrade från det inbyggda imagegen-verktyget. Ojämna atlasmarginaler/bossöverhäng korrigeras med regiondata, inte omskrivning av bildpixlar.
- Windows-exporten har byggts/startats och grafikpaketet renderats. Grafikförhandsvisningen har renderats nativt och körts via webbens `?view=art`; båda flikarna har granskats visuellt.
- Webbens ordinarie spelvy har startats, fem gems placerats och rätt porträtt/typ visats efter tornval. Browserkontrollen fångade och rättade en typkonvertering för förhandsvisningens query-parameter. Därefter noll konsolfel/-varningar vid både förhandsvisning och spelstart.
- Aquamarine valdes via riktiga musklick, Keep startade vågen och fiender besegrades. Närmare zoom och paus kontrollerades med synliga sprites, hälsostapel, räckvidd och fasindikator; inga browserfel uppstod.

Gång-/vinganimationer och användarens stilbedömning återstår. Se [grafikflödet](graphics.md) för hur bilder, storlekar, palett och UI-tema byts separat.

## Kvalitetsbilder v2

- Ett nytt oförändrat transparent PNG-ark, `qualities-v2.png` (1254×1254), innehåller 16 separata bilder för de åtta grundtypernas II/III. Manifestet kopplar dem till respektive kvalitet. V1-bilder finns kvar; inga ändringar i spelregler, balans eller sparformat.
- **61 regelkontroller och bildkontrollen för 44 sprites passerar.** Kontrollen av att byta en enda kvalitet behåller nu befintliga separata bilder för övriga nivåer.
- Grafikförhandsvisningens porträtt har renderats nativt. Webbens porträtt och nya **Board scale**-flik (15/32 pixlar per cell) har granskats visuellt för alla åtta typer och tre kvaliteter. Inga synliga atlasfragment från grannrutor upptäcktes.
- Båda exporterna har byggts. Den faktiska Windows-exporten har renderat 20 bildrutor i 1360×900, startat med `SMOKE_READY` och gett verifierat ljudinnehåll (RMS 0,018294).
- Chrome-test med riktiga musklick placerade fem gems och kombinerade två Amethyst I till II. Ny sprite och nytt porträtt syntes, övriga färska gems blev stenar och striden startade direkt. Paus och zoom provades. Noll konsolfel och noll varningar i grafikvyn och spelvyn.
- Lokala skärmbilder: `output/quality-gallery/frame00000001.png`, `output/playwright/quality-portraits.png`, `quality-board-scale.png` och `quality-upgrade-combat.png` i samma Playwright-mapp. De är testresultat, inte distribuerade bildkällor.

Detta verifierar visuell inkoppling och export. Fulla spelomgångar med naturlig progression och fortsatt stilbedömning återstår enligt avsnittet ovan.

## Rörelse, stridsåterkoppling och naturliga omgångar

- **61 regelkontroller + 14 presentationskontroller passerar**, liksom bildkontrollen för 44 sprites. Presentationstesterna kontrollerar löst skada, immunitet, undvikna attacker, exakt en dödshändelse, begränsad effektlagring, paus/rensning och samma fullständiga omgångsutfall/RNG/sparpunkt med och utan effektlyssnare.
- Native grafikförhandsvisning har renderat 40 bildrutor med skott/områdespulser i den nya fliken **Combat & motion**. Webbens levande förhandsvisning har öppnats och pausats; två skärmbilder tagna vid olika tidpunkter gav identisk SHA-256. Inga browserfel/-varningar.
- Båda exporterna har byggts efter ändringarna. Den faktiska Windows-exporten har renderat 20 bildrutor per ljudtest och verifierat genererade ljudsamples: placering RMS 0,018294 och attack RMS 0,002921. Detta är ingen subjektiv bedömning av ljudet.
- I Chrome placerades fem gems och Sapphire I behölls. Den första träffen visade skott, träffåterkoppling, hälsostapel och slow-markering. Två skärmbilder av pausad strid gav identisk SHA-256, inklusive effekterna. Återupptagning till 2× gav fortsatta fiender och killbelöningar utan konsolfel/-varningar. Vågen avslutades i byggfas två med 24 liv/18 gold (två kills och sex läckor). Zoom testades i samma strid.
- 20 automatiska omgångar med vanliga startförutsättningar, intjänad ekonomi, riktiga RNG-placeringar och lagliga kombinationer genomfördes separat från regressionstesterna. Ingen vann: tre förluster på våg 7, nio på våg 9, åtta på våg 10. Baslinjen bygger ingen planerad labyrint och värderar torn förenklat. Se [speltestrapport och bevarad rådata](playtest-report.md). Ingen balans ändrades.

Render-/browserresultat finns lokalt i `output/motion-gallery/`, `output/native-attack/` och `output/playwright/motion-*.png` samt `effects-*.png`. Effekterna ritas procedurmässigt och fiendernas rörelse använder deformation av befintliga PNG-bilder. Individuellt tecknade gång-/vingrutor återstår; visuellt uttryck, ljud och naturligt labyrintspel behöver fortsatt användarbedömning.

## Bygghjälp och valförhandsvisning 0.3

- **103 kontroller passerar:** 61 regler, 14 effekter, 21 bygghjälp och 7 UI-signaler. Därutöver bildkontroll för 44 sprites, headless-start och Windows-exportstart. Slutloggarna innehåller inga motorfel eller varningar.
- `GemBoard.placement_preview` ger samma validering och väg som verklig placering. Upprepade hoverkontroller bevarar RNG, gems och speltillstånd; sista utvägen från en checkpoint visas korrekt som blockerad. Rivning invaliderar vägförhandsvisningens cache.
- Keep, två/fyra lika och gamla/blandade recept har jämförts mellan förhandsvisning och verkligt utfall: rätt resultatplats, kvalitet, material och konvertering till stenar. Fel fas, för få gems och kvalitet över III saknar genomförbar förhandsvisning.
- De riktiga UI-signalernas tester väljer gems via femknappsfältet, genomför en fyrkombination till III, börjar om och provar samma knapp igen samt skapar Silver med gamla material och Asteriated Ruby med nya material. Ingen extra bekräftelse krävs. UI-fixturen använder `--smoke` och skriver ingen användarsparning. Ljudet är avstängt i det omedelbart avslutade headless-UI-testet för att undvika kvarvarande köade mixerkommandon; ljud verifieras genom renderad export.
- Native huvudscen har renderats med en förberedd kombinationsförhandsvisning för Ruby III. Båda exporterna är byggda och den faktiska Windows-exporten har renderat 20 bildrutor med verifierat attackljud (RMS 0,002921).
- Chrome: giltig tom ruta visade neutral markör/gul markrutt; checkpointklick nekades med 0/5 placeringar kvar. Fem vanliga klick fyllde valknapparna. Andra valknappen valde rätt Sapphire I. Hover på Combine 2 markerade båda materialen och resultatplatsen; klick gav Sapphire II, övriga blev stenar och striden startade direkt. Paus och 2× fungerade. Nästa byggfas nåddes med 30 liv/30 gold och fem tomma valknappar. Omladdning återställde samma byggfas och visade seed i sidfoten. Noll konsolfel/-varningar.

Lokala bilder finns i `output/build-guide-native/` och `output/playwright/build-*.png`. Spelregler, ekonomi, innehållskatalog och sparformat är oförändrade. Mänskligt labyrint-/balanstest och bedömning av läsbarhet återstår.

## Torncentrering och vågresultat 0.3.1

- Användarens Opal-bild visade att tornet låg för högt i rutan. Samtliga 27 tornsprites (åtta grundtyper × tre kvaliteter samt tre specialtorn) använder nu mittankare `[0.5,0.5]` i manifestet. Storlek och logiska rutor är oförändrade. Stenar, fiender och dekorationer behåller sina ankare. Skottens visuella startpunkt anpassades till den nya placeringen via `effects.muzzle_height`.
- `GemArt.sprite_rect` används av själva ritningen och bildkontrollen. **81 layoutfall** verifierar att samtliga torn ligger centrerade vid 15, 32 och 45 pixlar per cell. Bildkontrollen verifierar även samtliga 44 sprites och bildkopplingar som tidigare.
- **106 övriga kontroller passerar:** 61 regler, 14 effekter, 21 bygghjälp och nu 10 UI-kontroller. De tre nya UI-fallen kontrollerar en vågs faktiska kills/leaks/livförlust, nästa vågs delvärden i stället för ackumulerade totalsiffror samt rensning av gammal sammanfattning vid omstart.
- Native renderad Opal bredvid sten i 3× zoom och Ruby-förhandsvisning har granskats mot rutramen. Webbens **Board scale** har granskats med rutram/centrumkors för alla grundkvaliteter. Den matematiska kontrollen täcker också specialtornen.
- Båda exporterna har byggts. Verklig Windows-exe har startats och renderat 20 bildrutor per ljudkontroll med verifierat PCM-innehåll (placering 0,018294 RMS, attack 0,002921 RMS). Motor- och exportloggar är utan fel/varningar.
- Chrome: fem placeringar, val via gemfältet, kombination till Opal II, närmare zoom, paus och 2×. Tornen låg centrerade i sina ramar. Vågen avslutades med 24 liv/18 gold och sammanfattningen **Wave 1: 2 defeated · 6 leaked · 6 lives lost.** visades under spelplanen. Inga konsolfel/-varningar.

Lokala kontrollbilder: `output/alignment-pair/`, `output/alignment-native/`, `output/playwright/alignment-board-scale.png`, `alignment-opal-combat.png` och `alignment-wave-summary.png` i samma Playwright-mapp. Vågsammanfattningen är sessionsdata och ändrar inte byggsparpunkten. Innehållskatalogen och balansen är oförändrade.

## Visuell receptbok 0.4

- **132 kontroller passerar:** 61 regler, 14 effekter, 21 bygghjälp, 10 befintliga UI-fall, 14 receptinventeringsfall och 12 recept-UI-fall. Därutöver verifieras 44 sprites, 81 centreringsfall, headless-start och Windows-exportstart. Slutloggarna saknar motorfel och varningar.
- Receptinventeringen matchar exakt typ och kvalitet, räknar flera nödvändiga exemplar utan dubbelanvändning och skiljer gamla från nya material. Den använder varken RNG eller skrivning till speltillståndet. För få placeringar, bygg-/stridsfas och recept med enbart gamla material ger respektive förklaring.
- UI-testerna öppnar de tre receptkorten, följer recept på spelplanen, lokaliserar och växlar mellan matchande torn, hanterar borttagna material och avmarkerar recept. Ny omgång rensar markering och dialog. Öppning/stängning återställer både pågående och redan pausad strid korrekt.
- Native receptbok med blandade gamla/nya material har renderats och granskats. Porträtt hämtas från samma grafikmanifest som spelplanen. Textfärger för receptlänkar styrs av UI-temat, inklusive inaktiva länkar.
- Båda exporterna har byggts efter slutändringarna. Verklig Windows-export har renderat med verifierat ljudinnehåll (placering 0,018294 RMS, attack 0,002921 RMS).
- Chrome med riktiga musklick: två Sapphire I gav korrekt **1/3** för Silver och två markeringar på spelplanen. **Locate on board** växlade mellan tornen och centrerade kameran. Kombination till Sapphire II uppdaterade följningen till **0/3**. Receptboken pausade pågående strid och stängning återställde **2×** med fortsatta kills. Den slutliga exportens scrollning visade samtliga tre recept och stängningsknappen. Noll konsolfel och noll varningar.

Lokala kontrollbilder finns i `output/recipe-native/` och `output/playwright/recipes-*.png`. Följt recept är sessionsdata som rensas vid ny omgång eller omladdning. Spelregler, innehållskatalog, balans och sparformat är oförändrade. Naturliga fulla omgångar och användarens bedömning av läsbarheten återstår.

## Torninformation och resultatjämförelse 0.5

- **157 kontroller passerar:** tidigare 132 samt 17 torninformationsfall och 8 UI-fall. Därutöver passerar bildkontrollen för 44 sprites och 81 centreringsfall, huvudscenens headless-start och Windows-exportstart. Motor-, test- och exportloggar saknar fel/varningar.
- Attackintervallet beräknas nu gemensamt av simuleringen och informationen. Befintliga numeriska stridstester och hela tiovågsfixturen passerar efter flytten. Kontroller omfattar Aquamarine +200, olika Opal-kvaliteter, identiska aurasorter, avstånd och Opals egen aura. Auratornets ticks påverkas inte av attackhastighet.
- Resultatförhandsvisningen har jämförts med genomförd kvalitetsuppgradering och ett recept med enbart äldre material. Förbrukade Opals och färska gems som blir stenar tas bort från stödberäkningen. Ett äldre recept bevarar däremot orelaterade färska stödgems. Läsning och jämförelse bevarar inventory, RNG och tornval.
- UI-signaler verifierar visad aktuell hastighet, jämförelse i kombinationsknappen, uppdatering efter rivet stöd, separat magisk aura-DPS, dold oanvänd målprioritet och rensning när sten väljs eller omgången startas om. Texterna visar bara den valda kvalitetens effektvärden.
- Native huvudscen med Aquamarine och Opal I/II har renderats och granskats i 1360×900. Båda slutexporterna har byggts. Den riktiga Windows-exporten har dessutom renderat 20 bildrutor med verifierat attackljud (0,002921 RMS).
- Chrome: fem vanliga placeringar gav bland annat Opal I och Topaz I. Topaz visade 1,08 s/attack och 2,8 attack-DPS med Opal-stöd. Keep-förhandsvisningen visade 1,30 s och 2,3, eftersom Opal skulle bli sten. Verkligt Keep gav exakt dessa visade värden. Paus och 2× provades; 2× ändrade inte de visade simuleringsintervallen. Den radbrutna jämförelserutan granskades visuellt. Noll konsolfel och noll varningar.

Lokala bilder finns i `output/tower-native/` och `output/playwright/tower-*.png`. Attack-DPS är rå grundattack mot ett mål, inte uppmätt total vågskada; separata effekter och försvar kan ändra utfallet. Balansvärden, innehållskatalog och sparformat är oförändrade. Full Dota-skadeparitet och naturligt labyrint-/balanstest återstår enligt tidigare begränsningar.

## Vågöversikt 0.6

- **185 kontroller passerar:** tidigare 157, 15 våginformationsfall och 13 UI-fall. Därutöver verifieras 44 sprites, 81 centreringsfall, headless-start och Windows-exportstart. Slutloggarna innehåller inga motorfel eller varningar.
- Alla tio inspekterade vågor matchar katalogens ordning och värden. Inspektion lämnar våg, gems, ekonomi och RNG orörda; returnerade data kan inte skriva över katalogen. Nästa/pågående/avklarad våg samt vinst/förlust redovisas separat från vald informationsvy.
- Mark-/luftmål räknas med nya gems och behållna torn separat, utan stenar. Auratorn inkluderas enligt modellens målregler. Bossläcka visas som omedelbar förlust. Fysisk/magisk/ren träff använder befintlig skademodell; evasion visas separat och genomsnittsberäknas inte in i träffvärdena.
- UI-tester kontrollerar rätt startval, endast ett markerat listval, luft-/bossknappar, aktuell försvarsräkning efter återöppning, omstart och tidigare pausläge. Byte mellan Waves, Recipes och Help återställer ursprungligt pausläge när sista dialogen stängs. Dialogens minsta storlek testas med innehållet ovanför Close-raden.
- Native översikt för luftvåg och boss har renderats och granskats. Testet fångade en initial för stor textlayout; webbkontrollen visade dessutom att ändrad minimistorlek måste räknas om även utan en resize-signal. Båda händelserna hanteras nu. Den slutliga webblayouten lämnar Close-raden fri.
- Båda exporterna har byggts. Verklig Windows-export har startats och renderat med verifierat attackljud (0,002921 RMS).
- Chrome: alla vågor tillgängliga från våg ett; luftvåg, Guard hounds och boss inspekterades utan vågbyte. Guard hounds visade 50 % evasion separat från 76,9 fysisk träffskada per 100 rå skada. Fem verkliga placeringar gav fyra nya luftkapabla gems av fem och noll behållna. Keep på Diamond startade våg ett, övriga blev stenar och lufttalet blev korrekt 0/1 behållna samt 0/0 nya. Waves pausade striden; Close återställde 2× och sidopanelen visade CURRENT WAVE. Noll konsolfel/-varningar.

Lokala bilder finns i `output/waves-native/`, `output/waves-boss-native/` och `output/playwright/waves-*.png`. Antal torn med rätt måltyp är inte ett mått på räckviddstäckning eller vinstchans. Innehållskatalog, balans, spelregler och sparformat är oförändrade. Full skadeparitet och naturligt labyrint-/balanstest återstår enligt tidigare begränsningar.

## Version 1.0.0 – lokal granskningsleverans, 2026-10-24

- 220 regel-/presentations-/UI-kontroller och 180 numeriska referenskontroller passerar. Även 44 sprites, 81 centreringsfall och exportstarter har kontrollerats.
- Båda exporterna är byggda i release-läge. Windows har renderats och attackljudet verifierats (0,002921 RMS). Chrome rapporterar noll fel och varningar.
- Fast attack-/auraklocka behåller delstegsrester. Sex särskilda kontroller täcker bland annat 40 auraticks på tio sekunder och utebliven attackskuld efter tomgång.
- 20 naturliga omgångar med två enkla strategier har körts. Alla accepterade handlingar och utfall har återspelats oberoende med identiska resultat. Labyrintstrategin vann seed 8 med 30 liv. Detta är inte ett mått på mänsklig vinstfrekvens.
- Webben: eget seed, nekad ogiltig seed, fem bindande placeringar, Combine 2, stridsprogression, avklarad våg och Run summary granskade. Copy test report lästes tillbaka som spelets egen JSON: version 1.0.0, seed 8, sex handlingar, åtta besegrade fiender, build-fas och debug_build=false.
- Separat granskningspaket: builds/release/GemTD-1.0.0-local-review.zip, med Windows, webbserver, testguide, balansunderlag och reproducerbara rapporter. Paketets CRC och innehållshashar kontrolleras av paketeringsverktyget.

Se balance-v1.md och reports/ för mätunderlag. Full Dota-effektparitet och mänsklig balansgranskning återstår. Den nya beställningen om hela originalets innehåll är nästa utvecklingssteg och ingår inte redan i 1.0.

## Fullt innehåll – första utvecklingssteget 2026-10-24

- 304 GDScript-kontroller passerar: tidigare 220, 13 kontroller för datastyrda gränser och 71 för sex kvaliteter/Jade. Därutöver 180 låsta balansvärden, 2663 kontroller av hela referensbiblioteket samt befintliga bild-/centreringskontroller.
- Alla 48 grundgems jämförs mot originalets attackskada, intervall och räckvidd. Kvalitet VI testas med faktisk slow, armorvaraktighet, poison, pure splash och Aquamarine-/Opal-bonusar. Två V-gems ger VI; högre kvaliteter överlever byggsparpunkten och gamla innehållsversioner nekas.
- Jade testas med exakta material, förbrukning, bibehållet nytt tornval vid äldre material, verklig fjärde poison-effekt och receptbok/utbytbar reservbild.
- Båda release-exporterna har byggts. Windows-rendering och attackljud passerar. Chrome visar 1.1.0-dev, sex kvaliteter i två rader och ett läsbart Jade-kort. Grundspelet och utvecklingsläget använder skilda sparfiler.
- Samtliga 20 bevarade 1.0-rapporter återspelas fortfarande till samma resultat efter refaktoreringen. 1.0-zippen är bevarad; den har inte skrivits över av utvecklingsprofilen.

Utvecklingsläget har fortfarande tio vågor och fyra recept. De 50 grundvågorna, prövningsvågorna 51–100 och resterande recept finns inventerade men är inte redan spelbara. Se full-content-plan.md för nästa steg och källbegränsningar.

## Kampanj 1.2.0-dev – samtliga fem implementationssteg, 2026-10-24

Denna senare status ersätter innehållsbegränsningen i föregående avsnitt. Kampanjen har 100 spelbara vågor, 48 grundgems, 43 specialtorn, 59 receptalternativ och 24 stentavlor med 16 uppgraderingar. Grundvågor, prövningar, specialförmågor, ekonomi och MVP är datastyrda utifrån den granskade källögonblicksbilden 2026-08-01.

- **589 GDScript-fall passerar**: tidigare 304, 244 kampanjfall och 41 gränsfall. Alla recept, specialtorn och stentavlor provas, liksom spawn av samtliga vågor. En stark separat fixtur verifierar fasövergångarna genom våg 100; den är inte ett naturligt balansspeltest.
- **4436 numeriska kontroller passerar**: 180 låsta 1.0-värden, 2663 referensbiblioteksfall och 1593 kampanjfall. Inga motorfel i slutkedjan. Bildkontrollen verifierar 44 sprites och 273 centrerade kampanjlayouter vid 15/32/45 pixlar per ruta.
- Riktade fall täcker aura-stapling och Ancient-undantag, split vid primär evasion, refraction, regeneration/anti-healing, cleanse, återkommande cask-studsar, blinks världsdistans på glesa flygrutter, MVP-tak/arv, Guardian Stones rullade attack, skyddade tavelfält och alla diagonala uppgraderingar.
- Fem naturliga automatiska kampanjomgångar har journalförts och återspelats oberoende med samma utfall. Fyra förlorar vid boss tio och en vid våg sexton. Det är underlag för fortsatt mänskligt speltest, inte en skattad vinstfrekvens. Samtliga 20 bevarade 1.0-rapporter återspelas fortfarande korrekt.
- Båda senaste exporterna är byggda i release-läge. Verklig Windows-export har renderat 20 bildrutor i 1360×900 med attackljud RMS 0,002921. Inga fel eller varningar i denna körning.
- Chrome: sökning i alla 59 recept, femmaterialskort, navigering till våg 100, seed 8, fem bindande placeringar, kombination till Diamond II och verklig vågstrid. Vågen avslutades med tio kills, noll läckor, 100 liv och 50 guld. Tornet fick MVP 1 och attacken steg från 10 till 11.
- Spelets egen kopierade JSON kontrollerades: version 1.2.0-dev, seed 8, våg 2, sex accepterade handlingar, MVP 1 och debug_build=false. Omladdning återställde byggfas 2 med samma ekonomi och torn. Menybyte till 1.0 visade dess egna 30 liv/tre kvaliteter/tio vågor; retur till kampanjen behöll kampanjens sparpunkt. Noll webbkonsolfel och varningar.

Slutlogg: `output/campaign-final-checks.log`. Naturliga rapporter: `output/campaign-playtest/`. Oberoende återspelningsresultat: `docs/reports/campaign-replays.json`. Kontrollbilder: `output/playwright/campaign-*.png` och `output/campaign-native-attack/`.

Separat granskningspaket: `builds/release/GemTD-campaign-1.2.0-dev.zip`. Den ursprungliga 1.0-zippen bevaras. Läs `campaign-review.md` för avvikelser och `graphics-review-campaign.md` för den påbörjade grafik-/animationsbedömningen. Mänsklig slutbalansering och full Dota-motorparitet är inte verifierade.

## Projektiler och hastighetstak – 1.2.1-dev, 2026-10-24

- Användarens val är införda: målspårande flygtid för attacker/multiskott samt fast tak på 700 total attackhastighet. Skada och on-hit sker vid träff. Ingen historisk klassbonus har gissats fram. Faktisk skadeparitet och avrundning ska fortfarande jämföras med originalmatch.
- **614 GDScript-fall passerar**, inklusive 25 nya fall för flygtid, följning, rörliga/döda/utläckta mål, sekundärträffar, evasion, buffstart, hastighetstak och tangentfokus. Den gamla syntetiska 100-vågsfixturen fick en explicit testprojektilhastighet och en skyddad kontroll av listlängd; den verifierar fortfarande faser och utgör inget balansunderlag.
- **5013 referenskontroller passerar**: 180 låsta 1.0-värden, 3123 fullreferensfall och 1710 kampanjfall. Referensbiblioteket innehåller nu även ursprunglig projektilhastighet och attack animation point. Alla 115 torn-/slabenheters projektilhastigheter har jämförts. Bildkontrollen passerar fortsatt 44 sprites och 273 centreringsfall.
- Fem nya naturliga kampanjrapporter återspelas till identiska resultat. Utfallen är fortfarande fyra förluster på våg 10 och en på 16. Även de 20 bevarade 1.0-rapporterna återspelas korrekt. De föregående kampanjrapporterna finns separat i `output/campaign-playtest-1.2.0-dev/` och deras verifieringar i versionsmärkta filer under `docs/reports/`.
- Båda slutexporterna är release-byggen. Windows har startat och renderat 20 bildrutor i 1360×900. Den procedurstyrda attackljudsproben ger RMS 0,002921; det är en ljudprob, inte ett mått på stridens ljudmix. Inga motorfel i slutkontrollerna.
- Webben: synlig projektil mellan torn och fiende pausades. Två PNG-skärmbilder av den pausade vyn var byte-identiska. Under testningen upptäcktes att Space även återaktiverade en fokuserad hastighetsknapp. Fixen konsumerar pausens ned-/upphändelser före knappen och lämnar textfält/modala fönster till deras vanliga inmatning. Både verkliga Godot-tangenthändelser och webben bekräftar att 2× bevaras.
- Senaste webbexporten: seed 8, fem verkliga placeringar, Keep på Diamond I, faktisk strid i 2× och avklarad våg med tio kills/noll läckor/100 liv/50 guld samt MVP 1. Omladdning återställde byggfas 2 och samma ekonomi/torn från den nya v4-sparfilen. Webbkonsolen rapporterar noll fel/varningar.

Slutlogg: `output/flight-final-checks.log`. Kontrollbilder: `output/playwright/flight-*.png`. Den nya versionens data och sparfiler blandas inte med den gamla kampanjens. Ett separat paket heter `builds/release/GemTD-campaign-1.2.1-dev.zip`; de två äldre paketen bevaras. Se balansundersökningen för skillnaden mellan dokumenterade standardregler, testad implementation och återstående mätning i Dota.

## Utjämnad slump och bossrabatt – 1.2.2-dev, 2026-10-24

- Användarens bossrabatt är implementerad: 150 per besegrad grundboss, sparat till manuella oddsinköp. Grundpriser och guldbelöningar behålls; prövningsbossar ger ingen rabatt. Innehållsversion 6 och egna spar-/rapportfiler skyddar tidigare versioner.
- **689 GDScript-fall passerar:** 26 nya för PRD och 49 för rabatt, sparning, felaktiga data, återspelning, köp och UI. Ett riktigt bossdödsförlopp från en stark testfixtur återspelas oberoende inklusive det efterföljande rabatterade köpet; det är ett funktionstest, inte ett naturligt balansspeltest. Hela kedjan finns i `output/discount-checks.log`.
- **5042 referenskontroller passerar** (180 + 3129 + 1733). Kampanjens bildkontroll verifierar 44 sprites och 273 centrerade layouter. Tre uttryckliga käll-PRD-händelser är kopplade till separata enhets-/händelseräknare. 200 000 försök per händelse ger 10,0165 %, 1,998 % och 49,9195 %. Längsta observerade misslyckandeserier är 30/162/3 jämfört med 91/365/16 för vanlig slump i respektive jämförelsesekvens. Detta är reproducerbara fristående stickprov, inte Valves PRNG eller matchmätningar.
- Fem olika fasta killmängder har körts genom produktionsmodellens ekonomi mot XP-trösklarna. Separat Python-jämförelse täcker 1000 varierande syntetiska killsekvenser. Rabattmodellen följer XP-överkomligheten under dess dokumenterade antaganden; detta verifierar bokföring, inte spelbalans.
- Fem nya naturliga kampanjrapporter återspelas oberoende med identiska resultat: förlust 10/10/10/10/16. I seed 5 besegras boss tio och det andra köpets pris blir 250 i stället för grundpriset 400; journalen verifierar pris och förbrukad rabatt. De 20 bevarade 1.0-rapporterna återspelas fortsatt korrekt. 1.2.0 och 1.2.1 ligger kvar i separata granskningspaket.
- Båda slutexporterna är release-byggen. Windows-exporten har startat, renderat 20 bildrutor i 1360×900 och gett attackljud RMS 0,002921. Inga motorfel eller varningar i slutexport eller Windows-provet. Native UI-fixturer visar gratis köp med 450 rabatt och därefter 200 kvar till nästa köp; dessa bilder är presentationstest, inte spelrapporter.
- Chrome visar 1.2.2-dev, separat rabattbank och rätt inköpspris. Seed 8 startades via dialogen, fem gems placerades och två Diamond I kombinerades till II med automatisk stridsstart. 2× och övergången till byggfas två provades; omladdning återställde seed 8, 83 liv, noll guld och samma bräde. Slutlig webbkonsol: noll fel och varningar. Placeringen i detta UI-prov låg utanför rutten: noll kills, tio läckor, 83 liv och noll guld; detta är inget balansprov. Boss tio visar +150 gemrabatt separat från +150 guld. Ett teckenkodningsfel i våglistan upptäcktes och rättades under den visuella kontrollen; den berörda UI-sviten kördes därefter om och passerade alla 13 fall.

Underlag: `output/prd-distribution.json`, `docs/reports/progression-options.json`, `docs/reports/campaign-replays.json` och `output/playwright/discount-*.png`. Full motorparitet och mänsklig slutbalans är fortfarande öppna verifieringspunkter. Inga fiende-HP eller tornskador har sänkts/höjts för att få boten att vinna.

## Fem undersökningar – 1.3.0-dev, 2026-10-24

- Alla fem beställda undersökningar är genomförda i ordning; beslut och begränsningar finns i `investigation-five-steps.md`. Innehållsversion 7 använder egna spar-/rapportfiler och äldre paket bevaras.
- **737 GDScript-fall och 5067 referenskontroller passerar** (180 + 3129 + 1758), utöver befintliga bild-/ankarkontroller. De nya fallen täcker effektiva skadevärden kontra överflödig skada, bossens räckviddsfönster, observer utan RNG-/tillståndsskrivning, lika cache av/på, slutliga räknare före UI:s förlustsignal, rörelse/räckvidd, aura-livscykel och grafiska identiteter.
- Källbaserade grundvärden för HP/skada/recept/ekonomi behålls. Aura-efterverkan använder dokumenterad standard 0,5 s. En gammal aura-tickskuld kunde ge för täta träffar efter återinträde; den är rättad. Överlappande fientlig/egen avväpning håller skilda klockor. Exakt Dota-eventordning och extern true sight-radie är fortsatt uttryckliga osäkerheter.
- Tolv naturliga botomgångar med riktiga handlingar, RNG och ekonomi har samlats och återspelats oberoende. Alla förlorar vid boss tio. Fem ingår även i standardpaketets jämförelseserie. Seed 3 läcker bossen med cirka 0,7 % HP. Seed 5, som tidigare klarade bossen med hjälp av den gamla auraklockan, läcker nu med 3,91 %. Detta visar behov av mänsklig strategi-/balansgranskning, inte en uppmätt mänsklig vinstfrekvens. Alla 20 bevarade 1.0-rapporter återspelas fortsatt korrekt.
- Förbyggda uppställningar med 32 källgiltiga torn och angivna MVP-värden har körts mot 20/30/50/51/60/75/100. De klarar 20/30 och förlorar senare fall. Samtliga 50 prövningsöppningar har också provats. Inga syntetiska skador eller sänkta HP används, men uppställningarna är inte intjänade genom naturliga recept/ekonomi och bevisar ingen mänsklig kampanjvinst.
- Ett separat täthetstest använder 64 torn och 96 fiender med ändrat spawnschema. Det omfattar upp till 128 projektiler och cirka 1441 samtidiga modifier-/aura-instansposter. Optimerad auracache gav identisk diagnostik och utfall mot referensförloppet. Direkta headless-jämförelser visar cirka 28,5 ms p95 före och 12–27 ms efter beroende på samtidig belastning. Detta är CPU-tider utan rendering, inte allmänna FPS-löften.
- Isolerad release-webb med byte-identiska produktionsfiler har renderats i Chrome, 1360×900. Efter grafikpasset mättes cirka 44 ms median/50 ms p95 vid 1× och 51 ms median/100 ms p95 i en körning med växling till 2×. Extremfallet når inte 60 FPS. Normal export och testfixture ligger på olika lokala portar och använder olika webbläsarprofiler. Denna fixture ingår inte som en dold genväg i spelet.
- Nya kartmärken har granskats native och i den riktiga webbexportens **Clarity**-flik vid 15/32/45 px: I–VI, 43 unika specialkortkoder, åtta stentavlefamiljer/tre grader, MVP/avväpning samt åtta fiendetillstånd. Fullständiga nya animerade spriteark har inte producerats av detta pass. Diagnostikens scrollning och radbrytning har granskats i native-dialogen med en verklig naturlig seed-3-rapport.
- Båda ordinarie exporter är release-byggen. Windows har startat och renderat med attackljud RMS 0,002921. Den samlade headless-kedjan och granskade webbpass har inga motor-/konsolfel eller varningar.

Slutlogg: `output/investigation-final-checks.log`. Naturalkörningar och återspelning: `output/campaign-extended/`, `docs/reports/investigation-extended-replays.json`. Belastning: `output/late-game-audit.json`. Bilder: `output/playwright/clarity-*.png`, `load-web-*.png`, `diagnostics-native-summary.png`. Tidiga fel under utvecklingen rättades före slutkontrollen; de utgör inte godkända testresultat.
