"""Production audio-section detection (A2d algorithm).

Ports the validated A2d offline section-analysis algorithm into the production
server. The algorithm is preserved verbatim from the original spike; this module
exposes `analyze_mix_sections` (full behaviour) and a thin production-friendly
wrapper `build_structure_sections` that returns a minimal list of sections with
gentle beat/bar snapping.
"""
from __future__ import annotations

import numpy as np
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple
import librosa
from scipy.cluster.hierarchy import fcluster, linkage
from scipy.spatial.distance import pdist
from app.rhythm_dna import build_audio_structure_boundaries


def _checkerboard_novelty(R, width: int = 16):
    """Diagonal novelty from affinity SSM (checkerboard kernel)."""
    import numpy as np

    n = int(R.shape[0])
    w = max(2, int(width))
    kernel = np.ones((2 * w, 2 * w), dtype=float)
    kernel[:w, :w] = 1.0
    kernel[w:, w:] = 1.0
    kernel[:w, w:] = -1.0
    kernel[w:, :w] = -1.0
    # Normalize so flat regions ~0
    kernel /= float(np.abs(kernel).sum())
    nov = np.zeros(n, dtype=float)
    for i in range(w, n - w):
        patch = R[i - w : i + w, i - w : i + w]
        nov[i] = float(np.sum(patch * kernel))
    nov = np.maximum(0.0, nov)
    if nov.max() > 0:
        nov = nov / float(nov.max())
    return nov


def _normalize_curve(x):
    import numpy as np

    arr = np.asarray(x, dtype=float)
    arr = np.nan_to_num(arr, nan=0.0, posinf=0.0, neginf=0.0)
    arr = np.maximum(0.0, arr)
    peak = float(arr.max()) if arr.size else 0.0
    if peak <= 1e-12:
        return arr
    return arr / peak


def _smooth_ma(x, win: int):
    import numpy as np

    w = max(1, int(win))
    if w % 2 == 0:
        w += 1
    if w <= 1 or len(x) < 3:
        return np.asarray(x, dtype=float)
    kernel = np.ones(w, dtype=float) / float(w)
    return np.convolve(np.asarray(x, dtype=float), kernel, mode="same")


def _feature_novelty(y, sr: int, hop_length: int):
    """Multi-signal novelty in feature frames (same hop as chroma/mfcc)."""
    import librosa
    import numpy as np

    rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]
    rms_d = _normalize_curve(np.abs(np.diff(rms, prepend=float(rms[0]))))
    rms_d = _smooth_ma(rms_d, max(5, int(round(sr / hop_length / 8.0))))

    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)
    chroma_d = _normalize_curve(np.linalg.norm(np.diff(chroma, axis=1, prepend=chroma[:, :1]), axis=0))
    chroma_d = _smooth_ma(chroma_d, max(5, int(round(sr / hop_length / 6.0))))

    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=8, hop_length=hop_length)
    mfcc_d = _normalize_curve(np.linalg.norm(np.diff(mfcc, axis=1, prepend=mfcc[:, :1]), axis=0))
    mfcc_d = _smooth_ma(mfcc_d, max(5, int(round(sr / hop_length / 6.0))))

    # SSM novelty on beat-ish sync grid, then upsample to feature frames.
    sync_hop = max(1, int(round(1.0 * sr / hop_length)))
    chroma_sync = librosa.util.sync(chroma, np.arange(0, chroma.shape[1], sync_hop), aggregate=np.mean)
    R = librosa.segment.recurrence_matrix(
        chroma_sync, mode="affinity", metric="cosine", sym=True, width=3, self=False
    )
    try:
        R = librosa.segment.path_enhance(R, n=9)
    except Exception:
        pass
    ssm_nov = _checkerboard_novelty(R, width=max(3, int(round(8.0 / 1.0))))
    ssm_full = np.zeros(chroma.shape[1], dtype=float)
    for i, val in enumerate(ssm_nov):
        a = int(i * sync_hop)
        b = min(chroma.shape[1], int((i + 1) * sync_hop))
        if a < b:
            ssm_full[a:b] = float(val)
    ssm_full = _normalize_curve(_smooth_ma(ssm_full, max(5, sync_hop)))

    n = min(len(rms_d), len(chroma_d), len(mfcc_d), len(ssm_full))
    combo = 0.30 * rms_d[:n] + 0.30 * chroma_d[:n] + 0.20 * mfcc_d[:n] + 0.20 * ssm_full[:n]
    return _normalize_curve(combo), chroma, mfcc, rms


