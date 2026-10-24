# Kvalitetspass: skadevisning, skadeauror och MVP

2026-10-24. Beställda punkter 1–3 från granskningen är genomförda. Ändringarna
gäller presentation; inga balansvärden, stridsregler eller sparformat ändras.

## Skada och DPS

`GemTowerInfo.profile` räknar nu in mottagen `outgoing_percent` före MVP, med samma
avrundningsordning som striden. Utan MVP behålls bråkdelar av skada. Under strid
läser panelen tornets cachelagrade stöd, MVP och attackintervall samt aktiva
tillfälliga skadebonusar. Utgångna buffar läses bort utan att rensas ur modellen.
Förhandsvisningar av byggval räknas fortfarande på den tänkta uppställningen.

Siffrorna visar vanliga primärträffar före fiendens försvar; kritiska träffar,
multiskott och splash ingår fortsatt inte i attack-DPS. Avväpning visas separat
i effektlistan: DPS-siffran är teoretisk medan tornet tillåts skjuta.

## Skadeauror

Asteriated Ruby, Volcano och Burning Stone visar **MAGIC**, **TICK**, **AURA DPS**
och **AURA RADIUS**. Siffrorna hämtas från de riktiga `enemy_aura`-definitionerna,
inklusive eventuellt kopierade förmågor. Attackhastighet, attackräckviddsbonus och
vanlig utgående attackbonus förändrar inte aurans tick, radie eller skada.
MVP förstärker däremot auraskada enligt stridens skadefunktion.

Utan MVP gör Ruby 20 magisk skada varje 0,25 s: 80 DPS per fiende, radie
3,90625 rutor. Med MVP 4 och en närliggande MVP 10-källa blir tickskadan 48 och
DPS 192. Den valda aurans markering använder också auraradien. Rena auratorn
döljer oanvänd målprioritet. Hybrider som Antique Bloodstone behåller sina
primärattackvärden och får separata rader för varje skadeaura; DPS från olika
radier summeras inte till en missvisande totalsiffra.

## MVP 10

Maxade torn får en guldkrona inom sin cell och en gul segmenterad ring med
modellens radie 290/128 rutor. När källtornet väljs markeras mottagarna. När
mottagaren väljs framhävs MVP-källorna som når det. Stenar och källtornets egen
ruta räknas inte som mottagare. Färg och form skiljer MVP från övriga auror.
Effekterna följer paus/2× och befintlig global effektinställning.

## Verifiering

- `python tools/check.py`: hela sviten passerar.
- `tests/check_quality_pass.gd -- --campaign --smoke`: 17 nya kontroller för
  panelvärden mot verklig projektil-/auraskada, stöd och tillfälliga bonusar,
  avrundning, alla tre rena skadeauror, hybrider, MVP-räckvidd och panelbyten.
- Verklig Godot-rendering av strid och vald Ruby med MVP-stöd:
  `output/quality-native/frame00000039.png`, inga motorfel eller varningar.
- Windows och webb återexporterade med `tools/export.ps1 -Release`. Windows
  release startad med verifierad rendering och attackljud; Chrome-start av
  webbkampanjen ger 0 konsolfel och 0 varningar.
- Kampanjens befintliga rutkontroll passerar 372 layoutfall.

Regressionskontrollen ingår i den ordinarie kontrollkörningen. Full Dota-motorparitet
och mänskligt slutbalanstest är fortfarande separata granskningsuppgifter.
