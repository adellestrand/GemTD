# Kampanj 1.3.0-dev – lokal granskning

Aktuell användarändring: **innehållsversion 13** (2026-10-28). Efter fem gratis
tornflyttar per spelomgång kostar varje ytterligare lyckad flytt 100 guld.
Ogiltiga flyttar och avbrytning är gratis. Regelversionen får separat sparfil
`run_campaign_v13.json` och topplista. [Tornflyttar](tower-relocation.md) beskriver detaljerna.

Aktuell rättelse: **innehållsversion 11** (2026-10-28, paket 1 i [balansgranskningen](balance-review-2026-10-28.md)). Prövningarnas läckskada följer källans band 1–27/35/43/51/59 för våg 51–99 i stället för 1–23…39, och Torrent-fällan gör källans 150 magiska skada vid nedslaget. Sparning använder `run_campaign_v11.json`; äldre sparfiler migreras inte. Våg 1–50 påverkas inte av läckrättelsen.

Samma dag, paket 2 (motorregler, fortfarande innehållsversion 11 eftersom version 11 inte har distribuerats): magiskt motstånd staplas multiplikativt som i Dota (`1 − (1 − bas) · Π(1 − rᵢ)`) i stället för att summeras; Bloodstone/Sunstone-kedjan gör alltid fem träffar och studsar tillbaka på redan träffade mål när inga nya finns, som `chain.lua`; Emerald Golem förstenar 5 + floor(MVP/2) närmaste fiender i stället för fem i spawnordning.

Samma dag, paket 3: **innehållsversion 12** och `run_campaign_v12.json`. Framgångsserien flyttar fiendeantalet ett steg per händelse (`WinStreakAdjust`). Flera Sea Jewels har chansen p, p/2, p/3 …. Chain frost ministunnar bara första målet och studsar även på magiimmuna. Venom-fällan är en rörlig projektil (600/400/200 enheter/s). Fällorna kastar 0,05 s efter utlösningen med projektilernas restid, och Entangle/Paralysis silver och guld får dessutom 0,01–0,5 s slumpad fördröjning per mål. Bloodstone/Sunstone-kedjan stoppar när föregående mål har dött (`ShanDian`).

Senaste uppföljning: **1.4.1-dev**, innehållsversion **10**, lägger till [fem tornflyttar per omgång](tower-relocation.md). Alla 1.4-mekaniker nedan behålls.

Aktuell uppföljning: **1.4.0-dev**, innehållsversion **9**. [Mekanikuppdateringen](mechanics-update-1.4.md) ersätter äldre beskrivningar av prövningarnas byggfaser, belöningar och Emeralds urval. Nedgradering, läckserie, kombinationer av äldre torn under strid, berserk och alternativa vågor/bossar ingår. Äldre leveranser bevaras.

Uppföljning **1.3.1-dev**, innehållsversion **8**: nyskapade traps som använder nya gems får flyttas innan striden startas med **Start wave**. Tornvalet är redan förbrukat; övriga nya gems blir sten och fler byggval är låsta. Traps som skapas med bara äldre material kan som tidigare flyttas under den vanliga byggfasen. Sparning använder `run_campaign_v8.json`; tidigare granskningspaket och sparfiler bevaras. Texten nedan beskriver grundutgåvan 1.3.0-dev.

Denna uppföljning till 1.2.2-dev genomför de fem beställda undersökningarna: bossdiagnostik, rörelse/räckvidd, förmågesamverkan, sena vågor/prestanda och grafikens läsbarhet. Fiendeauror har 0,5 s efterverkan och en utgången aura återstartar sin intervallklocka vid återinträde. Stridsrapporter visar effektiv skada, överflödig skada, missar, blockerade skadehändelser, förkastade projektiler och bossens skjutfönster. Kartmärkena ligger i separat grafikdata. Tornskada, fiende-HP, recept, guldbelöningar, bossrabatt och inköpens grundpriser behålls. Äldre granskningspaket bevaras.

## Omfattning

Kampanjen innehåller 50 grundvågor i den granskade Dota-källans ordning och prövningsvågorna 51–100. Åtta grundtyper har sex kvaliteter. Alla 59 receptalternativ finns: 38 vanliga, 13 hemliga och åtta grundrecept för stentavlor. Sexton automatiska uppgraderingar ger totalt 24 stentavlor i brons/silver/guld. Flera recept kan ge samma torn utan att materiallistor skrivs över.

Aktivera **Run → Solo campaign · 100 waves** eller öppna `http://127.0.0.1:8060/?profile=campaign`. Från källa: `powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Campaign`. Sparfiler, rapportidentiteter och innehållshashar är separerade från 1.0 och den tidigare gemprofilen.

