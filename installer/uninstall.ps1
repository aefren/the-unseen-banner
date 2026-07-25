. "$PSScriptRoot\_lib.ps1"

Write-Host "=== The Unseen Banner - Battle Brothers accessibility - Uninstaller ==="
Write-Host ""

$Root = Split-Path $PSScriptRoot -Parent

try {
    # What the installer wrote, and where. Without a manifest (a fresh Windows
    # user, a manual install) fall back to removing only our own zip, which is
    # never shared with another mod.
    $manifest = Read-Manifest
    if ($manifest -and (Test-GameFolder $manifest.Game)) {
        $game = $manifest.Game
        $files = $manifest.Files
        Write-Ok "Found the recorded installation at: $game"
    }
    else {
        Write-Step "No installation record found. Looking for the game..."
        $game = Resolve-GameFolder
        $files = @('mod_unseen_banner.zip')
        Write-Ok "Found the game at: $game"
        Write-Warn "Modern Hooks and MSU will be left in place; they may belong to other mods."
    }

    $data = Join-Path $game 'data'
    $removed = 0
    foreach ($name in $files) {
        $target = Join-Path $data $name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
            Write-Ok "Removed data\$name."
            $removed++
        }
    }
    if ($removed -eq 0) { Write-Ok "Nothing left to remove; the game folder is already clean." }

    $launcher = Join-Path $Root 'play-unseen-banner.bat'
    if (Test-Path -LiteralPath $launcher) {
        Remove-Item -LiteralPath $launcher -Force
        Write-Ok "Removed the generated launcher."
    }

    Remove-Manifest

    Write-Host ""
    Write-Host "DONE. Battle Brothers is back to how it was; your saves are untouched."
    Write-Host "This folder (mod files and companion app) can now be deleted."
}
catch {
    Write-Host ""
    Write-Err $_.Exception.Message
    exit 1
}
