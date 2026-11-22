@echo off
title Rotwood Mega Mod Pack - uninstall
if not exist "%~dp0files\modpack.ps1" (
  echo Unpack the whole zip into a folder first, then run this file from that folder.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0files\modpack.ps1" uninstall
echo.
pause
