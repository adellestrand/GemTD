# Granska och spela GemTD Solo 1.0

## Start

**Windows:** packa upp hela leveransen och starta `Windows/GemTD.exe`. Behåll `GemTD.pck` bredvid exe-filen. Godot, Python och Dota behövs inte för Windows-spelet.

**Webb i leveransen:** kör `Web/Start-Web.cmd` eller `python Web/serve.py --open`. Det kräver Python och öppnar en lokal server på `http://127.0.0.1:8070/`. Stäng servern med Ctrl+C. Spelet går inte att starta genom att dubbelklicka på HTML-filen.

**Befintlig utvecklingsvy:** ladda om `http://127.0.0.1:8060/`. Sidfoten ska visa **1.0.0**. Om en gammal version ligger kvar, använd Ctrl+F5.

## Första speltestet

1. Välj **Run → Enter seed...** om du vill ha en reproducerbar start. Annars fortsätt den sparade byggfasen eller välj en ny omgång.
2. Placera fem gems, välj ett torn och granska Keep/Combine-förhandsvisningen innan klick. Slutvalet startar vågen direkt.
3. Prova zoom, panorering, markrutt och att riva gamla stenar/torn i byggfas. Markfiender måste alltid kunna nå alla checkpoints.
4. Använd **Recipes**, Locate och Track för att planera specialtorn. Gamla material kan kombineras utan att förbruka den nya rundans tornval.
5. Kontrollera luftförsvaret inför våg 5 och 8. **Waves** visar alla fiender och vilka av dina torn som kan välja deras måltyp.
6. Byt målprioritet, pausa, prova 1×/2× och justera ljud under strid. Vågprogression och bossliv ska stämma med det som händer.
7. Vid vinst/förlust: prova samma seed, ny omgång och **Run summary & test report**. Bossen måste dö; en bossläcka avslutar omgången direkt.
8. Ladda om under en byggfas och under strid. Återupptagning ska ske från byggfasens start, inte mitt i en strid eller efter redan gjorda placeringar.

Sparning är separat mellan Windows och webbadresser/webbläsare. Port 8060 och 8070 har därför separata webbsparningar. Det äldre interna Godot-projektnamnet behålls för att tidigare lokala byggsparpunkter ska fortsätta hittas.

## Återkoppling

Öppna **Run → Run summary / test report** och välj **Copy test report**. Om webbläsaren inte tillåter urklipp: öppna fliken **Report**, markera texten med Ctrl+A och kopiera med Ctrl+C. Spara texten som en `.json`-fil tillsammans med din återkoppling.

Ange gärna:

- Version, plattform och seed.
- Vilken våg och vilket val problemet gällde.
- Förväntat respektive faktiskt resultat.
- Hur labyrint, recept och luftförsvar kändes; särskilt våg 9 och bossen.
- Skärmbild om läsbarhet eller placering är problemet.

Rapporten innehåller versions-/balansprofil, startpunkt, accepterade handlingar och vågutfall. Den skickas inte automatiskt. En lokal kopia skrivs efter avklarad våg, slutläge eller öppnad rapport; sparfilen för själva omgången ändras inte av att läsa rapporten. Vid återupptagning beskriver rapporten den nya sessionen från dess byggsparpunkt.

## Tolka värdena

Attack-DPS är rå grundattack mot ett mål före försvar; gift, splash och extra mål är separata effekter. Auraskada visas separat. Antalet torn som kan välja luft/mark säger inget om deras räckviddstäckning. Dota-grundvärden behålls, men ekonomin, läckorna och vågföljden är anpassade till tio vågor. Se `balance-v1.md`.
