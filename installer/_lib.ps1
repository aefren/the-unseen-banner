# Shared helpers for The Unseen Banner installer / uninstaller.
# Written for Windows PowerShell 5.1 (ships with Windows) -- no pwsh required.
#
# These two scripts are the release counterpart of dev_install.bat /
# dev_uninstall_mod.bat: the only sanctioned way of touching a game folder.
# Everything they write into the game is a mod zip inside data\, and the
# uninstaller removes exactly what the manifest says was written -- nothing
# else is created, patched or deleted.

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host "  $Msg" }
function Write-Ok   { param([string]$Msg) Write-Host "[OK] $Msg" }
function Write-Warn { param([string]$Msg) Write-Host "[WARNING] $Msg" }
function Write-Err  { param([string]$Msg) Write-Host "[ERROR] $Msg" }

# Battle Brothers on Steam. Its folder is always <library>\steamapps\common\Battle Brothers.
$Script:SteamAppId   = '365360'
$Script:GameDirName  = 'Battle Brothers'
$Script:GameExeRel   = 'win32\BattleBrothers.exe'

# The manifest lives outside the game folder (and outside this download, which the
# player may move or delete) so the uninstaller always knows what the installer
# actually copied, and never removes a Modern Hooks / MSU that was already there.
$Script:ManifestPath = Join-Path $env:LOCALAPPDATA 'TheUnseenBanner\install-manifest.txt'

function Test-GameFolder {
    param([string]$Path)
    if (-not $Path) { return $false }
    return (Test-Path -LiteralPath (Join-Path $Path $Script:GameExeRel))
}

