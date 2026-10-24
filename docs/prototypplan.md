# GemTD – aktuell prototypplan

Aktuell uppföljning: **1.4.1-dev**, innehållsversion **10**, med [fem tornflyttar per hel omgång](tower-relocation.md). Tidigare leveransbeskrivningar nedan bevaras.

Senaste uppföljning: **1.4.0-dev**, innehållsversion **9**. De fyra beställda mekanikstegen är implementerade; se [nya regler och verifiering](mechanics-update-1.4.md). Särskilt gäller inga nya gems efter våg 50 och äldre tornkombinationer under strid. Historiska leveransbeskrivningar nedan bevaras.

Uppföljning 2026-10-24, 1.3.1-dev: traprecept med nya gems får ett placeringssteg före striden. Tornvalet förbrukas när receptet skapas; spelaren flyttar trappen och väljer sedan **Start wave**. Innehållsversion 8 separerar de ändrade reglernas sparning från äldre utgåvor. Gamla-material-recept fortsätter fungera under vanlig byggfas.

Datum: 2026-10-23. Underlag: användarens 61 interaktiva beslut i [beslutsloggen](prototyp-beslutsunderlag.md).

**Senaste leverans 2026-10-24:** kampanj 1.3.0-dev innehåller 50 grundvågor och prövningar 51–100, sex gemkvaliteter, 59 receptalternativ och 24 stentavlor. Implementation och automatiserade kontroller för de fem beställda stegen är genomförda. Mänskligt referensspeltest och slutbalansering återstår; en automatisk genomgång ersätter inte dessa. Se [kampanjgranskningen](campaign-review.md) och [grafikgranskningen](graphics-review-campaign.md). Den äldre planen nedan beskriver tiovågsprototypen.

Status 2026-10-24: version 1.0.0 är paketerad för lokal granskning i Windows och webb. Se [testguide](testguide-v1.md), [balansunderlag](balance-v1.md) och [teststatus](teststatus.md). Användaren har därefter beställt alla Dota 2-förlagans nivåer och tornkombinationer. Den äldre tiovågsavgränsningen nedan beskriver 1.0, inte taket för fortsatt arbete. Originalpaketet är daterat 2026-08-01; full effektparitet och mänsklig balansgranskning återstår.

## Mål och omfattning

En fristående solovariant nära Dota 2-versionens kärna, med en karta, tio fasta vågor och en avslutande boss. Kartlayout och full skademodell ska utgå från den aktuella Dota 2-förlagan. Vågföljden är egen och utformas för prototypens innehåll.

| Område | Vald riktning |
| --- | --- |
| Teknik | Godot och GDScript, ett gemensamt projekt för webb och Windows. Båda exportmålen provas tidigt. |
| Arbetsfördelning | Användaren beskriver och testar. Codex skriver kod och tar fram genomförandet inom beslutade ramar. |
| Grafik | 2D med pixelgrafik, spelplan ovanifrån och byggnadssprites med synligt tak och framsida. Enkla tillfälliga bilder först. |
| Gems | Alla grundtyper från förlagan, tre kvalitetsnivåer och tre specialrecept. |
| Specialtorn | Silver, Malachite och Asteriated Ruby; material och effektvärden verifierade i det lokala paketet och implementerade. |
| Strid | Mark och luft, valbar målprioritet per torn, förlagans fulla skademodell. |
| Progression | Köpta förbättringar av gemchanser; resurser från besegrade fiender och avklarade vågor. Samma startförutsättningar utan hjälteval. |
| Styrning | Direktplacering med musen, fast kameravinkel med zoom och panorering. |
| Gränssnitt | Engelsk speltext, öppen receptbok, frivillig hjälpsida, tydliga mark- och flygrutter. |
| Ljud | Grundläggande effekter med volym och mute. |
| Tid | Normal hastighet, dubbel hastighet och paus. |
| Sparning | Automatisk lokal sparning vid början av varje byggfas, separat för webb och Windows. |
| Omstart | Från våg ett, med samma startvärde för slumpen eller med ny slump. |
| Första test | Användaren provar båda versionerna lokalt. |

Visuell referens: [pixelgrafik.png](referenser/pixelgrafik.png). Den sparade bilden är stilunderlag.

Efter positiv återkoppling på den spelbara prototypen har användaren prioriterat grafik, med Dota-inspiration och enkel löpande utbytbarhet. Grafiklagret innehåller nu 44 bilder i tre ark, egna utseenden för alla åtta gemtypers I–III, separata kopplingar per gemkvalitet, ett fristående UI-tema och en grafikförhandsvisning med porträtt och spelstorlek. Konfigurerbara skott-/träff-/områdeseffekter och procedurstyrd fienderörelse är inkopplade, inklusive levande förhandsvisning. Se [grafikflödet](graphics.md). Individuellt tecknade gång-/vingrutor och fortsatt stilbedömning återstår.

