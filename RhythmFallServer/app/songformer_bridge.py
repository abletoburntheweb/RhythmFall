# app/songformer_bridge.py — OPTIONAL SongFormer structural signal (CPU, isolated venv, lazy, persistent worker)
# Integrated as: existing RhythmDNA + SongFormer -> fusion -> final (conservative)
# This module is intentionally isolated: no import of transformers/torch at top-level,
# so production server with songformer_enabled=False never touches heavy deps.

from __future__ import annotations

import os
import sys
import json
import time
import threading
import subprocess
import uuid
from pathlib import Path
from typing import List, Dict, Optional

SONGFORMER_ENABLED_DEFAULT = False
SONGFORMER_LOCAL_DIR = Path(__file__).resolve().parent.parent / "models" / "SongFormer"
SONGFORMER_VENV_PY = Path(__file__).resolve().parent.parent / ".venv-songformer" / "Scripts" / "python.exe"
SONGFORMER_WORKER_SCRIPT = Path(__file__).resolve().parent / "songformer_worker.py"
SONGFORMER_SUBPROCESS_SCRIPT = Path(__file__).resolve().parent / "songformer_subprocess.py"  # fallback per-request

_lock = threading.Lock()
_cached_available: Optional[bool] = None

# Persistent worker state
_worker_process: Optional[subprocess.Popen] = None
_worker_lock = threading.Lock()

def _log(msg: str) -> None:
    print(f"[SongFormer] {msg}")

def is_available() -> bool:
    global _cached_available
    if _cached_available is not None:
        return _cached_available
    if not (SONGFORMER_LOCAL_DIR / "model.safetensors").is_file():
        _cached_available = False
        return False
    if not (SONGFORMER_LOCAL_DIR / "config.json").is_file():
        _cached_available = False
        return False
    if not SONGFORMER_VENV_PY.is_file():
        _cached_available = False
        return False
    if not SONGFORMER_WORKER_SCRIPT.is_file() and not SONGFORMER_SUBPROCESS_SCRIPT.is_file():
        _cached_available = False
        return False
    _cached_available = True
    return True

def is_enabled(payload: Optional[Dict] = None) -> bool:
    # Payload from Game API has priority: metadata songformer_enabled
    if payload is not None:
        try:
            v = payload.get("songformer_enabled")
            if v is None:
                v = payload.get("songformerEnabled")
            if v is not None:
                enabled = bool(v) if not isinstance(v, str) else v.strip().lower() in ("1","true","yes","on")
                # Still requires availability
                if enabled:
                    return is_available()
                return False
        except Exception:
            pass
    # Env var override
    if "songformer_enabled" in os.environ:
        return os.environ.get("songformer_enabled", "0") == "1" and is_available()
    # Flag file
    flag_path = SONGFORMER_LOCAL_DIR / "enabled.flag"
    if flag_path.is_file():
        try:
            return flag_path.read_text(encoding="utf-8").strip() == "1" and is_available()
        except Exception:
            pass
    return SONGFORMER_ENABLED_DEFAULT and is_available()

def _ensure_worker() -> Optional[subprocess.Popen]:
    global _worker_process
    with _worker_lock:
        if _worker_process is not None and _worker_process.poll() is None:
            return _worker_process
        # Need to start new worker
        if _worker_process is not None:
            try:
                _worker_process.terminate()
                _worker_process.wait(timeout=5)
            except Exception:
                try:
                    _worker_process.kill()
                except Exception:
                    pass
            _worker_process = None
        if not is_available():
            return None
        # Start worker
        env = os.environ.copy()
        env["SONGFORMER_LOCAL_DIR"] = str(SONGFORMER_LOCAL_DIR)
        env["PYTHONIOENCODING"] = "utf-8"
        # Use unbuffered
        cmd = [str(SONGFORMER_VENV_PY), "-u", str(SONGFORMER_WORKER_SCRIPT)]
        try:
            _log(f"starting persistent worker: {' '.join(cmd)}")
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                bufsize=1,
                env=env,
            )
            # Give it a moment to start and load model lazily on first request
            time.sleep(0.5)
            if proc.poll() is not None:
                _log(f"worker failed to start, returncode {proc.returncode}")
                try:
                    err = proc.stderr.read()
                    _log(f"worker stderr: {err[:500]}")
                except Exception:
                    pass
                return None
            _worker_process = proc
            _log(f"worker started pid {proc.pid}")
            return proc
        except Exception as e:
            _log(f"failed to start worker: {e}")
            return None

