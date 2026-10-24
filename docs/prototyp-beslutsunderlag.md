# GemTD – beslutsunderlag för första prototypen

Datum: 2026-10-23. Status: 61 interaktiva beslut dokumenterade. Beslutsgenomgången är sammanställd; aktuella versionsdata behöver verifieras före implementation av berörda regler. Den aktuella omfattningen och arbetsordningen finns i prototypplan.md.

## Utgångsläge

- Repository: https://github.com/adellestrand/GemTD
- Granskad commit: `06dcaceb4a287762ecbd05a047ceee836d2e6de3` på `main`.
- Repot innehöll endast `README.md` med rubriken `GemTD` vid genomgången.
- Bekräftat av användaren: Dota 2-versionen är förlagan; bara solo ingår; arbetet befinner sig i planeringsstadiet.
- Målplattform, grafisk riktning och motor är valda enligt beslutsloggen nedan.
- Konkreta spelregler och mängder som inte uttryckligen bekräftats i beslutsloggen är prototypförslag. De är inte en verifierad återgivning av en viss GemTD-version.

Målet med prototypen är att kunna bedöma om labyrintbygge, slumpade gems, kombinationer och strider tillsammans ger rätt spelkänsla. Ett tydligt, spelbart varv genom dessa system är viktigare än mängden innehåll.

## Bekräftade beslut – interaktiv ordning

