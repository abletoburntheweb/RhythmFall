"""Short-lived in-memory stem cache (no persistent temp_uploads reuse on disk)."""
from __future__ import annotations

import hashlib
import os
import shutil
import threading
import time
from pathlib import Path
from typing import Optional

_LOCK = threading.Lock()
_CACHE: dict[str, tuple[str, float]] = {}
_CACHE_DIR = Path(os.environ.get("TEMP", "/tmp")) / "RhythmFall" / "stems"


def _ttl_seconds() -> int:
    raw = os.environ.get("RFALL_STEM_CACHE_TTL", "900").strip()
    try:
        return max(0, int(raw))
    except ValueError:
        return 900


def is_enabled() -> bool:
    return _ttl_seconds() > 0


def ttl_seconds() -> int:
    return _ttl_seconds()

def _purge_expired(now: Optional[float] = None) -> None:
    now = now or time.time()
    expired = [key for key, (_, exp) in _CACHE.items() if exp <= now]
    for key in expired:
        path, _ = _CACHE.pop(key, ("", 0.0))
        try:
            Path(path).unlink(missing_ok=True)
        except Exception:
            pass


def _audio_key(audio_path: Path) -> str:
    digest = hashlib.sha256()
    with open(audio_path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _cache_id(audio_path: str, stem_type: str = "drums") -> Optional[str]:
    path = Path(audio_path)
    if not path.is_file():
        return None
    kind = str(stem_type or "drums").strip().lower() or "drums"
    return f"{_audio_key(path)}:{kind}"


def get_cached_stem(audio_path: str, stem_type: str = "drums", content_hash: Optional[str] = None) -> Optional[str]:
    kind = str(stem_type or "drums").strip().lower() or "drums"
    # Build cache_id for logging even when disabled/invalid.
    _log_cache_id: Optional[str] = None
    if isinstance(content_hash, str) and content_hash.strip():
        _h = content_hash.strip().lower()
        if len(_h) == 64 and all(c in "0123456789abcdef" for c in _h):
            _log_cache_id = f"{_h}:{kind}"
    if _log_cache_id is None:
        try:
            _log_cache_id = _cache_id(audio_path, stem_type)
        except Exception:
            _log_cache_id = None
    if not is_enabled():
        print(f"[StemMemoryCache] MISS reason=disabled key={_log_cache_id or '<unknown>:'+kind}")
        return None
    cache_id: Optional[str] = _log_cache_id
    if not cache_id:
        # No valid audio path/hash
        _fallback_key = f"<unknown>:{kind}"
        if isinstance(content_hash, str) and content_hash.strip():
            _fallback_key = f"{content_hash.strip().lower()}:{kind}"
        print(f"[StemMemoryCache] MISS reason=invalid_key key={_fallback_key}")
        return None
    now = time.time()
    with _LOCK:
        _purge_expired(now)
        entry = _CACHE.get(cache_id)
        if not entry:
            print(f"[StemMemoryCache] MISS reason=no_entry key={cache_id}")
            return None
        cached_path, expires_at = entry
        if expires_at <= now:
            print(f"[StemMemoryCache] MISS reason=expired key={cache_id} path={cached_path} ttl_remaining=0")
            _CACHE.pop(cache_id, None)
            return None
        if not Path(cached_path).is_file():
            print(f"[StemMemoryCache] MISS reason=file_missing key={cache_id} path={cached_path}")
            _CACHE.pop(cache_id, None)
            return None
        ttl_remaining = int(expires_at - now)
        print(f"[StemMemoryCache] HIT key={cache_id} path={cached_path} ttl_remaining={ttl_remaining}")
        return cached_path


def store_cached_stem(audio_path: str, stem_path: str, stem_type: str = "drums", content_hash: Optional[str] = None) -> Optional[str]:
    kind = str(stem_type or "drums").strip().lower() or "drums"
    if not is_enabled():
        print(f"[StemMemoryCache] STORE SKIP reason=disabled key=<unknown>:{kind} ttl={_ttl_seconds()}")
        return None
    src = Path(stem_path)
    audio = Path(audio_path)
    if not src.is_file():
        print(f"[StemMemoryCache] STORE SKIP reason=source_missing src={str(src)} kind={kind}")
        return None
    if not audio.is_file():
        print(f"[StemMemoryCache] STORE SKIP reason=audio_missing audio={str(audio)} kind={kind}")
        return None
    cache_id: Optional[str] = None
    if isinstance(content_hash, str) and content_hash.strip():
        h = content_hash.strip().lower()
        if len(h) == 64 and all(c in "0123456789abcdef" for c in h):
            cache_id = f"{h}:{kind}"
    if cache_id is None:
        try:
            cache_id = _cache_id(audio_path, stem_type)
        except Exception as _e:
            print(f"[StemMemoryCache] STORE SKIP reason=hash_error key=<unknown>:{kind} error={type(_e).__name__}: {_e}")
            return None
    if not cache_id:
        print(f"[StemMemoryCache] STORE SKIP reason=invalid_key audio={str(audio)} kind={kind}")
        return None
    try:
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    except Exception as _e:
        print(f"[StemMemoryCache] STORE FAIL reason=mkdir key={cache_id} error={type(_e).__name__}: {_e}")
        return None
    dest = _CACHE_DIR / f"{cache_id.split(':', 1)[0][:16]}_{kind}.wav"
    try:
        shutil.copy2(src, dest)
    except Exception as _e:
        print(f"[StemMemoryCache] STORE FAIL reason=copy key={cache_id} src={str(src)} dst={str(dest)} error={type(_e).__name__}: {_e}")
        return None
    # Verify dest exists and size
    try:
        if not dest.is_file() or dest.stat().st_size < 1024:
            print(f"[StemMemoryCache] STORE FAIL reason=copy_verify key={cache_id} dst={str(dest)}")
            return None
    except Exception as _e:
        print(f"[StemMemoryCache] STORE FAIL reason=copy_verify key={cache_id} error={type(_e).__name__}: {_e}")
        return None
    ttl = _ttl_seconds()
    expires_at = time.time() + ttl
    with _LOCK:
        _purge_expired()
        old = _CACHE.get(cache_id)
        if old and old[0] != str(dest):
            try:
                Path(old[0]).unlink(missing_ok=True)
            except Exception:
                pass
        _CACHE[cache_id] = (str(dest), expires_at)
    print(f"[StemMemoryCache] STORE HIT key={cache_id} src={str(src)} dst={str(dest)} ttl={ttl}")
    return str(dest)
