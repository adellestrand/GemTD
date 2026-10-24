# GemTD

Fristående solospel med Dota 2-versionen av GemTD som förlaga. Användaren beskriver och testar; Codex skriver koden. Implementation och lokala tester är beställda. Läs även `docs/development.md` för körkommandon och verifieringsstatus.

## Läs före arbete

- `docs/campaign-review.md`: aktuell 100-vågskampanj, källbaserad progression, verifiering och uttryckliga motoravvikelser. `docs/graphics-review-campaign.md` beskriver efterföljande grafikarbete.

- `docs/prototyp-beslutsunderlag.md`: bekräftade val i interaktiv ordning.
- `docs/prototypplan.md`: aktuell omfattning, arbetsordning och kvarstående preciseringar.
- `docs/referensinventering.md`: källor och vad som ännu inte är verifierat.

## Projektramar

- Godot och GDScript; gemensamt projekt för webb och Windows. Tidigt exporttest på båda målen.
- 2D med pixelgrafik. Tillfälliga bilder först; stilreferens i `docs/referenser/pixelgrafik.png`.
- Engelsk speltext; svensk planering och dokumentation.
- Grafik ska gå att ändra löpande. Använd `assets/graphics/manifest.json`, separata PNG-filer/spriteark och `ui_theme.tres`; koppla inte bildval till spelregler. Läs `docs/graphics.md`. Spara nya bildförslag med versionsnamn.
- Respektera användarens bekräftade val framför äldre rekommendationer och generiska TD-konventioner.
- Verifiera aktuell kartlayout, grundtyper, recept och full skademodell. Märk antaganden och källversioner. Andra GemTD-versioner är inte automatiskt korrekta referenser.
- Utgå från förlagans verifierade balansvärden och dokumentera nödvändiga avvikelser.
- Befintliga skills används vid behov. En egen GemTD-skill är inte vald från början.

## Genomförande och kontroll

- Följ aktuell användarbegäran och projektfas. En planeringsuppgift innebär inte att motorinstallation eller spelimplementation är beställd.
- Håll spelregler separerade från presentation och lägg innehåll i tydliga datadefinitioner.
- Kontrollerad slump, reproducerbara scenarier och versionsmärkt lokal sparning ska stödja testerna.
- Dokumentera faktiska kör- och testkommandon i README när ett körbart projekt finns. Hitta inte på kommandon eller testresultat.
- Kontrollera meningsfulla regelgränsfall och relevanta exportmål när kod ändras. För rena dokumentändringar räcker relevanta dokumentkontroller.
- Uppdatera beslutslogg och plan när användaren ändrar riktning. Skilj genomförda kontroller från planerade.
