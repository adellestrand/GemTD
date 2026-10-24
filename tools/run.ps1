param([switch]$Web, [switch]$ExpandedGems, [switch]$Campaign)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    if ($Web) {
        if ($ExpandedGems) { Write-Host 'Development profile: http://127.0.0.1:8060/?profile=expanded-gems' }
        if ($Campaign) { Write-Host 'Solo campaign: http://127.0.0.1:8060/?profile=campaign' }
        if (-not (Test-Path -LiteralPath 'builds/web/index.html')) { throw 'Export first: powershell -File tools/export.ps1' }
        python tools/serve.py
    } else {
        if ($Campaign) { python tools/godot.py --path . -- --campaign }
        elseif ($ExpandedGems) { python tools/godot.py --path . -- --expanded-gems }
        else { python tools/godot.py --path . }
        if ($LASTEXITCODE -ne 0) { throw "Godot exited with $LASTEXITCODE" }
    }
} finally { Pop-Location }
