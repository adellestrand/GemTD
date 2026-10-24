# Grafikgranskning efter kampanjutbyggnaden

Den godkända pixelstilen behålls: sten, synliga tak/framsidor, tydliga kristaller och färgidentitet. Tornen ska fortsatt vara visuellt centrerade i rutorna. Detta är nästa produktionsunderlag; nya animerade bitmapark har inte redan producerats.

## Vad granskningen visar

Kampanjen har 48 grundgems, 43 specialtorn och 24 stentavlor. Bildbiblioteket har fortfarande 44 sprites totalt, varav 27 tornbilder. Kvalitet IV–VI återanvänder III-bilder med kvalitetsmarkeringar. Många specialtorn och fiender använder uttryckliga reservkopplingar i manifestet. Stentavlor har en enkel ritad markplatta i spelvyn och reservporträtt i receptboken. Det är lätt att ersätta bilderna, men igenkänningen behöver förbättras inför långa omgångar.

De 273 kontrollerade tornlayouterna täcker kampanjens grundgems och specialtorn vid 15, 32 och 45 pixlar per ruta. Centreringen fungerar. Markplattor räknas separat från byggnader. Befintlig rörelse är främst procedurstyrd bobbning/svajning, riktningsvändning, skott, träffblink och områdeseffekter. Spritebilderna har ännu inga kompletta gång-/attackcykler.

## Prioriterad visuell bearbetning

Uppföljning 1.2.1-dev: vanliga skott och multiskott ritas nu från simuleringens verkliga projektilpositioner. Paus stoppar flygningen och 2× följer simuleringen. Mynningsglimt och korta blixt-/områdeseffekter är fortfarande separata presentationshändelser. Spritearkens gång-/attackcykler nedan återstår.

1. **Igenkänning:** åtta tydliga symboler för stentavlor, tydlig brons/silver/guld-ram, särskilda silhuetter för supertornen och flygande bossar. Nivå IV–VI får successivt mer avancerad byggnad/kristall, med bibehållen fotpunkt.
2. **Fiendernas rörelse:** en pilot med fyra gångbilder och enkla riktningsvarianter. Fötterna behöver markkontakt och skuggan ska följa marken. Flygande typer får ving-/svävcykel och en separat markskugga. Gångtempo följer faktisk förflyttning, inte verklig klocktid.
3. **Tornens liv:** lågmäld kristallglöd och en kort attackförberedelse, utsläpp och återgång. Byggnadens bas står stilla; animationen sker i kristall, glöd och mekaniska detaljer. Hela tornet ska inte hoppa upp ur sin ruta.
4. **Stridstillstånd:** gör poison, refraction, osynlighet/detektering, petrifiering, avväpning och MVP begripliga med återhållsamma symboler och effekter. Crit får en tydlig kort träffaccent; flera auras behöver inte ritas som permanenta starka cirklar.
5. **Miljön:** diskret vegetation, kontrollpunktsrörelse och några återkommande detaljer. Markväg och giltiga byggytor ska förbli lätta att läsa.

## Utbytbar animationsstruktur

Utöka bildlagret med namngivna tillstånd såsom `idle`, `move`, `attack` och `hit`. Varje tillstånd beskriver bild-ID:n, bildfrekvens, loop och eventuella visuella förskjutningar. Spriteark och separata PNG-bilder ska båda fungera. Befintlig statisk bild är reserv när ett tillstånd saknas.

`assets/graphics/manifest.json` beskriver bildval, ankare, storlekar och tillstånd. Spelreglerna fortsätter skicka semantiska händelser. Animationer får aldrig läsa eller förbruka spelmodellens RNG, ändra träfftider eller flytta logiska rutor. Paus och 2× använder simuleringens tid. Mindre rörelse och minskad effektmängd bör kunna väljas i presentationen.

## Nästa konkreta grafikleverans

Gör en Sapphire och en markfiende som animerade pilotexempel, plus de åtta stentavlornas symboler. Granska vid spelstorlek innan ett stort bildpaket produceras. Kontrollera stillbild och rörelse vid 15/32/45 pixlar per ruta, paus/2×, zoom och tät strid. Utvärdera även Windows och webb med många fiender, flera auraeffekter och låg effektmängd. Den befintliga Godot-/Playwright-kedjan används för jämförelsebilder och faktisk inmatning.

## Läsbarhet 1.3.0-dev

Ett presentationspass är nu genomfört med `readability.json`: I–VI-märken, unika kortkoder för 43 specialtorn, åtta stentavlesymboler, tre gradmarkeringar samt prioriterade tillståndsikoner och MVP/avväpning. Högst tre tillståndsmärken visas per fiende; märken använder form utöver färg. Undetekterade osynliga fiender är svaga i bild men deras målbarhet ändras inte. Grafikverkstadens **Clarity**-flik visar 15/32/45 px/cell. Befintliga bildankare är oförändrade.

Detta är återanvändbar läsbarhet ovanpå de befintliga spritebilderna. De planerade nya gång-/attackcyklerna och egna silhuetterna för alla specialtorn återstår. Bildprov: output/playwright/clarity-native.png, clarity-web-final.png och load-web-clarity.png.
