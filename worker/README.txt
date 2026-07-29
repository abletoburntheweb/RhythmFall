RhythmFall — Windows generation worker
======================================

This folder ships with the game client and the Windows installer payload.

Server code lives in RhythmFallServer/ (sibling folder or worker\server_root.path).

Setup (development or release bundle)
------------------------------------
  1. Place server sources in RhythmFallServer/ (run.py + app/ + models/)
  2. powershell -ExecutionPolicy Bypass -File worker\install_windows_server.ps1
     Optional GPU: -Gpu auto|nvidia|amd
  3. powershell -ExecutionPolicy Bypass -File worker\download_effnet_models.ps1
  4. powershell -ExecutionPolicy Bypass -File worker\cleanup_wsl_legacy.ps1
     (removes obsolete WSL-era model folders if present)
  5. powershell -ExecutionPolicy Bypass -File worker\build_server_launcher.ps1
     → RhythmFallServer.exe next to the game / project root

Release layout (next to RhythmFall.exe)
---------------------------------------
  RhythmFall.exe
  RhythmFallServer.exe
  worker\          (this folder — no server_root.path / windows_python.path)
  RhythmFallServer\  (.venv, app, models, run.py)

Build installer: RFALL\BUILD.txt

Runtime
-------
  Settings → Generation → Auto — game starts hidden Windows Python or RhythmFallServer.exe.
  Manual console logs: RhythmFallServer.exe or worker\start_server_windows.bat
  Port 5000 /health — duplicate spawns are skipped.

Windows stack
-------------
  BPM — TempoCNN (%USERPROFILE%\.tempocnn\)
  Genres — EffNet ONNX in models/discogs-effnet/
  Stems — audio-separator + kuielab_a_drums.onnx (RFALL_GPU=auto)
  Drums — ADTOF fast-pick by default (RFALL_DRUM_BACKEND=heuristic fallback)

Optional paths
--------------
  worker\server_root.path — one line: folder containing run.py
  RFALL_PYTHON / RFALL_SERVER_ROOT — env overrides
  worker\windows_python.path — written by install_windows_server.ps1 (gitignored)

Verify
------
  RhythmFallServer\.venv\Scripts\python.exe scripts\verify_windows_server.py