def _peak_times_from_novelty(
    nov,
    *,
    sr: int,
    hop_length: int,
    duration: float,
    min_seg_s: float,
    target_bounds: int,
) -> List[Tuple[float, float]]:
    """Return (novelty_score, time_s) candidates — stronger peaks, wider wait (fewer overcuts)."""
    import librosa
    import numpy as np

    if nov.size < 8:
        return []
    # Wait ~ almost one min section so chorus interiors don't sprout 3 cuts.
    wait = max(3, int(round(min_seg_s * 0.85 * sr / hop_length)))
    delta = max(0.06, float(np.percentile(nov, 70)) * 0.28)
    peaks = librosa.util.peak_pick(
        nov,
        pre_max=wait,
        post_max=wait,
        pre_avg=wait,
        post_avg=wait,
        delta=delta,
        wait=wait,
    )
    scored: List[Tuple[float, float]] = []
    for p in peaks:
        t = float(librosa.frames_to_time(int(p), sr=sr, hop_length=hop_length))
        if min_seg_s * 0.7 <= t <= duration - min_seg_s * 0.7:
            scored.append((float(nov[int(p)]), round(t, 1)))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return scored[: max(target_bounds * 3, target_bounds)]


def _nms_boundaries(
    scored: Sequence[Tuple[float, float]],
    *,
    min_gap_s: float,
    max_keep: int,
) -> List[float]:
    """Greedy keep strongest peaks with min gap (reduces D/E/F shredding one chorus)."""
    kept: List[Tuple[float, float]] = []
    for score, t in sorted(scored, key=lambda x: (-x[0], x[1])):
        if any(abs(t - kt) < min_gap_s for _, kt in kept):
            continue
        kept.append((score, t))
        if len(kept) >= max_keep:
            break
    return sorted(t for _, t in kept)


def _trim_to_budget(
    bounds: Sequence[float],
    *,
    nov,
    sr: int,
    hop_length: int,
    duration: float,
    max_bounds: int,
    max_seg_s: float,
) -> List[float]:
    """Drop weakest boundaries while resulting gaps stay ≤ max_seg_s."""
    import librosa

    cur = sorted(float(t) for t in bounds if 0.0 < float(t) < duration)
    if len(cur) <= max_bounds:
        return cur

    def _score(t: float) -> float:
        f = int(librosa.time_to_frames(t, sr=sr, hop_length=hop_length))
        f = min(max(f, 0), len(nov) - 1)
        return float(nov[f])

    while len(cur) > max_bounds:
        # Candidate removals that won't create a mega-gap
        points = [0.0] + cur + [duration]
        removable: List[Tuple[float, float]] = []
        for i, t in enumerate(cur):
            gap = points[i + 2] - points[i]  # neighbors around t
            if gap <= max_seg_s * 1.05:
                removable.append((_score(t), t))
        if not removable:
            break
        removable.sort(key=lambda x: (x[0], x[1]))  # weakest first
        drop = removable[0][1]
        cur = [t for t in cur if abs(t - drop) > 0.05]
    return cur


def _enforce_segment_lengths(
    bound_times: Sequence[float],
    *,
    duration: float,
    min_seg_s: float,
    max_seg_s: float,
    nov=None,
    sr: int = 22050,
    hop_length: int = 512,
) -> List[float]:
    """Keep gaps in [min_seg_s, max_seg_s] using local novelty when available."""
    import librosa
    import numpy as np

    points = [0.0] + sorted(float(t) for t in bound_times if 0.0 < float(t) < duration) + [duration]
    # Fill long gaps
    filled: List[float] = [points[0]]
    for nxt in points[1:]:
        prev = filled[-1]
        gap = nxt - prev
        if gap <= max_seg_s * 1.05:
            filled.append(nxt)
            continue
        n_cuts = int(np.ceil(gap / max_seg_s))
        ideal = [prev + gap * (i / n_cuts) for i in range(1, n_cuts)]
        for ideal_t in ideal:
            lo = prev + min_seg_s * 0.75
            hi = nxt - min_seg_s * 0.75
            if hi <= lo:
                continue
            if nov is None or nov.size == 0:
                cut = min(max(ideal_t, lo), hi)
            else:
                f0 = max(0, int(librosa.time_to_frames(lo, sr=sr, hop_length=hop_length)))
                f1 = min(len(nov) - 1, int(librosa.time_to_frames(hi, sr=sr, hop_length=hop_length)))
                if f1 <= f0:
                    cut = min(max(ideal_t, lo), hi)
                else:
                    window = nov[f0 : f1 + 1]
                    # Prefer peak near ideal time
                    ideal_f = int(librosa.time_to_frames(ideal_t, sr=sr, hop_length=hop_length))
                    weights = np.exp(-0.5 * ((np.arange(f0, f1 + 1) - ideal_f) / max(3.0, (f1 - f0) * 0.25)) ** 2)
                    cut_f = int(f0 + int(np.argmax(window * weights)))
                    cut = float(librosa.frames_to_time(cut_f, sr=sr, hop_length=hop_length))
                    cut = min(max(cut, lo), hi)
            filled.append(round(cut, 1))
            prev = filled[-1]
        filled.append(round(nxt, 1))

    # Drop endpoints; prune too-close internals
    internal = [t for t in filled[1:-1] if min_seg_s * 0.55 < t < duration - min_seg_s * 0.55]
    pruned: List[float] = []
    for t in internal:
        if not pruned or t - pruned[-1] >= min_seg_s * 0.8:
            pruned.append(round(t, 1))
        elif nov is not None and nov.size:
            # Keep stronger novelty of the two close peaks
            f_old = int(librosa.time_to_frames(pruned[-1], sr=sr, hop_length=hop_length))
            f_new = int(librosa.time_to_frames(t, sr=sr, hop_length=hop_length))
            f_old = min(max(f_old, 0), len(nov) - 1)
            f_new = min(max(f_new, 0), len(nov) - 1)
            if float(nov[f_new]) > float(nov[f_old]):
                pruned[-1] = round(t, 1)
    return pruned


