# app/adtof_transcriber.py — ADTOF Frame-RNN with fast peak-pick (dense rolls).
from __future__ import annotations

import copy
import hashlib
import os
import threading
import time
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence

import numpy as np

# GM drum pitches: kick, snare, tom, hat, cymbal (same order as ADTOF LABELS_5).
ADTOF_DRUM_LABELS: List[int] = [35, 38, 47, 42, 49]

try:
    import torch
    from adtof_pytorch import get_default_weights_path
    from adtof_pytorch.model import (
        calculate_n_bins,
        create_frame_rnn_model,
        load_audio_for_model,
        load_pytorch_weights,
    )
    from adtof_pytorch.post_processing import LABELS_5, NotePeakPickingProcessor

    from .gpu_backend import resolve_adtof_torch_device, resolve_adtof_torch_device_label

    ADTOF_DRUM_LABELS = list(LABELS_5)
    ADTOF_AVAILABLE = True
except ImportError:
    ADTOF_AVAILABLE = False
    torch = None  # type: ignore
    NotePeakPickingProcessor = None  # type: ignore

# Per-class thresholds: kick, snare, tom, hat, cymbal (matches LABELS_5 order).
FAST_THRESHOLDS: List[float] = [0.16, 0.18, 0.24, 0.16, 0.22]

PITCH_TO_DRUM: Dict[int, str] = {
    35: "kick",
    38: "snare",
    47: "tom",
    42: "hat",
    49: "cymbal",
}

_MODEL = None
_WEIGHTS_PATH: Optional[str] = None

# In-memory memo for ADTOF classified_hits — single process, TTL 900 like stem_memory_cache.
_ADTOF_CACHE: dict[str, tuple[Dict, float]] = {}
_ADTOF_LOCK = threading.Lock()
_ADTOF_TTL_SEC = 900


def _adtof_ttl() -> int:
    raw = os.environ.get("RFALL_ADTOF_CACHE_TTL", "900").strip() if os.environ.get("RFALL_ADTOF_CACHE_TTL") else "900"
    try:
        return max(0, int(raw))
    except ValueError:
        return 900


def _adtof_purge_expired(now: Optional[float] = None) -> None:
    if _adtof_ttl() == 0:
        return
    now = now or time.time()
    expired = [k for k, (_, exp) in _ADTOF_CACHE.items() if exp <= now]
    for k in expired:
        _ADTOF_CACHE.pop(k, None)


def _adtof_cache_key(y: np.ndarray, sr: int, genre_params: Optional[Dict]) -> Optional[str]:
    # Key must reflect only drum stem content + ADTOF-relevant thresholds.
    # difficulty/mode/preset/lanes/chart_tag must NOT affect key (see audit).
    if y is None or getattr(y, "size", 0) == 0 or not sr:
        return None
    try:
        # Stem identity — hash of raw samples (float32 bytes). Deterministic for same wav.
        # File hash would require extra read; y already in memory.
        h = hashlib.sha256()
        # Ensure contiguous float32 for stable bytes.
        arr = np.ascontiguousarray(y, dtype=np.float32)
        h.update(arr.tobytes())
        h.update(str(int(sr)).encode("utf-8"))
        thresholds = _thresholds_for_genre(genre_params)
        # thresholds already incorporates FAST_THRESHOLDS, genre multipliers and RFALL_ADTOF_SNARE_THRESHOLD env.
        h.update(",".join(f"{t:.6f}" for t in thresholds).encode("utf-8"))
        return h.hexdigest()
    except Exception:
        return None


def drum_backend_name() -> str:
    raw = os.environ.get("RFALL_DRUM_BACKEND", "adtof_fast").strip().lower()
    if raw in ("adtof", "adtof_fast", "fastpick", "fast"):
        return "adtof_fast"
    if raw in ("heuristic", "librosa", "legacy", "off", "0"):
        return "heuristic"
    return raw


def is_adtof_available() -> bool:
    return ADTOF_AVAILABLE


def _resolve_weights_path() -> Optional[str]:
    env = os.environ.get("RFALL_ADTOF_WEIGHTS", "").strip()
    if env and os.path.isfile(env):
        return env
    if not ADTOF_AVAILABLE:
        return None
    try:
        return get_default_weights_path()
    except Exception:
        return None


def _get_model():
    global _MODEL, _WEIGHTS_PATH
    if not ADTOF_AVAILABLE:
        raise RuntimeError("adtof-pytorch not installed")
    weights = _resolve_weights_path()
    if _MODEL is not None and _WEIGHTS_PATH == weights:
        return _MODEL
    n_bins = calculate_n_bins()
    model = create_frame_rnn_model(n_bins)
    model.eval()
    if weights and os.path.isfile(weights):
        model = load_pytorch_weights(model, weights, strict=False)
    _WEIGHTS_PATH = weights
    _MODEL = model
    return _MODEL