1. **Fristående spel.** Spelet ska inte köras som ett custom game inuti Dota 2.
2. **Nära förlagans kärna, mindre innehåll.** Bevara centrala regler för labyrintbygge, gemval och kombinationer, med färre gems och vågor i prototypen. Prototypen har tio vågor, alla grundtyper från förlagan och tre specialrecept enligt senare beslut.
3. **2D med pixelgrafik.** Spelplan ovanifrån, med byggnadssprites som visar tak och framsida. Användarens bildreferens visar detaljrika fantasibyggnader med mörka konturer och färgade magiska effekter. Detta är inte ett val av riktig 3D eller en isometrisk spelplan.
4. **Webbläsare och Windows, om komplexiteten hålls rimlig.** Gemensam spelkod och gemensamt innehåll. Ett tidigt tekniskt test ska kontrollera båda målen innan större implementation.
5. **Användaren beskriver och testar; Codex skriver koden.** Användaren styr spelregler, utseende och prioriteringar.
6. **Godot + GDScript.** Gemensamt projekt för webb och Windows. Exakt motorversion och exportinställningar fastställs inför det tekniska testet.
7. **10 vågor.** Detta är omfattningen för den första spelbara prototypen.
8. **Kartlayout nära Dota 2-förlagan.** Kartlägg och efterlikna byggytor, hinder och kontrollpunkter. Användaren valde detta framför en förenklad testkarta.
9. **Den aktuella Dota 2-versionen är referens.** Dokumentera datum, kartversion när den kan identifieras och underlag vid inventeringen. Referensvalet innebär inte att kartlayout och regler redan är verifierade.
10. **Direktplacering med musen.** Spelaren väljer en giltig ruta; ingen styrbar byggare krävs.
11. **Separata bygg- och stridsfaser.** Placering, kombinationer och rivning sker mellan vågorna. Spelplanen är låst under strid.
12. **Automatisk vågstart.** Ingen tidsgräns i byggfasen och ingen separat startknapp. Vågen startar när byggfasens obligatoriska val är slutförda. Det avslutande tornvalet och fasordningen preciseras i beslut 61.
13. **Fem slumpade gemplaceringar per byggfas.** Detta är antalet placeringar per runda, inte antalet olika gemtyper i innehållet.
14. **Gemmen avslöjas efter placeringen.** Spelaren väljer först ruta. Typ och kvalitet avslöjas därefter; placeringen är bindande.
15. **Ett torn behålls per vanlig runda.** Kvalitetsuppgraderingar och specialrecept följer de senare besluten 25 och 30.
16. **Övriga gems blir stenar.** I en vanlig runda blir de fyra gems som inte behålls hinder som står kvar och formar labyrinten.
17. **Gratis, obegränsad rivning av stenar under byggfasen.** Ingen resurskostnad eller kvot per runda.
18. **Behållna torn kan rivas gratis under byggfasen.** Tornet försvinner och ger inga gems eller resurser tillbaka.
19. **Placering som helt blockerar någon etapp i fiendernas rutt nekas direkt.** Ingen gem ska avslöjas eller förbrukas vid en nekad placering. Hela rutten genom samtliga kontrollpunkter ska vara giltig efter varje placering.
20. **Åtta rörelseriktningar för markfiender.** Diagonal rörelse är tillåten endast om de två angränsande rutorna på sidorna om diagonalen är fria. Flygande fienders rörelse följer det senare beslutet 38.
21. **Både kvalitetsuppgraderingar och specialrecept ingår.** Lika gems kan uppgraderas; bestämda gemkombinationer kan skapa specialtorn.
22. **Olika materialregler för kombinationssystemen.** Kvalitetsuppgraderingar får bara använda gems från den aktuella byggfasen. Specialrecept får använda både nya gems och tidigare behållna torn. Stenar räknas aldrig som gems.
23. **Två eller fyra lika gems för kvalitetsuppgradering.** Samma gemtyp och kvalitet krävs. Två förbrukade gems ger en gem ett kvalitetssteg högre; fyra ger en gem två kvalitetssteg högre.
24. **Tre kvalitetsnivåer i prototypen.** Innehållsmodellen ska kunna utökas med fler nivåer senare. Regler för uppgraderingar över maxnivån följer av beslut 29.
25. **Kvalitetsuppgraderingen räknas som rundans enda behållna torn.** Ingen extra vanlig gem får behållas som bonus. Övriga oanvända nya gems blir stenar.
26. **Förbrukade material lämnar stenar.** Detta gäller både kvalitetsuppgraderingar och specialrecept, med undantag för den position där kombinationens nya torn står.
27. **Resultatet placeras på en materialposition som spelaren väljer.** Det nya tornet får inte placeras på en annan, ledig ruta.
28. **Ingen närhetsregel för kombinationer.** Både kvalitetsuppgraderingar och specialrecept kan använda material var som helst på kartan, med de materialbegränsningar som följer av beslut 22.
29. **Uppgraderingar som överskrider högsta kvalitetsnivån tillåts inte.** Bara uppgraderingar med ett resultat inom nivå ett till tre erbjuds. Material ska inte förbrukas för en ogiltig uppgradering.
30. **Specialreceptets påverkan på rundans tornval beror på materialen.** Om någon av den aktuella byggfasens nya gems används räknas resultatet som rundans behållna torn. Om bara tidigare behållna torn används får spelaren också behålla en ny gem den rundan.
31. **Tre specialrecept i prototypen.** Det preliminära urvalet följer av beslut 57. Exakta materialkrav och effekter ska verifieras mot aktuell kartversion.
32. **Alla grundtyper från Dota 2-förlagan ingår.** Urvalet begränsas inte till typerna som behövs för de tre specialrecepten. Typnamn och antal måste fastställas i referensinventeringen.
33. **Chansen till högre kvalitet förbättras under spelomgången.** Nyplacerade gems är inte begränsade till nivå ett under hela omgången. Exakta sannolikheter är ännu inte fastställda.
34. **Förbättrade gemchanser köps med resurser som tjänas under omgången.** Ingen automatisk förbättring med vågnumret är vald. Intäktskällorna följer av beslut 35; priser, startvärden och progressionstabell återstår att bestämma.
35. **Resurser tjänas både för besegrade fiender och för avklarade vågor.** Fiender som släpps igenom ger ingen fiendebelöning. En avslutad våg ger en grundsumma om spelaren fortfarande har liv kvar. Exakta belopp är ännu inte fastställda.
36. **Gemchanser kan uppgraderas när som helst, även under strid.** Köp påverkar bara framtida gemplaceringar. Redan avslöjade gems ändras inte. Sannolikheterna kan därför ändras mellan placeringar i samma byggfas.
37. **Både markfiender och flygande fiender ingår i prototypen.** Flygande fiender är inte uppskjutna till senare innehåll.
38. **Flygande fiender följer samma kontrollpunkter i samma ordning som markfienderna.** De flyger rakt mellan punkterna över torn och stenar. Marklabyrinten förlänger inte flygrutten.
39. **Ett bestämt urval av torn kan attackera luft.** Vissa torn attackerar mark och luft, andra bara mark. Målbegränsningen ska vara synlig i torninformationen. Vilka grundtyper och specialtorn som har luftattack återstår att fastställa.
40. **Förlagans fulla skademodell.** Skadetyper, motstånd och specialfall ska kartläggas och återskapas. Användaren valde detta framför en förenklad modell med en skadetyp eller enbart fysisk/magisk skada. Exakta regler är ännu inte verifierade.
41. **Valbar målprioritet per torn.** Spelaren ska kunna välja exempelvis först, sist, starkast eller närmast, varefter tornet väljer mål automatiskt enligt prioriteten.
42. **Egen, fast följd av tio vågor med fiender från förlagan.** Anpassa ordning och sammansättning för att testa markförsvar, luftförsvar, skadetyper och progression. Vågor ska inte slumpas och behöver inte följa förlagans första tio vågor.
43. **En avslutande bossvåg på våg tio.** Inga ytterligare bossvågor är valda. Exakt boss och vågsammansättning fastställs senare.
44. **Livkostnad vid genomsläpp varierar med fiendetyp.** Fienden försvinner vid slutmålet. Vanliga fiender kan kosta lite och farligare fiender mer. Livkostnaden ska framgå av våginformationen. Exakta kostnader och antalet startliv är ännu inte fastställda.
45. **Bossen måste besegras för vinst.** Spelaren måste besegra bossen och avsluta våg tio med liv kvar. Om bossen når slutmålet blir det förlust även om liv återstår.
46. **Två omstartsalternativ.** Både nytt försök med samma startvärde för slumpen och en ny omgång med ny slump ska erbjudas. Båda börjar på våg ett. Ändrade köp av kvalitetsuppgraderingar kan påverka gemresultaten trots samma slumpföljd.
47. **Automatisk lokal sparning vid början av varje byggfas.** Omgången återupptas från den senaste sparpunkten. Sparning sker separat i webb- respektive Windows-versionen. Exakt återupptagning mitt i strid är inte vald.
48. **Normal hastighet, dubbel hastighet och paus.** Fyrdubbel hastighet ingår inte i det valda läget.
49. **Zoom och panorering med fast kameravinkel.** Spelaren ska kunna få överblick över kartan och zooma in för att se pixelgrafik och välja torn. Hela kartan behöver inte alltid synas samtidigt.
50. **Vägvisning under byggfas, valbar under strid.** Mark- och flygrutter ska visas med tydligt olika markeringar. Markrutten uppdateras när labyrinten ändras.
51. **Öppen receptbok från början.** Alla tre specialrecept visas med materialkrav och resultat. Spelet markerar vilka material spelaren redan har.
52. **Engelsk speltext.** Menyer, instruktioner, torninformation och recept ska vara på engelska. Planering och dokumentation kan fortsätta på svenska. Speltexter hålls separerade från kod för att underlätta fler språk senare.
53. **Tillfälliga bilder före detaljerad pixelgrafik.** Testa mekanik, läsbarhet och storlekar med enkla symboler först. Ersätt därefter med pixelgrafik i användarens referensstil.
54. **Grundläggande ljudeffekter.** Ljud för placering, kombinationer, attacker, genomsläpp och vinst/förlust. Volymkontroll och mute ska finnas. Bakgrundsmusik ingår inte i den valda ljudomfattningen.
55. **Frivillig hjälpsida.** Reglerna finns att läsa, men inga automatiska hjälprutor eller separat guidad övning ingår.
56. **Samma startförutsättningar utan hjälteval.** Inga hjältebonusar eller aktiva hjälteförmågor i prototypen. Direktplacering med musen gäller fortsatt.
57. **Preliminärt Silver, Malachite och Asteriated Ruby.** Roller enligt det offentliga kandidatunderlaget: slow, flera mål och områdesskada över tid. Slutliga recept och effekter kräver verifiering mot aktuell kartversion. Urvalet ersätter inte referensinventeringen.
58. **Förlagans balansvärden så långt det går.** Startliv, fiendeliv, belöningar, priser, sannolikheter och tornvärden ska utgå från förlagans verifierade värden. Anpassningar som krävs av tio vågor och tre kvalitetsnivåer ska dokumenteras. Förlagans fulla skademodell enligt beslut 40 gäller fortsatt.
59. **Projektinstruktioner och befintliga skills.** En kort AGENTS.md och projektets dokumentation ska stödja arbetet. Befintliga skills används vid konkreta behov. Ingen egen GemTD-skill från början; den kan skapas när ett återkommande arbetssätt motiverar det.
60. **Första spelbara prototypen testas lokalt av användaren.** Både webb- och Windows-versionen provas på användarens dator och justeras efter återkoppling. Delad eller offentlig testdistribution ingår inte i detta första teststeg.
61. **Rundans tornval görs sist och startar vågen direkt.** Rivning och kombinationer med bara tidigare behållna torn görs före slutvalet. Efter de fem placeringarna avslutas byggfasen när spelaren behåller en ny gem, genomför en kvalitetsuppgradering eller skapar ett specialtorn med någon ny gem. Övriga nya gems hanteras enligt reglerna för stenar och förbrukade material. Ingen extra bekräftelse eller efterföljande kombinationsfas ingår.