def _label_sections(
    features: "Any",
    bounds_frames: Sequence[int],
    n_frames: int,
    sim_threshold: float = 0.72,
) -> List[Dict[str, Any]]:
    """Cut → mean feature; hierarchical cluster → letters A/B/C (repeats share id)."""
    import numpy as np
    from scipy.cluster.hierarchy import fcluster, linkage
    from scipy.spatial.distance import pdist

    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    ends = list(bounds_frames) + [n_frames]
    raw: List[Dict[str, Any]] = []
    centroids: List[np.ndarray] = []
    start = 0
    for end in ends:
        end = max(start + 1, min(int(end), n_frames))
        chunk = features[:, start:end]
        if chunk.size == 0:
            start = end
            continue
        cen = np.mean(chunk, axis=1)
        norm = float(np.linalg.norm(cen)) + 1e-9
        cen = cen / norm
        energy = float(np.mean(np.square(chunk)))
        raw.append(
            {
                "start_frame": start,
                "end_frame": end,
                "energy": round(energy, 5),
            }
        )
        centroids.append(cen)
        start = end

    if not centroids:
        return []

    X = np.vstack(centroids)
    n = len(centroids)
    if n == 1:
        labels = [1]
    else:
        # Prefer a small alphabet (A–F-ish) with real repeats, not one mega-cluster.
        target_k = max(3, min(8, int(round(n * 0.55))))
        condensed = pdist(X, metric="cosine")
        Z = linkage(condensed, method="average")
        labels = list(fcluster(Z, t=target_k, criterion="maxclust"))
        # If maxclust still collapses (rare), fall back to distance cut from sim_threshold.
        if len(set(labels)) < 2 and n >= 4:
            dist_t = max(0.05, min(0.4, 1.0 - float(sim_threshold)))
            labels = list(fcluster(Z, t=dist_t, criterion="distance"))

    # Map cluster id → letter by first appearance order
    cluster_to_letter: Dict[int, str] = {}
    segments: List[Dict[str, Any]] = []
    for i, seg in enumerate(raw):
        cid = int(labels[i])
        if cid not in cluster_to_letter:
            idx = len(cluster_to_letter)
            cluster_to_letter[cid] = letters[idx] if idx < len(letters) else f"S{idx}"
        # similar_score: mean cosine to other members of same cluster
        same = [j for j, lab in enumerate(labels) if int(lab) == cid and j != i]
        sim = 0.0
        if same:
            sim = float(np.mean([np.dot(centroids[i], centroids[j]) for j in same]))
        segments.append(
            {
                **seg,
                "section": cluster_to_letter[cid],
                "similar_score": round(sim, 3),
            }
        )
    return segments


def _sections_from_bounds(
    *,
    y,
    sr: int,
    hop_length: int,
    duration: float,
    chroma,
    mfcc,
    rms,
    pruned: List[float],
    sim_threshold: float,
    max_seg_s: float,
    merge_same_letter: bool,
) -> List[Dict[str, Any]]:
    import librosa
    import numpy as np

    mfcc_z = (mfcc - np.mean(mfcc, axis=1, keepdims=True)) / (np.std(mfcc, axis=1, keepdims=True) + 1e-6)
    rms_n = (rms - float(np.mean(rms))) / (float(np.std(rms)) + 1e-6)
    feats = np.vstack([chroma, mfcc_z * 0.45, rms_n.reshape(1, -1) * 0.4])
    n_frames = min(feats.shape[1], chroma.shape[1], len(rms))
    feats = feats[:, :n_frames]

    bound_feat = [
        min(n_frames - 1, int(librosa.time_to_frames(t, sr=sr, hop_length=hop_length)))
        for t in pruned
    ]
    labeled = _label_sections(feats, bound_feat, n_frames, sim_threshold=sim_threshold)

    sections: List[Dict[str, Any]] = []
    for seg in labeled:
        start_s = float(librosa.frames_to_time(seg["start_frame"], sr=sr, hop_length=hop_length))
        end_s = float(librosa.frames_to_time(seg["end_frame"], sr=sr, hop_length=hop_length))
        if end_s - start_s < 2.5:
            continue
        sections.append(
            {
                "start_s": round(start_s, 1),
                "end_s": round(min(end_s, duration), 1),
                "section": seg["section"],
                "energy": seg["energy"],
                "similar_score": seg["similar_score"],
            }
        )

    if not merge_same_letter:
        return sections

    merged: List[Dict[str, Any]] = []
    for seg in sections:
        if (
            merged
            and merged[-1]["section"] == seg["section"]
            and (seg["end_s"] - merged[-1]["start_s"]) <= max_seg_s * 1.15
        ):
            merged[-1]["end_s"] = seg["end_s"]
            merged[-1]["energy"] = round(0.5 * (merged[-1]["energy"] + seg["energy"]), 5)
        else:
            merged.append(dict(seg))
    return merged


