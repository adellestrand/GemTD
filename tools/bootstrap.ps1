param([switch]$SkipTemplates)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$toolsPath = Join-Path $projectRoot '.tools'
$version = '4.7.2-stable'
$baseUrl = "https://github.com/godotengine/godot-builds/releases/download/$version"
New-Item -ItemType Directory -Force -Path $toolsPath | Out-Null
Set-Content -LiteralPath (Join-Path $toolsPath '.gdignore') -Value ''

function Get-VerifiedArchive([string]$Name, [string]$LocalName, [string]$ExpectedSha256) {
    $destination = Join-Path $toolsPath $LocalName
    if (-not (Test-Path -LiteralPath $destination)) {
        Write-Host "Downloading $Name"
        Invoke-WebRequest -Uri "$baseUrl/$Name" -OutFile $destination -UseBasicParsing
    }
    $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256) { throw "Hash mismatch: $destination. Remove this archive and retry." }
    return $destination
}

$engineZip = Get-VerifiedArchive "Godot_v${version}_win64.exe.zip" 'godot.zip' '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
$enginePath = Join-Path $toolsPath 'godot'
if (-not (Test-Path -LiteralPath (Join-Path $enginePath "Godot_v${version}_win64_console.exe"))) {
    Expand-Archive -LiteralPath $engineZip -DestinationPath $enginePath -Force
}
# Self-contained editor settings. tools/godot.py also isolates the child's APPDATA.
Set-Content -LiteralPath (Join-Path $enginePath '_sc_') -Value ''

if (-not $SkipTemplates) {
    $templateArchive = Get-VerifiedArchive "Godot_v${version}_export_templates.tpz" 'templates.tpz' 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($templateArchive)
    $destination = Join-Path $toolsPath 'templates'
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    try {
        foreach ($name in @('windows_debug_x86_64.exe','windows_release_x86_64.exe','web_nothreads_debug.zip','web_nothreads_release.zip')) {
            $entry = $archive.GetEntry("templates/$name")
            if ($null -eq $entry) { throw "Missing template: $name" }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $destination $name), $true)
        }
    } finally { $archive.Dispose() }
}
Write-Host 'Godot ready. Run: powershell -ExecutionPolicy Bypass -File tools/run.ps1'