## Strid och progression

- Sammanställda definitioner för 107 förmågor beskriver passiva värden, stöd-/fiendeauror, slow, poison, armor, magiskt motstånd, splash, split, crit, stun, kedjor, blixtutbrott, petrifiering, frosteffekter och stentavlor. Kosmetiska källförmågor ger ingen dold stridsbonus.
- Fiender får bland annat osynlighet/detektering, magiimmunitet, fysisk resistens, evasion, avväpning, armorauror, refraction, läkande kontrollpunkter, guldstöld, regeneration, blink, Windrun, riktat försvar och skadebaserad rensning av debuffs.
- Vågor 35/36/38 kan välja sina alternativa enheter. Prövningarna återanvänder 1–50 med två reproducerbara slumpförmågor, källans HP-regler och 1,8× hastighet.
- Varje avklarad grundvåg 1–50 ger en MVP-nivå till det mest skadegörande berättigade tornet. Tio nivåer ger +100 % skada och en +100 %-aura till andra torn inom 290 källenheter. Samlad MVP-bonus har +500 % tak. Kombinationer för över materialens nivåer med tak tio. Prövningar ger inga nya nivåer.
- Natural Emerald kopierar upp till tre olika förmågor från kvarvarande torn inom 220 källenheter vid skapandet. Guardian Stone rullar sin attack från källans begränsade normalfördelning; resultat och RNG kan återspelas.
- Stentavlor lämnar markvägen öppen. Receptet öppnar den valda materialrutan; övriga förbrukade material blir sten. Välj tavlan och **Move path trap** under byggfasen. Två lika traps var som helst på brädet slås automatiskt ihop till nästa nivå (brons → silver → guld) på den nyaste trappens ruta; den andra rutan blir fri (användarbeslut 2026-10-24, avviker från Dotas tre i rak linje). Start-/målhörnen är skyddade. Räckvidd för utlösning är en ruta och cooldown tio sekunder.

## Balansreferens och avvikelser

Referensen är den lokalt granskade ögonblicksbilden **2026-08-01**. Detta är inte ett påstående om senaste Workshop-innehåll eller full Dota-motorparitet.

Kampanjen startar med 100 liv och 0 guld. Tidiga fiender ger fem guld, senare band 10/15/20/25 och bossar 150. Fast prototypinkomst för avklarad våg används inte. Läckkostnaden rullas i källans intervall. Antalet vanliga fiender börjar på tio och anpassas med framgångs-/läckserien; nedre gräns fem. Bossvågor innehåller en boss.

De manuella inköpen av gemchanser behålls från projektets beslutade spelregler. Grundpriserna **250/400/550/700** följer differenserna mellan originalets kumulativa XP-trösklar 0/250/650/1200/1900. Varje besegrad grundboss på våg **10/20/30/40/50** ger **150 sparad rabatt** på kommande oddsinköp, utöver sin oförändrade guldbelöning. Prövningsbossar och utläckta bossar ger ingen rabatt. Vid köp används högst grundpriset ur rabattbanken; överskott ligger kvar. Ett köp kan bli gratis men måste fortfarande göras manuellt. Knappen visar faktiskt guldpris och tillgänglig rabatt. Exempel: grundpris 400 och rabatt 150 kostar 250 guld. Rabatt 450 mot grundpris 250 ger ett gratis köp och 200 kvar till nästa.

Det är en dokumenterad anpassning: originalet höjer hjältenivån genom XP, medan spelaren här väljer när guldet används. I 1000 syntetiska killsekvenser följer denna rabatt XP-trösklarnas överkomlighet när alla bossar besegras och köp görs direkt. Greed kan fortfarande påskynda köpen och guldstöld försena dem; originalets XP påverkas inte på samma sätt. Se `progression-options.md`. Inga torn-/fiendegrundvärden höjs för att få teststrategin att vinna.

Ytterligare skillnader: inga hjältar, slumpeliter eller veckoteman; deterministiskt vägval och blink som bevarar kontrollpunkternas ordning. Aura-linger, klass-/förmågebaserade reduktioner och vissa motorberoende staplings-/avrundningsdetaljer är inte fullständigt jämförda med en körande Dota-match. Gamla Siege-/Soft-etiketter behandlas inte som bevis för en historisk extra skadebonus. True-sight-radien 900 källenheter är en uttrycklig reservtolkning eftersom den lokala förmågan hänvisar till en extern modifierdefinition. Slabskapande på materialrutan följer prototypens atomära tornval snarare än originalets hjälteposition. Enstaka engelska visningsnamn är lokala översättningar; ursprungs-ID:n behålls i data.

