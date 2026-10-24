# Mekanikgranskning mot Dota 2 GemTD

Historisk granskning före ändringarna. De fyra beställda rekommendationerna har därefter genomförts i [1.4.0-dev](mechanics-update-1.4.md). Beskrivningar av saknade funktioner nedan avser 1.3.1, inte den aktuella kampanjen.

Undersökt 2026-10-24. Vår kampanj: 1.3.1-dev, innehållsversion 8. Uppdraget är en undersökning; inga spelregler ändras här.

## Underlag och gränser

Primärkällan är det installerade paketet för [Dota 2 GemTD, Workshop 474619917](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917), med intilliggande `publish_data.txt` daterad 19 oktober 2026. Skript läses som text, utan att köras. Workshop-sidan visar också uppdatering 19 oktober; den specificerar inte mekaniken. Exakta nedanstående regler kommer från lokala Lua/KeyValues-filer, inte från sidans beskrivning.

`python tools/audit_mechanics_reference.py 'E:/SteamLibrary/steamapps/workshop/content/570/474619917/474619917.vpk'` skapar [maskinell jämförelse](reports/mechanics-audit-reference.json). Nio centrala tabeller är oförändrade mot vårt augustiunderlag: vågor, vågförmågor, prövningspool, tre receptfamiljer, trapuppgraderingar, kvalitetsodds och Emeralds kopieringspool. 185 referensenhetsposter och 109 utvalda förmågedefinitioner jämfördes utan ändrade faktavärden. Enhets- och förmågefilerna har dessutom exakt samma SHA-256 som tidigare råreferens. Lua-filen är däremot ändrad.

Detta verifierar innehållsdefinitioner. Det bevisar inte att vår tolkning av deras händelser, tidsordning och modifierare är identisk med Dota-motorn. En körande originalmatch har inte jämförts. Serverstyrda hjälte-/kontodata och alla enskilda hjälteförmågor ingår inte i denna genomgång.

## Viktigaste saknade eller avvikande mekaniker

### 1. Prövningarna fortsätter utan nya byggomgångar i originalet

**Bekräftad stor avvikelse.** I `start_build`, ungefär rad 4683 i oktoberkällan, går `_G.level > 50` direkt till strid och returnerar före vanlig byggfas. Prövningarna startas alltså utan fem nya gems inför varje våg. Vår `GemRun.finish_wave` går till byggfas efter alla vågor utom den sista.

Konsekvens: hos oss kan spelaren få upp till 250 ytterligare gemplaceringar på våg 51–100 och fortsätta utöka sin labyrint. Originalets prövningar testar i stället det försvar man byggt fram till våg 50, med de stridsåtgärder originalet fortfarande tillåter. De är inte en period där hela brädet nödvändigtvis är fullständigt låst; originalet tillåter exempelvis vissa äldre tornkombinationer under strid.

**Rekommendation:** högsta prioritet om vi vill efterlikna slutspelsbalansen. Definiera samtidigt vad spelaren får kombinera och flytta under prövningarna. Rätta inte bara bort byggfasen utan att lösa detta samband, sparpunkter, rapporter och mellanvågsinformation.

### 2. Nedgradera en ny gem som rundans slutval

**Saknas.** Originalet ger nya gems med kvalitet II eller högre `gemtd_downgrade_stone` efter de fem placeringarna (cirka 5208). Funktionen (5881) sänker den valda gemmens kvalitet slumpmässigt, behåller typen, gör övriga fyra till sten och avslutar rundans tornval. Det är inte en kostnadsfri omrullning till valfri nivå och inte ett sätt att nedgradera alla äldre torn. Särskild hjälteförmåga kan ge en garanterad sänkning med ett steg; den är ett separat system.

Konsekvens: originalspelaren har ett sätt att försöka få lågkvalitetsmaterial till exakta recept även när gemchanserna blivit bättre. Vår spelare måste vänta på rätt nya material. Detta är ett strategiskt val, inte bara en saknad knapptext.

**Rekommendation:** lägg till det källbaserade slumpvalet som ett separat slutalternativ, med tydliga chanser och testad RNG/återspelning. Garanterad hjältenedgradering bör inte ingå automatiskt.

### 3. Faktiska läckor ska sänka framgångsserien

**Bekräftad ofullständig regel.** Originalets `OnThink` drar av `3 × faktisk skada på slottet` vid en läcka (3802), utöver kontrollpunkternas avdrag. Hos oss finns kontrollpunktsavdrag, men `prepare_escape`/`GemRun.leaked` gör inget motsvarande serieavdrag.

