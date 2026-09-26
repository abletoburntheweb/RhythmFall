# app/routes.py

from flask import Blueprint, request, jsonify, send_file, after_this_request
import os
import time
import json
from pathlib import Path
import shutil
import re
import hashlib
import subprocess
import tempfile
import app.bpm_analyzer as bpm_analyzer
from . import drum_generator
from .drum_utils import CANONICAL_MAX_LANES
from .generation_presets import available_preset_ids, resolve_generation_preset
from .generation_intents import (
    resolve_generation_request,
    resolve_goal_difficulty_request,
    normalize_chart_intent,
    normalize_goal,
    normalize_difficulty,
)

try:
    from .genre_detector import detect_genres, detect_genre_predictions, is_discogs400_available

    GENRE_DETECTION_AVAILABLE = bool(is_discogs400_available())
    if GENRE_DETECTION_AVAILABLE:
        print("[Routes] Определение жанров доступно")
    else:
        print("[Routes] Определение жанров недоступно (нужен EffNet ONNX в models/discogs-effnet/)")
except ImportError:
    GENRE_DETECTION_AVAILABLE = False
    print("[Routes] Определение жанров недоступно")

bp = Blueprint("main", __name__)

os.makedirs("temp_uploads", exist_ok=True)

TASK_PROGRESS = {}
TASK_RESULTS = {}
TASK_RHYTHM_DNA = {}
TASK_RHYTHM_DNA_SIDECAR = {}
TASK_CANCELLED = set()
TASK_CONTEXT = {}
DEBUG_HTTP = os.getenv("RF_DEBUG_HTTP", "0") == "1"
DRUMGEN_VERBOSE = os.getenv("RF_VERBOSE_DRUMGEN", "0") == "1"


def _debug_log(*args):
    if DEBUG_HTTP:
        print(*args)


def _extract_artist_title_from_filename(filename: str) -> tuple[str, str]:
    stem = Path(filename).stem
    parts = stem.split(' - ', 1)
    if len(parts) == 2:
        return parts[0].strip(), parts[1].strip()
    return "Unknown", stem

def _report_status(task_id: str, status_text: str):
    if not task_id:
        return
    lst = TASK_PROGRESS.get(task_id)
    if lst is None:
        lst = []
        TASK_PROGRESS[task_id] = lst
    lst.append(status_text)


def _store_task_result(task_id: str, data: dict):
    if task_id:
        TASK_RESULTS[task_id] = data


def _store_rhythm_dna(task_id: str, payload: dict, sidecar_path: str = ""):
    if not task_id or not isinstance(payload, dict) or not payload:
        return
    TASK_RHYTHM_DNA[task_id] = payload
    if sidecar_path:
        TASK_RHYTHM_DNA_SIDECAR[task_id] = sidecar_path

def _register_task_context(task_id: str, temp_path: str, metadata: dict | None = None):
    if not task_id or not temp_path:
        return
    from app import song_storage

    meta = metadata if isinstance(metadata, dict) else {}
    chart_id = song_storage.resolve_chart_id(meta)
    if chart_id:
        song_folder = str(song_storage.song_dir(chart_id))
    else:
        base_name = Path(temp_path).stem
        song_folder = str(Path("temp_uploads") / base_name)
    TASK_CONTEXT[task_id] = {
        "temp_path": temp_path,
        "song_folder": song_folder,
        "chart_id": chart_id,
        "metadata": meta,
        "success": False,
        "use_stems": True,
    }
def _normalize_filename(name: str, default_ext: str = ".mp3") -> str:
    s = "".join(c for c in name if c.isalnum() or c in "._- ")
    s = re.sub(r"\s+", " ", s).strip()
    base, ext = os.path.splitext(s)
    if not ext:
        ext = default_ext
    base = re.sub(r"\.{2,}", ".", base)
    base = base.lstrip(". ").strip()
    if not base:
        base = f"audio_{int(time.time())}"
    return f"{base}{ext}"

def _mark_cancelled(task_id: str):
    if not task_id:
        return
    TASK_CANCELLED.add(task_id)
    _report_status(task_id, "Отмена запрошена")
    _report_status(task_id, "Отменено пользователем")

def _is_cancelled(task_id: str) -> bool:
    if not task_id:
        return False
    return task_id in TASK_CANCELLED

def _keep_temp_uploads() -> bool:
    """Keep song folders (stems, notes, splitter) after generation — dev default on."""
    return os.getenv("RFALL_KEEP_TEMP_UPLOADS", "1").strip().lower() in ("1", "true", "yes", "on")


def _cleanup_task(task_id: str):
    from app import song_storage, stem_retention

    ctx = TASK_CONTEXT.get(task_id, {})
    temp_path = ctx.get("temp_path")
    song_folder = ctx.get("song_folder")
    chart_id = str(ctx.get("chart_id", "")).strip()
    metadata = ctx.get("metadata", {}) if isinstance(ctx.get("metadata"), dict) else {}
    success = bool(ctx.get("success", False))
    use_stems = bool(ctx.get("use_stems", True))
    original_filename = str(metadata.get("original_filename", "")).strip()
    legacy_stem = str(metadata.get("legacy_stem", "")).strip()
    if not legacy_stem and temp_path:
        legacy_stem = Path(str(temp_path)).stem

    if chart_id and temp_path:
        moved = song_storage.ensure_audio_in_song_dir(
            temp_path,
            chart_id,
            original_filename=original_filename,
        )
        if moved is not None:
            temp_path = str(moved)
            song_folder = str(moved.parent)
            ctx["temp_path"] = temp_path
            ctx["song_folder"] = song_folder

    has_client_policy = isinstance(metadata, dict) and (
        "stem_keep_all" in metadata or "stem_retention_mode" in metadata
    )
    if has_client_policy or not _keep_temp_uploads():
        stem_retention.apply_post_job(
            song_folder or "",
            metadata,
            success=success,
            use_stems=use_stems,
        )
    elif _keep_temp_uploads():
        if song_folder and os.path.isdir(song_folder):
            print(f"[Очистка] RFALL_KEEP_TEMP_UPLOADS — сохранено: {song_folder}")

    song_storage.cleanup_temp_uploads_root_artifacts(
        temp_path=temp_path,
        chart_id=chart_id,
        legacy_stem=legacy_stem,
        original_filename=original_filename,
    )

    if not has_client_policy and not _keep_temp_uploads():
        if song_folder and os.path.isdir(song_folder):
            try:
                shutil.rmtree(song_folder, ignore_errors=True)
                print(f"[Очистка] Удалена папка песни: {song_folder}")
            except Exception as e:
                print(f"[Предупреждение] Не удалось удалить папку песни: {e}")

    TASK_CONTEXT.pop(task_id, None)
    TASK_CANCELLED.discard(task_id)

def _check_cancel(task_id: str):
    if _is_cancelled(task_id):
        raise RuntimeError("__CANCELLED__")

@bp.route("/task_status", methods=["GET"])
def task_status():
    task_id = request.args.get("task_id", "")
    if not task_id:
        return jsonify({"error": "task_id required"}), 400
    statuses = TASK_PROGRESS.get(task_id, [])
    return jsonify({"task_id": task_id, "statuses": statuses, "status": "ok"})