Tre källhändelser använder en separat PRD-räknare per enhet och namngiven händelse: `tower_baoji1` (10 % crit), `tower_aojiao` (2 % självavväpning) och `enemy_bukeqinfan` (50 % defensiv avväpning). Misslyckanden höjer nästa chans och framgång nollställer räknaren. Koefficienterna är kalibrerade för den angivna långsiktiga frekvensen; procenten är ett genomsnitt, inte varje enskilt slumpslags chans. Räknare följer torn mellan vågor/sparpunkter och nollställs för en ny kombinerad enhet. Övriga slumpförmågor behåller befintlig fördelning. Detta är en fristående rekonstruktion; Valves interna PRNG, startvärden, exakta koefficienter och motorernas eventordning är inte matchverifierade.

Vanliga attacker och multiskott följer målet med originalenhetens `ProjectileSpeed`, omräknad från världenheter till rutor. De flesta använder 3000 och Egyptian Gold 2000. Skada och on-hit sker vid träff; dött eller utläckt mål kastar bort skottet utan nytt mål. Multiskottens sekundärträffar kringgår evasion och utlöser inte grundattackens träffeffekter. Blixtförmågor som källskriptet applicerar direkt behåller sin direkta skada; de förvandlas inte automatiskt till flygande skott. All flygtid följer 30 Hz-simuleringen, paus och 2×.

Attackfrekvensen använder samma beräkning i strid och tornpanel: total hastighet = bas 100 + bonusar, begränsad till 20–700. +500 innebär alltså totalen 600, inte ett uppnått 700-tak. Panelen förklarar när taket nås och överskjutande bonus inte hjälper. 700 är standardgränsen som Valve dokumenterade i 7.20. En textsökning i det lokala kartpaketets 73 skript-/textfiler hittade ingen `SetMaximumAttackSpeed`/`SetMinimumAttackSpeed` eller undersökt modifieroverride. Det är underlag för den valda standardregeln, inte en utförd mätning i en körande GemTD-match.

Innehållsversionen är nu 7. Sparpunkten `run_campaign_v7.json` och rapportfilen `last_review_campaign_v7.json` separeras från föregående kampanjfiler så att äldre data inte skrivs över. Rabattsaldo, redan belönade bossar och tornens PRD-räknare sparas och valideras. Tidigare kampanjrapporter hör till respektive bevarat paket; aktuella rapporter kräver 1.3.0 och samma innehållshash. Version 5 användes endast under lokal utveckling och levererades inte.

## Kontroller

- Regeltester provar alla recept, alla specialtorn/stentavlor och spawn för varje våg. En separat stark testfixtur provar hela övergångskedjan till vinst på våg 100; den är inte ett balansspeltest.
- Gränsfall täcker modifiernamn och stapling, magiimmunitet, osynlighet, poisonens sista tick, refraction, anti-healing, cleanse, upprepade cask-studsar, MVP-tak/arv och Guardian-rollens återspelning.
- `python tools/verify_campaign.py` jämför numeriska grundvärden, recept, ordning, oddspriser och MVP-parametrar med referensunderlaget. `python tools/verify_reviews.py --campaign` återspelar naturliga omgångars accepterade handlingar.
- De fem paketerade enkla labyrinttesterna förlorar vid boss tio. Även en utökad serie med tolv seeds förlorar där. En tidigare bossvinst i seed 5 fick hjälp av aurans gamla tickskuld; med rättad klocka läcker bossen med 3,91 % HP. Det visar behov av mänsklig balansgranskning och en bättre spelstrategi, inte en uppmätt mänsklig vinstfrekvens. Tidigare utvecklingskörningar med de lägre provisoriska oddspriserna nådde längre och ska inte blandas med den slutliga prisprofilen.

För granskning: spela samma seed igen, jämför boss-/luftvågor och kopiera **Run summary → Copy test report**. Uppge vad som kändes svårt eller otydligt tillsammans med rapporten. Den innehåller accepterade handlingar, startpunkt, vågutfall, stridsdiagnostik, MVP-/rollvärden, PRD-räknare, sparad rabatt, belönade bossar, stentavlor och versionsidentitet. Ingen rapport skickas automatiskt.

## Kort manuell testomgång