class FastPeakPicker:
    """Shorter pre_avg/combine than ADTOF default — better on drum rolls."""

    def __init__(
        self,
        thresholds: Sequence[float] = FAST_THRESHOLDS,
        fps: int = 100,
        pre_avg: float = 0.03,
        combine: float = 0.008,
        pre_max: float = 0.015,
        post_max: float = 0.008,
    ):
        if isinstance(thresholds, (list, tuple)):
            self.processors = [
                NotePeakPickingProcessor(
                    threshold=float(t),
                    pre_avg=pre_avg,
                    post_avg=0.005,
                    pre_max=pre_max,
                    post_max=post_max,
                    combine=combine,
                    fps=fps,
                )
                for t in thresholds
            ]
        else:
            self.processors = NotePeakPickingProcessor(
                threshold=float(thresholds),
                pre_avg=pre_avg,
                post_avg=0.005,
                pre_max=pre_max,
                post_max=post_max,
                combine=combine,
                fps=fps,
            )
        self.fps = fps

    def pick(
        self,
        activations: np.ndarray,
        labels: Optional[Sequence[int]] = None,
    ) -> Dict[int, List[float]]:
        if labels is None:
            labels = ADTOF_DRUM_LABELS
        x = np.asarray(activations, dtype=np.float32)
        if x.ndim == 2:
            x = x[None, ...]
        process_list = (
            self.processors
            if isinstance(self.processors, list)
            else [self.processors] * len(labels)
        )
        result: Dict[int, List[float]] = {}
        for i, lab in enumerate(labels):
            peaks = process_list[i].process(x[0, :, i])
            result[int(lab)] = [float(t) for t, _ in peaks]
        return result


def _last_audible_time(y: np.ndarray, sr: int, threshold: float = 0.02, win_s: float = 0.1) -> float:
    win = max(1, int(win_s * sr))
    last = 0.0
    for i in range(0, max(0, len(y) - win), win):
        seg = y[i : i + win]
        if float(np.sqrt(np.mean(seg * seg))) > threshold:
            last = float(i / sr)
    return last


def _merge_close(times: List[float], gap: float = 0.05) -> List[float]:
    ordered = sorted(float(t) for t in times)
    if not ordered:
        return []
    out = [ordered[0]]
    for t in ordered[1:]:
        if t - out[-1] >= gap:
            out.append(t)
    return out


def _normalize_stem_for_transcription(y: np.ndarray, target_rms: float = 0.11) -> np.ndarray:
    """Boost quiet drum stems so ADTOF catches soft intro hits."""
    if y is None or len(y) == 0:
        return y
    x = np.asarray(y, dtype=np.float32)
    rms = float(np.sqrt(np.mean(x * x)))
    if rms < 1e-6 or rms >= target_rms:
        return x
    gain = min(4.0, target_rms / rms)
    return np.clip(x * gain, -1.0, 1.0)


def _thresholds_for_genre(genre_params: Optional[Dict]) -> List[float]:
    """Lower peak-pick thresholds when genre config asks for higher sensitivity."""
    thresholds = list(FAST_THRESHOLDS)
    if not genre_params:
        return thresholds
    kick_mult = float(genre_params.get("kick_sensitivity_multiplier", 1.0) or 1.0)
    snare_mult = float(genre_params.get("snare_sensitivity_multiplier", 1.0) or 1.0)
    tom_mult = float(genre_params.get("snare_sensitivity_multiplier", 1.0) or 1.0)
    thresholds[0] = max(0.07, thresholds[0] / max(0.35, kick_mult))
    thresholds[1] = max(0.06, thresholds[1] / max(0.35, snare_mult))
    thresholds[2] = max(0.10, thresholds[2] / max(0.35, tom_mult))
    env_snare = os.environ.get("RFALL_ADTOF_SNARE_THRESHOLD", "").strip()
    if env_snare:
        try:
            thresholds[1] = float(env_snare)
        except ValueError:
            pass
    return thresholds


def _merge_peak_maps(primary: Dict[int, List[float]], extra: Dict[int, List[float]], gap: float = 0.04) -> Dict[int, List[float]]:
    merged: Dict[int, List[float]] = {}
    for pitch in set(primary) | set(extra):
        times = _merge_close(list(primary.get(pitch, [])) + list(extra.get(pitch, [])), gap=gap)
        if times:
            merged[int(pitch)] = times
    return merged