@bp.route("/task_result", methods=["GET"])
def task_result():
    task_id = request.args.get("task_id", "")
    if not task_id:
        return jsonify({"error": "task_id required"}), 400
    if task_id in TASK_RESULTS:
        return jsonify(TASK_RESULTS[task_id])
    if task_id in TASK_PROGRESS or task_id in TASK_CONTEXT:
        return jsonify({"status": "processing", "task_id": task_id}), 202
    return jsonify({"error": "unknown task", "task_id": task_id}), 404


@bp.route("/rhythm_dna", methods=["GET"])
def rhythm_dna_endpoint():
    task_id = request.args.get("task_id", "")
    if not task_id:
        return jsonify({"error": "task_id required"}), 400
    from app.rhythm_dna import parse_rfd, is_full_rhythm_dna

    payload = TASK_RHYTHM_DNA.get(task_id)
    if not isinstance(payload, dict) or not payload:
        stored = TASK_RESULTS.get(task_id, {})
        if isinstance(stored, dict):
            candidate = stored.get("rhythm_dna")
            if isinstance(candidate, dict) and candidate:
                payload = candidate
    if isinstance(payload, dict) and payload:
        return jsonify({"status": "ok", "task_id": task_id, "rhythm_dna": payload})
    sidecar_rel = TASK_RHYTHM_DNA_SIDECAR.get(task_id, "")
    if sidecar_rel:
        sidecar = Path(sidecar_rel)
        if sidecar.is_file():
            try:
                disk_payload = parse_rfd(sidecar.read_text(encoding="utf-8"))
            except OSError:
                disk_payload = {}
            if isinstance(disk_payload, dict) and disk_payload:
                TASK_RHYTHM_DNA[task_id] = disk_payload
                return jsonify({"status": "ok", "task_id": task_id, "rhythm_dna": disk_payload})
    if task_id in TASK_PROGRESS or task_id in TASK_CONTEXT:
        return jsonify({"status": "processing", "task_id": task_id}), 202
    return jsonify({"error": "rhythm_dna not found", "task_id": task_id}), 404


@bp.route("/rhythm_dna_sidecar", methods=["GET"])
def rhythm_dna_sidecar_endpoint():
    from app.rhythm_dna import load_sidecar_from_disk, is_full_rhythm_dna

    track = request.args.get("track", "").strip()
    mode = request.args.get("mode", "basic").strip() or "basic"
    instrument = request.args.get("instrument", "drums").strip() or "drums"
    if not track:
        return jsonify({"error": "track required"}), 400
    payload = load_sidecar_from_disk(track, mode=mode, instrument=instrument)
    if not isinstance(payload, dict) or not payload:
        return jsonify({"error": "sidecar not found", "track": track, "mode": mode}), 404
    status = "ok" if is_full_rhythm_dna(payload) else "minimal"
    return jsonify({"status": status, "track": track, "mode": mode, "rhythm_dna": payload})


@bp.route("/cancel_task", methods=["POST", "GET"])
def cancel_task():
    task_id = None
    if request.method == "GET":
        task_id = request.args.get("task_id", "")
    else:
        try:
            data = request.get_json(force=True, silent=True) or {}
        except Exception:
            data = {}
        task_id = (data.get("task_id") or request.args.get("task_id", "")).strip()
    if not task_id:
        return jsonify({"error": "task_id required"}), 400
    _mark_cancelled(task_id)
    return jsonify({"task_id": task_id, "status": "cancel_requested"})

@bp.route("/")
def home():
    return jsonify({
        "message": "RhythmFallServer is running",
        "endpoints": {
            "analyze_bpm": "POST /analyze_bpm - Analyze BPM from audio",
            "generate_drums": "POST /generate_drums - Generate drum notes",
            "health": "GET /health - Health check"
        }
    })


