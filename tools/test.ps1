param([switch]$Exports)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    if ($Exports) { python tools/check.py --exports } else { python tools/check.py }
    if ($LASTEXITCODE -ne 0) { throw 'Godot checks failed; see output/checks.log' }
} finally { Pop-Location }
