# Builds the distributable release folder (and its zip) from the repo.
# Roadmap 5.3. Run it through build-release.bat in the repo root.
#
# The layout it produces is exactly what installer\install.ps1 expects:
#
#   TheUnseenBanner-<version>\
#     install.bat, uninstall.bat, README.md, LICENSE
#     installer\   _lib.ps1, install.ps1, uninstall.ps1
#     mods\        the three zips that go into the game's data\ folder
#     companion\   the self-contained companion app (no .NET install needed)
#
# Nothing here touches a game folder: that is the installer's job alone.

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host ""; Write-Host "== $Msg ==" }
function Write-Ok   { param([string]$Msg) Write-Host "[OK] $Msg" }
function Write-Warn { param([string]$Msg) Write-Host "[WARNING] $Msg" }

$Root = Split-Path $PSScriptRoot -Parent

# Windows' own bsdtar, by absolute path on purpose: a plain "tar" picks up Git
# Bash's GNU tar when this runs from such a shell, and GNU tar reads "D:\..." as
# a remote host ("Cannot connect to D") instead of a path.
$Tar = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $Tar)) { throw "Windows' tar.exe was not found at $Tar" }
$ModNut = Join-Path $Root 'mod\scripts\!mods_preload\mod_unseen_banner.nut'
$Plugin = Join-Path $Root 'plugin'

# Single source of truth for the version: what the mod registers with Modern Hooks.
$m = [regex]::Match((Get-Content -LiteralPath $ModNut -Raw), 'Version\s*=\s*"([0-9][0-9.]*)"')
if (-not $m.Success) { throw "Could not read ::UnseenBanner.Version from $ModNut" }
$Version = $m.Groups[1].Value
Write-Host "=== The Unseen Banner - building release $Version ==="

# The companion says its own version out loud on startup, and the csproj stamps the
# exe. A release where the three disagree is a support nightmare, so check early.
$progVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $Root 'companion\Program.cs') -Raw),
    'ModVersion\s*=\s*"([0-9][0-9.]*)"').Groups[1].Value
$csprojVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $Root 'companion\TheUnseenBanner.Companion.csproj') -Raw),
    '<Version>([0-9][0-9.]*)</Version>').Groups[1].Value
if (-not $Version.StartsWith($progVersion)) { Write-Warn "companion/Program.cs says $progVersion, the mod says $Version." }
if ($csprojVersion -ne $Version) { Write-Warn "the csproj says $csprojVersion, the mod says $Version." }

$Dist = Join-Path $Root 'dist'
$Out = Join-Path $Dist ("TheUnseenBanner-" + $Version)
if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out -Force | Out-Null

# --- The mod zip ---------------------------------------------------------------
# Packed with tar, exactly as dev_install.bat does, so what ships is structurally
# the same zip that was verified by ear during development.
Write-Step "Packing mod_unseen_banner.zip from mod/"
$modZip = Join-Path $Plugin 'mod_unseen_banner.zip'
if (Test-Path -LiteralPath $modZip) { Remove-Item -LiteralPath $modZip -Force }
Push-Location (Join-Path $Root 'mod')
try {
    & $Tar -a -cf $modZip scripts ui
    if ($LASTEXITCODE -ne 0) { throw "tar failed packing the mod zip." }
}
finally { Pop-Location }
Write-Ok "Packed $modZip"

# --- mods\ ---------------------------------------------------------------------
Write-Step "Collecting the mod zips"
$mods = Join-Path $Out 'mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
$zips = @()
foreach ($pattern in @('mod_modern_hooks-*.zip', 'mod_msu-*.zip', 'mod_unseen_banner.zip')) {
    $found = @(Get-ChildItem -LiteralPath $Plugin -Filter $pattern -ErrorAction SilentlyContinue)
    if ($found.Count -eq 0) { throw "Missing $pattern in plugin\ -- download it before building a release." }
    $zips += $found
}
foreach ($zip in $zips) {
    Copy-Item -LiteralPath $zip.FullName -Destination $mods -Force
    Write-Ok ("mods\" + $zip.Name)
}

# --- companion\ ----------------------------------------------------------------
# Self-contained on purpose: a blind player should not have to install a .NET
# runtime before hearing anything, and a missing runtime fails silently-ish.
Write-Step "Publishing the companion app (self-contained win-x64)"
$companionOut = Join-Path $Out 'companion'
& dotnet publish (Join-Path $Root 'companion\TheUnseenBanner.Companion.csproj') `
    -c Release -r win-x64 --self-contained true -o $companionOut | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed." }

# The speech DLLs are native and must sit next to the exe. The csproj copies them,
# but a publish profile change would break that silently -- so verify, and repair.
foreach ($dll in @('Tolk.dll', 'nvdaControllerClient64.dll')) {
    $target = Join-Path $companionOut $dll
    if (-not (Test-Path -LiteralPath $target)) {
        Copy-Item -LiteralPath (Join-Path $Plugin $dll) -Destination $target -Force
        Write-Warn "$dll was missing from the publish output; copied from plugin\."
    }
}
$exe = Join-Path $companionOut 'TheUnseenBanner.Companion.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "The published companion has no exe: $exe" }
Write-Ok "Published to companion\"

# --- The installer and the docs -------------------------------------------------
Write-Step "Copying the installer and the documentation"
foreach ($file in @('install.bat', 'uninstall.bat', 'README.md', 'LICENSE')) {
    Copy-Item -LiteralPath (Join-Path $Root $file) -Destination $Out -Force
    Write-Ok $file
}
$installerOut = Join-Path $Out 'installer'
New-Item -ItemType Directory -Path $installerOut -Force | Out-Null
Copy-Item -Path (Join-Path $Root 'installer\*.ps1') -Destination $installerOut -Force
Write-Ok "installer\"

# --- The zip the player downloads ------------------------------------------------
Write-Step "Zipping the release"
$releaseZip = Join-Path $Dist ("TheUnseenBanner-" + $Version + ".zip")
if (Test-Path -LiteralPath $releaseZip) { Remove-Item -LiteralPath $releaseZip -Force }
Push-Location $Dist
try {
    & $Tar -a -cf $releaseZip (Split-Path $Out -Leaf)
    if ($LASTEXITCODE -ne 0) { throw "tar failed zipping the release." }
}
finally { Pop-Location }

$sizeMb = [math]::Round((Get-Item -LiteralPath $releaseZip).Length / 1MB, 1)
Write-Host ""
Write-Host "SUCCESS. Release $Version built:"
Write-Host "  folder: $Out"
Write-Host "  zip:    $releaseZip ($sizeMb MB)"
Write-Host ""
Write-Host "Before publishing it, install that zip on a clean machine and verify by ear."
