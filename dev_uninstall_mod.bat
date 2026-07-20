@echo off
rem The Unseen Banner - dev uninstall
rem Removes everything dev_install.bat put into the local game copy,
rem plus the config folder bb-launcher generates, leaving the game as
rem shipped.
setlocal
set "REPO=%~dp0"
set "GAME=%REPO%Battle Brothers"

if not exist "%GAME%\win32\BattleBrothers.exe" (
    echo ERROR: game copy not found at "%GAME%".
    exit /b 1
)

echo == Removing mod zips from data/ ==
if exist "%GAME%\data\mod_modern_hooks-0.6.0.zip" del "%GAME%\data\mod_modern_hooks-0.6.0.zip"
if exist "%GAME%\data\mod_msu-1.9.0.zip" del "%GAME%\data\mod_msu-1.9.0.zip"
if exist "%GAME%\data\mod_unseen_banner.zip" del "%GAME%\data\mod_unseen_banner.zip"

echo == Removing bb-launcher + Coherent development DLL from win32/ ==
if exist "%GAME%\win32\bb-launcher-steam.exe" del "%GAME%\win32\bb-launcher-steam.exe"
if exist "%GAME%\win32\CoherentUIGTDevelopment.dll" del "%GAME%\win32\CoherentUIGTDevelopment.dll"

echo == Removing bb-launcher generated config ==
if exist "%GAME%\awesome-battle-brothers" rmdir /s /q "%GAME%\awesome-battle-brothers"
if exist "%GAME%\win32\awesome-battle-brothers" rmdir /s /q "%GAME%\win32\awesome-battle-brothers"

echo Done. The game folder is back to vanilla.
endlocal
