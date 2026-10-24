# Tornflyttar – 1.4.1-dev

Användarens beställning 2026-10-24: flytta torn till annan plats, även där det står en sten, fem gånger per omgång. Omgång tolkas som **hela spelomgången**, inte varje våg. Alla torn delar på fem flyttar. Detta är en beställd egen spelregel, inte ett påstående om Dota-originalet.

Under byggfasen, före det slutliga tornvalet:

1. Välj ett behållet torn och **Move tower · N / 5 left this run**.
2. Klicka på en tom ruta eller en sten.
3. Tornet flyttas. På tom ruta lämnas ursprungsrutan tom; vid en sten byter torn och sten plats.

Alla kontrollpunkters markväg måste vara öppen efter flytten. Checkpoints, traps, andra torn och nya gems är ogiltiga mål. Nya gems kan inte flyttas innan de valts. Flyttning är låst under strid, prövningsmellanrum och det avslutande trapplaceringssteget. Eftersom prövningarna 51–100 saknar byggomgångar används tornflyttarna senast i byggfasen inför våg 50.

Hovring visar giltig/ogiltig destination och förhandsvisad rutt. Escape, knappen **Cancel tower move** eller klick på ursprungstornet avbryter utan kostnad. Ogiltiga försök förbrukar inget. Trapflytt använder inte tornens kvot.

Tornets kvalitet, MVP, kopierade förmågor, slumpade grundattack, PRD-räknare och målprioritet bevaras. Flyttningen kostar inget guld, förbrukar ingen gemplacering och ändrar ingen RNG. Ingen ny typ eller förmåga rullas vid flytt. Kvoten återställs inte mellan vågor; ny spelomgång börjar med fem.

Innehållsversion **10** använder `run_campaign_v10.json`. Kvarvarande flyttar sparas tillsammans med brädet i byggfasens sparpunkt och ingår i oberoende rapportåterspelning. Som tidigare återgår omladdning till början av byggfasen: både flyttade torn och flyttkvot återställs till samma sparpunkt. Äldre sparfiler lämnas kvar och migreras inte till nya regler.

`tests/check_tower_moves.gd` täcker 47 fall: tomma rutor, stenbyten, metadata, blockerad rutt, femgränsen, ogiltiga tillstånd, avbrytning, nya vågor, omstart, sparvalidering och återspelning. Testet ingår i `python tools/check.py`.

Slutverifiering: 897 GDScript-kontroller och 5 257 referenskontroller godkända, utan motorfel eller motorvarningar. Windows/Web återexporterade; Windows-rendering och attackljud verifierade. I en separat renderad Chrome-fixture klickades tornflytt och byte med sten: Diamond III flyttades, stenen hamnade på ursprungsrutan och räknaren gick 5 → 4 utan ny gemplacering. Ordinarie webbexport startades som 1.4.1-dev. Browserkonsolen var fri från fel och varningar. Fixturen var konstruerad och mäter inte spelbalans.

```powershell
python tools/godot.py --headless --path . --script res://tests/check_tower_moves.gd -- --campaign --smoke
python tools/check.py
powershell -ExecutionPolicy Bypass -File tools/export.ps1 -Release
python tools/smoke_windows.py --campaign --attack
```
