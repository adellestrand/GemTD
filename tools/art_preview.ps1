param([switch]$Motion)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    python tools/godot.py --headless --editor --path . --import
    if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
    if ($Motion) {
        python tools/godot.py --path . res://game/art_gallery.tscn -- --motion
    } else {
        python tools/godot.py --path . res://game/art_gallery.tscn
    }
    if ($LASTEXITCODE -ne 0) { throw 'Art preview failed' }
} finally { Pop-Location }
