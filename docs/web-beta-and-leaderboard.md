# Webbtest och framtida leaderboard

## GitHub Pages

Repot är publikt enligt användarens val. Pages använder GitHub Actions och
adressen https://adellestrand.github.io/GemTD/ . Publicering körs uttryckligen
via **Actions → Publish web beta → Run workflow**, inte automatiskt vid varje push.

Flödet installerar den SHA-kontrollerade Godot-versionen, kör regressionstester,
exporterar webbversionen och förbereder ett separat publikt paket. Bara efter
lyckat bygge publicerar deploy-jobbet till Pages. Egna GitHub-hemligheter behövs
inte; deploy använder GitHubs kortlivade jobbtoken. Bygget kräver inte lokala
referenspaket eller bildgeneratorer.

`python tools/prepare_web_beta.py` kopierar en uttrycklig lista av exportfiler
från `builds/web` till `builds/pages`. Okända filer i målmapppen stoppar körningen.
Paketet innehåller `build.json` med commit, innehållsversion och kontrollsummor.
Den publika HTML-sidan väljer kampanjen när ingen profil anges; den lokala
tiovågsprofilens standardbeteende ändras inte. Exportbeskrivningen anger 100 vågor.
PWA/offline-cache är avstängd tills uppdateringsflödet testats separat.

För återställning: kör workflow från en tidigare godkänd kodversion där workflow
finns, exempelvis en releasegren/tagg. Arkiverat webbpaket finns som Actions-artifact
i 14 dagar. Publicera bara en vald testversion åt gången och behåll samma origin
för webbläsarens lokala sparning. Ett domänbyte överför inte automatiskt sparfiler.

Verifierat 2026-10-24: fyra paketeringstester, full regression i en ren GitHub-runner
och lyckad [första publicering](https://github.com/adellestrand/GemTD/actions/runs/40124814499).
Publika `build.json` motsvarar commit `0166e336a70cea15b189f56f11a159fb9fac2950`.
Chrome startar kampanj 1.4.1-dev från den publika adressen utan profilparameter;
fem placeringar och vågstart har testats med 0 konsolfel/varningar.

## Leaderboard – rekommenderad nästa etapp, ännu inte aktiverad

GitHub Pages serverar filer. En gemensam resultatlista behöver ett separat API
och datalager. Förslaget är **Supabase Postgres + en Edge Function**, med
anonym spelaridentitet och visningsnamn. Det gör konton frivilliga i första
betan, med möjlighet att koppla identiteten till ett konto senare.

- Klienten läser topplistan via begränsad läsåtkomst.
- Resultat skickas till ett API som validerar format, gränser och dubbletter;
  klienten får inte skriva eller ändra godtyckliga resultat direkt i databasen.
- Serverns privilegierade nyckel ligger bara på servern. Klientens offentliga
  nyckel är inte ett skydd för resultat; databasregler och serverkontroller behövs.
- Spara `run_id`, spelar-id, visningsnamn, seed, innehållshash, vågor avklarade,
  liv, simuleringstid, commit och verifieringsstatus.
- Sortera först på avklarade vågor och därefter kvarvarande liv. Simuleringstid
  kan bli en senare utslagsregel; 2× och paus ska inte ge någon tidsfördel.
- Separera listor efter balans/innehållshash. En senare daglig utmaning med samma
  seed och fasta vågvarianter ger mer jämförbara resultat än fria slumpomgångar.
- Spela vidare även om API:t är nere; resultatlistan får inte stoppa en lokal omgång.

Viktigt: formatkontroll, autentisering och rimlighetskontroll bevisar inte att en
webbläsaromgång är äkta. För kompisbetan kan resultat märkas **unverified** och
omgångsrapporten sparas. En verifierad tävlingslista kräver serveråterspelning med
rätt låst motor/innehåll och resursgränser, exempelvis i en separat Godot-worker.
Rapporter som börjar vid en obetrodd sparpunkt eller har trunkerade handlingar
kan inte verifieras fullt som en ny obruten omgång.

Supabase Free räcker storleksmässigt för en liten testgrupp, men projekt kan
pausas efter en veckas inaktivitet. Bekräfta därför kontots aktuella villkor innan
det väljs för permanent drift. Ingen databas, inloggning eller resultatsändning
har skapats i denna etapp.

Källor, kontrollerade 2026-10-24:

- [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Godot webbexport](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Supabase leaderboard/API](https://supabase.com/docs/guides/api/quickstart)
- [Anonym inloggning](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [Priser och inaktivitet](https://supabase.com/pricing)