# Locate the Steam copy of the game by walking Steam's own library list.
# Returns the game folder path, or $null if it is not found.
function Find-GameFolder {
    $libraries = @()

    $steamPath = $null
    try { $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath } catch {}
    if (-not $steamPath) {
        try { $steamPath = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop).InstallPath } catch {}
    }
    if ($steamPath) {
        $libraries += $steamPath
        # Extra libraries (second disk, etc.) are listed here, one "path" per entry.
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            $found = Select-String -LiteralPath $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches
            foreach ($line in $found) {
                foreach ($m in $line.Matches) { $libraries += ($m.Groups[1].Value -replace '\\\\', '\') }
            }
        }
    }

    # Common defaults, in case the registry lookup fails entirely.
    $libraries += 'C:\Program Files (x86)\Steam'
    $libraries += 'C:\Steam'

    foreach ($lib in ($libraries | Select-Object -Unique)) {
        if (-not $lib) { continue }
        $game = Join-Path $lib ('steamapps\common\' + $Script:GameDirName)
        if (Test-GameFolder $game) { return $game }
    }
    return $null
}

# Auto-detect the Steam install; if that fails, ask the player to paste the path.
function Resolve-GameFolder {
    $game = Find-GameFolder
    if ($game) { return $game }

    Write-Host ""
    Write-Host "Could not find Battle Brothers in any Steam library."
    Write-Host "Paste the full path to the game folder (the one that contains 'data' and 'win32')"
    Write-Host "and press Enter. Example: C:\Games\Steam\steamapps\common\Battle Brothers"
    for ($i = 0; $i -lt 3; $i++) {
        $manual = (Read-Host "Game folder").Trim().Trim('"')
        if (Test-GameFolder $manual) { return $manual }
        if ($manual) { Write-Host "That folder does not contain win32\BattleBrothers.exe. Try again." }
    }
    throw "No valid game folder given. Nothing was changed."
}

# The three zips this release installs, resolved from the folder shipped next to
# the installer: 'mods' in a release download, 'plugin' when run from the repo.
function Get-ModSourceFolder {
    $root = Split-Path $PSScriptRoot -Parent
    foreach ($name in @('mods', 'plugin')) {
        $candidate = Join-Path $root $name
        if (Test-Path -LiteralPath (Join-Path $candidate 'mod_unseen_banner.zip')) { return $candidate }
    }
    throw "Cannot find mod_unseen_banner.zip in the 'mods' folder next to the installer."
}

# Ordered so the mod itself is reported last: the two frameworks it needs first.
function Get-ModZips {
    param([string]$Source)
    $zips = @()
    foreach ($pattern in @('mod_modern_hooks-*.zip', 'mod_msu-*.zip', 'mod_unseen_banner.zip')) {
        $zips += @(Get-ChildItem -LiteralPath $Source -Filter $pattern -ErrorAction SilentlyContinue)
    }
    return $zips
}

# The companion app is the voice: it stays where this download is. Release layout
# first, repo build second. Returns $null when none of the three is there.
function Find-CompanionExe {
    param([string]$Root)
    foreach ($rel in @('companion\TheUnseenBanner.Companion.exe',
                       'companion\bin\Release\net8.0\TheUnseenBanner.Companion.exe',
                       'companion\bin\Debug\net8.0\TheUnseenBanner.Companion.exe')) {
        $candidate = Join-Path $Root $rel
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

# The mod zip and the companion are two halves of one release, and the installer
# checks they agree (see install.ps1). The mod's version is the one string
# build-release.ps1 reads too: ::UnseenBanner.Version in the preload script.
# Returns $null if the zip does not carry a version we can read.
function Get-ModZipVersion {
    param([string]$ZipPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $text = $null
    $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = @($zip.Entries | Where-Object { $_.Name -eq 'mod_unseen_banner.nut' })[0]
        if (-not $entry) { return $null }
        $reader = New-Object IO.StreamReader($entry.Open())
        try { $text = $reader.ReadToEnd() } finally { $reader.Close() }
    }
    finally { $zip.Dispose() }
    $m = [regex]::Match($text, 'Version\s*=\s*"([0-9][0-9.]*)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# The exe carries the csproj's <Version> as a four-part FileVersion (0.8.0.0);
# cut it to the mod's three parts so the two are comparable.
function Get-CompanionVersion {
    param([string]$ExePath)
    $v = (Get-Item -LiteralPath $ExePath).VersionInfo.FileVersion
    if (-not $v) { return $null }
    $parts = $v.Split('.')
    if ($parts.Count -ge 3) { return ($parts[0..2] -join '.') }
    return $v
}

function Write-Manifest {
    param([string]$GameFolder, [string[]]$Files)
    $dir = Split-Path $Script:ManifestPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $lines = @("game=$GameFolder") + ($Files | ForEach-Object { "file=$_" })
    Set-Content -LiteralPath $Script:ManifestPath -Value $lines -Encoding UTF8
}

# Returns @{ Game = <path>; Files = @(<name>...) }, or $null when no install was recorded.
function Read-Manifest {
    if (-not (Test-Path -LiteralPath $Script:ManifestPath)) { return $null }
    $game = $null
    $files = @()
    foreach ($line in (Get-Content -LiteralPath $Script:ManifestPath)) {
        if ($line -like 'game=*') { $game = $line.Substring(5) }
        elseif ($line -like 'file=*') { $files += $line.Substring(5) }
    }
    if (-not $game) { return $null }
    return @{ Game = $game; Files = $files }
}

function Remove-Manifest {
    if (Test-Path -LiteralPath $Script:ManifestPath) { Remove-Item -LiteralPath $Script:ManifestPath -Force }
}

# A one-click launcher with the resolved game path baked in, written next to the
# installer. Steam's rungameid URL is used rather than the exe so the game starts
# exactly as it does from the library (Steam running, overlay, cloud saves).
function Write-Launcher {
    param([string]$Root, [string]$CompanionExe)
    $path = Join-Path $Root 'play-unseen-banner.bat'
    $lines = @(
        '@echo off',
        'rem Written by install.bat. Starts the companion (the voice) and then the game.',
        'title The Unseen Banner',
        ('start "The Unseen Banner Companion" /D "' + (Split-Path $CompanionExe -Parent) + '" "' + $CompanionExe + '"'),
        ('start "" "steam://rungameid/' + $Script:SteamAppId + '"')
    )
    Set-Content -LiteralPath $path -Value $lines -Encoding ASCII
    return $path
}
