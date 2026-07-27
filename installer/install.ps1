. "$PSScriptRoot\_lib.ps1"

Write-Host "=== The Unseen Banner - Battle Brothers accessibility - Installer ==="
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

try {
    $source = Get-ModSourceFolder
    $zips = Get-ModZips $source
    if ($zips.Count -eq 0) { throw "No mod zips found in $source." }

    # The mod and the companion are two halves of one release: the mod reads the
    # game and the companion speaks it, so pairing them across releases silently
    # loses whatever the newer half added, and the version the voice announces on
    # startup is the only hint. Both halves are checked here, while the game
    # folder is still untouched, rather than after copying the zips in.
    $companion = Find-CompanionExe $Root
    if (-not $companion) {
        throw @"
The companion app was not found in this folder, and without it nothing is spoken.
Expected it at: $(Join-Path $Root 'companion\TheUnseenBanner.Companion.exe')
Re-extract the release (keeping the 'companion' folder next to install.bat) and run this again.
"@
    }
    $modVersion = Get-ModZipVersion (Join-Path $source 'mod_unseen_banner.zip')
    $companionVersion = Get-CompanionVersion $companion
    if (-not $modVersion -or -not $companionVersion) {
        Write-Warn "Could not read the version of the mod zip or the companion; installing without checking they match."
    }
    elseif ($modVersion -ne $companionVersion) {
        throw @"
The mod and the companion app here are from different releases: the mod zip is $modVersion, the companion is $companionVersion.
  mod zip:   $(Join-Path $source 'mod_unseen_banner.zip')
  companion: $companion
Installing that pair would leave the older half in charge of what you hear.
If this is a release download, re-extract it without mixing folders from another version.
If you are running this from the repo, the companion build is stale: run build-release.bat and
install from dist\, or rebuild it in place with 'dotnet build -c Debug' inside companion\.
"@
    }
    else { Write-Ok "Mod and companion are both version $modVersion." }

    Write-Step "Looking for Battle Brothers in your Steam libraries..."
    $game = Resolve-GameFolder
    Write-Ok "Found the game at: $game"

    $data = Join-Path $game 'data'
    if (-not (Test-Path -LiteralPath $data)) { throw "The game folder has no 'data' subfolder: $data" }

    $installed = @()
    foreach ($zip in $zips) {
        $target = Join-Path $data $zip.Name

        # Modern Hooks and MSU are shared with the rest of the modding scene. If a
        # DIFFERENT version of either is already installed, leave it alone: two
        # versions of the same framework loaded at once break every mod that uses
        # it, and the player's existing one is the one their other mods expect.
        if ($zip.Name -ne 'mod_unseen_banner.zip') {
            $family = ($zip.Name -split '-')[0]
            $others = @(Get-ChildItem -LiteralPath $data -Filter ($family + '-*.zip') -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne $zip.Name })
            if ($others.Count -gt 0) {
                Write-Warn ("$family is already installed as " + $others[0].Name + "; keeping yours and skipping " + $zip.Name + ".")
                Write-Warn "If the mod does not load, delete that file and run this installer again."
                continue
            }
        }

        # Our own zip is always ours to remove. For the two frameworks, record them
        # only when this installer created them, so uninstalling never takes away a
        # copy the player already had for their other mods.
        $existed = Test-Path -LiteralPath $target
        Copy-Item -LiteralPath $zip.FullName -Destination $target -Force
        if (-not $existed -or $zip.Name -eq 'mod_unseen_banner.zip') { $installed += $zip.Name }
        Write-Ok ("Installed " + $zip.Name + " into data\.")
    }

    Write-Manifest -GameFolder $game -Files $installed

    # The companion app is the voice, resolved and version-checked above; it stays
    # where this download is, and only needs to be running while you play.
    Write-Host ""
    $launcher = Write-Launcher -Root $Root -CompanionExe $companion
    Write-Ok "Wrote the launcher: $launcher"
    Write-Host ""
    Write-Host "SUCCESS. With your screen reader running, start the game with:"
    Write-Host "  $launcher"
    Write-Host ""
    Write-Host "It starts the companion app (the voice) and then the game through Steam."
    Write-Host "You can also start them separately, in any order: run"
    Write-Host "  $companion"
    Write-Host "and launch Battle Brothers as you normally do."
}
catch {
    Write-Host ""
    Write-Err $_.Exception.Message
    Write-Host "The game folder was left as it was; you can try again or install manually (see README)."
    exit 1
}
