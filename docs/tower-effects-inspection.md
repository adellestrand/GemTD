# Effekter på valt torn

När ett torn väljs visar sidopanelen **AFFECTING THIS TOWER**. Listan kan rullas
och visar egen MVP-nivå, MVP-auror, mottagna stödauror, medfödda statbonusar,
tillfälliga bonusar och avväpning. Aurakällor namnges med kartposition (1-baserad
kolumn/rad). Tillfälliga effekter visar återstående simuleringstid; paus fryser den.
Uppdatering sker med den befintliga UI-takten på 0,2 sekunder. Rullpositionen
bevaras när nedräkningen ändras; val av ett annat torn börjar högst upp.

`game/presentation/tower_effects.gd` läser tillstånd utan att ändra det. Identiska
icke-staplande auror listas en gång per effekt-id enligt modellens ersättningsordning.
Olika effekter från samma torn visas separat. MVP visar varje närliggande källa
och den effektiva totalsumman efter +500%-taket. Det valda tornets egna utgående
förmågor finns kvar ovanför listan, med full beskrivning som verktygstips.

Byggfasen visar aktuell uppställnings bonusar; strid visar även levande tillfälliga
buffar och attackbegränsningar. Stenar/tomma rutor visar ingen gammal effektlista.
Trap-buffar saknar källposition i det befintliga stridstillståndet och visas därför
som **Temporary**, utan påhittat källtorn. Ingen balans eller sparning ändras.

Verifierat 2026-10-24: hela `python tools/check.py` passerar, inklusive
`tests/check_tower_effects.gd` med 12 kontroller för egen/närliggande MVP,
stapling, räckvidd, källposition, tillfällig tid, avväpning, skrivskydd, faktiskt
tornval och rensning. Windows-rendering granskad i
`output/tower-effects-native/frame00000029.png`. Windows/Web exporterade;
Windows release startad med verifierad rendering och attackljud.