Konsekvens: antalet fiender minskar inte efter misslyckanden på samma sätt. Felet förklarar inte att vi skulle ha färre fiender; det kan tvärtom hålla uppe antalet och möjlig killinkomst.

**Rekommendation:** rätta som separat regeländring med tester för trösklar, minimiantal fem och flera läckor i samma våg.

### 4. Berserk för mycket långdragna vågor

**Saknas.** `OnThink` använder `antal spelare × 120 + 60` sekunder, alltså 180 s i solo, och aktiverar `enemy_crazy` när vågtiden överskrider gränsen. Förmågedefinitionen ger fiender +100 % rörelsehastighet och magiimmunitet genom slottets aura. Tillståndet tas bort inför nästa byggomgång. Hos oss finns ingen sådan vågtimer eller förstärkning.

Konsekvens: extrema slow-/stunlockstrategier kan fungera annorlunda, särskilt sent. Det handlar om simulerad stridstid, inte realtid vid paus eller 2×.

**Rekommendation:** inför med synlig nedräkning och tydlig varning, efter kontroll av hur tidsgränsen påverkar våra befintliga strategier.

### 5. Natural Emeralds kopiering är förenklad

**Förmågan finns, men urvalet avviker.** Originalets `merge_tower` använder en uttrycklig lista på 72 tillåtna förmågor från närliggande ranged-enheter inom 220 källenheter. Flera donatorer med samma förmåga ger flera poster i draglistan. Tornet får upp till tre olika förmågor genom upprepade slumpdrag med ett försökstak.

Vår `GemRun.combine` bygger i stället en lista med unika förmåge-ID:n, filtrerar huvudsakligen på namn och drar utan återläggning. Bland våra direkta torndonatorer kan `tower_true_sight` väljas trots att det inte finns i källans tillåtelselista. Tre käll-ID:n saknas bland våra direkta donatorers definitioner; det bevisar i sig inte att tre torn saknas, eftersom listan kan innehålla äldre/alternativa förmågor.

Konsekvens: olika sannolikheter och potentiellt en extra förmåga, vilket påverkar vilka torn det lönar sig att placera runt Emerald vid skapandet.

**Rekommendation:** använd tillåtelselistan, samma donatorvillkor och källans viktning/försökstak. Kontrollera båda ursprungliga kombinationsvägarna innan ändring.

### 6. Alternativa vågor och bossar

**Delvis implementerat.** Vi har individvarianterna på 35/36/38. Originalets `start_shuaguai` (6290 ff.) kan dessutom välja ett alternativ via `guai[level+100]` och har kalender-/slumpstyrda bossvarianter på bland annat 20, 30, 40 och 50. Dessa väljs inte i vår kampanj, även om vissa alternativa enhetsfakta finns i referensbiblioteket.

Konsekvens: mindre variation och färre försvarskrav i vår version. Exakta variantförmågor måste inkluderas, inte bara alternativa namn/bilder.

**Rekommendation:** börja med ett litet verifierat urval. Knyt gärna datumval till uttrycklig omgångskonfiguration så att samma seed och rapport går att återspela även ett annat datum. Dokumentera då anpassningen.

### 7. Prövningarnas ekonomi återanvänder våra grundvågsbelöningar

**Bekräftad data-/flödesskillnad.** Solo-grenen i `OnEntityKilled` börjar med `exp_count=5`; högre band och bossens 300 XP gäller specifika vågnummer 1–50. Därefter omvandlas belöningen till guld, med särskilda effekter för bland annat eliter/Greed. Vår byggare återanvänder bandbelöningar 5/10/15/20/25 och 150 för bossar även på 51–100.

Konsekvens: annan slutspelsekonomi. Betydelsen beror också på vilka guldköp vi tillåter efter att byggfasen upphört. Vår manuella oddsmodell är redan en godkänd anpassning.

**Rekommendation:** hantera tillsammans med punkt 1; ändra inte belöningar isolerat och anta att ekonomin då blir identisk.

## Saknas men ligger utanför eller ändrar tidigare val