def _seg_centroid(feats, start_s: float, end_s: float, *, sr: int, hop_length: int):
    import librosa
    import numpy as np

    f0 = max(0, int(librosa.time_to_frames(start_s, sr=sr, hop_length=hop_length)))
    f1 = min(feats.shape[1], max(f0 + 1, int(librosa.time_to_frames(end_s, sr=sr, hop_length=hop_length))))
    chunk = feats[:, f0:f1]
    cen = np.mean(chunk, axis=1)
    return cen / (float(np.linalg.norm(cen)) + 1e-9)


def _boundary_strength(nov, t: float, *, sr: int, hop_length: int) -> float:
    import librosa

    if nov is None or getattr(nov, "size", 0) == 0:
        return 0.0
    f = int(librosa.time_to_frames(t, sr=sr, hop_length=hop_length))
    f = min(max(f, 0), len(nov) - 1)
    # local max in ±0.6s
    rad = max(1, int(round(0.6 * sr / hop_length)))
    lo = max(0, f - rad)
    hi = min(len(nov), f + rad + 1)
    return float(max(nov[lo:hi])) if hi > lo else float(nov[f])


def _merge_adjacent_once(
    cur: List[Dict[str, Any]],
    *,
    feats,
    nov,
    sr: int,
    hop_length: int,
    hard_max_s: float,
    soft_max_s: float,
    weak_bound: float,
    sim_merge: float,
    short_s: float,
    prefer_same_letter: bool,
    same_letter_only: bool = False,
) -> bool:
    """Try one best merge. Returns True if merged."""
    import numpy as np

    best_i = -1
    best_key = None
    for i in range(len(cur) - 1):
        a, b = cur[i], cur[i + 1]
        start = float(a["start_s"])
        end = float(b["end_s"])
        joined = end - start
        len_a = float(a["end_s"]) - start
        len_b = end - float(b["start_s"])
        bound_t = float(b["start_s"])
        strength = _boundary_strength(nov, bound_t, sr=sr, hop_length=hop_length)
        ca = _seg_centroid(feats, start, float(a["end_s"]), sr=sr, hop_length=hop_length)
        cb = _seg_centroid(feats, float(b["start_s"]), end, sr=sr, hop_length=hop_length)
        sim = float(np.dot(ca, cb))
        same_letter = str(a.get("section")) == str(b.get("section"))
        short_side = short_s > 0 and min(len_a, len_b) <= short_s
        very_similar = sim >= (sim_merge + 0.06)
        # Soft cap ONLY for same-letter (chorus halves). Cross-letter stays on hard_max
        # so Verse doesn't get eaten by Chorus.
        limit = soft_max_s if same_letter else hard_max_s
        if joined > limit:
            continue
        allow = False
        if same_letter and strength < weak_bound + 0.15:
            allow = True
        elif same_letter and prefer_same_letter and sim >= sim_merge - 0.10 and strength < weak_bound + 0.22:
            allow = True
        elif (not same_letter_only) and (not same_letter) and strength < weak_bound and sim >= sim_merge - 0.05:
            allow = True
        elif (not same_letter_only) and (not same_letter) and short_side and sim >= sim_merge:
            allow = True
        if not allow:
            continue
        key = (0 if same_letter else 1, 0 if very_similar else 1, strength, -sim, min(len_a, len_b))
        if best_key is None or key < best_key:
            best_key = key
            best_i = i
    if best_i < 0:
        return False
    a, b = cur[best_i], cur[best_i + 1]
    len_a = float(a["end_s"]) - float(a["start_s"])
    len_b = float(b["end_s"]) - float(b["start_s"])
    keep_letter = b.get("section", a.get("section")) if len_b > len_a else a.get("section")
    a["end_s"] = b["end_s"]
    a["section"] = keep_letter
    a["energy"] = round(0.5 * (float(a.get("energy", 0)) + float(b.get("energy", 0))), 5)
    del cur[best_i + 1]
    return True