En utforskande provkörning av 20 naturliga omgångar med enkel automatisk strategi har genomförts utan förbyggt försvar eller extra ekonomi. Resultat och begränsningar finns i [speltestrapporten](playtest-report.md). Den ersätter inte användarens labyrint-/balanstest och har inte lett till ändrade balansvärden.

Efter godkänd visuell grund finns även skrivskyddad bygghjälp: fem valknappar för avslöjade gems, placerings-/ruttförhandsvisning, låsorsaker och markering av kombinationsmaterial/resultat/stenar. Direkta slutval enligt beslut 61 gäller fortsatt. Omgångens seed visas i sidfoten för speltest och återkoppling.

Användarens lägeskorrigering är genomförd: tornbildernas centrum förankras nu i rutans centrum, inklusive alla kvaliteter och specialtorn. Därefter har en vågsammanfattning lagts till med besegrade fiender, läckor och livförlust för just den senaste vågen. Sammanfattningen är presentationsdata för pågående session och ändrar inte sparformat eller balans.

Receptboken har därefter fått visuella kort, exakta lagerantal/kvaliteter, kamerafokus till ägda ingredienser och möjlighet att fästa ett recept med löpande markeringar på spelplanen. Dessa planeringsval är skrivskyddade och använder samma regelmodell som tidigare. Receptboken pausar striden och återställer tidigare pausläge när den stängs.

Torninformationen visar nu aktuell attackhastighet med stöd på spelplanen, vald kvalitets effekt och rå grundattack-DPS. Auraskada visas separat. Byggvalens verktygstips jämför resultatet med valt torn och räknar med att oanvända nya gems och förbrukade material blir stenar. Attackintervallets beräkning delas med stridssimuleringen; inga balansvärden eller regler har ändrats.

Vågöversikten visar hela den fasta tiovågsföljden, fiendeporträtt, rörelsesätt, värden och läck-/belöningsregler. Den skiljer nästa/pågående/avklarad våg från inspekterad framtida våg, visar träffskada efter grundförsvar och räknar behållna respektive nya torn som kan välja rätt måltyp. Översikten pausar på samma sätt som receptboken och ändrar inga spelval, innehållsdata eller sparformat.

## Beslutade byggregler

- Byggfas och strid är separata. Placering, rivning och kombinationer sker mellan vågorna.
- Fem gems placeras per byggfas. Typ och kvalitet avslöjas efter placering; placeringen är bindande.
- En vanlig runda ger ett behållet torn. Övriga nya gems blir stenar.
- Stenar och behållna torn kan rivas gratis och obegränsat i byggfasen. Ett rivet torn ger inget tillbaka.
- En placering som blockerar någon etapp genom kontrollpunkterna nekas innan slump används eller gem förbrukas.
- Markfiender går i åtta riktningar. Diagonal passage kräver att båda angränsande sidorutorna är fria.
- Flygande fiender flyger rakt mellan samma kontrollpunkter i samma ordning, över hinder.
- Mark- och flygrutter visas under byggfasen och kan visas eller döljas under strid.

## Beslutade kombinationsregler

- Kvalitetsuppgraderingar använder bara den aktuella byggfasens gems. Samma typ och kvalitet krävs.
- Två lika gems ger ett kvalitetssteg; fyra ger två steg. Resultat över nivå tre tillåts inte.
- Uppgraderingen räknas som rundans enda behållna torn.
- Specialrecept får använda både nya gems och tidigare behållna torn. Stenar är inte material.
- Används någon ny gem i ett specialrecept räknas resultatet som rundans behållna torn. Recept med bara tidigare behållna torn förbrukar inte rundans nya tornval.
- Resultatet placeras på en av materialens positioner som spelaren väljer. Övriga materialpositioner blir stenar.
- Material får stå var som helst på kartan; inget närhetskrav gäller.

## Byggfasens avslut – beslut 61

1. Byggfasen börjar med en lokal sparpunkt. Spelaren har obegränsad planeringstid.
2. Spelaren genomför fem bindande gemplaceringar. Rivning och kombinationer med bara tidigare behållna torn kan göras före slutvalet. Köp av gemchanser kan göras enligt beslut 36 och påverkar bara kommande placeringar.
3. När de fem gems är placerade väljer spelaren sitt slutliga torn: behåll en ny gem, gör en kvalitetsuppgradering eller skapa ett specialtorn där någon ny gem används.
4. Valet genomförs atomärt: rätt material förbrukas, resultatet behålls och kvarvarande nya gems samt förbrukade materialpositioner blir stenar enligt beslut 16 och 26.
5. Vågen startar direkt. Det finns ingen separat startknapp, extra bekräftelse eller kombinationsfas efter slutvalet. Tornens målprioritet och köp av gemchanser kan fortsatt ändras under strid; spelplanen är låst.