@bp.route("/analyze_bpm", methods=["POST"])
def analyze_bpm():
    _debug_log("DEBUG /analyze_bpm Content-Type:", request.content_type)
    _debug_log("DEBUG /analyze_bpm Files keys:", list(request.files.keys()))
    _debug_log("DEBUG /analyze_bpm Form keys:", list(request.form.keys()))

    temp_path = None
    task_id = request.headers.get("X-Task-Id", "") or request.args.get("task_id", "")
    try:
        _check_cancel(task_id)
        if "audio_file" in request.files:
            file = request.files["audio_file"]
            if file.filename == "":
                return jsonify({"error": "No file selected"}), 400

            safe_filename = _normalize_filename(file.filename, default_ext=".mp3")
            temp_path = os.path.join("temp_uploads", f"bpm_{int(time.time())}_{safe_filename}")
            file.save(temp_path)
            print(f"[BPM] Файл получен через multipart: {temp_path}")

        elif request.data:
            temp_path = os.path.join("temp_uploads", f"bpm_{int(time.time())}_uploaded_audio.mp3")
            with open(temp_path, "wb") as f:
                f.write(request.data)
            print(f"[BPM] Сохранены сырые аудиоданные: {temp_path}")

        else:
            print("[Ошибка] В запросе не найдены аудиоданные")
            return jsonify({"error": "No audio file provided in the request"}), 400

        if task_id:
            _register_task_context(task_id, temp_path, {})
        _check_cancel(task_id)
        result = bpm_analyzer.calculate_bpm(temp_path, save_cache=False, cancel_cb=lambda: _check_cancel(task_id))

        if result.get("bpm") is not None:
            print(f"[BPM] Успешно рассчитан BPM: {result['bpm']}")
            return jsonify({
                "bpm": result["bpm"],
                "filename": os.path.basename(temp_path),
                "status": "success"
            })
        elif "error" in result:
            error_msg = result.get("error", "Unknown error during BPM analysis")
            print(f"[Ошибка] Анализ BPM завершился с ошибкой: {error_msg}")
            return jsonify({"error": error_msg}), 500
        else:
            print("[Ошибка] Анализ BPM вернул неожиданный формат результата")
            return jsonify({"error": "BPM analysis returned unexpected result format"}), 500

    except Exception as e:
        print(f"[Исключение] {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
                print(f"[Очистка] Удалён временный файл: {temp_path}")
            except Exception as e:
                print(f"[Предупреждение] Не удалось удалить временный файл: {e}")


@bp.route("/detect_genres_audio", methods=["POST"])
def detect_genres_audio():
    temp_path = None
    try:
        if "audio_file" in request.files:
            file = request.files["audio_file"]
            if file.filename == "":
                return jsonify({"error": "No file selected"}), 400
            safe_filename = _normalize_filename(file.filename, default_ext=".mp3")
            temp_path = os.path.join("temp_uploads", f"genres_{int(time.time())}_{safe_filename}")
            file.save(temp_path)
        elif request.data:
            temp_path = os.path.join("temp_uploads", f"genres_{int(time.time())}_uploaded_audio.mp3")
            with open(temp_path, "wb") as f:
                f.write(request.data)
        else:
            return jsonify({"error": "No audio file provided in the request"}), 400

        if not GENRE_DETECTION_AVAILABLE or not is_discogs400_available():
            return jsonify({"error": "Genre detection model is not available"}), 503

        predictions = detect_genre_predictions(temp_path, top_k=5)
        genres = [p.get("id") for p in predictions if isinstance(p, dict) and p.get("id")]
        return jsonify({
            "status": "success",
            "predictions": predictions,
            "genres": genres,
            "filename": os.path.basename(temp_path),
        })
    except Exception as e:
        print(f"[Исключение] detect_genres_audio: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception as e:
                print(f"[Предупреждение] Не удалось удалить временный файл: {e}")


@bp.route("/generate_drums", methods=["POST"])
def generate_drums():
    _debug_log("DEBUG /generate_drums: запрос получен")
    _debug_log(f"DEBUG /generate_drums Content-Type: {request.content_type}")
    import time as _perf_time
    _perf_start = _perf_time.perf_counter()
    _perf = {}

    temp_path = None
    task_id = request.headers.get("X-Task-Id", "")
    try:
        _check_cancel(task_id)
        if "audio_file" not in request.files:
            return jsonify({"error": "Missing 'audio_file' in multipart form"}), 400

        if "metadata" not in request.form:
            return jsonify({"error": "Missing 'metadata' in multipart form"}), 400

        audio_file = request.files["audio_file"]
        metadata_json = request.form["metadata"]

        try:
            metadata = json.loads(metadata_json)
        except json.JSONDecodeError as e:
            return jsonify({"error": f"Invalid JSON in 'metadata': {str(e)}"}), 400

        original_filename = metadata.get("original_filename", "uploaded_audio.mp3")
        bpm = metadata.get("bpm")
        lanes = metadata.get("lanes", 4)
        instrument_type = metadata.get("instrument_type", "drums")
        sync_tolerance = metadata.get("sync_tolerance", 0.2)
        generation_mode = metadata.get("generation_mode", "basic")
        preset_id = metadata.get("preset_id")
        chart_intent = metadata.get("chart_intent")
        generation_goal = metadata.get("goal") or metadata.get("generation_goal")
        generation_difficulty = metadata.get("difficulty") or metadata.get("generation_difficulty")
        chart_stem_meta = metadata.get("chart_stem")
        print(
            f"[DrumGen] metadata raw goal={generation_goal!r} difficulty={generation_difficulty!r} "
            f"chart_stem={chart_stem_meta!r} chart_intent={chart_intent!r}"
        )
        auto_identify_track = metadata.get("auto_identify_track", False)
        progress_delay_seconds = float(metadata.get("progress_delay_seconds", 0.0))
        genres = metadata.get("genres")
        primary_genre = metadata.get("primary_genre")
        use_stems = bool(metadata.get("use_stems", True))
        stem_keep_all = bool(metadata.get("stem_keep_all", False))
        stem_retention_mode = str(metadata.get("stem_retention_mode", "after_job")).strip().lower()
        stem_keep_count = metadata.get("stem_keep_count", 10)
        stem_ttl_seconds = metadata.get("stem_ttl_seconds")
        fill    = metadata.get("fill")
        groove  = metadata.get("groove")
        density = metadata.get("density")
        grid_snap_strength = metadata.get("grid_snap_strength")
        accent_strong_beats = metadata.get("accent_strong_beats")
        genre_template_strength = metadata.get("genre_template_strength")
        songformer_enabled = bool(metadata.get("songformer_enabled", False))
        songformer_backend = str(metadata.get("songformer_backend", "auto") or "auto")
        if songformer_enabled:
            print(f"[SongFormer] requested enabled backend={songformer_backend} (CPU-only, fallback to current pipeline if unavailable)")
            try:
                from .songformer_bridge import is_available as _sf_avail
                if not _sf_avail():
                    print("[SongFormer] not available (models missing) — using current pipeline")
                else:
                    print("[SongFormer] available but conservative fusion keeps current pipeline (opt-in)")
            except Exception as _e:
                print(f"[SongFormer] bridge check failed: {_e} — fallback")
        else:
            print("[SongFormer] disabled (default) — using current pipeline")
        include_hi_hats = metadata.get("include_hi_hats")
        critic_strength = metadata.get("critic_strength")
        groove_completion = metadata.get("groove_completion")
        raw_adtof = metadata.get("raw_adtof")
        if include_hi_hats is not None:
            include_hi_hats = bool(include_hi_hats)
        if groove_completion is not None:
            groove_completion = bool(groove_completion)
        if raw_adtof is not None:
            raw_adtof = bool(raw_adtof)
        if critic_strength is not None:
            try:
                critic_strength = int(critic_strength)
                critic_strength = max(0, min(100, critic_strength))
            except (ValueError, TypeError):
                critic_strength = None
        if fill is not None:
            try:
                fill = int(fill)
                fill = max(0, min(100, fill))
            except (ValueError, TypeError):
                fill = None
        if groove is not None:
            try:
                groove = int(groove)
                groove = max(0, min(100, groove))
            except (ValueError, TypeError):
                groove = None
        if density is not None:
            try:
                density = int(density)
                density = max(0, min(100, density))
            except (ValueError, TypeError):
                density = None
        if grid_snap_strength is not None:
            try:
                grid_snap_strength = int(grid_snap_strength)
                grid_snap_strength = max(0, min(100, grid_snap_strength))
            except (ValueError, TypeError):
                grid_snap_strength = None
        if accent_strong_beats is not None:
            accent_strong_beats = bool(accent_strong_beats)
        if genre_template_strength is not None:
            try:
                genre_template_strength = int(genre_template_strength)
                genre_template_strength = max(0, min(100, genre_template_strength))
            except (ValueError, TypeError):
                genre_template_strength = None

        valid_modes = {"minimal", "basic", "enhanced", "natural", "custom"}
        if not isinstance(lanes, int) or not (1 <= lanes <= 8):
            return jsonify({"error": "Invalid 'lanes': must be integer 1-8"}), 400
        if not isinstance(sync_tolerance, (int, float)) or not (0.01 <= sync_tolerance <= 1.0):
            return jsonify({"error": "Invalid 'sync_tolerance': must be float 0.01-1.0"}), 400
        if generation_mode not in valid_modes:
            return jsonify({"error": f"'generation_mode' must be one of {sorted(valid_modes)}"}), 400
        user_params = {
            "fill": fill,
            "groove": groove,
            "density": density,
            "grid_snap_strength": grid_snap_strength,
            "accent_strong_beats": accent_strong_beats,
            "genre_template_strength": genre_template_strength,
            "include_hi_hats": include_hi_hats,
            "critic_strength": critic_strength,
            "groove_completion": groove_completion,
            "raw_adtof": raw_adtof,
        }
        save_stem = ""
        resolution_label = ""
        try:
            use_legacy_intent = bool(metadata.get("use_legacy_chart_intent", False))
            preset_user_params = user_params
            if str(generation_mode or "").strip().lower() != "custom":
                # Goal×difficulty matrix owns slider values; ignore client fill/groove/density.
                preset_user_params = {}
                if user_params.get("raw_adtof") is not None:
                    preset_user_params["raw_adtof"] = user_params["raw_adtof"]
            if use_legacy_intent and chart_intent is not None and str(chart_intent).strip():
                resolved = resolve_generation_request(
                    chart_intent=chart_intent,
                    generation_mode=generation_mode,
                    preset_id=preset_id,
                    user_params=user_params,
                )
                generation_preset = resolved["preset"]
                chart_intent = resolved["chart_intent"]
                preset_id = resolved["preset_id"]
                generation_mode = resolved["legacy_mode"]
                save_stem = str(chart_intent or preset_id).strip()
                resolution_label = "legacy_intent"
            elif use_legacy_intent:
                generation_preset = resolve_generation_preset(preset_id, generation_mode)
                preset_id = generation_preset["preset_id"]
                generation_mode = generation_preset["mode"]
                chart_intent = None
                save_stem = str(preset_id or generation_mode).strip()
                resolution_label = "legacy_preset"
            else:
                resolved = resolve_goal_difficulty_request(
                    goal=generation_goal,
                    difficulty=generation_difficulty,
                    chart_intent=chart_intent,
                    chart_stem=chart_stem_meta,
                    generation_mode=generation_mode,
                    user_params=preset_user_params,
                )
                generation_preset = resolved["preset"]
                chart_intent = resolved["chart_intent"]
                preset_id = resolved["preset_id"]
                generation_mode = resolved["legacy_mode"]
                save_stem = resolved["chart_stem"]
                generation_goal = resolved["goal"]
                generation_difficulty = resolved["difficulty"]
                resolution_label = str(resolved.get("resolution", "goal×difficulty"))
        except ValueError as exc:
            if "arcade" in str(exc).lower():
                return jsonify({"error": str(exc)}), 400
            return jsonify({"error": f"'preset_id' must be one of {sorted(available_preset_ids())}"}), 400
        if save_stem:
            generation_preset["chart_stem"] = save_stem
        print(
            f"[DrumGen] metadata goal={generation_goal!r} difficulty={generation_difficulty!r} "
            f"chart_stem={chart_stem_meta!r} chart_intent={chart_intent!r}"
        )
        print(
            f"[DrumGen] resolution={resolution_label} "
            f"goal={generation_goal} difficulty={generation_difficulty} "
            f"stem={save_stem or '-'} preset_id={preset_id}"
        )
        if genres is not None and not isinstance(genres, list):
            return jsonify({"error": "'genres' must be a list of strings"}), 400
        if primary_genre is not None and not isinstance(primary_genre, str):
            return jsonify({"error": "'primary_genre' must be a string"}), 400

        safe_filename = _normalize_filename(original_filename, default_ext=".mp3")

        from app import song_storage

        song_path_client = song_storage.normalize_song_path(str(metadata.get("song_path", "")))
        chart_id = song_storage.resolve_chart_id(metadata, song_path=song_path_client)
        legacy_stem = Path(safe_filename).stem
        if chart_id:
            song_storage.maybe_migrate_legacy_folder(chart_id, legacy_stem)
            upload_dir = song_storage.song_dir(chart_id)
            upload_dir.mkdir(parents=True, exist_ok=True)
            temp_path = str(upload_dir / safe_filename)
            song_storage.write_song_meta(
                chart_id,
                {
                    "chart_id": chart_id,
                    "song_path": song_path_client,
                    "original_filename": original_filename,
                    "legacy_stem": legacy_stem,
                },
            )
        else:
            temp_path = os.path.join("temp_uploads", safe_filename)
        audio_file.save(temp_path)
        _perf["request_parse_ms"] = int((_perf_time.perf_counter() - _perf_start) * 1000)
        print(f"[DrumGen] Аудио сохранено: {temp_path}")
        if chart_id:
            print(f"[DrumGen] chart_id={chart_id}")
        print(f"[DrumGen] Исходное имя файла (Unicode-safe): {original_filename}")
        if chart_id:
            metadata["legacy_stem"] = legacy_stem
        _register_task_context(task_id, temp_path, metadata)
        if task_id in TASK_CONTEXT:
            TASK_CONTEXT[task_id]["use_stems"] = use_stems
        _check_cancel(task_id)

        _t_bpm = _perf_time.perf_counter()
        if bpm is None:
            print("[DrumGen] BPM не передан, выполняется расчёт...")
            _check_cancel(task_id)
            bpm_result = bpm_analyzer.calculate_bpm(temp_path, save_cache=False, cancel_cb=lambda: _check_cancel(task_id))
            if bpm_result.get("bpm") is None:
                error_msg = bpm_result.get("error", "Failed to calculate BPM")
                return jsonify({"error": f"Could not determine BPM: {error_msg}"}), 500
            bpm = bpm_result["bpm"]
            print(f"[DrumGen] Рассчитанный BPM: {bpm}")
            _perf["bpm_ms"] = int((_perf_time.perf_counter() - _t_bpm) * 1000)
        else:
            _perf["bpm_ms"] = 0
            try:
                bpm = float(bpm)
                if not (1 <= bpm <= 300):
                    raise ValueError("BPM out of range")
            except (ValueError, TypeError):
                return jsonify({"error": "Invalid 'bpm': must be number 1-300"}), 400

        normalized_genres = [g for g in (genres or []) if isinstance(g, str) and g.strip()]
        provided_genres = normalized_genres if normalized_genres else None
        normalized_primary_genre = (
            primary_genre
            if primary_genre and primary_genre.strip().lower() != "unknown"
            else None
        )
        track_info = None
        print("[DrumGen] Используем только аудио-модель жанров (без сетевых источников)")
        artist_guess, title_guess = _extract_artist_title_from_filename(original_filename)
        track_info = {
            "artist": artist_guess or "Unknown",
            "title": title_guess or "Unknown",
            "genres": [],
            "primary_genre": "",
            "success": False
        }
        _check_cancel(task_id)

        print(f"[DrumGen] Генерация нот | BPM: {bpm}, Линии: {lanes}, Режим: {generation_mode}, Пресет: {preset_id}, Intent: {chart_intent or '-'}, Stem: {save_stem or '-'}")
        print(f"[DrumGen] Использовать стемы: {'да' if use_stems else 'нет'}")
        if stem_keep_all:
            print("[DrumGen] Стемы на диске: не удалять (debug)")
        else:
            print(f"[DrumGen] Стемы на диске: {stem_retention_mode} (keep={stem_keep_count})")
        print(f"[DrumGen] Параметры | fill={fill} groove={groove} density={density} grid_snap_strength={grid_snap_strength} accent_strong_beats={accent_strong_beats} genre_template_strength={genre_template_strength} include_hi_hats={include_hi_hats} critic_strength={critic_strength} groove_completion={groove_completion} raw_adtof={raw_adtof}")
        _t_genre = _perf_time.perf_counter()
        effective_primary = normalized_primary_genre
        genres_source = "client"
        if effective_primary is None and provided_genres is None and GENRE_DETECTION_AVAILABLE:
            _report_status(task_id, "Идентификация трека...")
            _report_status(task_id, "Определение жанров...")
            if progress_delay_seconds > 0:
                time.sleep(progress_delay_seconds)
            try:
                detected = detect_genres("Unknown", "Unknown", audio_path=temp_path) or []
                track_info['genres'] = detected
                track_info['genre_predictions'] = detect_genre_predictions(temp_path, top_k=5)
                if detected:
                    effective_primary = detected[0]
                genres_source = "server"
                print(f"[DrumGen] Жанры по аудио: {detected}")
            except Exception as e:
                print(f"[DrumGen] Ошибка определения жанров: {e}")
        if provided_genres is not None:
            track_info["genres"] = list(provided_genres)
        if effective_primary is not None:
            track_info["primary_genre"] = effective_primary
        _perf["genre_ms"] = int((_perf_time.perf_counter() - _t_genre) * 1000)
        print(f"[DrumGen] Жанр для генерации: {effective_primary or 'groove'}")
        _check_cancel(task_id)
        generate_lanes = CANONICAL_MAX_LANES
        print(f"[DrumGen] Unified chart: generate lanes={generate_lanes} (request lanes={lanes})")
        _t_chart = _perf_time.perf_counter()
        primary_notes = drum_generator.generate_drums_notes(
            temp_path,
            bpm,
            lanes=generate_lanes,
            sync_tolerance=sync_tolerance,
            use_madmom_beats=True,
            use_stems=use_stems,
            generation_mode=generation_mode,
            preset_id=preset_id,
            generation_preset=generation_preset,
            fill=fill,
            groove=groove,
            density=density,
            grid_snap_strength=grid_snap_strength,
            accent_strong_beats=accent_strong_beats,
            genre_template_strength=genre_template_strength,
            include_hi_hats=include_hi_hats,
            track_info=track_info,
            auto_identify_track=False,
            use_filename_for_genres=False,
            provided_genres=provided_genres,
            provided_primary_genre=effective_primary,
            verbose=DRUMGEN_VERBOSE,
            status_cb=lambda s: _report_status(task_id, s),
            cancel_cb=lambda: _check_cancel(task_id),
            chart_id=chart_id,
            songformer_enabled=bool(songformer_enabled),
            songformer_backend=str(songformer_backend or "auto"),
        )
        _perf["chart_generation_ms"] = int((_perf_time.perf_counter() - _t_chart) * 1000)
        _check_cancel(task_id)
        if not primary_notes or len(primary_notes) == 0:
            return jsonify({"error": f"No drum notes generated for lanes={generate_lanes}"}), 500
        chosen_notes = primary_notes
        print(f"[DrumGen] Unified chart ready: lanes={generate_lanes}, notes={len(chosen_notes)}")

        _report_status(task_id, "Сохранение нот...")
        _check_cancel(task_id)
        from app.rhythm_dna import format_rhythm_dna_log, rhythm_dna_sidecar_path

        rhythm_dna_payload = drum_generator.get_last_rhythm_dna()
        save_intent = save_stem or chart_intent or normalize_chart_intent(None, generation_mode)
        _t_save = _perf_time.perf_counter()
        drum_generator.save_drums_notes(
            chosen_notes,
            temp_path,
            mode=generation_mode,
            chart_intent=save_intent,
            chart_stem=save_stem or None,
            lanes=generate_lanes,
            artist=str(track_info.get("artist", "")) if track_info else "",
            title=str(track_info.get("title", "")) if track_info else "",
            rhythm_dna=rhythm_dna_payload,
            chart_id=chart_id,
            songformer_enabled=bool(songformer_enabled),
            songformer_backend=str(songformer_backend or "auto"),
        )
        _perf["save_ms"] = int((_perf_time.perf_counter() - _t_save) * 1000)
        _check_cancel(task_id)

        drum_count = len([n for n in chosen_notes if n.get("type") == "DrumNote"])
        if chart_id:
            notes_rf_path = (
                song_storage.song_dir(chart_id)
                / "notes"
                / song_storage.chart_notes_filename("drums", save_intent, generate_lanes)
            )
        else:
            base_name = Path(temp_path).stem
            notes_rf_path = Path("temp_uploads") / base_name / "notes" / f"{base_name}_drums_{save_intent}.rf"
        sidecar_path = rhythm_dna_sidecar_path(notes_rf_path)
        _store_rhythm_dna(task_id, rhythm_dna_payload or {}, str(sidecar_path))

        from app.stage_ledger import save_stage_ledger

        ledger_path = save_stage_ledger(notes_rf_path, drum_generator.get_last_stage_ledger())
        if ledger_path:
            print(f"[StageLedger] {ledger_path}")

        final_genres = provided_genres if provided_genres is not None else (track_info.get("genres") if track_info else [])
        final_primary = effective_primary or (track_info.get("primary_genre") if track_info else "")
        # Phase 3D.2: actually used stem model (not config RFALL_STEM_MODEL)
        try:
            from app.audio_analysis import get_last_stem_model
            _stem_model_val = str(get_last_stem_model("drums") or "")
        except Exception:
            _stem_model_val = ""

        _perf["total_ms"] = int((_perf_time.perf_counter() - _perf_start) * 1000)
        response_data = {
            "status": "success",
            "task_id": task_id,
            "rhythm_dna": rhythm_dna_payload,
            "bpm": bpm,
            "lanes": generate_lanes,
            "requested_lanes": lanes,
            "instrument_type": instrument_type,
            "mode": generation_mode,
            "chart_intent": chart_intent,
            "chart_stem": save_stem or save_intent,
            "generation_goal": normalize_goal(generation_goal),
            "generation_difficulty": normalize_difficulty(generation_difficulty),
            "preset_id": preset_id,
            "stem_model": _stem_model_val,
            "notes": chosen_notes,
            "statistics": {
                "total_notes": len(chosen_notes),
                "drum_notes": drum_count
            },
            "track_info": {
                'title': (track_info.get('title') if track_info else 'Unknown'),
                'artist': (track_info.get('artist') if track_info else 'Unknown'),
                'genres': final_genres,
                'primary_genre': final_primary,
                'genres_source': genres_source,
                'genre_predictions': track_info.get('genre_predictions', []) if track_info else [],
            },
            "perf": _perf,
        }
        style_label = str(save_stem or preset_id or chart_intent or generation_mode or "basic")
        print(f"[DrumGen] Успешно сгенерировано {len(chosen_notes)} нот ({style_label})")
        print(f"   - Жанры: {', '.join(final_genres) if final_genres else 'не определены'}")
        print(f"   - Источник жанров: {genres_source} | primary: {final_primary or 'не задан'}")
        print(format_rhythm_dna_log(rhythm_dna_payload, context="API response / task_result payload"))
        print(f"[RhythmDNA] task_id={task_id} -> /rhythm_dna?task_id={task_id}")
        print("[PERF][GENERATION]")
        for _k, _v in _perf.items():
            print(f"  {_k:20} {_v} ms")
        _report_status(task_id, "Формирование ответа...")
        if task_id in TASK_CONTEXT:
            TASK_CONTEXT[task_id]["success"] = True
        _store_task_result(task_id, response_data)
        return jsonify(response_data)

    except RuntimeError as e:
        if str(e) == "__CANCELLED__":
            print(f"[DrumGen] Задача отменена: {task_id}")
            _report_status(task_id, "Отменено пользователем")
            cancelled_payload = {
                "status": "cancelled_by_user",
                "message": "Отменено пользователем",
                "task_id": task_id
            }
            _store_task_result(task_id, cancelled_payload)
            return jsonify(cancelled_payload), 200
        raise
    except Exception as e:
        print(f"[DrumGen] Исключение: {e}")
        import traceback
        traceback.print_exc()
        error_payload = {"status": "error", "error": str(e)}
        _store_task_result(task_id, error_payload)
        return jsonify({"error": str(e)}), 500
    finally:
        _cleanup_task(task_id)


@bp.route("/generate_bass", methods=["POST"])
def generate_bass():
    _debug_log("DEBUG /generate_bass: request received")
    import time as _perf_time_bass
    _perf_start_bass = _perf_time_bass.perf_counter()
    _perf_bass = {}
    temp_path = None
    task_id = request.headers.get("X-Task-Id", "")
    try:
        _check_cancel(task_id)
        if "audio_file" not in request.files:
            return jsonify({"error": "Missing 'audio_file' in multipart form"}), 400
        if "metadata" not in request.form:
            return jsonify({"error": "Missing 'metadata' in multipart form"}), 400
        audio_file = request.files["audio_file"]
        try:
            metadata = json.loads(request.form["metadata"])
        except json.JSONDecodeError as e:
            return jsonify({"error": f"Invalid JSON in 'metadata': {str(e)}"}), 400

        bpm = metadata.get("bpm")
        lanes = metadata.get("lanes", 5)
        chart_stem = metadata.get("chart_stem") or metadata.get("chart_intent") or "original"
        generation_goal = metadata.get("goal") or metadata.get("generation_goal")
        generation_difficulty = metadata.get("difficulty") or metadata.get("generation_difficulty")
        use_stems = bool(metadata.get("use_stems", True))
        original_filename = metadata.get("original_filename", "uploaded_audio.mp3")
        genres = metadata.get("genres")
        primary_genre = metadata.get("primary_genre")
        progress_delay_seconds = float(metadata.get("progress_delay_seconds", 0.0))

        from app import song_storage
        from app.bass_generator import generate_bass_notes, save_generated_bass
        from app.drum_utils import CANONICAL_MAX_LANES
        from app.generation_intents import resolve_goal_difficulty_request

        resolved = resolve_goal_difficulty_request(
            goal=generation_goal,
            difficulty=generation_difficulty,
            chart_stem=chart_stem,
        )
        generation_goal = resolved["goal"]
        generation_difficulty = resolved["difficulty"]
        chart_stem = resolved.get("chart_stem") or chart_stem
        print(
            f"[BassGen] goal={generation_goal!r} difficulty={generation_difficulty!r} "
            f"chart_stem={chart_stem!r} resolution={resolved.get('resolution')!r}"
        )

        generate_lanes = max(int(lanes), CANONICAL_MAX_LANES)
        safe_filename = _normalize_filename(original_filename, default_ext=".mp3")
        song_path_client = song_storage.normalize_song_path(str(metadata.get("song_path", "")))
        chart_id = song_storage.resolve_chart_id(metadata, song_path=song_path_client)
        legacy_stem = Path(safe_filename).stem
        if chart_id:
            song_storage.maybe_migrate_legacy_folder(chart_id, legacy_stem)
            upload_dir = song_storage.song_dir(chart_id)
            upload_dir.mkdir(parents=True, exist_ok=True)
            temp_path = str(upload_dir / safe_filename)
            song_storage.write_song_meta(
                chart_id,
                {
                    "chart_id": chart_id,
                    "song_path": song_path_client,
                    "original_filename": original_filename,
                    "legacy_stem": legacy_stem,
                },
            )
        else:
            os.makedirs("temp_uploads", exist_ok=True)
            temp_path = os.path.join("temp_uploads", safe_filename)
        audio_file.save(temp_path)
        _register_task_context(task_id, temp_path, metadata)
        _check_cancel(task_id)

        if bpm is None:
            print("[BassGen] BPM не передан, выполняется расчёт...")
            _check_cancel(task_id)
            bpm_result = bpm_analyzer.calculate_bpm(temp_path, save_cache=False, cancel_cb=lambda: _check_cancel(task_id))
            if bpm_result.get("bpm") is None:
                error_msg = bpm_result.get("error", "Failed to calculate BPM")
                return jsonify({"error": f"Could not determine BPM: {error_msg}"}), 500
            bpm = bpm_result["bpm"]
            print(f"[BassGen] Рассчитанный BPM: {bpm}")
        else:
            try:
                bpm = float(bpm)
                if not (1 <= bpm <= 300):
                    raise ValueError("BPM out of range")
            except (ValueError, TypeError):
                return jsonify({"error": "Invalid 'bpm': must be number 1-300"}), 400

        normalized_genres = [g for g in (genres or []) if isinstance(g, str) and g.strip()]
        provided_genres = normalized_genres if normalized_genres else None
        normalized_primary_genre = (
            primary_genre
            if primary_genre and primary_genre.strip().lower() != "unknown"
            else None
        )
        artist_guess, title_guess = _extract_artist_title_from_filename(original_filename)
        track_info = {
            "artist": artist_guess or "Unknown",
            "title": title_guess or "Unknown",
            "genres": [],
            "primary_genre": "",
            "success": False,
        }
        effective_primary = normalized_primary_genre
        if effective_primary is None and provided_genres is None and GENRE_DETECTION_AVAILABLE:
            _report_status(task_id, "Идентификация трека...")
            _report_status(task_id, "Определение жанров...")
            if progress_delay_seconds > 0:
                time.sleep(progress_delay_seconds)
            try:
                detected = detect_genres("Unknown", "Unknown", audio_path=temp_path) or []
                track_info["genres"] = detected
                track_info["genre_predictions"] = detect_genre_predictions(temp_path, top_k=5)
                if detected:
                    effective_primary = detected[0]
                print(f"[BassGen] Жанры по аудио: {detected}")
            except Exception as e:
                print(f"[BassGen] Ошибка определения жанров: {e}")
        if provided_genres is not None:
            track_info["genres"] = list(provided_genres)
        if effective_primary is not None:
            track_info["primary_genre"] = effective_primary
        _check_cancel(task_id)

        notes = generate_bass_notes(
            temp_path,
            float(bpm),
            lanes=generate_lanes,
            use_stems=use_stems,
            chart_id=chart_id,
            goal=generation_goal,
            difficulty=generation_difficulty,
            status_cb=lambda s: _report_status(task_id, s),
            cancel_cb=lambda: _check_cancel(task_id),
        )
        if not notes:
            return jsonify({"error": "No bass notes generated"}), 500

        _report_status(task_id, "Сохранение нот...")
        save_generated_bass(
            notes,
            temp_path,
            chart_stem=str(chart_stem),
            lanes=generate_lanes,
            chart_id=chart_id,
        )
        from app.bass_generator import _shape_counts as bass_shape_counts

        print(
            f"[BassGen] Успешно сгенерировано {len(notes)} нот "
            f"(stem={chart_stem}, goal={generation_goal}, difficulty={generation_difficulty})"
        )
        print(f"   - shapes: {bass_shape_counts(notes)} | lanes={generate_lanes} | bpm={bpm:g}")
        try:
            from app.audio_analysis import get_last_stem_model as _get_bass_stem_model
            _bass_stem_model_val = str(_get_bass_stem_model("bass") or "")
        except Exception:
            _bass_stem_model_val = ""
        _perf_bass["total_ms"] = int((_perf_time_bass.perf_counter() - _perf_start_bass) * 1000)
        response_data = {
            "status": "success",
            "task_id": task_id,
            "bpm": bpm,
            "lanes": generate_lanes,
            "instrument_type": "bass",
            "chart_stem": chart_stem,
            "goal": generation_goal,
            "difficulty": generation_difficulty,
            "generation_goal": generation_goal,
            "generation_difficulty": generation_difficulty,
            "stem_model": _bass_stem_model_val,
            "notes": notes,
            "statistics": {"total_notes": len(notes)},
            "perf": _perf_bass,
        }
        print("[PERF][GENERATION]")
        for _k, _v in _perf_bass.items():
            print(f"  {_k:20} {_v} ms")
        if task_id in TASK_CONTEXT:
            TASK_CONTEXT[task_id]["success"] = True
        _store_task_result(task_id, response_data)
        _report_status(task_id, "Формирование ответа...")
        return jsonify(response_data)
    except RuntimeError as e:
        if str(e) == "__CANCELLED__":
            cancelled_payload = {"status": "cancelled_by_user", "message": "Отменено пользователем", "task_id": task_id}
            _store_task_result(task_id, cancelled_payload)
            return jsonify(cancelled_payload), 200
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        error_payload = {"status": "error", "error": str(e)}
        _store_task_result(task_id, error_payload)
        return jsonify({"error": str(e)}), 500
    finally:
        _cleanup_task(task_id)


@bp.route("/stem_file", methods=["GET"])
def stem_file():
    """Deliver already generated stem WAV (no generation)."""
    from app import song_storage

    kind = str(request.args.get("kind", "")).strip().lower()
    content_hash = str(request.args.get("content_hash", "")).strip().lower()
    chart_id = str(request.args.get("chart_id", "")).strip().lower()

    # --- Validation ---
    if kind not in ("drums", "bass"):
        return jsonify({"error": "invalid kind: must be drums or bass", "kind": kind}), 400

    def _is_valid_hex(s: str, lengths: tuple[int, ...]) -> bool:
        if not s or len(s) not in lengths:
            return False
        return all(c in "0123456789abcdef" for c in s)

    has_content = bool(content_hash)
    has_chart = bool(chart_id)
    if has_content and not _is_valid_hex(content_hash, (16, 64)):
        return jsonify({"error": "invalid content_hash: must be 16 or 64 hex chars"}), 400
    if has_chart and not song_storage.is_hash_dir_name(chart_id):
        return jsonify({"error": "invalid chart_id: must be 16 hex chars"}), 400
    if not has_content and not has_chart:
        return jsonify({"error": "content_hash or chart_id required"}), 400

    # No path traversal: never accept filesystem path from client, only hashes.
    if any(sep in content_hash for sep in ("/", "\\", ".")) or any(sep in chart_id for sep in ("/", "\\", ".")):
        return jsonify({"error": "invalid identifier"}), 400

    fmt = str(request.args.get("format", "wav")).strip().lower()
    if fmt not in ("wav", "mp3"):
        return jsonify({"error": "invalid format: must be wav or mp3"}), 400

    # --- Lookup ---
    # Use absolute base to be independent of CWD / app.root_path (Flask relative resolution).
    try:
        base_uploads = Path(song_storage.TEMP_UPLOADS_DIR).resolve()
    except Exception:
        base_uploads = Path("temp_uploads").resolve()
    stem_path: Path | None = None

    # 1) content_hash + kind (primary) — scan existing temp folders, compare SHA256(original bytes)
    if has_content:
        # Scan hash-named directories only; no recursive arbitrary path read.
        try:
            if base_uploads.is_dir():
                for entry in base_uploads.iterdir():
                    if not entry.is_dir() or not song_storage.is_hash_dir_name(entry.name):
                        continue
                    # Find original audio in this folder (any audio extension)
                    original_candidates: list[Path] = []
                    try:
                        for p in entry.iterdir():
                            if p.is_file() and p.suffix.lower() in song_storage._AUDIO_EXTENSIONS:
                                if p.name.lower().endswith((".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac")):
                                    original_candidates.append(p)
                    except OSError:
                        continue
                    if not original_candidates:
                        continue
                    # Use same helper as Phase 1: SHA256(original bytes)
                    matched = False
                    for orig in original_candidates:
                        try:
                            full_hash = song_storage.audio_content_hash(orig)
                        except Exception:
                            full_hash = ""
                        if not full_hash:
                            continue
                        if len(content_hash) == 16:
                            if full_hash[:16] == content_hash:
                                matched = True
                                break
                        else:
                            if full_hash == content_hash:
                                matched = True
                                break
                    if not matched:
                        continue
                    # Content matched — check stem exists via canonical name (absolute)
                    candidate = base_uploads / entry.name / "splitter" / song_storage.stem_wav_name(entry.name, kind)
                    if candidate.is_file():
                        stem_path = candidate
                        break
                    # Fallback: any valid stem candidate in splitter (should not happen, but safe)
                    alt = list((entry / "splitter").glob(f"*_{kind}.wav"))
                    for a in alt:
                        if a.is_file():
                            stem_path = a
                            break
                    if stem_path is not None:
                        break
        except Exception:
            pass

    # 2) legacy chart_id + kind fallback (if content_hash miss or not provided)
    if stem_path is None and has_chart:
        candidate = base_uploads / chart_id / "splitter" / song_storage.stem_wav_name(chart_id, kind)
        if candidate.is_file():
            stem_path = candidate

    # 3) fallback to existing stem_memory_cache (temporary cache, TTL 900) if splitter missing
    # Do not reconstruct cache filename manually — use existing helper get_cached_stem which
    # computes SHA256(original bytes)+kind and respects TTL/purge.
    if stem_path is None:
        try:
            import app.stem_memory_cache as stem_memory_cache
            # Content_hash based cache lookup: find original audio matching content_hash, then get_cached_stem
            if has_content and base_uploads.is_dir():
                for entry in base_uploads.iterdir():
                    if not entry.is_dir() or not song_storage.is_hash_dir_name(entry.name):
                        continue
                    # Collect originals in this entry
                    try:
                        candidates: list[Path] = []
                        for p in entry.iterdir():
                            if p.is_file() and p.suffix.lower() in song_storage._AUDIO_EXTENSIONS:
                                if p.name.lower().endswith((".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac")):
                                    candidates.append(p)
                    except OSError:
                        continue
                    for orig in candidates:
                        # Verify original matches requested content_hash (same helper as temp lookup)
                        try:
                            fh = song_storage.audio_content_hash(orig)
                        except Exception:
                            fh = ""
                        if not fh:
                            continue
                        if len(content_hash) == 16:
                            if fh[:16] != content_hash:
                                continue
                        else:
                            if fh != content_hash:
                                continue
                        # Use existing API — pass original path, not hash
                        try:
                            cached = stem_memory_cache.get_cached_stem(str(orig), kind)
                        except Exception:
                            cached = None
                        if cached and Path(cached).is_file():
                            stem_path = Path(cached)
                            break
                    if stem_path is not None:
                        break
            # Chart_id based cache fallback (if content_hash miss or not provided, or cache miss)
            if stem_path is None and has_chart:
                chart_folder = base_uploads / chart_id
                if chart_folder.is_dir():
                    for p in chart_folder.iterdir():
                        if not p.is_file() or p.suffix.lower() not in song_storage._AUDIO_EXTENSIONS:
                            continue
                        if not p.name.lower().endswith((".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac")):
                            continue
                        # If content_hash was provided, ensure this original matches it
                        if has_content:
                            try:
                                fh2 = song_storage.audio_content_hash(p)
                            except Exception:
                                fh2 = ""
                            if not fh2:
                                continue
                            if len(content_hash) == 16:
                                if fh2[:16] != content_hash:
                                    continue
                            else:
                                if fh2 != content_hash:
                                    continue
                        try:
                            cached2 = stem_memory_cache.get_cached_stem(str(p), kind)
                        except Exception:
                            cached2 = None
                        if cached2 and Path(cached2).is_file():
                            stem_path = Path(cached2)
                            break
        except Exception:
            pass

    if stem_path is None or not stem_path.is_file():
        return jsonify({"error": "stem not found", "kind": kind}), 404

    # Never trigger generation: only serve existing file under TEMP_UPLOADS_DIR or stem_memory_cache
    # Do not copy cache to temp_uploads, do not move, do not change TTL.
    try:
        resolved = stem_path.resolve()
        uploads_resolved = base_uploads.resolve()
        # Allow either temp_uploads tree or stem_memory_cache dir (%TEMP%/RhythmFall/stems)
        is_in_uploads = uploads_resolved in resolved.parents or resolved.parent.resolve() == uploads_resolved or str(resolved).startswith(str(uploads_resolved))
        is_in_cache = False
        try:
            import app.stem_memory_cache as stem_memory_cache_check
            cache_dir = Path(stem_memory_cache_check._CACHE_DIR).resolve()
            is_in_cache = cache_dir in resolved.parents or resolved.parent.resolve() == cache_dir or str(resolved).startswith(str(cache_dir))
        except Exception:
            is_in_cache = False
        if not is_in_uploads and not is_in_cache:
            return jsonify({"error": "invalid stem path"}), 400
    except Exception:
        return jsonify({"error": "stem not found"}), 404

    if fmt == "wav":
        return send_file(str(resolved), mimetype="audio/wav", as_attachment=False, download_name=stem_path.name)

    # MP3 conversion (server-side, 192k, transient) — only from existing WAV
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("[StemFile] ffmpeg not found for mp3 conversion")
        return jsonify({"error": "ffmpeg not available for mp3 conversion"}), 500
    tmp_mp3 = resolved.with_name(resolved.stem + ".mp3.tmp")
    try:
        if tmp_mp3.is_file():
            tmp_mp3.unlink(missing_ok=True)
    except Exception:
        pass
    cmd = [ffmpeg, "-y", "-nostdin", "-hide_banner", "-loglevel", "error", "-i", str(resolved), "-f", "mp3", "-codec:a", "libmp3lame", "-b:a", "192k", str(tmp_mp3)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except Exception as e:
        print(f"[StemFile] ffmpeg subprocess failed: {e}")
        return jsonify({"error": "mp3 conversion failed", "detail": str(e)}), 500
    if result.returncode != 0:
        print(f"[StemFile] ffmpeg failed code={result.returncode} stderr={result.stderr[:500] if result.stderr else ''}")
        try:
            if tmp_mp3.is_file():
                tmp_mp3.unlink(missing_ok=True)
        except Exception:
            pass
        return jsonify({"error": "mp3 conversion failed", "detail": (result.stderr or "")[:500]}), 500
    if not tmp_mp3.is_file():
        return jsonify({"error": "mp3 conversion failed: output missing"}), 500
    try:
        if tmp_mp3.stat().st_size < 1024:
            tmp_mp3.unlink(missing_ok=True)
            return jsonify({"error": "mp3 conversion failed: output too small"}), 500
    except Exception:
        try:
            tmp_mp3.unlink(missing_ok=True)
        except Exception:
            pass
        return jsonify({"error": "mp3 conversion failed"}), 500
    print(f"[StemFile] wav->mp3 {resolved.name} -> {tmp_mp3.name} {tmp_mp3.stat().st_size} bytes")

    @after_this_request
    def _cleanup_mp3(response):
        try:
            if tmp_mp3.is_file():
                tmp_mp3.unlink(missing_ok=True)
        except Exception:
            pass
        return response

    return send_file(str(tmp_mp3), mimetype="audio/mpeg", as_attachment=False, download_name=resolved.stem + ".mp3")


@bp.route("/health", methods=["GET"])
def health_check():
    gpu = {}
    try:
        from .gpu_backend import gpu_status_payload

        gpu = gpu_status_payload()
    except Exception:
        gpu = {}
    return jsonify({
        "status": "healthy",
        "timestamp": time.time(),
        "gpu": gpu,
        "endpoints": [
            "/",
            "/analyze_bpm",
            "/generate_drums",
            "/generate_bass",
            "/task_status",
            "/task_result",
            "/rhythm_dna",
            "/rhythm_dna_sidecar",
            "/cancel_task",
            "/storage_usage",
            "/storage_reclaim",
            "/stem_file",
            "/health",
        ]
    })


def _temp_uploads_root_artifacts_usage() -> dict:
    """Usage for files directly under temp_uploads/ root (not song subfolders)."""
    from app import song_storage

    root = song_storage.TEMP_UPLOADS_DIR
    total_bytes: int = 0
    files: int = 0
    try:
        if root.exists() and root.is_dir():
            for p in root.iterdir():
                try:
                    if p.is_file():
                        files += 1
                        total_bytes += int(p.stat().st_size)
                except OSError:
                    pass
    except Exception:
        # Keep endpoint resilient; UI can fall back to N/A.
        return {"bytes": 0, "files": 0, "error": "usage_failed"}
    return {"bytes": total_bytes, "files": files}


def _temp_uploads_root_artifacts_reclaim() -> dict:
    """Delete all files directly under temp_uploads/ root (never song subfolders)."""
    from app import song_storage

    root = song_storage.TEMP_UPLOADS_DIR
    total_bytes: int = 0
    deleted_files: int = 0
    errors: int = 0
    try:
        if root.exists() and root.is_dir():
            for p in root.iterdir():
                try:
                    if not p.is_file():
                        continue
                    try:
                        total_bytes += int(p.stat().st_size)
                    except OSError:
                        pass
                    p.unlink(missing_ok=True)
                    deleted_files += 1
                except Exception:
                    errors += 1
    except Exception:
        return {"deleted_files": 0, "freed_bytes": 0, "errors": 1, "error": "reclaim_failed"}
    return {"deleted_files": deleted_files, "freed_bytes": total_bytes, "errors": errors}


def _temp_stem_wavs_usage() -> dict:
    """Usage for stem wav files under temp_uploads/*/splitter/. (server stems)."""
    uploads = Path("temp_uploads")
    total_bytes: int = 0
    files: int = 0
    try:
        if uploads.exists() and uploads.is_dir():
            for splitter in uploads.glob("*/splitter"):
                if not splitter.is_dir():
                    continue
                for wav in splitter.glob("*.wav"):
                    if wav.is_file():
                        files += 1
                        try:
                            total_bytes += int(wav.stat().st_size)
                        except OSError:
                            pass
    except Exception:
        return {"bytes": 0, "files": 0, "error": "usage_failed"}
    return {"bytes": total_bytes, "files": files}


@bp.route("/storage_usage", methods=["GET", "POST"])
def storage_usage_endpoint():
    """Return a minimal storage usage breakdown for disk reclaim UI."""
    temp_usage = _temp_uploads_root_artifacts_usage()
    stem_usage = _temp_stem_wavs_usage()
    return jsonify(
        {
            "ok": True,
            "temp_uploads_root_artifacts": temp_usage,
            "temp_stem_wavs": stem_usage,
        }
    )


@bp.route("/storage_reclaim", methods=["POST"])
def storage_reclaim_endpoint():
    """Reclaim safe disk space (server-side temp uploads artifacts)."""
    payload = request.get_json(silent=True) or {}
    reclaim_temp = bool(payload.get("temp_uploads_root_artifacts", False))
    reclaim_stems = bool(payload.get("temp_stem_wavs_all", False))

    summary: dict = {"ok": True, "reclaimed": []}
    if reclaim_temp:
        res = _temp_uploads_root_artifacts_reclaim()
        summary["reclaimed"].append(
            {
                "key": "temp_uploads_root_artifacts",
                "deleted_files": res.get("deleted_files", 0),
                "freed_bytes": res.get("freed_bytes", 0),
                "errors": res.get("errors", 0),
            }
        )

    if reclaim_stems:
        from app import stem_retention

        res = stem_retention.purge_all_stem_wavs()
        summary["reclaimed"].append(
            {
                "key": "temp_stem_wavs_all",
                "deleted_files": res.get("deleted_files", 0),
                "freed_bytes": res.get("freed_bytes", 0),
                "errors": res.get("errors", 0),
            }
        )

    return jsonify(summary)
