# Undersökning och förbättring – fem steg

Beställt 2026-10-24. Genomför i ordning. Fatta rutinbeslut själv; fråga bara om viktiga vägval. Bevara äldre granskningspaket. Ny leverans planeras som 1.3.0-dev.

1. Klar: bossdiagnostik, effektiv skada, missar, skjutfönster och naturliga seeds.
2. Klar: rörelse, räckvidd, kontrollpunkter och osynlighet.
3. Klar: aura-linger, stapling, försvar och effektordning.
4. Klar: långa omgångar, realistiska sena tornuppsättningar och prestanda.
5. Klar: läsbarhet för kvaliteter, specialtorn, stentavlor och tillstånd.

Källbaserade rättelser prioriteras. Balansändringar kräver ett beskrivet problem och jämförbara före/efter-resultat. Syntetiska styrke-/belastningsfixturer redovisas separat från naturliga spelomgångar. Ingen uppmätt Dota-motorparitet påstås utan motsvarande matchtest.

## Steg 1 – utfall

Observationslagret lämnar RNG och stridsutfall oförändrade. Boss tio läcker med 69,46/55,84/0,69/10,43 % HP i seed 1–4 och besegras i seed 5. Ingen generell HP-sänkning införs: tornval och faktisk räckviddstäckning ger stora skillnader. Rapporter visar effektiv fysisk/magisk/ren skada, överflödig skada, missar, blockerade skadehändelser, bortkastade skott och bossens skjutfönster. Underlag: reports/boss-diagnostics-baseline.json.

## Steg 2 – utfall

13 riktade fall verifierar rörelsebudget genom svängar, fullständigt stopp vid stun/petrifiering, minsta hastighet, procent/konstant-ordning, exakt attack-/upptäcktsgräns samt alla sju kontrollpunkter för mark och luft. Befintliga beteenden behålls. Källans `IsEnemyOnPath` använder 64 världenheter, vilket motsvarar vår radie 0,5 rutor. Spawnkoden lägger till `modifier_bloodseeker_thirst`; ett nytt antaget 550-tak införs därför inte. True sight 900 är fortfarande uttryckligen provisoriskt: lokal förmåga hänvisar till en extern modifier utan dess radiedefinition. Att ändra den utan bevis skulle flytta luft-/osynlighetsbalansen. Rörelsevärden/radier är nu synliga i kampanjens combat-data.

## Steg 3 – underlag

ModDotas genererade motor-API anger standard 0,5 s aura-stickiness: https://docs.moddota.com/lua_server/#cdota_buff. Detta används som dokumenterat fristående standardval för auras efter utträde. Exakt Dota-eventordning och externa native-modifierare är fortfarande inte matchmätta. Ingen historisk klassbonus införs.

## Steg 3 – utfall

15 nya fall täcker inträde/utträde, 0,5 s efterverkan, sista DoT-tick, återinträde utan gammal tidsskuld, avväpningsaura samt sammansatt fysisk/magisk/ren skada. 1.2.2:s aura-timer kunde behålla gammal tickskuld under tiden utanför räckvidd. Den är rättad: ny aura-instans startar en ny intervallklocka. Återspelbara naturliga körningar visar att seed 5 nu läcker boss tio med 3,91 % HP; den tidigare vinsten fick hjälp av den gamla auraklockan. Det kompenseras inte med en generell skade-/HP-ändring. Övriga fyra seeds är jämförbara kontrollfall. Samma namngivna aura staplas inte om dess källmodifier saknar MULTIPLE; olika namn och uttryckliga MULTIPLE-källor hålls separata.

## Steg 4 – utfall

Källgiltiga, men förbyggda, uppställningar har körts mot 20/30/50/51/60/75/100; samtliga prövningsvågor 51–100 har även fått ett öppningsprov. Uppställningen klarar 20/30 men förlorar de senare fallen. Detta är varken en naturligt intjänad kampanjvinst eller bevis för slutlig mänsklig balans. Tolv naturliga bot-seeds stannar vid boss tio med den enkla strategin; de sena fixturerna redovisas därför separat.

Täthetstestet samlar 96 fiender samtidigt mot 64 torn (avsiktligt ändrat spawnschema). Cache för auror per delsteg samt förvalda aura-/detektorkällor minskar upprepade sökningar. Samma täta förlopp ger identiska diagnoser och utfall före/efter optimering; ett separat cache-av/på-test verifierar RNG och alla räknare. Headless p95 har gått från cirka 28,5 till 12,1 ms i en direkt jämförelse; tider varierar med samtidig last. Isolerad release-webb med samma spelkod visar cirka 33,3 ms median och 35,2 ms p95 per renderad bildruta i detta extrema test. Inga sänkta fiende-HP eller artificiella skadebonusar ingår. Ny grafik provas åter i slutkontrollen.

## Steg 5 – utfall

Kvaliteter I–VI har egna tydliga märken. Alla 43 specialtorn har unika kortkoder; de visas vid större zoom eller val. Åtta stentavlefamiljer får skilda symboler och tre gradmarkeringar. Gift/DoT, slow, armor-reduktion, stun, petrifiering, refraction, osynlighet och magiimmunitet får prioriterade form-/färgmarkeringar; avväpnade torn och MVP får egna tecken. Max tre tillståndsikoner per fiende begränsar trängsel. Undetekterade osynliga fiender visas svagt men kan fortfarande inte attackeras.

Separat `assets/graphics/readability.json` och `GemReadability` gör märkena utbytbara utan regeländringar. Grafikverkstadens Clarity-flik och native jämförelsebilder visar 15/32/45 px. Bildernas fotpunkt och storlek har inte ändrats. Åtta presentationstester verifierar täckning, distinkta identiteter och oförändrade modifierdata. Inga nya kompletta gång-/attack-spriteark påstås vara producerade.

## Kvarstående praktiska gränser

Tolv naturliga botomgångar är fortfarande tidiga förluster, inte mänsklig vinststatistik. De sena testuppställningarna använder verkliga enhetsvärden men är förbyggda och bevisar inte ekonomiskt möjlig progression. Täthetstestets slutliga webbgranskning gav cirka 50 ms p95 vid 1× och 100 ms i en körning med växling till 2×; det extremfallet når inte 60 FPS. Sparad rapport med seed och nya skade-/räckviddssiffror är nästa mänskliga balansunderlag. Upptäcktsradien 900 och exakt Dota-eventordning förblir märkta antaganden/osäkerheter. Grundvärden har inte justerats för att få en bot att vinna.

Överlappande avväpning har ett extra gränsfall: fientlig aura uppdateras även medan en oberoende avväpning pågår. Diagnostikens avläsning ändrar aldrig denna klocka; den ansvarar enbart stridsmodellen för.