def _clip_times(times: List[float], max_time: float) -> List[float]:
    return [t for t in times if 0.0 <= t <= max_time]


def _peaks_to_hit_data(peaks: Dict[int, List[float]], max_time: float) -> Dict:
    kick, snare, hat = [], [], []
    classified: List[Dict] = []
    for pitch, times in peaks.items():
        drum = PITCH_TO_DRUM.get(int(pitch), "perc")
        for t in _clip_times(times, max_time):
            classified.append({"time": float(t), "drum": drum})
            if drum == "kick":
                kick.append(t)
            elif drum == "snare":
                snare.append(t)
            elif drum == "hat":
                hat.append(t)

    classified.sort(key=lambda h: h["time"])
    all_times = _merge_close([h["time"] for h in classified])
    return {
        "kick_times": sorted(set(kick)),
        "snare_times": sorted(set(snare)),
        "hat_times": sorted(set(hat)),
        "classified_hits": classified,
        "dominant_onsets": all_times,
    }


def transcribe_drum_stem(
    audio_path: str,
    y: np.ndarray,
    sr: int,
    *,
    genre_params: Optional[Dict] = None,
    cancel_cb: Optional[Callable[[], None]] = None,
) -> Dict:
    """Run ADTOF fast-pick on drum stem path (same settings as exp_heartbeat_adtof_fastpick)."""
    if cancel_cb:
        cancel_cb()

    duration = float(len(y) / sr) if sr else 0.0
    tail = _last_audible_time(y, sr) + 0.25
    max_time = min(duration, tail) if tail > 0 else duration

    # In-memory memo — same drum stem + same genre thresholds → same classified_hits.
    # difficulty/mode/preset/lanes/chart_tag must NOT affect key (see audit).
    _cache_key: Optional[str] = _adtof_cache_key(y, sr, genre_params)
    if _cache_key is not None and _adtof_ttl() > 0:
        now = time.time()
        with _ADTOF_LOCK:
            _adtof_purge_expired(now)
            _cached_entry = _ADTOF_CACHE.get(_cache_key)
            if _cached_entry is not None:
                _cached_data, _cached_exp = _cached_entry
                if _cached_exp > now:
                    # Deep copy — caller may mutate lists/dicts downstream.
                    return copy.deepcopy(_cached_data)
                _ADTOF_CACHE.pop(_cache_key, None)

    device = resolve_adtof_torch_device()
    device_label = resolve_adtof_torch_device_label()

    model = _get_model()
    model.to(device)

    if cancel_cb:
        cancel_cb()

    y_norm = _normalize_stem_for_transcription(y)
    if y_norm is not y:
        import soundfile as sf
        import tempfile

        tmp = tempfile.NamedTemporaryFile(suffix="_adtof_norm.wav", delete=False)
        tmp_path = tmp.name
        tmp.close()
        try:
            sf.write(tmp_path, y_norm, sr)
            model_input_path = tmp_path
        except Exception:
            model_input_path = audio_path
    else:
        model_input_path = audio_path

    tensor = load_audio_for_model(model_input_path)
    tensor = tensor.to(device)
    with torch.no_grad():
        pred = model(tensor).cpu().numpy()

    if cancel_cb:
        cancel_cb()

    thresholds = _thresholds_for_genre(genre_params)
    peaks = FastPeakPicker(thresholds).pick(pred[0])
    soft_thresholds = list(thresholds)
    soft_thresholds[0] = max(0.06, soft_thresholds[0] - 0.05)
    soft_thresholds[1] = max(0.05, soft_thresholds[1] - 0.06)
    peaks_soft = FastPeakPicker(soft_thresholds).pick(pred[0])
    peaks = _merge_peak_maps(peaks, peaks_soft, gap=0.035)

    if model_input_path != audio_path:
        try:
            os.unlink(model_input_path)
        except OSError:
            pass

    data = _peaks_to_hit_data(peaks, max_time)
    print(
        f"[ADTOF/fast] device={device_label} hits={len(data['dominant_onsets'])} "
        f"kick={len(data['kick_times'])} snare={len(data['snare_times'])} hat={len(data['hat_times'])} "
        f"thr_k={thresholds[0]:.2f} thr_s={thresholds[1]:.2f} max_t={max_time:.1f}s"
    )
    # Memoize successful result — in-memory only, TTL 900, deep copy for isolation.
    if _cache_key is not None and _adtof_ttl() > 0:
        try:
            with _ADTOF_LOCK:
                _adtof_purge_expired()
                _ADTOF_CACHE[_cache_key] = (copy.deepcopy(data), time.time() + _adtof_ttl())
        except Exception:
            pass
    return data
