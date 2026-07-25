. "$PSScriptRoot\_lib.ps1"

Write-Host "=== The Unseen Banner - Battle Brothers accessibility - Installer ==="
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

try {
    $source = Get-ModSourceFolder
    $zips = Get-ModZips $source
    if ($zips.Count -eq 0) { throw "No mod zips found in $source." }

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

    # The companion app is the voice: it stays where this download is, and only
    # needs to be running while you play. Release layout first, repo build second.
    $companion = $null
    foreach ($rel in @('companion\TheUnseenBanner.Companion.exe',
                       'companion\bin\Release\net8.0\TheUnseenBanner.Companion.exe',
                       'companion\bin\Debug\net8.0\TheUnseenBanner.Companion.exe')) {
        $candidate = Join-Path $Root $rel
        if (Test-Path -LiteralPath $candidate) { $companion = $candidate; break }
    }

    Write-Host ""
    if ($companion) {
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
    else {
        Write-Warn "The mod is installed, but the companion app was not found in this folder."
        Write-Warn "Without it nothing is spoken. Re-download the release and run this again."
    }
}
catch {
    Write-Host ""
    Write-Err $_.Exception.Message
    Write-Host "The game folder was left as it was; you can try again or install manually (see README)."
    exit 1
}
