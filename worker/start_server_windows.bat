@echo off
setlocal EnableExtensions
chcp 65001 >nul
title RhythmFall Server (Windows, no WSL)

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

set "RFALL_PYTHON=%ROOT%\RhythmFallServer\.venv\Scripts\python.exe"
if not exist "%RFALL_PYTHON%" (
  echo [RhythmFall] Python venv not found:
  echo   %RFALL_PYTHON%
  echo Run: powershell -ExecutionPolicy Bypass -File "%ROOT%\worker\install_windows_server.ps1"
  pause
  exit /b 1
)

if exist "%ROOT%\worker\use_wsl.flag" (
  echo [RhythmFall] Disabling WSL: renaming worker\use_wsl.flag
  ren "%ROOT%\worker\use_wsl.flag" "use_wsl.flag.off" 2>nul
)

if not exist "%ROOT%\RhythmFallServer.exe" (
  echo [RhythmFall] RhythmFallServer.exe not found in:
  echo   %ROOT%
  pause
  exit /b 1
)

echo [RhythmFall] Windows Python: %RFALL_PYTHON%
echo [RhythmFall] Starting server... Close this window to stop.
echo.

cd /d "%ROOT%"
set "RFALL_USE_WSL=0"
if not defined RFALL_GPU set "RFALL_GPU=auto"
"%ROOT%\RhythmFallServer.exe"
pause
endlocal
