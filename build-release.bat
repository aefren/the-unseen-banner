@echo off
rem The Unseen Banner - build the distributable release into dist\ (roadmap 5.3).
rem No administrator rights needed: this only writes inside the repo.
setlocal
title The Unseen Banner - Build release

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0packaging\build-release.ps1"

echo.
echo Press any key to close this window . . .
pause >nul
