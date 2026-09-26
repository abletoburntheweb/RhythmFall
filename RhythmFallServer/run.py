# run.py
import os
import signal
from pathlib import Path

from app import create_app

app = create_app()


def _write_worker_pid_file() -> None:
    pid_file = os.environ.get("RF_PID_FILE", "").strip()
    if not pid_file:
        return
    path = Path(pid_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(os.getpid()), encoding="utf-8")


def _clear_worker_pid_file() -> None:
    pid_file = os.environ.get("RF_PID_FILE", "").strip()
    if not pid_file:
        return
    path = Path(pid_file)
    if path.is_file():
        path.unlink()


def _handle_exit_signal(signum, _frame) -> None:
    _clear_worker_pid_file()
    raise SystemExit(128 + int(signum))


if __name__ == "__main__":
    for sig_name in ("SIGINT", "SIGTERM", "SIGBREAK"):
        sig = getattr(signal, sig_name, None)
        if sig is not None:
            signal.signal(sig, _handle_exit_signal)
    bind_host = os.environ.get("RF_BIND_HOST", "0.0.0.0")
    port = int(os.environ.get("RF_BIND_PORT", "5000"))
    debug = os.environ.get("RF_FLASK_DEBUG", "0").strip().lower() in ("1", "true", "yes", "on")
    print(f"[RhythmFallServer] http://{bind_host}:{port}/", flush=True)
    _write_worker_pid_file()
    try:
        app.run(debug=debug, use_reloader=False, port=port, host=bind_host)
    finally:
        _clear_worker_pid_file()