1. Öppna kampanjprofilen och kontrollera **1.4.1-dev**, **Wave 1 / 100**, 100 liv och sex kvaliteter. **Run → New run** startar alltid med en ny slumpad seed.
2. Placera fem gems på giltiga rutor. Välj en att behålla, eller kombinera två lika om sådana finns. Övriga färska gems blir sten och striden startar. Kontrollera paus/hastighet och markvägens kontrollpunkter.
3. Öppna **Waves** under strid och inspektera våg 8, boss 10 och prövning 100 utan att ändra den pågående vågen. Dialogen pausar; stängning återställer tidigare hastighet.
4. Efter en avklarad våg: kontrollera faktisk guldinkomst, kills/leaks och MVP. Öppna **Run summary**, kopiera rapporten och ladda om sidan. Omladdning startar vid byggfasens sparpunkt, inte mitt i den avbrutna striden.
5. Sök i **Recipes** efter ett torn eller `secret`. Följ material över flera byggfaser. För en stentavla: skapa på en tillåten materialruta, välj **Move path trap**, flytta under byggfasen och kontrollera att markvägen är öppen. Två lika tavlor var som helst på brädet uppgraderas.
6. Starta en ny omgång och kontrollera att seed i rapporten ändras. Anteckna vilken våg, luft-/marktyp eller effekt som blev svår eller svårläst och bifoga testrapporten. Kontrollerad återspelning sker med testverktygen, inte genom seedval i spelmenyn.

7. Efter besegrad grundboss: kontrollera +150 sparad rabatt och oförändrat bossguld. Gör ett manuellt oddsinköp och kontrollera det reducerade priset samt eventuell kvarvarande rabatt. Ladda om i nästa byggfas och kontrollera saldot.

## Leveransens fem steg

| Steg | Genomfört | Kvar för mänsklig granskning |
| --- | --- | --- |
| 1. Referensgranskning av 1.0 | Bevarat paket, 20 återspelade naturliga rapporter och verklig webb-/Windows-körning. | Användarens jämförelse av känsla och svårighet. |
| 2. Originalvågor 1–20 | Källordning, fiendeförmågor, bossar, läckor och solofaktorer. | Praktisk strategi och upplevd kurva. |
| 3. Recept och effekter | Alla 59 alternativ, specialtorn och 24 stentavlor med källbaserade värden. | Läsbarhet och motorberoende effektparitet. |
| 4. Hela omgångar och ekonomi | Naturliga handlingar, versionsmärkt rapport, oberoende återspelning och riktade ekonomitester. | Mänsklig slutbalansering; teststrategin vinner inte kampanjen. |
| 5. Fullt våginnehåll | 50 grundvågor, 51–100, varianter och slutlig vinstövergång; exporterat till båda målen. | Långa naturliga spelomgångar, belastning i sent spel och slutlig balans. |

Grafikbedömningen är påbörjad i `graphics-review-campaign.md`. Den skiljer befintliga effekter från kommande animerade spriteark.

## Undersökningens praktiska resultat

Aura-linger använder ModDotas dokumenterade standard på 0,5 s (https://docs.moddota.com/lua_server/#cdota_buff). Vår implementering räknar slutliga periodiska ticks och tar bort en utgången instans; ett återinträde återspelar ingen gammal tickskuld. Olika modifiernamn respektive uttryckliga MULTIPLE-källor hålls separata. Exakt motorordning och native-modifierare behöver fortfarande en originalmatch.

`Run summary` visar senaste vågens skadefördelning och de fem mest skadegörande källorna; full JSON innehåller tolv källor och totalsummor för samtliga. Effektiv skada räknas högst till fiendens återstående HP. MVP:s befintliga källbaserade skadebokföring ändras inte av denna observationsmätning. Skjutfönster för grundattack och skadande auror redovisas separat.

Förbyggda uppställningar med källgiltiga torn har testats mot sena vågor och alla prövningsöppningar. De är belastnings-/sammansättningsprov, inte intjänade kampanjvinster. Täthetstestet använder 64 torn och 96 samtidigt spawnade fiender. Normal- och dubbel hastighet fungerar, men extremfallet är tungt i webb: uppmätt p95 cirka 50 ms vid 1× och 100 ms i en körning som växlade till 2×. Värdena gäller denna dator/testmiljö; 60 FPS i sådana extremfall utlovas inte.

Romerska kvalitetsmärken visas på kartan. Specialtorn får kortkoder när de är valda eller inzoomade; åtta trapsymboler skiljer effektfamiljer och en/två/tre kantmarkeringar visar brons/silver/guld. Fiendetillstånd har högst tre prioriterade märken. Färger, kortkoder och familjekopplingar finns i `assets/graphics/readability.json`. Detta ersätter inte framtida egna spriteark för alla högkvaliteter/specialtorn. Grafikverkstaden har en ny **Clarity**-flik.

Se `investigation-five-steps.md` för ordning, underlag, beslut och kvarvarande begränsningar. Naturlig slutbalans, en mänsklig hel kampanj och Dota-motorparitet är fortfarande inte verifierade.