| Mekanik | Original och vår skillnad | Bedömning |
| --- | --- | --- |
| Kombinationer av äldre torn under strid | `merge_tower` kräver `_G.game_status == 2` i solo/co-op; `start_shuaguai`/`finish_build` använder detta som stridsläge. Hos oss sker kombinationer bara i byggfas. | Stor strategisk skillnad, men följer uttryckliga beslut 11 och 61. Ändra inte utan nytt vägval. |
| Bossens läckskada | `AdjustBossAttackDamage` sätter skadan till avrundad kvarvarande HP-procent. Vår bossläcka ger alltid omedelbar förlust. | Medvetet användarval 45. Lägre kvarvarande boss-HP är därför mer förlåtande i originalet; originalets slutvillkor efter våg 50 skiljer också mellan grundomgång och prövningsresultat. |
| Slumpeliter | 1/400 av vanliga spawns blir elit; HP-faktor sjunker från 8× på våg 1 till 2,12× på våg 50 och därefter. +1,5 seriepoäng och förhöjd XP/guldbelöning. | Uttryckligen exkluderat i kampanjens balansnot. Ett nytt innehållsval, inte en oavsiktligt försvunnen normalfiende. |
| Hjälteval och aktiva förmågor | Exempelvis påverkan på kommande gems, positionsbyte och betald läkning finns i källan. | Hjältar/byggare är bortvalda i beslut 10 och 56. Inför inte deras bonusar som gratis standardförmågor. |
| XP och guldens användning | Originalets hjälteprogression och förmågekostnader ersätts av manuella oddsinköp och godkänd bossrabatt. | Behåll det godkända upplägget; exakt originalbalans kan inte förutsättas när resursanvändningen skiljer sig. |
| Veckoteman | Läggs till som extra regler/förmågor i prövningarna. | Uttryckligen exkluderade; kan bli ett senare utmaningsläge. |
| Byggare, fri tornrivning och trapplacering | Originalet har hjältebaserade bygg-/flyttregler; `gemtd_remove` tar bort stenar. Vi har direktplacering och gratis rivning av äldre torn samt nytt trapplaceringssteg. | Nuvarande lättanvända flöde bygger på användarens beslut. Originalets alla regler för rivning/flytt är inte fullständigt inventerade här. |
| Multiplayer, race, kontoprogression, uppdrag och kosmetik | Finns i kartpaketet. | Utanför fristående solo. Exempelvis ligger anropet till `dropItem` i race-grenen och ska inte räknas som en verifierad saknad solomekanik. |

## Implementerat, men ännu inte exakt motorverifierat

- Skadetyper, armor, resistens, evasion, flygande projektiler, slow, poison, stun, multiskott, auror och MVP finns. Ingen genomgång av definitioner bevisar exakt matchning av Dotas händelseordning eller avrundningar.
- True sight finns, men radien 900 källenheter är fortfarande en märkt reservtolkning av en extern modifierare.
- Attackintervallets beräkning och projektilhastighet finns. Dotas attackanimation/attack point före projektilsläpp återskapas inte separat; vår attack skickar projektilen när attackklockan tillåter det. Praktisk betydelse vid målbyte/avbrott behöver verifieras.
- Buffar, debuffar, trap-/förmågecooldowns och aura-tickar återskapas som egna tillstånd. Kampanjstarten rensar flera sådana tillstånd varje våg. Vilka Dota-tillstånd som faktiskt fortsätter genom mellanrummet behöver kontrolleras, särskilt om prövningar ska följas utan byggfas.
- Markrutter, blink och flygvägar är deterministiska rekonstruktioner. Kollisions-/vägval i Dota är inte exakt samma algoritm.

## Rekommenderad genomförandeordning

1. Rätta serieavdraget vid läcka och Natural Emeralds urvalsregler; båda är avgränsade avvikelser inom befintlig mekanik.
2. Lägg till slumpmässig nedgradering som tydligt slutval.
3. Ta ett samlat beslut om originalets prövningsflöde efter 50 och kombinationer under strid. Därefter rättas flöde, ekonomi och sparning tillsammans.
4. Inför berserk med tydlig återkoppling och testa kontrollstrategier.
5. Utöka alternativa vågor/bossar; överväg eliter som ett separat val.
6. Jämför motorberoende detaljer och mänsklig balans efter att dessa strukturella skillnader är hanterade.

Inga hjältesystem, veckoteman eller omedelbara ändringar av användarens val föreslås som automatiska följder av granskningen. Endast auditverktyg, jämförelserapport och den här dokumentationen har lagts till; befintliga samtidiga grafik-/UI-ändringar har inte ändrats.
