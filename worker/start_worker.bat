@echo off
setlocal EnableExtensions
chcp 65001 >nul
title RhythmFall Generation Server

set "HERE=%~dp0"
set "SERVER="

if defined RFALL_SERVER_ROOT (
  set "SERVER=%RFALL_SERVER_ROOT%"
) else if exist "%HERE%server_root.path" (
  set /p SERVER=<"%HERE%server_root.path"
)

if not defined SERVER (
  if exist "%HERE%..\RhythmFallServer\run.py" (
    for %%I in ("%HERE%..\RhythmFallServer") do set "SERVER=%%~fI"
  )
)

if not defined SERVER (
  echo [RhythmFall Worker] Put server in ..\RhythmFallServer or create worker\server_root.path
  exit /b 1
)

for %%I in ("%SERVER%") do set "SERVER=%%~fI"

if not exist "%SERVER%\run.py" (
  echo [RhythmFall Worker] run.py not found in: %SERVER%
  exit /b 1
)

cd /d "%SERVER%"
set "RF_BIND_HOST=127.0.0.1"
if not defined RF_BIND_PORT set "RF_BIND_PORT=5000"
set "RF_FLASK_DEBUG=0"
set "PYTHONUNBUFFERED=1"

if defined RFALL_PYTHON (
  "%RFALL_PYTHON%" -u run.py
) else if defined RFALL_CONDA_ENV (
  call conda run -n %RFALL_CONDA_ENV% python -u run.py
) else (
  python -u run.py
)

endlocal