def _split_mega_sections(
    sections: List[Dict[str, Any]],
    *,
    nov,
    sr: int,
    hop_length: int,
    min_seg_s: float,
    mega_s: float,
) -> List[Dict[str, Any]]:
    """Only split truly huge blocks (practice-useless), not soft-merged choruses."""
    import librosa
    import numpy as np

    out: List[Dict[str, Any]] = []
    for seg in sections:
        start = float(seg["start_s"])
        end = float(seg["end_s"])
        length = end - start
        if length <= mega_s or nov is None or getattr(nov, "size", 0) == 0:
            out.append(seg)
            continue
        lo = start + max(min_seg_s, length * 0.28)
        hi = end - max(min_seg_s, length * 0.28)
        if hi <= lo:
            out.append(seg)
            continue
        f0 = max(0, int(librosa.time_to_frames(lo, sr=sr, hop_length=hop_length)))
        f1 = min(len(nov) - 1, int(librosa.time_to_frames(hi, sr=sr, hop_length=hop_length)))
        if f1 <= f0:
            out.append(seg)
            continue
        cut_f = int(f0 + int(np.argmax(nov[f0 : f1 + 1])))
        cut = float(librosa.frames_to_time(cut_f, sr=sr, hop_length=hop_length))
        left = dict(seg)
        left["end_s"] = round(cut, 1)
        right = dict(seg)
        right["start_s"] = round(cut, 1)
        out.append(left)
        out.append(right)
    return out


def _merge_pass(
    sections: List[Dict[str, Any]],
    *,
    feats,
    nov,
    sr: int,
    hop_length: int,
    duration: float,
    max_seg_s: float,
    min_seg_s: float,
    soft_max_s: float = 48.0,
    mega_s: float = 70.0,
    weak_bound: float = 0.30,
    sim_merge: float = 0.80,
    short_s: float = 12.0,
) -> List[Dict[str, Any]]:
    """Merge overcuts / swallow short chunks; soft-glue same-letter / chorus-like."""
    if not sections:
        return sections

    cur = [dict(s) for s in sections]
    # Pass 1: general merge under hard/soft caps
    while _merge_adjacent_once(
        cur,
        feats=feats,
        nov=nov,
        sr=sr,
        hop_length=hop_length,
        hard_max_s=max_seg_s * 1.12,
        soft_max_s=soft_max_s,
        weak_bound=weak_bound,
        sim_merge=sim_merge,
        short_s=short_s,
        prefer_same_letter=True,
    ):
        pass

    cur = _split_mega_sections(
        cur, nov=nov, sr=sr, hop_length=hop_length, min_seg_s=min_seg_s, mega_s=mega_s
    )
    cur = _relabel_sections(cur, feats=feats, sr=sr, hop_length=hop_length)

    # Pass 2 (A2d): after relabel, glue adjacent SAME letters only (soft_max).
    while _merge_adjacent_once(
        cur,
        feats=feats,
        nov=nov,
        sr=sr,
        hop_length=hop_length,
        hard_max_s=max_seg_s * 1.05,
        soft_max_s=soft_max_s,
        weak_bound=weak_bound,
        sim_merge=sim_merge,
        short_s=0.0,
        prefer_same_letter=True,
        same_letter_only=True,
    ):
        pass

    # Final relabel so pattern letters stay clean
    return _relabel_sections(cur, feats=feats, sr=sr, hop_length=hop_length)


def _phrase_pass(
    sections: List[Dict[str, Any]],
    *,
    nov,
    sr: int,
    hop_length: int,
    bars: "np.ndarray",
    max_phrase_bars: int = 16,
    min_phrase_bars: int = 2,
    max_iter: int = 64,
) -> List[Dict[str, Any]]:
    """Strict refinement of A2d (variant C / "a2e").

    Only ADDS internal boundaries inside sections longer than ``max_phrase_bars``
    bars, splitting each at the bar with the strongest novelty. It NEVER removes
    or shifts an existing A2d boundary (no merge step), so the invariant
    ``boundaries(C) ⊇ boundaries(A)`` holds by construction.

    Split sections inherit the parent section letter (no global relabel), so all
    existing labels/positions are preserved.
    """
    import numpy as np

    if not sections or nov is None or getattr(nov, "size", 0) == 0:
        return sections
    if bars is None or bars.size < 2:
        return sections

    bd = float(np.median(np.diff(np.asarray(bars, dtype=float))))
    if bd <= 0:
        return sections

    max_seg = max_phrase_bars * bd
    margin = min_phrase_bars * bd
    # need room for two sub-sections of at least `margin` each
    if max_seg <= 2.0 * margin:
        return sections

    out: List[Dict[str, Any]] = [dict(s) for s in sections]
    guard = 0
    changed = True
    while changed and guard < max_iter:
        changed = False
        guard += 1
        new_out: List[Dict[str, Any]] = []
        for seg in out:
            start = float(seg["start_s"])
            end = float(seg["end_s"])
            if (end - start) <= max_seg:
                new_out.append(seg)
                continue
            lo = start + margin
            hi = end - margin
            cands = np.asarray(bars, dtype=float)
            cands = cands[(cands >= lo) & (cands <= hi)]
            if cands.size == 0:
                new_out.append(seg)
                continue
            best_t = None
            best_v = -1.0
            for c in cands:
                v = _boundary_strength(nov, float(c), sr=sr, hop_length=hop_length)
                if v > best_v:
                    best_v = v
                    best_t = float(c)
            if best_t is None:
                new_out.append(seg)
                continue
            cut = round(best_t, 3)
            left = dict(seg)
            left["end_s"] = cut
            right = dict(seg)
            right["start_s"] = cut
            new_out.append(left)
            new_out.append(right)
            changed = True
        out = new_out
    return out


