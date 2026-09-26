"""Hash-keyed temp_uploads layout (matches client NotesUtils.chart_id_from_song_path)."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path
from typing import Any, Optional

_SERVER_ROOT = Path(__file__).resolve().parent.parent
CANONICAL_TEMP_UPLOADS_DIR = _SERVER_ROOT / "temp_uploads"
LEGACY_TEMP_UPLOADS_DIR = Path("temp_uploads")
# Canonical stable path — always used for writes. Reads fallback to legacy if canonical missing/empty.
TEMP_UPLOADS_DIR = CANONICAL_TEMP_UPLOADS_DIR
META_FILENAME = "song_meta.json"


def _temp_uploads_dir_for_read() -> Path:
    # Prefer canonical; if canonical missing/empty and legacy exists with data, use legacy
    if CANONICAL_TEMP_UPLOADS_DIR.is_dir() and any(CANONICAL_TEMP_UPLOADS_DIR.iterdir()):
        return CANONICAL_TEMP_UPLOADS_DIR
    if LEGACY_TEMP_UPLOADS_DIR.is_dir() and any(LEGACY_TEMP_UPLOADS_DIR.iterdir()):
        # Legacy has data, canonical empty — fallback to legacy for reads
        return LEGACY_TEMP_UPLOADS_DIR
    return CANONICAL_TEMP_UPLOADS_DIR


def _resolve_song_dir_for_read(chart_id: str) -> Path:
    cid = str(chart_id or "").strip()
    if not cid:
        return CANONICAL_TEMP_UPLOADS_DIR
    canonical = CANONICAL_TEMP_UPLOADS_DIR / cid
    if canonical.is_dir():
        return canonical
    legacy = LEGACY_TEMP_UPLOADS_DIR / cid
    if legacy.is_dir():
        return legacy
    return canonical
_AUDIO_EXTENSIONS = frozenset({".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac"})


def normalize_song_path(song_path: str) -> str:
    return str(song_path or "").replace("\\", "/").strip()


def chart_id_from_song_path(song_path: str) -> str:
    normalized = normalize_song_path(song_path)
    if not normalized:
        return ""
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return digest[:16]


# Phase 1 — content identity (separate from path-based chart_id).
# chart_id = SHA256(normalized path)[:16] — path identity (rename changes it, content edit keeps it).
# audio_content_hash = SHA256(original bytes) — content identity (rename keeps it, content edit changes it).
# For future persistent stems: user://stems/{content_hash}_{kind}_{model}.mp3 (MP3, not WAV).
# Server WAV remains temporary. This phase adds helpers only — no behavior change.
def audio_content_hash(audio_path: str | Path) -> str:
    p = Path(audio_path) if not isinstance(audio_path, Path) else audio_path
    if not p.is_file():
        return ""
    h = hashlib.sha256()
    try:
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                if not chunk:
                    break
                h.update(chunk)
    except OSError:
        return ""
    return h.hexdigest()


def audio_content_hash16(audio_path: str | Path) -> str:
    full = audio_content_hash(audio_path)
    return full[:16] if full else ""


def bytes_content_hash(data: bytes | bytearray) -> str:
    if not data:
        return ""
    return hashlib.sha256(bytes(data)).hexdigest()


def resolve_chart_id(metadata: Optional[dict] = None, *, song_path: str = "") -> str:
    meta = metadata if isinstance(metadata, dict) else {}
    explicit = str(meta.get("chart_id", "")).strip().lower()
    if len(explicit) == 16 and all(c in "0123456789abcdef" for c in explicit):
        return explicit
    path = normalize_song_path(str(meta.get("song_path", song_path)))
    if path:
        return chart_id_from_song_path(path)
    return ""


def song_dir(chart_id: str) -> Path:
    return CANONICAL_TEMP_UPLOADS_DIR / str(chart_id or "").strip()


def legacy_song_dir(legacy_stem: str) -> Path:
    return CANONICAL_TEMP_UPLOADS_DIR / str(legacy_stem or "").strip()


def _legacy_song_dir_for_read(legacy_stem: str) -> Path:
    # For reads, fallback to legacy if canonical not found
    canonical = CANONICAL_TEMP_UPLOADS_DIR / str(legacy_stem or "").strip()
    if canonical.is_dir():
        return canonical
    legacy = LEGACY_TEMP_UPLOADS_DIR / str(legacy_stem or "").strip()
    if legacy.is_dir():
        return legacy
    return canonical


def is_hash_dir_name(name: str) -> bool:
    n = str(name or "").strip().lower()
    return len(n) == 16 and all(c in "0123456789abcdef" for c in n)


def song_folder_for_audio_path(audio_path: str, chart_id: str = "") -> Path:
    cid = str(chart_id or "").strip()
    if cid:
        # Use canonical for writes, but check legacy for reads
        canonical = CANONICAL_TEMP_UPLOADS_DIR / cid
        if canonical.is_dir():
            return canonical
        legacy = LEGACY_TEMP_UPLOADS_DIR / cid
        if legacy.is_dir():
            return legacy
        return canonical
    path = Path(audio_path)
    parent = path.parent
    # Check both canonical and legacy temp_uploads
    try:
        if parent.resolve() == CANONICAL_TEMP_UPLOADS_DIR.resolve() or parent.resolve() == LEGACY_TEMP_UPLOADS_DIR.resolve() or parent.name == "temp_uploads" or not parent.name:
            return CANONICAL_TEMP_UPLOADS_DIR / path.stem
        if parent.parent.resolve() == CANONICAL_TEMP_UPLOADS_DIR.resolve() or parent.parent.resolve() == LEGACY_TEMP_UPLOADS_DIR.resolve():
            if is_hash_dir_name(parent.name):
                return parent
        if parent.name == "temp_uploads":
            return CANONICAL_TEMP_UPLOADS_DIR / path.stem
    except Exception:
        if parent.name == "temp_uploads" or not parent.name:
            return CANONICAL_TEMP_UPLOADS_DIR / path.stem
        if parent.parent.name == "temp_uploads" and is_hash_dir_name(parent.name):
            return parent
        if parent.name == "temp_uploads":
            return CANONICAL_TEMP_UPLOADS_DIR / path.stem
    return parent


def meta_path(chart_id: str) -> Path:
    return song_dir(chart_id) / META_FILENAME


def write_song_meta(chart_id: str, payload: dict[str, Any]) -> None:
    if not chart_id:
        return
    folder = song_dir(chart_id)
    folder.mkdir(parents=True, exist_ok=True)
    path = meta_path(chart_id)
    try:
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError as exc:
        print(f"[SongStorage] meta write failed: {exc}")


def maybe_migrate_legacy_folder(chart_id: str, legacy_stem: str) -> bool:
    if not chart_id or not legacy_stem or chart_id == legacy_stem:
        return False
    target = song_dir(chart_id)
    if target.is_dir() and any(target.iterdir()):
        return False
    legacy = legacy_song_dir(legacy_stem)
    if not legacy.is_dir():
        return False
    try:
        if target.exists():
            shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(legacy, target)
        print(f"[SongStorage] legacy → hash: {legacy.name} → {chart_id}")
        return True
    except Exception as exc:
        print(f"[SongStorage] migrate failed {legacy} → {chart_id}: {exc}")
        return False


def chart_notes_filename(instrument: str, intent: str, lanes: int, chart_variant: str = "") -> str:
    inst = str(instrument or "drums").strip().lower() or "drums"
    mode = str(intent or "groove").strip().lower() or "groove"
    lane_n = max(int(lanes), 1)
    base = f"{inst}_{mode}_lanes{lane_n}"
    tag = str(chart_variant or "").strip().lower()
    if tag and tag not in ("default", "prod", "production", "main"):
        safe = "".join(c for c in tag if c.isalnum() or c == "_")
        if safe:
            return f"{base}_{safe}.rf"
    return f"{base}.rf"


def stem_wav_name(chart_id: str, stem_type: str = "drums") -> str:
    cid = str(chart_id or "track").strip() or "track"
    kind = str(stem_type or "drums").strip().lower() or "drums"
    return f"{cid}_{kind}.wav"


def is_temp_uploads_root_path(path: str | Path) -> bool:
    try:
        parent_resolved = Path(path).parent.resolve()
        if parent_resolved == CANONICAL_TEMP_UPLOADS_DIR.resolve():
            return True
        if parent_resolved == LEGACY_TEMP_UPLOADS_DIR.resolve():
            return True
        return parent_resolved == TEMP_UPLOADS_DIR.resolve()
    except Exception:
        return Path(path).parent.name == TEMP_UPLOADS_DIR.name


def ensure_audio_in_song_dir(
    temp_path: str | Path,
    chart_id: str,
    *,
    original_filename: str = "",
) -> Optional[Path]:
    """Move a root-level upload into temp_uploads/{chart_id}/ before root cleanup."""
    cid = str(chart_id or "").strip()
    if not cid:
        return None
    src = Path(temp_path)
    if not src.is_file():
        return None
    dest_dir = song_dir(cid)
    dest_dir.mkdir(parents=True, exist_ok=True)
    if src.parent.resolve() == dest_dir.resolve():
        return src
    if not is_temp_uploads_root_path(src):
        return None
    name = Path(str(original_filename or "").strip() or src.name).name
    dest = dest_dir / name
    if dest.is_file():
        return dest
    try:
        shutil.move(str(src), str(dest))
        print(f"[SongStorage] Аудио перенесено в папку трека: {dest}")
        return dest
    except Exception:
        try:
            shutil.copy2(str(src), str(dest))
            print(f"[SongStorage] Аудио скопировано в папку трека: {dest}")
            return dest
        except Exception as exc:
            print(f"[SongStorage] Не удалось перенести аудио в {dest}: {exc}")
            return None


def cleanup_temp_uploads_root_artifacts(
    *,
    temp_path: str | Path | None = None,
    chart_id: str = "",
    legacy_stem: str = "",
    original_filename: str = "",
) -> dict | None:
    """Delete stray audio files directly under temp_uploads/ (never song subfolders).

    When called from interactive "storage reclaim", we want a summary.
    For existing generation cleanup paths, keep backwards-compatibility by
    returning None when summary isn't requested.
    """
    candidates: set[Path] = set()
    freed_bytes: int = 0
    deleted_files: int = 0
    errors: int = 0

    if temp_path:
        root_file = Path(temp_path)
        if root_file.is_file() and is_temp_uploads_root_path(root_file):
            candidates.add(root_file)

    if chart_id and song_dir(chart_id).is_dir():
        stems_to_check: list[str] = []
        if legacy_stem.strip():
            stems_to_check.append(legacy_stem.strip())
        if original_filename.strip():
            stems_to_check.append(Path(original_filename).stem)
        for stem in stems_to_check:
            for ext in _AUDIO_EXTENSIONS:
                candidate = TEMP_UPLOADS_DIR / f"{stem}{ext}"
                if candidate.is_file():
                    candidates.add(candidate)

    for path in sorted(candidates, key=lambda p: p.name):
        try:
            try:
                freed_bytes += int(path.stat().st_size)
            except OSError:
                pass
            path.unlink(missing_ok=True)
            deleted_files += 1
            print(f"[SongStorage] Удалён корневой upload: {path.name}")
        except Exception as exc:
            errors += 1
            print(f"[SongStorage] Не удалось удалить корневой upload {path}: {exc}")

    # If nothing was deleted, return still-empty summary for reclaim routes.
    # For older callers, their "expected type" was None; we keep it by returning
    # a dict only when arguments indicate a reclaim/summary use.
    if temp_path is not None or chart_id or legacy_stem or original_filename:
        return {
            "deleted_files": deleted_files,
            "freed_bytes": freed_bytes,
            "errors": errors,
        }
    return None
