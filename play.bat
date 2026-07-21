@echo off
rem Lanza la app companera (voz) y el juego via bb-launcher-steam con un solo doble clic.
setlocal
set "ROOT=%~dp0"

start "Unseen Banner Companion" /D "%ROOT%companion\bin\Debug\net8.0" "%ROOT%companion\bin\Debug\net8.0\TheUnseenBanner.Companion.exe"
start "Battle Brothers" /D "%ROOT%Battle Brothers\win32" "%ROOT%Battle Brothers\win32\bb-launcher-steam.exe"