def _relabel_sections(
    sections: List[Dict[str, Any]],
    *,
    feats,
    sr: int,
    hop_length: int,
) -> List[Dict[str, Any]]:
    import numpy as np
    from scipy.cluster.hierarchy import fcluster, linkage
    from scipy.spatial.distance import pdist

    if not sections:
        return sections
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    cents = [
        _seg_centroid(feats, float(s["start_s"]), float(s["end_s"]), sr=sr, hop_length=hop_length)
        for s in sections
    ]
    n = len(cents)
    if n == 1:
        labels = [1]
    else:
        X = np.vstack(cents)
        target_k = max(3, min(7, int(round(n * 0.5))))
        Z = linkage(pdist(X, metric="cosine"), method="average")
        labels = list(fcluster(Z, t=target_k, criterion="maxclust"))
    cluster_to_letter: Dict[int, str] = {}
    out: List[Dict[str, Any]] = []
    for i, seg in enumerate(sections):
        cid = int(labels[i])
        if cid not in cluster_to_letter:
            idx = len(cluster_to_letter)
            cluster_to_letter[cid] = letters[idx] if idx < len(letters) else f"S{idx}"
        same = [j for j, lab in enumerate(labels) if int(lab) == cid and j != i]
        sim = 0.0
        if same:
            sim = float(np.mean([np.dot(cents[i], cents[j]) for j in same]))
        row = dict(seg)
        row["section"] = cluster_to_letter[cid]
        row["similar_score"] = round(sim, 3)
        out.append(row)
    return out


