@echo off
rem The Unseen Banner - dev install
rem Rebuilds the mod zip from mod/ into plugin/ and copies everything
rem installable from plugin/ into the local game copy. This script and
rem dev_uninstall_mod.bat are the ONLY allowed way of touching the game
rem folder (see CLAUDE.md).
setlocal
set "REPO=%~dp0"
set "GAME=%REPO%Battle Brothers"

if not exist "%GAME%\win32\BattleBrothers.exe" (
    echo ERROR: game copy not found at "%GAME%".
    exit /b 1
)

echo == Rebuilding mod_unseen_banner.zip from mod/ ==
pushd "%REPO%mod"
if exist "%REPO%plugin\mod_unseen_banner.zip" del "%REPO%plugin\mod_unseen_banner.zip"
tar -a -cf "%REPO%plugin\mod_unseen_banner.zip" scripts ui || (popd & echo ERROR: packing failed & exit /b 1)
popd

echo == Installing mod zips into data/ ==
copy /y "%REPO%plugin\mod_modern_hooks-0.6.0.zip" "%GAME%\data\" >nul || exit /b 1
copy /y "%REPO%plugin\mod_msu-1.9.0.zip" "%GAME%\data\" >nul || exit /b 1
copy /y "%REPO%plugin\mod_unseen_banner.zip" "%GAME%\data\" >nul || exit /b 1

echo == Installing bb-launcher + Coherent development DLL into win32/ ==
copy /y "%REPO%plugin\bb-launcher-steam.exe" "%GAME%\win32\" >nul || exit /b 1
copy /y "%REPO%plugin\CoherentUIGTDevelopment.dll" "%GAME%\win32\" >nul || exit /b 1

echo Done. Launch the game with "%GAME%\win32\bb-launcher-steam.exe".
echo The UI Inspector (plugin\UI Inspector\bb-ui-inspector\bb-ui-inspector.exe)
echo runs from plugin/ and connects to 127.0.0.1:19999 while the game runs.
endlocal