## Fortsatt arbete

Se [aktuell prototypplan](prototypplan.md) för omfattning, arbetsordning, kontrollfall och kvarstående verifiering. Se [referensinventeringen](referensinventering.md) för källor och deras begränsningar.

Det tidigare diskussionsunderlagets rekommendationer är ersatta av denna beslutslogg och prototypplanen. Loggen bevarar planeringsbesluten; aktuell implementations- och teststatus finns i prototypplanen och teststatus.md.

## Fortsatt återkoppling 2026-10-23

Användaren är mycket nöjd med den spelbara prototypen och har valt grafik som nästa steg: pixelstilen enligt referensbilden med inspiration från Dota-versionen. Grafiken ska vara lätt att ändra under hela utvecklingen. Det genomförs med en fristående bildkatalog, separata bildfiler/spriteark, per-kvalitetskopplingar, redigerbart UI-tema och en grafikförhandsvisning. Se [graphics.md](graphics.md).

Efter kvalitetsvarianter, procedurstyrd rörelse och stridseffekter bedömde användaren detta som en bra grund och bad att arbetet skulle fortsätta. Samma visuella riktning behålls. Fortsatt bygghjälp och bättre återkoppling genomförs inom befintliga regler; återkopplingen är inte ett nytt balans- eller innehållsbeslut.