def analyze_mix_sections(
    audio_path: Path,
    *,
    max_duration_s: float = 480.0,
    hop_length: int = 512,
    min_seg_s: float = 10.0,
    max_seg_s: float = 28.0,
    max_sections: int = 14,
    sim_threshold: float = 0.78,
    bpm: float = 0.0,
    method: str = "a2",
    beats: Optional[List[float]] = None,
    max_phrase_bars: int = 16,
    min_phrase_bars: int = 4,
) -> Dict[str, Any]:
    import librosa
    import numpy as np

    from app.rhythm_dna import build_audio_structure_boundaries

    y, sr = librosa.load(str(audio_path), sr=22050, mono=True, duration=max_duration_s)
    duration = float(len(y)) / float(sr)
    if duration < 20.0:
        raise RuntimeError(f"audio too short ({duration:.1f}s): {audio_path}")

    method_key = str(method or "a2").strip().lower()
    if method_key in ("a2", "v4", "seg_a2", "a2b", "a2c", "a2d", "a2e", "a2d-phrase"):
        # Form-sized chunks (~12–22s). Prefer fewer weak cuts over shredding a chorus.
        target_sections = max(8, min(max_sections, int(round(duration / 17.5)) + 1))
        target_bounds = max(7, target_sections - 1)
        nov, chroma, mfcc, rms = _feature_novelty(y, sr, hop_length)
        scored = _peak_times_from_novelty(
            nov,
            sr=sr,
            hop_length=hop_length,
            duration=duration,
            min_seg_s=min_seg_s,
            target_bounds=target_bounds,
        )
        # RMS DNA peaks only if they sit on a real novelty ridge (avoid shredding).
        for t in build_audio_structure_boundaries(
            str(audio_path), bpm=float(bpm or 0.0), max_boundaries=10
        ):
            f = int(librosa.time_to_frames(float(t), sr=sr, hop_length=hop_length))
            f = min(max(f, 0), len(nov) - 1)
            if float(nov[f]) >= float(np.percentile(nov, 60)):
                scored.append((float(nov[f]), round(float(t), 1)))
        bound_times = _nms_boundaries(
            scored,
            min_gap_s=min_seg_s * 0.95,
            max_keep=max(target_bounds + 2, max_sections),
        )
        pruned = _enforce_segment_lengths(
            bound_times,
            duration=duration,
            min_seg_s=min_seg_s,
            max_seg_s=max_seg_s,
            nov=nov,
            sr=sr,
            hop_length=hop_length,
        )
        pruned = _trim_to_budget(
            pruned,
            nov=nov,
            sr=sr,
            hop_length=hop_length,
            duration=duration,
            max_bounds=max(target_bounds, max_sections - 1),
            max_seg_s=max_seg_s,
        )
        # Re-fill only if trimming left a mega-gap.
        pruned = _enforce_segment_lengths(
            pruned,
            duration=duration,
            min_seg_s=min_seg_s,
            max_seg_s=max_seg_s,
            nov=nov,
            sr=sr,
            hop_length=hop_length,
        )
        sections = _sections_from_bounds(
            y=y,
            sr=sr,
            hop_length=hop_length,
            duration=duration,
            chroma=chroma,
            mfcc=mfcc,
            rms=rms,
            pruned=pruned,
            sim_threshold=sim_threshold,
            max_seg_s=max_seg_s,
            merge_same_letter=True,
        )
        mfcc_z = (mfcc - np.mean(mfcc, axis=1, keepdims=True)) / (np.std(mfcc, axis=1, keepdims=True) + 1e-6)
        rms_n = (rms - float(np.mean(rms))) / (float(np.std(rms)) + 1e-6)
        feats = np.vstack([chroma, mfcc_z * 0.45, rms_n.reshape(1, -1) * 0.4])
        do_merge = method_key != "a2b"
        do_phrase = method_key in ("a2e", "a2d-phrase")
        soft = method_key in ("a2", "a2d", "v4", "seg_a2") or method_key == "a2c"
        # a2c kept for comparison; a2/a2d use soft same-letter glue (48s)
        soft_max = 42.0 if method_key == "a2c" else 48.0
        if do_merge:
            sections = _merge_pass(
                sections,
                feats=feats,
                nov=nov,
                sr=sr,
                hop_length=hop_length,
                duration=duration,
                max_seg_s=max_seg_s,
                min_seg_s=min_seg_s,
                soft_max_s=soft_max,
                mega_s=70.0 if soft else 55.0,
            )
        if do_phrase and beats is not None:
            _bars = np.sort(np.asarray(beats, dtype=float))
            if _bars.size >= 4:
                _bars4 = _bars[::4]
                sections = _phrase_pass(
                    sections,
                    nov=nov,
                    sr=sr,
                    hop_length=hop_length,
                    bars=_bars4,
                    max_phrase_bars=max_phrase_bars,
                    min_phrase_bars=min_phrase_bars,
                )
        pattern = " · ".join(s["section"] for s in sections)
        method_name = "novelty_nms+max_seg_a2b"
        if do_merge:
            method_name = "novelty_nms+merge_a2d" if soft_max >= 48.0 else "novelty_nms+merge_a2c"
        if do_phrase and beats is not None:
            method_name = method_name + "+phrase_a2e"
        return {
            "audio": str(audio_path),
            "duration_s": round(duration, 1),
            "sr": sr,
            "hop_length": hop_length,
            "sections": sections,
            "pattern": pattern,
            "method": method_name,
            "params": {
                "min_seg_s": min_seg_s,
                "max_seg_s": max_seg_s,
                "soft_max_s": soft_max if do_merge else None,
                "max_sections": max_sections,
                "target_sections": target_sections,
                "sim_threshold": sim_threshold,
                "n_bounds": len(pruned),
                "bound_times": pruned,
                "merge_pass": do_merge,
            },
        }
    # --- legacy v3 (RMS DNA bounds + SSM + uniform grid) ---
    bound_times = build_audio_structure_boundaries(
        str(audio_path),
        bpm=float(bpm or 0.0),
        max_boundaries=max(4, max_sections - 1),
    )
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=hop_length)
    sync_hop = max(1, int(round(1.0 * sr / hop_length)))
    chroma_sync = librosa.util.sync(chroma, np.arange(0, chroma.shape[1], sync_hop), aggregate=np.mean)
    R = librosa.segment.recurrence_matrix(
        chroma_sync, mode="affinity", metric="cosine", sym=True, width=3, self=False
    )
    try:
        R = librosa.segment.path_enhance(R, n=9)
    except Exception:
        pass
    width = max(3, int(round(min_seg_s / 1.0)))
    nov = _checkerboard_novelty(R, width=width)
    wait = max(2, width // 2)
    peaks = librosa.util.peak_pick(
        nov,
        pre_max=wait,
        post_max=wait,
        pre_avg=wait,
        post_avg=wait,
        delta=max(0.02, float(np.percentile(nov, 60)) * 0.18),
        wait=wait,
    )
    for p in peaks:
        t = float(librosa.frames_to_time(int(p) * sync_hop, sr=sr, hop_length=hop_length))
        if min_seg_s <= t <= duration - min_seg_s:
            bound_times.append(round(t, 1))

    n_uniform = max(5, min(max_sections, int(round(duration / 18.0))))
    for i in range(1, n_uniform):
        bound_times.append(round(duration * i / n_uniform, 1))

    bound_times = sorted(set(float(t) for t in bound_times if min_seg_s * 0.5 < float(t) < duration - 2.0))
    pruned: List[float] = []
    for t in bound_times:
        if not pruned or t - pruned[-1] >= min_seg_s * 0.75:
            pruned.append(t)
    if len(pruned) > max_sections - 1:
        rms_set = set(
            build_audio_structure_boundaries(str(audio_path), bpm=float(bpm or 0.0), max_boundaries=20)
        )
        pruned = sorted(
            pruned,
            key=lambda t: (0 if any(abs(t - r) < 2.0 for r in rms_set) else 1, t),
        )[: max_sections - 1]
        pruned = sorted(pruned)

    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=8, hop_length=hop_length)
    rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]
    sections = _sections_from_bounds(
        y=y,
        sr=sr,
        hop_length=hop_length,
        duration=duration,
        chroma=chroma,
        mfcc=mfcc,
        rms=rms,
        pruned=pruned,
        sim_threshold=sim_threshold,
        max_seg_s=999.0,
        merge_same_letter=True,
    )
    pattern = " · ".join(s["section"] for s in sections)
    return {
        "audio": str(audio_path),
        "duration_s": round(duration, 1),
        "sr": sr,
        "hop_length": hop_length,
        "sections": sections,
        "pattern": pattern,
        "method": "rms_boundaries+chroma_labels_v3",
        "params": {
            "min_seg_s": min_seg_s,
            "max_sections": max_sections,
            "sim_threshold": sim_threshold,
            "n_bounds": len(pruned),
            "bound_times": pruned,
        },
    }


