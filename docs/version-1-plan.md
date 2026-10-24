# Version 1.0 – lokal granskningsversion

Beställd av användaren 2026-10-23: genomför hela vägen till version 1, granska och speltesta därefter, med Dota 2 GemTD som balansreferens.

Levererad lokalt 2026-10-24. Den efterföljande beställningen om allt originalinnehåll följs i full-content-plan.md; den äldre avgränsningen nedan gäller det bevarade 1.0-paketet.

Leveransen är den beslutade solovarianten: en karta, åtta grundtyper I–III, tre specialrecept och tio fasta vågor. Fler kartor, multiplayer, hjältar och ytterligare kvaliteter ingår inte. 1.0 betyder en sammanhängande lokal granskningsversion; exakt Dota-motorparitet och mänskligt slutbalanstest ska inte påstås utan bevis.

## Leveranskriterier

- Numeriska torn-/fiendegrundvärden, effekter och kvalitetschanser låses mot den granskade Dota-ögonblicksbilden. Verifierare och en separat balansrapport skiljer fakta från tiovågsanpassningar. Inga godtyckliga tornbuffar för att få en enkel bot att vinna.
- Fasta simuleringssteg bevarar attack-/auraintervallens resttid, utan att skapa uppsamlad eld efter tomgång. Verkliga stridsförlopp och numeriska gränsfall testas.
- Pågående våg får tydlig framdrift och bossliv. Slutläge ger begripliga resultat, samma/ny seed, återupptagning av byggsparpunkt och tillgång till en lokal speltestrapport.
- Versionsmärkt rapport innehåller startpunkt, accepterade handlingar och vågutfall så att användarens senare tester kan analyseras. Rapporten skickas inte någonstans automatiskt.
- Manuellt seedval och tydlig uppgift om vilken version/balansprofil som körs.
- Naturliga omgångar körs separat från starka regressionsfixturer. Strategins begränsningar och även förluster redovisas.
- Windows och webb byggs, renderas och provas med riktig inmatning. Inga motor-/konsolfel i slutkontrollen.
- Lokal leveransmapp/arkiv med startinstruktioner, testguide, kända avvikelser och SHA-256. Ingen publik uppladdning eller automatisk Git-push.

## Referensgräns

Det lokala paketet anger 2026-08-01. Workshop-sidan kontrollerades på nytt, men bevisar inte att dess nuvarande innehåll är identiskt med de lokalt granskade filerna. Se referensinventering.md. MVP, CombatClass, aura-linger och projektilflygtid förblir uttryckliga kompatibilitetsbegränsningar tills de kan verifieras; de ska inte döljas genom versionsnumret.