Användaren bedömde även bygghjälpen positivt men visade att tornen låg för högt i rutorna. Alla tornbilder centreras därför visuellt i sina rutor med ett ändrat manifestankare. Samma logiska rutor, regler och storlekar behålls. Därefter fortsätter arbetet med tydligare återkoppling om vågutfall.

## Fortsatt beställning 2026-10-24

Användaren beställer fortsatt implementation utan fler rutinbekräftelser. När 1.0 är klar ska alla nivåer och tornkombinationer i Dota 2-versionen implementeras. Fortsättning ska schemaläggas när kapacitet åter finns om användningsgränsen nås. Detta utökar tidigare tiovågs-/trekvalitets-/trereceptsgräns; solospel, Godot, utbytbar grafik och separat innehållsdata kvarstår. 1.0 behålls som en separat lokal granskningsleverans.

## Genomförandebeställning 2026-10-24

Användaren godkänner rekommendationen: slutför hela kedjan från speltest av 1.0 och en 20-vågsetapp till 50 grundvågor, resterande tornkombinationer och prövningsvågorna 51–100. När detta är implementerat får arbetet fortsätta med utvärdering av mer levande grafik och bättre animationer. Inga nya rutinbekräftelser behövs. Den lokala 1.0-leveransen bevaras som jämförelse.

