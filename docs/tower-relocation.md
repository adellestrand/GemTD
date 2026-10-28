# Tornflyttar – fem gratis, därefter 100 guld

Användarens godkända ändring 2026-10-28: de första fem tornflyttarna är gratis
per **hel spelomgång**, gemensamt för alla torn. Varje ytterligare lyckad flytt
kostar **100 guld**. Priset är fast och det finns ingen extra antalsgräns.
Detta är en egen spelregel, inte ett påstående om Dota-originalet.

Under vanlig byggfas, före slutvalet:

1. Välj ett behållet torn. Knappen visar kvarvarande gratis flyttar eller 100g.
2. Välj Move tower och klicka på en tom ruta eller en sten.
3. På en tom ruta lämnas ursprungsrutan tom; vid en sten byter torn och sten plats.

Checkpoints, traps, andra torn och nya gems är ogiltiga mål. Alla kontrollpunkters
markväg måste förbli öppen. Nya gems kan inte flyttas före slutvalet. Strid,
prövningsmellanrum och det avslutande trapplaceringssteget tillåter inte flyttar.
Prövningarna 51–100 saknar byggfas, så sista möjligheten är inför våg 50.

Guld dras först när flytten är fullständigt validerad och genomförs. Otillräckligt
saldo, blockerad väg, ogiltiga mål, Escape, Cancel move och klick på källrutan
kostar inget. Förhandsvisningen visar priset utan att ändra tillståndet och
uppdateras om saldo eller gratisräknare ändras. Köp med 100 guld kvar lämnar 0.

Tornets kvalitet, MVP, kopierade förmågor, slumpade grundattack, PRD-räknare och
målprioritet bevaras. Gemplaceringar och RNG påverkas inte. Gratisräknaren stannar
på noll under betalda flyttar och återställs inte mellan vågor. Ny omgång börjar
med fem. Trapflytt använder varken gratisräknaren eller denna guldavgift.

Innehållsversion **13** sparar i `run_campaign_v13.json`. Återladdning återgår som
vanligt till byggfasens sparpunkt med samma bräde, guld och gratisräknare. Äldre
sparfiler lämnas kvar och migreras inte. En ny innehållshash håller topplistorna
för de ändrade reglerna separerade från äldre omgångar.

Rapporter innehåller varje accepterad flytts faktiska kostnad (0 eller 100).
Oberoende återspelning räknar om priset och verifierar både kostnad, slutguld,
bräde och gratisräknare. En förfalskad kostnad nekas.

`tests/check_tower_moves.gd` provar 63 fall inklusive femgräns, betald fortsättning,
exakt/otillräckligt saldo, stenbyte, blockerad väg, avbrytning, cache, sparning,
UI och återspelning. En riktig Godot-rendering kontrollerar även 100g-knappen.
Testet ingår i `python tools/check.py`.

```powershell
python tools/godot.py --headless --path . --script res://tests/check_tower_moves.gd -- --campaign --smoke
```
