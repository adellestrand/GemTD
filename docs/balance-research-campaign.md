# Liten balansundersökning – 2026-10-24

Undersökningen jämför kampanj 1.2.0-dev med den lokala GemTD-källögonblicksbilden 2026-08-01 och publik utvecklardokumentation. Inga spelvärden har ändrats. Resultaten är prioriteringar för nästa jämförelse, inte ett fastställt balanseringsrecept.

## 1. Kontrollera verklig fysisk träffskada före generella HP-ändringar

Alla 48 grundtorn och 67 special-/slabenheter i referensbiblioteket har `DOTA_COMBAT_CLASS_ATTACK_SIEGE`. Alla 50 grundfiender och de tre alternativa enheterna har `DOTA_COMBAT_CLASS_DEFEND_SOFT`. ModDotas [dokumentation för enheter](https://moddota.com/units/unit-keyvalues) beskriver dessa attack-/försvarsklasser separat från numerisk armor.

Vår `game/core/damage.gd` räknar fysisk armor men ingen klassmultiplikator. Att klasserna finns är verifierat; exakt aktuell Siege→Soft-multiplikator och dess tillämpning på attack respektive skriptad extraskada är **inte** verifierade här. Vi ska därför inte införa en gissad procentsats. En skillnad skulle kunna påverka stora delar av tornbalansen och förhållandet mellan grundattack och magiska/rena effekter.

Nästa kontroll: jämför en ensam grundattack utan stöd/MVP mot en identisk fiende i en körande Dota-match; gör separata fall för positiv/negativ armor, crit och skriptad sekundärskada. Använd samma versionsmärkta referens innan en eventuell kampanjändring. Behåll 1.0-profilen låst.

## 2. Kontrollera hastighetstak och stödstackar i sent spel

Vår kampanj räknar attackintervallet som grundintervall delat med `max(0.2, 1 + bonus/100)` och saknar ett övre hastighetstak. Aquamarine VI har +500 attack speed. Sex olika Opal-kvaliteter ger totalt +270 och specialauran +160. Om alla når samma torn ger modellen +930, alltså 10,3 gånger grundens attackfrekvens. Detta är en beräkning av vår modell, inte ett uppmätt Dota-resultat.

Det genererade [Dota-API-underlaget](https://docs.moddota.com/lua_server/) har `GetMaximumAttackSpeed`/`SetMaximumAttackSpeed` samt motsvarande minimigräns. Den granskade huvudfilen `mode.lua` sätter inget sådant tak, men det bevisar inte vilket standardvärde eller vilka övriga modifierare som faktiskt gäller i matchen. Inget godtyckligt värde, exempelvis 700, införs på denna grund.

Nästa kontroll: mät Aquamarine VI ensam, med en Opal och med flera olika kvaliteter. Kontrollera samtidigt gränser för fienders rörelsehastighet innan prövningsvågorna justeras. Det här kan vara en fråga om för starkt stöd i sent spel snarare än att alla fiender behöver mer HP.

## 3. Jämför gemprogressionens tidpunkt, inte bara samma tröskelsiffror

I originalets `mode.lua:767` är XP-trösklarna 0/250/650/1200/1900. Vid död får hjälten XP före guldkonverteringen (`mode.lua:6477–6559`). En grundboss ger **300 XP men 150 guld**. Vår manuella oddsuppgradering kostar 250/400/550/700 guld, sammanlagt samma 1900 som XP-tröskeln.

Det betyder att samma tröskelsiffror inte ger samma progression: varje besegrad grundboss ger 150 färre vanliga guldenheter än XP, före eventuella guldförmågor. I ett förenklat exempel med tio fiender per våg och perfekta nio första vågor blir det 450 vanliga enheter; efter boss tio har originalet 750 XP medan vår modell har tjänat 600 guld. Originalets 650-tröskel är passerad, men andra köpet hos oss kräver totalt 650. Exemplet isolerar ekonomin; verkligt fiendeantal anpassas och tidpunkten kan därför skilja sig.

Behåll användarens beslut om manuella köp. Kalibrera i stället köpkurvan mot vilken byggfas originalet når varje oddsprofil vid, över flera jämförbara omgångar. Undersök också eliternas borttagna XP och hur extra guld från Greed här kan köpa progression, medan originalets Greed inte ökar den utdelade XP:n.

Den här bosskonverteringen inträffar efter en bossvinst och förklarar därför **inte** de fyra förlusterna mot boss tio. Den motiverar inget generellt billigare tidigt köp utan separat test.

## 4. Inför utjämnad slump där originalet uttryckligen använder den

Den lokala `abilities.json` anger `PseudoRandom` i:

- `tower_baoji1`: 10 % kritisk träff med 5× skada, bland annat för Pink Diamond och Cullinan Diamond.
- `tower_aojiao`: 2 % risk för egen avväpning, för Sunstone.
- `enemy_bukeqinfan`: 50 % för fiendens avväpnande motreaktion.

Vår kampanj använder oberoende slumpdrag för dessa. [ModDotas förmågedokumentation](https://moddota.com/abilities/ability-keyvalues) visar att datadrivna Random-händelser har ett särskilt `PseudoRandom`-fält.

Oberoende 10 %-slag ger ungefär **12,2 % risk att inte få en enda crit på 20 försök** (`0.9^20`). Detta är en matematisk beräkning, inte en mätning av Dotas exakta fördelning. Utjämnad slump bör minska långa sviter och göra korta bossmöten mer förutsägbara. De nominella chanserna ska inte samtidigt höjas för att kompensera. Förmågor som använder vanlig `RandomInt`, exempelvis Greed, ska inte automatiskt byta slumpmodell.

Nästa ändring kan vara en datastyrd slumpmodell per förmåga, med separata räknare och återspelbart tillstånd. Kontrollera långsiktig frekvens, svitlängd och bossutfall. Exakt räknardelning och om försök räknas vid attackstart eller träff behöver också följa källhändelsen.

## Lägre prioritet: projektilflygtid

Originalenheterna anger attack animation point 0 för alla 115 inventerade torn-/slabenheter. Projektilhastighet är 3000 för 112, 2000 för Egyptian Gold och 1200 för de två auratornen. Vid stillastående mål 600 enheter bort är 600/3000 = **0,20 s**; verklig flygtid mot ett rörligt mål varierar. ModDotas [enhetsdokumentation](https://moddota.com/units/unit-keyvalues) beskriver projektilegenskapen separat från attackintervallet.

Vår direkta träff är alltså en verklig skillnad, men underlaget motiverar att undersöka klasskada, hastighetstak och progression först. Om flygtid senare införs behöver vi kontrollera döda mål, överdriven koncentration av skott på samma mål, checkpointläkning och sena läckor.

## Källversion och testunderlag

[Workshopens ändringslogg](https://steamcommunity.com/sharedfiles/filedetails/changelog/474619917) visar senare uppdateringar än vår augustikälla, bland annat i oktober. De synliga senaste noteringarna ger ingen fullständig balansspecifikation. De bevisar därför inte att våra torn-/fiendevärden ska ändras. En ny källversion måste inventeras separat om den ska ersätta augustireferensen.

De fem journalförda automatiska kampanjomgångarna förlorar vid våg 10/10/10/10/16. I tre av bossförlusterna återstod 95–100 liv efter våg nio; bossen är därmed ett tydligt testfall. Strategin är enkel och planerar inte recept långsiktigt. Underlaget visar ingen mänsklig vinstfrekvens och räcker inte för att fastställa en HP-sänkning.

**Rekommenderad ordning:** verifiera fysisk klasskada och hastighetstak; korrigera bekräftade mekanikskillnader och den uttryckliga slumpmodellen; jämför köpkurvan; spela därefter flera fasta seeds innan fiende-HP eller tornskada balanseras. Mät bossens återstående HP vid läcka, aktiv skjuttid, skada per torn/effekt och oddsprofil per byggfas. Blanda inte flera balansändringar i samma försök.

## Bekräftad riktning efter undersökningen

Användaren har valt alternativ 1 i två följdfrågor: följ Dota-förlagans skadeberäkning och använd dess fasta övre attackhastighetstak. Detta är ett val av målmodell, inte en verifiering av varje siffra. Spelvärdena är ännu inte ändrade i denna frågeomgång.

Ytterligare primärkällor hittades vid kontrollen:

- [Valves 7.20-noteringar](https://www.dota2.com/720/) dokumenterar höjningen av maximal attackhastighet från 600 till **700**. Det är total attackhastighet, inte +700 bonus ovanpå basen. Detta ger en dokumenterad standardreferens; eventuell faktisk override i GemTD måste fortfarande uteslutas i matchen. Med bas 100 och +500 blir totalen 600, alltså 6× grundfrekvens; högst 7× med tak 700.
- [Valves Primal Beast-/7.31-noteringar](https://www.dota2.com/primalbeast?l=english) beskriver att attack-/rustningstyper flyttades till förmågor, bland annat Reinforced och Piercing. Gamla Siege-/Soft-etiketter i ett anpassat enhets-KV bevisar därför inte att en äldre klassmatris fortfarande ger en särskild multiplikator. Ingen historisk +50 %-bonus ska införas utifrån enbart de etiketterna. Kontrollera aktuella enheters verkliga förmågor och faktisk träffskada.

Nästa öppna designfråga gäller träfftid: faktisk projektilflygtid enligt originalets enhetsvärden eller fortsatt omedelbar skada med visuella skott. Den frågan påverkar målval, överkoncentration av skott och när slow/armor/gift börjar verka.

Användaren valde därefter faktisk flygtid (alternativ 1). Detta och 700-taket är implementerat i 1.2.1-dev. En full textsökning i det lokala kartpaketets 73 skript-/textfiler gav inga träffar för de undersökta API-/modifiernamnen som ändrar attackhastighetstaket. En direkt jämförelse i en fungerande GemTD-match återstår fortfarande för faktisk skadeberäkning, avrundning och eventordning. Utjämnad slump och ekonomikalibrering är efterföljande arbete; de är inte genomförda av denna fysikändring.

## Uppföljning 1.2.2-dev

Användaren valde källkod och dokumenterade regler som nuvarande verifieringsunderlag eftersom en jämförande Dota-match inte kan köras nu. Detta bekräftar inte motorparitet. Tre uttryckliga `PseudoRandom`-händelser använder nu kalibrerad utjämning per enhet och händelse. Tester med 200 000 försök per händelse ger 10,0165 %, 1,998 % och 49,9195 % mot nominellt 10/2/50 %. Exakt Valve-implementation och eventordning är fortfarande öppna jämförelsepunkter; evasion har inte gjorts om till denna modell utan motsvarande bevis.

Användaren valde även bossrabatt: 150 per besegrad grundboss, sparad till manuella oddsinköp, utan ändrade grundpriser eller guld. De 1000 syntetiska ekonomisekvenserna i `progression-options.md` följer originalets XP-överkomlighet under dess angivna antaganden. Det är bokföringskontroll, inte mänsklig balansmätning. Naturliga botrapporter har därefter samlats på nytt och återspelats; utfallen är fortfarande 10/10/10/10/16. Tornskada och fiende-HP behålls.
