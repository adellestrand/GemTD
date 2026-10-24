# Geminköp – jämförelse och valt alternativ

Beräkning av när fyra oddsinköp blir överkomliga. Alla bossar antas besegrade. Spelaren köper direkt när pengarna räcker; gemchanserna används först i nästa byggfas. Inga strider eller mänskliga strategier simuleras. Greed, stöld, eliter och hjältebonusar ingår inte.

| Vanliga kills/våg | Originalets XP | Nuvarande priser | Lägre fasta priser | Bossrabatt |
| --- | --- | --- | --- | --- |
| 5 | 11/14/21/30 | 11/17/24/32 | 11/16/23/30 | 11/14/21/30 |
| 8 | 8/11/18/23 | 8/13/20/26 | 8/13/19/24 | 8/11/18/23 |
| 10 | 6/11/16/21 | 6/12/17/23 | 6/11/16/21 | 6/11/16/21 |
| 12 | 6/11/14/20 | 6/11/16/21 | 6/11/15/19 | 6/11/14/20 |
| 15 | 5/10/13/18 | 5/10/14/19 | 5/9/13/17 | 5/10/13/18 |

Siffrorna är byggfasernas vågnummer. De beskriver ekonomiska möjligheter, inte garanterade tornkvaliteter eller vinst.

**Alternativ A – bossrabatt (rekommenderat):** behåll grundpriserna 250/400/550/700 och originalets bossguld 150. Varje besegrad grundboss ger dessutom 150 i rabatt på kommande geminköp. Rabatten förbrukas vid köp; överskott sparas till nästa köp. Den kan inte användas till annat och ger ingen extra guldbelöning. Det behåller manuella köp och motsvarar originalets extra boss-XP i denna basmodell.

**Alternativ B – lägre fasta priser:** 250/350/500/550. Enklare att visa. Matchar originalets byggfaser i tiokillsfallet, men inte lika bra om antalet besegrade fiender ändras.

**Alternativ C – behåll nuvarande priser:** 250/400/550/700 tills fler mänskliga omgångar finns.

1000 varierande syntetiska killsekvenser kontrollerades: bossrabattens överkomlighet följer XP-trösklarna i samtliga fall under de angivna begränsningarna. Det bevisar bokföringen, inte spelbalansen. Greeds extra guld skulle fortfarande kunna påskynda manuella inköp, och guldstöld försena dem; originalets XP påverkas inte på samma sätt.

Användaren valde alternativ A: bossrabatt. Den är implementerad i kampanj 1.2.2-dev; jämförelsen ovan visar den tidigare ekonomin och alternativen. Maskinläsbart underlag: `reports/progression-options.json`.