## Balansuppföljning 2026-10-24

Användaren godkänner balansundersökningens riktning och vill besvara frågor om skadeberäkning och hastighetstak. Frågorna tas en i taget med numrerade alternativ.

1. **Skadeberäkning: alternativ 1.** Följ Dota-versionens verifierade samspel mellan attacktyp, försvarstyp och rustning.
2. **Attackhastighet: alternativ 1.** Ett fast övre tak enligt Dota-förlagan. Ytterligare hastighetsbonus över taket ger ingen ytterligare attackfrekvens. Exakt tillämpning ska verifieras, inte antas utifrån en äldre klassmatris eller historiska etiketter.
3. **Träfftid: alternativ 1.** Skada och träffeffekter sker när projektilen når målet, med faktisk flygtid enligt originalets projektilvärden. Visuella skott ska följa simuleringens projektilpositioner.

Se [balansundersökningen](balance-research-campaign.md) för källor, den dokumenterade standardgränsen 700 total attackhastighet och kvarvarande kontroll i originalmatch.

4. **Referensverifiering: alternativ 2.** Användaren kan inte köra en jämförande Dota-match nu. Fortsätt med källkoden och dokumenterade Dota-regler; märk uttryckligen vad som inte är uppmätt i motorn.
5. **Geminköp: alternativ 1, bossrabatt.** Varje besegrad grundboss ger 150 rabatt på framtida manuella gemchansköp. Bossens guldbelöning och grundpriserna behålls. Oanvänd rabatt sparas till nästa köp. Gäller grundbossar 10–50, inte prövningsbossar. Underlag: [ekonomijämförelsen](progression-options.md). Implementerat i 1.2.2-dev.

## Fem undersökningar – genomförandemandat 2026-10-24

Senare användarbeställning: **fem tornflyttar per hel spelomgång**, även till stenrutor. I 1.4.1-dev flyttas behållna torn under vanlig byggfas. Tom destination lämnar ursprungsrutan tom; sten byter plats med tornet. Nyplaceringar får inte flyttas, giltig väg krävs, ogiltig/avbruten flytt kostar inget. Kvoten delas mellan torn och återställs inte vid nästa våg. Se [tornflyttar](tower-relocation.md). Trapflytt är fortsatt separat.

Användaren har därefter beställt alla fyra rekommendationerna i mekanikgranskningens svar. I 1.4.0-dev rättas läckserien/Emerald, slumpmässig nedgradering införs, prövningarna får inga nya byggomgångar och äldre tornrecept tillåts under strid. Detta utökar beslut 11/61 för kampanjens äldre tornrecept. Berserk och källbaserade alternativa vågor/bossar införs. Manuella oddsinköp/bossrabatt i grundomgången och omedelbar förlust vid bossläcka behålls. Se [genomförandet](mechanics-update-1.4.md).

Efterföljande användarbeslut: **nyskapade traps ska kunna flyttas samma runda**. Implementerat i 1.3.1-dev med innehållsversion 8: ett recept som förbrukar nya gems låser tornvalet och gör övriga nya gems till sten, men väntar med striden. Flytta trappen eller behåll platsen, välj sedan **Start wave**. Inga fler placeringar, rivningar eller kombinationer tillåts under placeringssteget. Recept med bara äldre material behåller vanligt byggflöde. Automatisk trapuppgradering och separat vågstart omfattas av tester och återspelning.

Användaren beställer samtliga fem rekommenderade steg i ordning: bossdiagnostik, rörelse/räckvidd, förmågesamverkan, sent spel/prestanda och grafikens läsbarhet. Codex får fatta rutin- och balansbeslut för ett roligt, balanserat spel; endast viktiga vägval ska stämmas av. Undersökningens beslut och begränsningar dokumenteras i investigation-five-steps.md. Ingen generell HP-/skadeändring införs utan ett konstaterat problem; konstaterad aura-tickskuld rättas och dess balanspåverkan redovisas.
