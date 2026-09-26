#!/usr/bin/env python3
"""
Persistent SongFormer worker — loads model once, serves multiple requests via stdin/stdout JSON lines.
Isolated in .venv-songformer, CPU only, no internet.

Protocol:
  stdin: JSON line {"id": "...", "audio_path": "/path/to/audio.wav"}
  stdout: JSON line {"id": "...", "segments": [{"start":0.0,"end":16.1,"label":"intro"},...], "error": null}
  stderr: logs

If audio_path is missing or inference fails, returns {"segments": [], "error": "..."}.

Model is loaded lazily on first request.
"""

import sys
import os
import json
import time
import traceback
from pathlib import Path

# Ensure local_dir is in path for custom code
local_dir = Path(os.environ.get("SONGFORMER_LOCAL_DIR", Path(__file__).resolve().parent.parent / "models" / "SongFormer"))
if str(local_dir) not in sys.path:
    sys.path.insert(0, str(local_dir))

# Patch check_imports to ignore local 'model'
try:
    import transformers.dynamic_module_utils
    transformers.dynamic_module_utils.check_imports = lambda *a, **k: []
except Exception:
    pass

_model = None
_model_load_time = 0.0

def _log(msg: str):
    print(f"[SongFormerWorker] {msg}", file=sys.stderr, flush=True)

def _load_model():
    global _model, _model_load_time
    if _model is not None:
        return _model
    t0 = time.time()
    _log(f"loading model from {local_dir} ...")
    from transformers import AutoModel
    try:
        model = AutoModel.from_pretrained(str(local_dir), trust_remote_code=True, local_files_only=True)
        model.eval()
        _model = model
        _model_load_time = time.time() - t0
        _log(f"model loaded in {_model_load_time:.1f}s")
        return _model
    except Exception as e:
        _log(f"failed to load model: {e}")
        traceback.print_exc(file=sys.stderr)
        raise

def _infer(audio_path: str):
    model = _load_model()
    # SongFormer expects 24k, but model does librosa.load(sr=24000) internally, so we can pass path directly
    # Use no_grad
    import torch
    with torch.no_grad():
        result = model(audio_path)
    # Normalize
    out = []
    for seg in result:
        try:
            out.append({
                "start": float(seg.get("start", 0.0)),
                "end": float(seg.get("end", 0.0)),
                "label": str(seg.get("label", "verse")).strip().lower(),
            })
        except Exception:
            continue
    return out

def main():
    _log(f"worker started, pid {os.getpid()}, local_dir={local_dir}, python={sys.executable}")
    # Preload check
    if not (local_dir / "model.safetensors").is_file():
        _log(f"model.safetensors not found in {local_dir}")
    # Loop reading stdin
    for line in sys.stdin:
        line=line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as e:
            _log(f"invalid JSON: {e}")
            continue
        req_id = str(req.get("id", ""))
        audio_path = str(req.get("audio_path", ""))
        _log(f"request {req_id}: {audio_path}")
        t0 = time.time()
        try:
            if not Path(audio_path).is_file():
                raise FileNotFoundError(f"audio not found: {audio_path}")
            segments = _infer(audio_path)
            elapsed = time.time() - t0
            _log(f"done {req_id} in {elapsed:.1f}s segments={len(segments)}")
            resp = {"id": req_id, "segments": segments, "error": None, "elapsed": elapsed}
        except Exception as e:
            elapsed = time.time() - t0
            _log(f"error {req_id}: {e}")
            traceback.print_exc(file=sys.stderr)
            resp = {"id": req_id, "segments": [], "error": str(e), "elapsed": elapsed}
        # Write to stdout
        try:
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
        except Exception as e:
            _log(f"failed to write response: {e}")

if __name__ == "__main__":
    main()