Det är därmed inte den femte placeringen i sig som startar vågen. Kombinationer med enbart äldre torn förbrukar inte rundans nya tornval och avslutar inte byggfasen.

## Ekonomi och avslut

Gemchanser kan uppgraderas när som helst, även under strid. Ändringen påverkar bara framtida gemplaceringar. Fiender som släpps igenom ger ingen fiendebelöning. Avklarad våg ger grundinkomst om spelaren har liv kvar.

Genomsläppta fiender försvinner vid slutmålet och kostar liv beroende på fiendetyp. Livkostnaden visas i våginformationen. För vinst krävs att bossen besegras och att våg tio avslutas med liv kvar. Bossen vid slutmålet innebär förlust även om liv återstår.

Förlagans balansvärden ska användas så långt det går. Varje nödvändig anpassning till tio vågor och tre kvalitetsnivåer dokumenteras med ursprungsvärde, nytt värde och skäl. Siffror från obestyrkta källor ska inte presenteras som aktuella originalvärden.

## Genomförande i beroendeordning

| Steg | Leverans | Kontroll för att gå vidare |
| --- | --- | --- |
| 1. Referensinventering och regelspecifikation | Versionsmärkt kartunderlag, grundtyper, recept, skademodell, balansunderlag och exakt fasordning. | Verifierade fakta skiljs från valda avvikelser och öppna frågor. Se referensinventering.md. |
| 2. Litet exporttest | Ett minimalt Godot-projekt med tillfällig grafik och lokal körning i webb och Windows. | Kontrollera rendering, musinmatning, enkel ljudsignal och lokal sparning på båda målen innan större implementation. |
| 3. Spelplan och byggfas | Karta, kontrollpunkter, placering, rivning, markväg och flygrutt. | Alla etapper förblir nåbara. Ogiltiga placeringar avslås utan slumpförbrukning. Diagonaler fungerar enligt beslut 20. |
| 4. En komplett runda | Fem gems, tornval, automatisk vågstart, strid, läckor och nästa byggfas. | En korrekt övergång genom samtliga faser, inklusive sparpunkt. |
| 5. Kombinationer och full strid | Tre kvaliteter, valda recept, verifierade effekter, ekonomi, mark/luft och målprioriteter. | Rätt material förbrukas exakt en gång. Gamla respektive nya gems och rundans tornval hanteras konsekvent. |
| 6. Tio vågor och speltest | Boss, vinst/förlust, omstart, sparning, receptbok, hjälp, kamera, ljud och 1×/2×/paus. | Hela omgången kan spelas lokalt på båda målen. Återkoppling från användaren dokumenteras. |
| 7. Visuell bearbetning | Pixelgrafik enligt referensen. | Läsbarhet för typ, kvalitet, material, fiender och effekter även vid zoom och strid. |

Exporttestet kan förberedas parallellt med faktainsamling när implementation efterfrågas; det innebär inte att obekräftade spelregler har fastställts.

## Tekniskt genomförandeförslag

Följande är arbetsförslag inom det valda teknikpaketet, inte ytterligare bekräftade produktval:

- Typad GDScript och separata moduler för speltillstånd, innehåll, vägval, strid och presentation.
- Datadefinitioner för grundtyper, kvaliteter, recept, effekter och vågor, med validerade referenser.
- Fasta simuleringssteg och en kontrollerad slumpgenerator. Återskapande kräver samma startvärde, handlingar, innehållsversion och ordning; bara samma startvärde räcker inte.
- Versionsmärkt lokal sparning av byggfasens starttillstånd och slumptillstånd. Webbens beständighet och återladdning provas i exporttestet.
- Meningsfulla regeltester, scenarier utan grafik där det passar och korta manuella kontroller i båda exporterna.
- Felsökningsverktyg för rutter, fas, räckvidd, gemchanser och reproducerbara scenarier.
- Motorversion, exportinställningar och körkommandon väljs och dokumenteras vid exporttestet. Inga exakta prestandalöften är fastställda.

## Projektstöd och avgränsning

En kort AGENTS.md och dessa dokument ger projektkontext. Befintliga skills används vid behov: visualisering för skisser, imagegen för senare bildproduktion och spreadsheets för balansarbete. En egen GemTD-skill kan bli aktuell när ett arbetsflöde har visat sig återkomma.

Första leveransen ska gå att testa lokalt. Någon publik testdistribution är inte beställd i detta steg. Fler kartor, fler specialrecept, fler kvalitetsnivåer, hjältesystem och ytterligare plattformar hör till senare omfattningsbeslut.

## Källor

- [Beslutslogg](prototyp-beslutsunderlag.md): användarens val, inklusive skillnader mot tidigare rekommendationer.
- [Referensinventering](referensinventering.md): spelkällor, preliminära recept och osäkerheter.
- [Godot: webbexport](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) och [Windows-export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html): tekniska exportförutsättningar, inte bevis för att vårt projekt har testats.
