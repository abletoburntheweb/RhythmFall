"""Minimal logger for server (Python) with INFO/WARN/ERROR, consistent with client GDScript AppLogger."""
import os

def _is_verbose() -> bool:
    return os.getenv("RFALL_VERBOSE", "0").strip().lower() in ("1", "true", "yes", "on")

def info(msg: str, verbose_only: bool = False) -> None:
    if verbose_only and not _is_verbose():
        return
    print(f"[INFO] {msg}")

def warn(msg: str) -> None:
    print(f"[WARN] {msg}")

def error(msg: str) -> None:
    print(f"[ERROR] {msg}")