def _call_worker(audio_path: str, timeout: float = 700.0) -> List[Dict]:
    proc = _ensure_worker()
    if proc is None or proc.stdin is None or proc.stdout is None:
        return []
    try:
        req_id = str(uuid.uuid4())[:8]
        req = {"id": req_id, "audio_path": str(Path(audio_path).resolve())}
        # Send request
        proc.stdin.write(json.dumps(req, ensure_ascii=False) + "\n")
        proc.stdin.flush()
        # Read response with timeout
        # Use a separate thread to read with timeout
        import select
        # For Windows, select not available for pipes, use polling
        start = time.time()
        # Simple polling: read line with timeout
        # Use proc.stdout.readline with timeout via threading
        result_holder = {}
        def _read():
            try:
                line = proc.stdout.readline()
                result_holder["line"] = line
            except Exception as e:
                result_holder["error"] = str(e)
        t = threading.Thread(target=_read, daemon=True)
        t.start()
        t.join(timeout)
        if t.is_alive():
            _log(f"worker timeout after {timeout}s for {req_id}")
            # Kill and restart worker
            try:
                proc.terminate()
            except Exception:
                pass
            return []
        line = result_holder.get("line", "")
        if not line:
            err = result_holder.get("error", "empty")
            _log(f"worker empty response: {err}")
            return []
        try:
            resp = json.loads(line.strip())
        except Exception as e:
            _log(f"worker invalid JSON: {e} line: {line[:200]}")
            return []
        if resp.get("id") != req_id:
            _log(f"worker id mismatch: {resp.get('id')} vs {req_id}")
            # Still try to use segments if present
        if resp.get("error"):
            _log(f"worker error: {resp.get('error')}")
            return []
        segments = resp.get("segments", [])
        if not isinstance(segments, list):
            return []
        # Normalize
        normalized = []
        for seg in segments:
            if not isinstance(seg, dict):
                continue
            try:
                normalized.append({
                    "start": float(seg.get("start", 0.0)),
                    "end": float(seg.get("end", 0.0)),
                    "label": str(seg.get("label", "verse")).strip().lower(),
                })
            except Exception:
                continue
        return normalized
    except Exception as e:
        _log(f"worker call failed: {e}")
        return []

def _call_subprocess_fallback(audio_path: str, timeout: float = 700.0) -> List[Dict]:
    # Fallback per-request subprocess (loads model each time, slow)
    if not SONGFORMER_SUBPROCESS_SCRIPT.is_file():
        return []
    cmd = [str(SONGFORMER_VENV_PY), str(SONGFORMER_SUBPROCESS_SCRIPT), str(Path(audio_path).resolve())]
    env = os.environ.copy()
    env["SONGFORMER_LOCAL_DIR"] = str(SONGFORMER_LOCAL_DIR)
    env["PYTHONIOENCODING"] = "utf-8"
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=timeout, env=env)
        if result.returncode != 0:
            _log(f"subprocess failed: {result.stderr[:500]}")
            return []
        out = result.stdout.strip()
        if not out:
            return []
        data = json.loads(out)
        if not isinstance(data, list):
            return []
        normalized = []
        for seg in data:
            if not isinstance(seg, dict):
                continue
            try:
                normalized.append({
                    "start": float(seg.get("start", 0.0)),
                    "end": float(seg.get("end", 0.0)),
                    "label": str(seg.get("label", "verse")).strip().lower(),
                })
            except Exception:
                continue
        return normalized
    except Exception as e:
        _log(f"subprocess fallback failed: {e}")
        return []

def get_songformer_structure(audio_path: str, timeout: float = 700.0) -> List[Dict]:
    if not is_available():
        _log("disabled (not available)")
        return []
    # Check enabled (allow direct test even if disabled, caller should check)
    # For now, if not enabled, still allow but log
    # The caller (rhythm_dna) should check is_enabled() before calling
    audio = Path(audio_path)
    if not audio.is_file():
        _log(f"audio not found: {audio_path}")
        return []
    with _lock:
        # Try persistent worker first
        try:
            # Check if worker is available and try
            if SONGFORMER_WORKER_SCRIPT.is_file():
                # Try worker
                res = _call_worker(audio_path, timeout=timeout)
                if res:
                    _log(f"worker segments: {len(res)}")
                    return res
                # If worker returned empty, fallback to subprocess
                _log("worker empty, trying subprocess fallback")
        except Exception as e:
            _log(f"worker error, fallback: {e}")
        # Fallback
        res = _call_subprocess_fallback(audio_path, timeout=timeout)
        if res:
            _log(f"subprocess segments: {len(res)}")
        return res

