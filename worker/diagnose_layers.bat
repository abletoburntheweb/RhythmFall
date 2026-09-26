@echo off
setlocal
set "PYTHONIOENCODING=utf-8"
set "SERVER=%~dp0..\RhythmFallServer-main"
if not exist "%SERVER%\scripts\diagnose_layers.py" (
  set "SERVER=%~dp0..\RhythmFallServer"
)
if exist "D:\Games\godotprojects\RhythmFall\RhythmFallServer\scripts\diagnose_layers.py" (
  set "SERVER=D:\Games\godotprojects\RhythmFall\RhythmFallServer"
)
if not exist "%SERVER%\scripts\diagnose_layers.py" (
  echo script not found: %SERVER%\scripts\diagnose_layers.py
  exit /b 1
)
set "PY=%SERVER%\.venv\Scripts\python.exe"
if not exist "%PY%" (
  set "PY=python"
)
cd /d "%SERVER%"
"%PY%" scripts\diagnose_layers.py %*
exit /b %ERRORLEVEL%
