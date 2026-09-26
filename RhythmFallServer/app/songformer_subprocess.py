#!/usr/bin/env python3
"""Isolated SongFormer subprocess — called by songformer_bridge.py via .venv-songformer

Usage: python songformer_subprocess.py /path/to/audio.wav
Output: JSON list to stdout: [{"start":0.0,"end":16.1,"label":"intro"}, ...]
Logs to stderr.

This script is intentionally minimal and isolated: it imports heavy deps only here,
so the main server (app/rhythm_dna.py) never imports transformers/torch unless needed.
"""

import sys
import os
import json
from pathlib import Path

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def main():
    if len(sys.argv) < 2:
        eprint("Usage: songformer_subprocess.py <audio_path>")
        sys.exit(1)
    audio_path = Path(sys.argv[1])
    if not audio_path.is_file():
        eprint(f"audio not found: {audio_path}")
        print("[]")
        sys.exit(0)

    # Resolve local_dir
    _env_dir = os.environ.get("SONGFORMER_LOCAL_DIR", "").strip()
    local_dir = Path(_env_dir) if _env_dir else Path(__file__).resolve().parent.parent / "models" / "SongFormer"
    if not local_dir.is_dir() or not (local_dir / "config.json").is_file():
        # Fallback to sibling models/SongFormer
        _fallback = Path(__file__).resolve().parent.parent / "models" / "SongFormer"
        if _fallback.is_dir() and (_fallback / "config.json").is_file():
            local_dir = _fallback
        else:
            # Try production path
            _prod = Path(r"D:\Games\godotprojects\RhythmFall\RhythmFallServer\models\SongFormer")
            if _prod.is_dir() and (_prod / "config.json").is_file():
                local_dir = _prod
    if not (local_dir / "config.json").is_file():
        eprint(f"SongFormer local_dir not found: {local_dir} (env={_env_dir})")
        print("[]")
        sys.exit(0)

    # Patch check_imports to ignore local 'model'
    try:
        import transformers.dynamic_module_utils
        transformers.dynamic_module_utils.check_imports = lambda *a, **k: []
    except Exception:
        pass

    # Add local_dir to path for `from model import Model` etc.
    if str(local_dir) not in sys.path:
        sys.path.insert(0, str(local_dir))

    try:
        from transformers import AutoModel
    except Exception as e:
        eprint(f"Failed to import transformers: {e}")
        print("[]")
        sys.exit(0)

    try:
        # Use local_files_only to avoid internet
        model = AutoModel.from_pretrained(
            str(local_dir),
            trust_remote_code=True,
            local_files_only=True,
        )
        model.eval()
    except Exception as e:
        eprint(f"Failed to load SongFormer model from {local_dir}: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        print("[]")
        sys.exit(0)

    try:
        # SongFormer handles 24k internally via librosa.load(sr=24000), so we can pass path directly
        # It also handles mono/stereo via librosa
        result = model(str(audio_path))
        # result is list of dicts with start/end/label
        # Ensure JSON serializable
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
        print(json.dumps(out, ensure_ascii=False))
    except Exception as e:
        eprint(f"Inference failed: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        print("[]")
        sys.exit(0)

if __name__ == "__main__":
    main()