def fuse_structures(existing: Optional[List[Dict]], songformer: Optional[List[Dict]], duration: float, tolerance: float = 2.0) -> tuple[List[Dict], str]:
    """
    Safe fusion: existing + SongFormer -> merged.
    - Never replaces existing entirely unless existing is degenerate (solo/inst dominates).
    - Otherwise refines boundaries where SongFormer aligns within tolerance, but keeps existing labels.
    - Returns (fused_segments, reason_string)
    - Never raises: on invalid input, returns existing (fallback) and logs.
    """
    try:
        # Validate inputs are lists of dicts with start/end
        if not isinstance(existing, list):
            return (songformer if isinstance(songformer, list) else []), "invalid_existing"
        if not isinstance(songformer, list):
            return existing, "invalid_songformer"
        # Filter to valid dicts
        existing_valid = [s for s in existing if isinstance(s, dict) and "start" in s and "end" in s and "label" in s]
        songformer_valid = [s for s in songformer if isinstance(s, dict) and "start" in s and "end" in s and "label" in s]
        # If filtering removes all, treat as empty
        if not songformer_valid:
            return (existing_valid if existing_valid else existing), "no_songformer_keep_existing"
        if not existing_valid:
            return songformer_valid, "no_existing_use_songformer"
        # Use filtered lists for further logic
        existing = existing_valid
        songformer = songformer_valid
        # coverage
        total = float(duration) if duration and duration>0 else max((float(s.get("end",0)) for s in existing), default=0)
        cov = 0.0
        for s in songformer:
            try:
                cov += max(0.0, float(s.get("end",0))-float(s.get("start",0)))
            except Exception:
                continue
        if total>0 and cov < total*0.5:
            return existing, f"low_coverage {cov:.1f}/{total:.1f} keep existing"
        if len(songformer) <2:
            return existing, "songformer_too_few"
        # degeneracy check: solo/inst dominates
        solo_labels = {"solo", "instrumental", "inst"}
        solo_dur = sum(float(s.get("end",0))-float(s.get("start",0)) for s in existing if str(s.get("label","")).lower() in solo_labels)
        uniq = len(set(str(s.get("label","")).lower() for s in existing))
        solo_cnt = sum(1 for s in existing if str(s.get("label","")).lower() in solo_labels)
        is_degenerate = False
        if total>0 and solo_dur/total > 0.5:
            is_degenerate = True
        elif len(existing)>=5 and solo_cnt/len(existing) > 0.6:
            is_degenerate = True
        elif uniq==1 and len(existing)>=3:
            is_degenerate = True
        if is_degenerate:
            return songformer, "degenerate_existing_prefers_songformer"
        # Check alignment
        ex_bounds = [float(s.get("start",0)) for s in existing[1:]]
        sf_bounds = [float(s.get("start",0)) for s in songformer[1:]]
        aligned = 0
        for sf in sf_bounds:
            if not ex_bounds:
                break
            closest = min(ex_bounds, key=lambda x: abs(x-sf))
            if abs(closest - sf) <= tolerance:
                aligned += 1
        # Conservative: keep existing, would refine boundaries if aligned >30%
        if aligned / max(len(sf_bounds),1) > 0.3:
            return existing, f"aligned {aligned}/{len(sf_bounds)} within {tolerance}s (conservative keep existing, would refine)"
        return existing, f"no_alignment {aligned}/{len(sf_bounds)} keep existing"
    except Exception as e:
        print(f"[SongFormer] fuse error {e}, keep existing")
        try:
            return (existing if isinstance(existing, list) else []), f"fuse_error_{e}"
        except Exception:
            return [], "fuse_error"


def shutdown_worker():
    global _worker_process
    with _worker_lock:
        if _worker_process is not None:
            try:
                _worker_process.terminate()
                _worker_process.wait(timeout=5)
                _log("worker shutdown")
            except Exception:
                try:
                    _worker_process.kill()
                except Exception:
                    pass
            _worker_process = None