def build_structure_sections(
    mix_audio_path: str,
    *,
    bpm: float = 0.0,
    beats: Optional[List[float]] = None,
    hop_length: int = 512,
    method: str = "a2d",
    min_seg_s: float = 10.0,
    max_seg_s: float = 28.0,
    max_sections: int = 14,
    sim_threshold: float = 0.78,
    max_phrase_bars: int = 16,
    min_phrase_bars: int = 4,
) -> List[Dict[str, Any]]:
    """Run the validated A2d audio-section analysis and return a minimal,
    production-friendly list of sections.

    Returns a list of dicts with keys: id (str letter A..), start_s (float),
    end_s (float). Boundaries are gently snapped to musical positions
    (bar/beat) when reliable beat information is supplied.

    Raises nothing fatal to the caller on analysis failure — the caller wraps
    this; but this function itself may raise (it is the caller's job to guard).
    """
    result = analyze_mix_sections(
        Path(mix_audio_path),
        bpm=bpm,
        hop_length=hop_length,
        method=method,
        min_seg_s=min_seg_s,
        max_seg_s=max_seg_s,
        max_sections=max_sections,
        sim_threshold=sim_threshold,
        beats=beats,
        max_phrase_bars=max_phrase_bars,
        min_phrase_bars=min_phrase_bars,
    )

    raw_sections = result.get("sections", [])
    if not raw_sections:
        return []

    sections: List[Dict[str, Any]] = []
    for s in raw_sections:
        sid = str(s.get("section", "")).strip().upper() or "?"
        start = float(s.get("start_s", 0.0))
        end = float(s.get("end_s", start))
        sections.append({"id": sid, "start_s": start, "end_s": end})

    if beats:
        try:
            bt = np.sort(np.asarray(beats, dtype=float))
        except Exception:
            bt = np.array([], dtype=float)
        if bt.size >= 4:
            bars = bt[::4]
        else:
            bars = bt

        def snap(t: float) -> float:
            t = float(t)
            if bars.size:
                bidx = int(np.argmin(np.abs(bars - t)))
                bar = float(bars[bidx])
                if abs(t - bar) <= 1.0:
                    return bar
            if bt.size:
                bidx = int(np.argmin(np.abs(bt - t)))
                beat = float(bt[bidx])
                if abs(t - beat) <= 0.5:
                    return beat
            return t

        for s in sections:
            s["start_s"] = snap(s["start_s"])
            s["end_s"] = snap(s["end_s"])

    sections.sort(key=lambda x: x["start_s"])
    cleaned: List[Dict[str, Any]] = []
    for s in sections:
        start = float(s["start_s"])
        end = float(s["end_s"])
        if end - start < 0.5:
            # collapse: extend previous kept section's end if adjacent
            if cleaned and abs(start - cleaned[-1]["end_s"]) <= 0.5:
                cleaned[-1]["end_s"] = max(cleaned[-1]["end_s"], end)
            continue
        if cleaned:
            cleaned[-1]["end_s"] = min(cleaned[-1]["end_s"], start - 0.01)
        cleaned.append({"id": s["id"], "start_s": start, "end_s": end})

    out: List[Dict[str, Any]] = []
    for i, s in enumerate(cleaned):
        start = float(s["start_s"])
        end = float(s["end_s"])
        if end - start < 0.5:
            end = start + 0.5
        if i + 1 < len(cleaned):
            nxt = float(cleaned[i + 1]["start_s"])
            if end > nxt:
                end = max(start + 0.5, nxt - 0.01)
        out.append(
            {
                "id": str(s["id"]),
                "start_s": round(float(start), 3),
                "end_s": round(float(end), 3),
            }
        )
    return out
