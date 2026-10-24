# Balansunderlag för GemTD Solo 1.0

Profil: **dota-solo-10w-v1**. Den granskade lokala Dota 2 GemTD-ögonblicksbilden är daterad **2026-08-01**. [Workshop-originalet](https://steamcommunity.com/sharedfiles/filedetails/?id=474619917) kontrollerades på nytt; sidans ändringsdatum bevisar inte att dess nuvarande filer matchar den lokala ögonblicksbilden. Vi gör därför inget påstående om exakt senaste Workshop-balans.

## Bevarade originalvärden

- Alla 24 grundtorn I–III och tre specialtorns skada, grundintervall och räckvidd.
- Slow, poison, armor-reduktion, attackhastighet, supportauror, splash och sekundära projektilers antal enligt det tidigare granskade underlaget.
- Valda fienders HP, rörelse, armor och magic resistance. Referensens solofaktor **0,69** används för HP/hastighet; räckvidd och hastighet omräknas med **128 världs-enheter per cell**.
- De första tre kvalitetsfördelningarna: **100/0/0**, **80/20/0**, **60/30/10**.
- 37×37-karta, 32 startstenar och sju kontrollpunkter.

`data/balance_baseline.json` bevarar numeriska referensfakta och filhashar, utan att distribuera Dota-kod eller bilder. `python tools/verify_balance.py` kontrollerar katalogen med **180 jämförelser** och kontrollerar även råfilernas hash om det lokala referensunderlaget finns installerat. Bevarad kontrollrapport: `docs/reports/balance-reference-v1.json`.

## Anpassningar till tio vågor

| Område | Granskat original | 1.0 och skäl |
| --- | --- | --- |
| Startliv | 100 | 30. En tiovågsomgång ska kunna förloras före bossen. |
| Startpengar | 0 | 0, oförändrat. |
| Vanlig kill, tidiga vågor | 5 i den granskade solo-/coop-koden | 2 i våg 1–5, 3 i våg 6–10. Ingår i den komprimerade ekonomin tillsammans med clear-belöningen. |
| Bosskill vid originalvåg 10 | 300 erfarenhet, därefter halverat till 150 gold i koden | 3 gold plus 32 för clear. Omgången avslutas här, ingen senare ekonomi behöver finansieras. |
| Clear-inkomst | Inte fastställd som motsvarande separat originalbonus | 12 + 2×våg, endast om spelaren överlever. Både kill- och clear-inkomst är beslutade för solovarianten. |
| Köp av kvalitetschanser | Direkta motsvarande priser ej verifierade | 20/45 gold; två köp räcker för de tre tillåtna kvaliteterna. |
| Vågor | Längre originalprogression | Tio kuraterade typer/antal med boss sist, originalens valda enhetsgrundvärden behållna. |
| Läckor | Originalets läckskada kan slumpas | Fasta 1–4 liv beroende på typ. Bossläcka avslutar direkt. |
| Luftmål | Exakt originalbegränsning ej fastställd | Diamond/Ruby väljer bara mark; övriga inkluderade torn väljer mark och luft. Tillfällig, dokumenterad uppdelning. |

Dessa anpassningar har **inte** buffats för att få en enkel bot att vinna. Tidigare innehållsvärden från 0.6 behålls i 1.0. En korrektionsändring bevarar däremot resttiden mellan fasta simuleringssteg: en aura med 0,25 s intervall ger nu 40 ticks under tio sekunder i stället för att varje tick avrundas uppåt. Torn under tomgång samlar ingen eldskuld.

## Naturliga provomgångar

20 omgångar med vanliga startvillkor, intjänad ekonomi och lagliga placeringar/kombinationer, seed 1–10 för vardera strategin:

| Strategi | Utfall |
| --- | --- |
| Greedy täckning av rutten | 0/10 vinster; två förluster på våg 9 och åtta vid bossen. |
| Greedy ruttförlängning och befintlig torntäckning | 1/10 vinster; nio förluster vid bossen. |

Maze-strategins **seed 8** vann med 30 liv. Dess fullständiga rapport och de andra nitton rapporterna kan spelas upp med samma slutresultat. Detta är lagligt spel från normal start, inte en förbyggd försvarsfixture. En seed ensam är ingen vinstgaranti: placeringar, köp och tornval måste också stämma.

Botarna planerar inte recept flera vågor framåt, river inte för omdirigering och väljer målprioritet förenklat. Resultaten är **inte** en uppskattning av mänsklig vinstchans. Bossen och våg 9 är fortsatt viktiga granskningspunkter. Råresultat och källhashar finns i `docs/reports/v1-playtest-results.json`; verifiering av alla rapporters återspelning finns i `docs/reports/replay-verification-v1.json`.

## Kvarstående Dota-skillnader

Full motorekvivalens är inte verifierad. MVP-bonusar/-auror, CombatClass, exakt aura-linger och caster-stapling samt simulerad projektilflygtid ingår inte fullt ut. Träffar appliceras direkt och får separata visuella skotteffekter. Slutlig svårighetsbedömning ska göras tillsammans med användarens riktiga speltest, inte döljas av versionsnumret.
