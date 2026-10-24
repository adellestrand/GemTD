# Gemensam topplista

Supabase-projektet **GemTD Solo** ligger på gratisnivån i Stockholm (`eu-north-1`).
Databasen och `submit-run` är driftsatta. Anonym inloggning är aktiverad.
Webbklienten ansluts via `assets/online/leaderboard.json`; bara projektets publika
URL och publishable key finns där. Ingen privilegierad nyckel ska finnas i Git,
spelet, en rapport eller en klientlogg.

## Så används den

Öppna **Run → Leaderboard**, eller **Run summary → Leaderboard & submit result**.
Listan går att läsa utan att skapa spelaridentitet. Efter en avslutad omgång
väljer spelaren ett visningsnamn och klickar **Submit this run**. Resultat skickas
aldrig automatiskt. Namnet och omgångsrapporten lagras på servern; bara namn,
avklarade vågor, liv, verifieringsstatus och tidpunkt visas offentligt.

Listan sorteras på avklarade vågor, därefter kvarvarande liv. Den våg där spelaren
förlorar räknas inte som avklarad. Vid lika resultat kommer det tidigare resultatet
först. Varje anonym spelaridentitet får en plats per innehållshash: dess bästa
resultat. Samma omgång kan skickas igen efter nätverksfel utan dubbletter eller
överskrivning av det första resultatet.

Endast nya kampanjomgångar i releasebyggen får skickas. Återupptagna sparpunkter,
pågående omgångar, andra profiler och trunkerade handlingsjournaler nekas.
Listorna skiljs åt med SHA-256 för katalog + kampanj, med normaliserade LF-radbrytningar
så att Windows, webb och CI använder samma identitet. Inga balansvärden ändras av
integrationen. Vid ändrat innehåll behöver den nya, granskade hashen uttryckligen
läggas till i `leaderboard_releases`; okända klienthashar godkänns inte automatiskt.

Anonym spelaridentitet sparas lokalt med uppdateringsbar Auth-session. Den gäller
bara aktuellt Supabase-projekt och skickas aldrig i omgångsrapporter. Annan enhet
eller rensad webbläsarlagring ger en ny identitet. Namn är inte unika eller reserverade.
Att senare koppla ett riktigt konto till samma identitet är en separat funktion.

## Säkerhet och drift

- Klienten får bara läsa den begränsade funktionen `leaderboard_top`. Tabellerna
  saknar klientbehörighet och har RLS med avsiktlig deny-by-default, utan policies.
- Edge Function verifierar användarens JWT mot Auth, härleder spelar-id från
  svaret och validerar profil, release, namn, våghistorik, seed och storlek.
- `verify_jwt=false` på Edge-gatewayen är avsiktligt: funktionen gör egen
  Auth-verifiering. Saknad eller felaktig spelar-JWT ger 401 före databasåtkomst.
- Endast serverrollen får anropa skrivfunktionen. Upprepade run-id:n är idempotenta;
  tio nya resultat per spelare och timme tillåts, kontrollerat under transaktionslås.
- CORS för skrivning tillåter `https://adellestrand.github.io`. Lokala/native HTTP-klienter
  är inte skyddade av CORS; autentisering och databasregler gäller även där.
- Rapporter begränsas till 1 MiB. HTTP-anrop i spelet har 15 sekunders timeout.
  Tjänstfel stoppar inte lokal spelning och ger ingen automatisk sändningskö.
- Resultaten är **unverified**. Auth och formatkontroll bevisar inte spelad omgång;
  manipulerade klienter kan fortfarande fuska. Serveråterspelning återstår.
- Gratisprojekt kan pausas vid inaktivitet. Behåll pausad tjänst som ett hanterat
  fel i spelet. Aktuella gränser/villkor kontrolleras före större spridning.
- Före öppen marknadsföring: inför CAPTCHA för anonym signup, starkare skydd mot
  flera identiteter samt rutin för moderering/radering och lagringstid för rapporter.
  Timgränsen per spelare hindrar inte skapande av fler anonyma spelare.

Supabases rådgivare: inga prestandafynd. Informationsfynd om RLS utan policies är
avsiktliga för privata tabeller. Varningarna för publik `SECURITY DEFINER` gäller
den avsiktligt publika, läsande topplistefunktionen; den har låst sökväg, inga
dynamiska SQL-strängar, högst 100 rader och en fast projektion utan rårapport/id.
Se [rådgivarens förklaring](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).

## Återskapa och verifiera

1. Skapa ett Supabase-projekt och aktivera anonyma sign-ins i Authentication →
   Sign In / Providers. Bevara övriga providerinställningar.
2. Applicera `supabase/migrations/202610240001_leaderboard.sql` med migrationsverktyget.
   Kör därefter granskade DML-filer i `supabase/releases/` för senare publicerade hashvärden.
3. Driftsätt `supabase/functions/submit-run/index.ts` tillsammans med `handler.mjs`
   och `validation.mjs`. Funktionen använder serverns automatiska Supabase-hemligheter.
   `LEADERBOARD_ORIGINS` kan ange andra tillåtna origins, kommaseparerat.
4. Ange URL + **publishable** key i klientkonfigurationen och `enabled:true`.
   `enabled:false` stänger av nätfunktionen utan att påverka spelet.
5. Kör testerna, exportera och publicera den granskade webbversionen via Pages-workflow.

```powershell
python tools/check.py
node --test supabase/functions/submit-run/submit-run.test.mjs
python tools/test_prepare_web_beta.py
python tools/check_leaderboard_live.py
```

`tests/leaderboard_database.sql` körs administrativt mot en migrerad testdatabas:
sortering, bästa resultat, idempotens, identitetskonflikt, timgräns och SQL-behörigheter
kontrolleras i en transaktion som rullas tillbaka. Node-testerna kräver Node 22+;
spelet självt har inget Node-beroende.

Verifierat 2026-10-24: full regression i isolerad källkopia, 18 Godot-kontroller för
klient/modal, 21 Node-kontroller, fem paketeringstester, databastransaktion samt
live läsning, anonym signup och dubbelt inskick av disponibel API-fixtur.
Fixturen använde en naturlig debugrapport med releaseflaggan ändrad för att prova API:t;
det är inte ett äkthetsbevis för en spelad releaseomgång. Testspelare/resultat togs bort.
Webbexporten läser listan från Supabase i Chrome utan konsolfel. Windows-exportens
grafik och ljud har också startkontrollerats.

Källor: [anonyma identiteter](https://supabase.com/docs/guides/auth/auth-anonymous),
[Edge-autentisering](https://supabase.com/docs/guides/functions/auth),
[serverhemligheter](https://supabase.com/docs/guides/functions/secrets),
[prisvillkor](https://supabase.com/pricing).
