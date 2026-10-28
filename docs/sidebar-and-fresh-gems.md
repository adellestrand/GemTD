# Fast högerpanel och markering av nya gems

2026-10-28: användaren vill slippa scrolla högerpanelen och tydligt kunna skilja
rundans nya gems från tidigare torn, innan ett slutval görs.

Högerpanelen har nu fyra flikar: **Tower**, **Wave**, **Upgrades** och **Effects**.
Tornval, kombination, rivning och flytt ligger i ett fast block under flikarna.
Gemchansköp och alla tolv guldbesvärjelser finns under Upgrades. Tornkortets
**Effects & support** öppnar hela listan av påverkande effekter. När man granskar
Effects kan man klicka mellan torn utan att lämna den fliken.

Ingen ScrollContainer omger menyn. Om många recept är tillgängliga väljer man
recept i en väljare i stället för att alla receptknappar växer nedåt. Valet
visar fortfarande separata alternativ för äldre material och slutval med nya
gems, med samma förhandsvisning och modellregler. Långa effektlistor kan läsas
i sin egen textyta; de skjuter inte längre undan byggkontrollerna. Seed och
versionsraden hålls kompakta, med full text i verktygstips.

Alla nya gems får gulmarkerade hörn och nummer 1–5 på spelplanen. Samma nummer
visas på rundans fem bildknappar till vänster. Markeringarna ritas efter tornen
så att de syns även utan vald gem. De visas bara under byggfasen före slutvalet
och försvinner direkt vid Keep, uppgradering, downgrade eller recept som avslutar
valet. Äldre torn och trapplaceringsfasen får inga nya markeringar.

`game/presentation/fresh_gems.gd` läser färger/storlek från
`assets/graphics/fresh_gems.json`. Nummerbrickan stannar i sin egen cell vid zoom;
spritebilder, tornankare, balans, sparversion och RNG ändras inte.

Kontroller: `tests/check_sidebar.gd` provar flikarnas och kontrollernas geometri
vid 1280×720, 1360×900 och 1920×1080, högsta gemchansnivå, alla tolv spellknappar,
många recept, markeringarnas numrering och gränser samt oförändrat speltillstånd.
Testet ingår i `python tools/check.py`. Webbexporten har visuellt granskats med
fem riktiga placeringar och Upgrades-fliken i både 1360×900 och 1280×720.
