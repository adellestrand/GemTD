param([switch]$Release)
$ErrorActionPreference = 'Stop'
$exportMode = if ($Release) { '--export-release' } else { '--export-debug' }
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force -Path builds/windows, builds/web | Out-Null
    Set-Content -LiteralPath builds/.gdignore -Value ''
    python tools/godot.py --headless --editor --path . --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    python tools/godot.py --headless --path . $exportMode 'Windows Desktop' builds/windows/GemTD.exe
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
    python tools/godot.py --headless --path . $exportMode 'Web' builds/web/index.html
    if ($LASTEXITCODE -ne 0) { throw 'Web export failed' }
} finally { Pop-Location }
