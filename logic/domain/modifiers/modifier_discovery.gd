# logic/domain/modifiers/modifier_discovery.gd
# MVP Modifier Discovery — 7 правил, TOP3, объяснимо.
# API: ModifierDiscovery.build(song_path: String = "") -> Array[Dictionary Candidate]
# Candidate: {mods:Array[String], params:Dictionary, category:String, reason_key:String, reason_args:Array, score:float, confidence:float, reward_delta:float, difficulty_stars:int, is_safe:bool}
extends RefCounted
class_name ModifierDiscovery

const _RunModifiers = preload("res://logic/domain/modifiers/run_modifiers.gd")

# Категории для UI бейджей
const CAT_FIT := "fit"         # Тебе подходит
const CAT_NEXT := "next"       # Следующий шаг
const CAT_COMBO := "combo"     # Попробуй сочетание
const CAT_CHALLENGE := "challenge" # Брось вызов

# Внутренний порог показа
const CONFIDENCE_THRESHOLD := 0.55

# Phase 1-3: веса ранжирования и лимиты
const NOVELTY_W := 6.0         # вес новизны кандидата
const PRIORITY_W := 6.0        # вес приоритетности (категория × momentum)
const QUALITY_MARGIN := 12.0   # мягкий порог качества для TOP3 (не форсируем слабые карточки)
const ANTI_REPEAT_RUNS := 10   # (заготовка V2) окно подавления повторов
const MAX_RATING := 10         # потолок звёзд сложности (chart_rating — int 1..10)
const DIFFICULTY_MIN_SAMPLES := 3  # мин. сэмплов на рейтинг для потолка сложности
const DIFFICULTY_COMFORT_ACC := 0.90  # порог комфорта по точности
const DIFFICULTY_DECLINE_DELTA := -0.03  # спад точности — не предлагать рост

static func build(song_path: String = "") -> Array:
	var candidates: Array = []
	# Глобальный сбор — song_path == "" (MVP), track-specific уже заложен (фильтр по path в V2)
	var stats := _collect_stats(song_path)

	# --- MVP правила (сохранены без изменений поведения) ---
	# 1) strict_timing — готовность = качество × сложность
	candidates.append_array(_rule_strict_timing(stats, song_path))
	# 2) hidden — visibility новичок
	candidates.append_array(_rule_hidden(stats, song_path))
	# 3) hidden+strict — синергия, следующий шаг после hidden
	candidates.append_array(_rule_hidden_strict(stats, song_path))
	# 4) hidden+mirror — кросс-категория
	candidates.append_array(_rule_hidden_mirror(stats, song_path))
	# 5) mirror — lane remap новичок
	candidates.append_array(_rule_mirror(stats, song_path))
	# 6) easy_windows — для низкой точности
	candidates.append_array(_rule_easy_windows(stats, song_path))
	# 7) sudden — challenge, осторожно (конъюнкция)
	candidates.append_array(_rule_sudden_challenge(stats, song_path))

	# --- Phase 1-3: правила прогрессии модификаторов ---
	candidates.append_array(_rule_prog_strict_combo(stats))
	candidates.append_array(_rule_prog_hidden_mirror(stats))
	candidates.append_array(_rule_prog_sudden_visibility(stats))
	candidates.append_array(_rule_prog_mirror_rush(stats))
	candidates.append_array(_rule_prog_category_next(stats))
	candidates.append_array(_rule_prog_combo_challenge(stats))
	# --- Phase 1-3: рекомендация сложности (comfort ceiling) ---
	candidates.append_array(_rule_difficulty(stats))

	# V2 runtime-UI: в strict_high_acc-рекомендации сложность (3-й аргумент reason)
	# выносим в отдельный difficulty-widget (zap+число), чтобы не писать "X stars" текстом.
	# Не меняет логику 7 MVP-правил — только подготовка данных для отображения.
	_prepare_strict_difficulty_widget(candidates)

	# Фильтр: sanitize + DNA-gate + autoplay exclude + пропуск не-модификаторных типов
	candidates = _filter_candidates(candidates, song_path)

	# Единая модель кандидата: тип по умолчанию "modifier", новизна и приоритет
	for c in candidates:
		if not c.has("type"):
			c["type"] = "modifier"
		c["novelty"] = _compute_novelty(stats, c)
		c["priority"] = _compute_priority(stats, c)

	# Ранжирование: score*0.85 + confidence*15 + novelty*W + priority*W - repeat_penalty
	_rank(candidates)

	# Порог confidence
	var filtered: Array = []
	for c in candidates:
		if float(c.get("confidence",0)) >= CONFIDENCE_THRESHOLD:
			filtered.append(c)
	if filtered.is_empty() and not candidates.is_empty():
		# Новый профиль — показать популярные безопасные (hidden, mirror, no_fail) с low confidence
		filtered = _fallback_popular(candidates)

	# Diversity: дедуп по ключу рекомендации (не дублируем одно и то же)
	var diverse: Array = _apply_diversity(filtered)
	# TOP3 с мягким порогом качества и лимитом по типу
	var top3 := _pick_top3(diverse)
	return top3

# ---------------------------------------------------------------------------
# Stats сбор — минимальный достаточный набор (4 сигнала из аудита)
static func _collect_stats(song_path: String) -> Dictionary:
	var out := {}
	# PlayerDataManager
	var pdm = PlayerDataManager
	var track_mgr = TrackStatsManager
	# Modifier stats
	var mod_stats: Dictionary = {}
	if pdm and pdm.has_method("get_modifier_stats"):
		mod_stats = pdm.get_modifier_stats()
	out["mod_stats"] = mod_stats
	# Chart difficulty
	var chart_stats: Dictionary = {}
	if pdm and pdm.has_method("get_chart_difficulty_stats"):
		chart_stats = pdm.get_chart_difficulty_stats()
	out["chart_stats"] = chart_stats
	# Max / avg
	out["max_cleared"] = int(chart_stats.get("max_cleared", 0))
	var clears_count := int(chart_stats.get("clears_count", 0))
	var rating_sum := int(chart_stats.get("rating_sum", 0))
	out["avg_rating"] = float(rating_sum) / float(maxi(clears_count,1)) if clears_count>0 else 0.0
	out["clears_count"] = clears_count
	# Weekly accuracy
	var hist: Array = []
	if pdm and pdm.has_method("get_modifier_stats"):
		# session_history через ResultsHistoryService
		var svc = preload("res://logic/data/results_history_service.gd").new()
		hist = svc.get_history()
	# Используем ProfileStatTrends если доступно, иначе fallback по hist
	var week_acc := -1.0
	var week_delta := 0.0
	var week_n := 0
	if hist.size() >= 5:
		# Простой расчет: последние 7 дней vs предыдущие 7
		var now_unix := int(Time.get_unix_time_from_system())
		var acc_recent := []
		var acc_prior := []
		for s in hist:
			var d: String = str(s.get("date",""))
			var ts: int = TimeUtils.unix_from_local_iso_datetime(d)
			if ts <=0: continue
			var diff := now_unix - ts
			if diff < 0: continue
			if diff < 7*86400:
				acc_recent.append(float(s.get("accuracy",0)))
			elif diff < 14*86400:
				acc_prior.append(float(s.get("accuracy",0)))
		if acc_recent.size()>0:
			week_acc = 0.0
			for v in acc_recent: week_acc+=v
			week_acc/=acc_recent.size()
			week_n = acc_recent.size()
		if acc_recent.size()>0 and acc_prior.size()>0:
			var prior_avg := 0.0
			for v in acc_prior: prior_avg+=v
			prior_avg/=acc_prior.size()
			week_delta = week_acc - prior_avg
	out["week_average_accuracy"] = week_acc
	out["week_accuracy_delta"] = week_delta
	out["week_n"] = week_n
	# Total accuracy по hist
	var total_acc := 0.0
	var total_cnt := 0
	for s in hist:
		total_acc += float(s.get("accuracy",0))
		total_cnt+=1
	out["global_avg_accuracy"] = total_acc / float(maxi(total_cnt,1)) if total_cnt>0 else -1.0
	out["total_runs"] = total_cnt
	# Rating frequency map — для потолка сложности (comfort ceiling)
	var rating_freq := {}
	for s in hist:
		var r: int = int(s.get("chart_rating", 0))
		if r > 0:
			rating_freq[r] = int(rating_freq.get(r, 0)) + 1
	out["rating_freq"] = rating_freq
	# Сырая история — для новизны и потолка сложности
	out["history"] = hist
	# Genre / instrument — для V1 не используем, но собираем для V2
	out["song_path"] = song_path
	return out

# ---------------------------------------------------------------------------
# Правила — каждое возвращает 0..1 кандидатов с уже проставленными score/confidence

static func _rule_strict_timing(stats: Dictionary, song_path: String) -> Array:
	# Готовность = качество × сложность: accuracy≥95 AND max≥5 AND avg≥4.5 AND n≥5
	var n: int = int(stats.get("clears_count",0))
	var acc: float = float(stats.get("week_average_accuracy", -1))
	if acc <0: acc = float(stats.get("global_avg_accuracy",0))
	var max_cleared: int = int(stats.get("max_cleared",0))
	var avg: float = float(stats.get("avg_rating",0))
	if acc <95 or max_cleared <5 or avg <4.5 or n <5:
		return []
	var mods := [RunModifiers.ID_STRICT_TIMING]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_STRICT_TIMING,0))
	var stars := RunModifiers.modifier_difficulty_stars(RunModifiers.ID_STRICT_TIMING)
	var confidence := _confidence_for_n(n, float(stats.get("week_accuracy_delta",0)))
	return [{
		"mods": mods, "params": params, "category": CAT_FIT,
		"reason_key": "MODREC_REASON_STRICT_HIGH_ACC", "reason_args": [n, "%.1f%%" % acc, str(max_cleared)],
		"score": 85.0, "confidence": confidence, "reward_delta": reward, "difficulty_stars": stars, "is_safe": true
	}]

static func _rule_hidden(stats: Dictionary, _song_path: String) -> Array:
	var mod_stats: Dictionary = stats.get("mod_stats",{})
	var cat_vis: int = int(mod_stats.get("clears_cat_visibility",0))
	if cat_vis != 0:
		return []
	# Нет видимости — самый мягкий hardening
	var mods := [RunModifiers.ID_HIDDEN]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_HIDDEN,0))
	var stars := RunModifiers.modifier_difficulty_stars(RunModifiers.ID_HIDDEN)
	return [{
		"mods": mods, "params": params, "category": CAT_NEXT,
		"reason_key": "MODREC_REASON_HIDDEN_FIRST", "reason_args": [],
		"score": 78.0, "confidence": 0.85, "reward_delta": reward, "difficulty_stars": stars, "is_safe": true
	}]

static func _rule_hidden_strict(stats: Dictionary, _song_path: String) -> Array:
	var mod_stats: Dictionary = stats.get("mod_stats",{})
	var hidden_clears: int = int(mod_stats.get("clears_hidden",0))
	var strict_clears: int = int(mod_stats.get("clears_strict_timing",0))
	if hidden_clears <3 or strict_clears !=0:
		return []
	var acc: float = float(stats.get("week_average_accuracy", -1))
	if acc <0: acc = float(stats.get("global_avg_accuracy",0))
	if acc <93: return []
	var mods := [RunModifiers.ID_HIDDEN, RunModifiers.ID_STRICT_TIMING]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_HIDDEN,0)) + float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_STRICT_TIMING,0))
	return [{
		"mods": mods, "params": params, "category": CAT_COMBO,
		"reason_key": "MODREC_REASON_HIDDEN_STRICT", "reason_args": [hidden_clears],
		"score": 82.0, "confidence": _confidence_for_n(hidden_clears, 0), "reward_delta": reward, "difficulty_stars": 4, "is_safe": true
	}]

static func _rule_hidden_mirror(stats: Dictionary, _song_path: String) -> Array:
	var mod_stats: Dictionary = stats.get("mod_stats",{})
	var hidden_clears: int = int(mod_stats.get("clears_hidden",0))
	var mirror_clears: int = int(mod_stats.get("clears_cat_lanes",0)) # proxy for mirror
	if hidden_clears <3:
		return []
	# mirror/shuffle not yet cleared
	var has_mirror := false
	if mod_stats.has("clears_hidden") and int(mod_stats.get("clears_hidden",0))>0:
		# check if any remap cleared
		has_mirror = int(mod_stats.get("clears_cat_lanes",0)) >0
	if has_mirror:
		return []
	var mods := [RunModifiers.ID_HIDDEN, RunModifiers.ID_MIRROR_MODE]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_HIDDEN,0)) + float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_MIRROR_MODE,0))
	return [{
		"mods": mods, "params": params, "category": CAT_COMBO,
		"reason_key": "MODREC_REASON_HIDDEN_MIRROR", "reason_args": [],
		"score": 80.0, "confidence": 0.68, "reward_delta": reward, "difficulty_stars": 3, "is_safe": true
	}]

static func _rule_mirror(stats: Dictionary, _song_path: String) -> Array:
	var mod_stats: Dictionary = stats.get("mod_stats",{})
	var lanes_clears: int = int(mod_stats.get("clears_cat_lanes",0))
	if lanes_clears !=0:
		return []
	var mods := [RunModifiers.ID_MIRROR_MODE]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_MIRROR_MODE,0))
	return [{
		"mods": mods, "params": params, "category": CAT_NEXT,
		"reason_key": "MODREC_REASON_MIRROR_FIRST", "reason_args": [],
		"score": 75.0, "confidence": 0.75, "reward_delta": reward, "difficulty_stars": 2, "is_safe": true
	}]

static func _rule_easy_windows(stats: Dictionary, _song_path: String) -> Array:
	var acc: float = float(stats.get("week_average_accuracy", -1))
	if acc <0: acc = float(stats.get("global_avg_accuracy",0))
	var max_cleared: int = int(stats.get("max_cleared",0))
	if acc >=85 or max_cleared >4:
		return []
	var mods := [RunModifiers.ID_EASY_WINDOWS]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_EASY_WINDOWS,0))
	return [{
		"mods": mods, "params": params, "category": CAT_FIT,
		"reason_key": "MODREC_REASON_EASY_WINDOWS", "reason_args": [acc],
		"score": 70.0, "confidence": 0.7, "reward_delta": reward, "difficulty_stars": 1, "is_safe": true
	}]

static func _rule_sudden_challenge(stats: Dictionary, _song_path: String) -> Array:
	# Осторожно: hidden≥5 AND accuracy≥94 AND max≥5 AND delta>-1 AND sudden==0
	var mod_stats: Dictionary = stats.get("mod_stats",{})
	var hidden_clears: int = int(mod_stats.get("clears_hidden",0))
	var sudden_clears: int = int(mod_stats.get("clears_sudden",0))
	if hidden_clears <5 or sudden_clears !=0:
		return []
	var acc: float = float(stats.get("week_average_accuracy", -1))
	if acc <0: acc = float(stats.get("global_avg_accuracy",0))
	var max_cleared: int = int(stats.get("max_cleared",0))
	var delta: float = float(stats.get("week_accuracy_delta",0))
	if acc <94 or max_cleared <5 or delta <= -1.0:
		return []
	var mods := [RunModifiers.ID_SUDDEN]
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	var reward := float(RunModifiers.REWARD_DELTA.get(RunModifiers.ID_SUDDEN,0))
	return [{
		"mods": mods, "params": params, "category": CAT_CHALLENGE,
		"reason_key": "MODREC_REASON_SUDDEN_CHALLENGE", "reason_args": [hidden_clears, "%.1f%%" % acc],
		"score": 72.0, "confidence": _confidence_for_n(hidden_clears, delta), "reward_delta": reward, "difficulty_stars": 3, "is_safe": false
	}]

# ---------------------------------------------------------------------------
# Phase 1-3: правила прогрессии модификаторов
# Каждая функция возвращает 0..1 кандидатов типа "modifier".

static func _rule_prog_strict_combo(stats: Dictionary) -> Array:
	# Синергия: освоил hidden и strict по отдельности -> попробуй вместе
	var ms: Dictionary = stats.get("mod_stats", {})
	var hidden_clears: int = int(ms.get("clears_hidden", 0))
	var strict_clears: int = int(ms.get("clears_strict_timing", 0))
	if hidden_clears < 5 or strict_clears < 5:
		return []
	return [_mk([RunModifiers.ID_HIDDEN, RunModifiers.ID_STRICT_TIMING], CAT_COMBO,
		"MODREC_PROG_STRICT_COMBO", [hidden_clears], 82.0, _confidence_for_n(hidden_clears, 0))]

static func _rule_prog_hidden_mirror(stats: Dictionary) -> Array:
	# Освоил hidden, но ещё не пробовал lane-remap -> hidden+mirror
	var ms: Dictionary = stats.get("mod_stats", {})
	var hidden_clears: int = int(ms.get("clears_hidden", 0))
	var lanes_clears: int = int(ms.get("clears_cat_lanes", 0))
	if hidden_clears < 5 or lanes_clears != 0:
		return []
	return [_mk([RunModifiers.ID_HIDDEN, RunModifiers.ID_MIRROR_MODE], CAT_COMBO,
		"MODREC_PROG_HIDDEN_MIRROR", [hidden_clears], 80.0, 0.7)]

static func _rule_prog_sudden_visibility(stats: Dictionary) -> Array:
	# Готов к sudden: освоил visibility (hidden>=5, cat_vis>=5) и ещё не пробовал sudden
	var ms: Dictionary = stats.get("mod_stats", {})
	var hidden_clears: int = int(ms.get("clears_hidden", 0))
	var vis_clears: int = int(ms.get("clears_cat_visibility", 0))
	var sud_clears: int = int(ms.get("clears_sudden", 0))
	if sud_clears != 0 or hidden_clears < 5 or vis_clears < 5:
		return []
	return [_mk([RunModifiers.ID_SUDDEN], CAT_NEXT,
		"MODREC_PROG_SUDDEN_VIS", [hidden_clears], 75.0, _confidence_for_n(hidden_clears, 0))]

static func _rule_prog_mirror_rush(stats: Dictionary) -> Array:
	# Освоил lane-remap (>=3) и комбо-моды (>=1) -> mirror+rush
	var ms: Dictionary = stats.get("mod_stats", {})
	var lanes_clears: int = int(ms.get("clears_cat_lanes", 0))
	var c2_clears: int = int(ms.get("clears_2plus", 0))
	if lanes_clears < 3 or c2_clears < 1:
		return []
	return [_mk([RunModifiers.ID_MIRROR_MODE, RunModifiers.ID_RUSH], CAT_COMBO,
		"MODREC_PROG_MIRROR_RUSH", [lanes_clears], 78.0, 0.68)]

static func _rule_prog_category_next(stats: Dictionary) -> Array:
	# Глубоко освоил visibility -> следующий visibility-мод: spotlight
	var ms: Dictionary = stats.get("mod_stats", {})
	var hidden_clears: int = int(ms.get("clears_hidden", 0))
	var vis_clears: int = int(ms.get("clears_cat_visibility", 0))
	if hidden_clears < 8 or vis_clears < 12:
		return []
	return [_mk([RunModifiers.ID_SPOTLIGHT], CAT_NEXT,
		"MODREC_PROG_NEXT_SPOTLIGHT", [hidden_clears], 74.0, 0.66)]

static func _rule_prog_combo_challenge(stats: Dictionary) -> Array:
	# Часто берёт 2+ модификатора и не пробовал sudden -> вызов: sudden+no_fail
	var ms: Dictionary = stats.get("mod_stats", {})
	var c2_clears: int = int(ms.get("clears_2plus", 0))
	var sud_clears: int = int(ms.get("clears_sudden", 0))
	if c2_clears < 6 or sud_clears != 0:
		return []
	return [_mk([RunModifiers.ID_SUDDEN, RunModifiers.ID_NO_FAIL], CAT_CHALLENGE,
		"MODREC_PROG_COMBO_CHALLENGE", [c2_clears], 72.0, 0.6)]

# ---------------------------------------------------------------------------
# Phase 1-3: рекомендация сложности (comfort ceiling)
# Не использует модификаторы — destination routing реализуется в V2 Phase 4+.

static func _rule_difficulty(stats: Dictionary) -> Array:
	var hist: Array = stats.get("history", [])
	var rating_freq: Dictionary = stats.get("rating_freq", {})
	if hist.size() < 10:
		return []
	# Потолок комфорта: наивысший рейтинг с >=DIFFICULTY_MIN_SAMPLES и mean>=комфорта
	var ceiling := 0
	for r in range(1, MAX_RATING + 1):
		var cnt := int(rating_freq.get(r, 0))
		if cnt >= DIFFICULTY_MIN_SAMPLES:
			var mean_acc := _mean_accuracy_at_rating(hist, r)
			if mean_acc >= DIFFICULTY_COMFORT_ACC:
				ceiling = r
	if ceiling == 0:
		# Нет комфортного потолка (нет рейтинга с >=DIFFICULTY_MIN_SAMPLES и mean>=комфорта)
		# — НЕ предлагаем сложность (не используем max_cleared+1, см. V2 Review)
		return []
	if ceiling >= MAX_RATING:
		return []  # уже на потолке
	var delta: float = float(stats.get("week_accuracy_delta", 0))
	if delta <= DIFFICULTY_DECLINE_DELTA:
		return []  # точность падает — не толкаем вверх
	var target := ceiling + 1
	var conf := _confidence_for_difficulty(hist, ceiling)
	return [{
		"mods": [], "params": {}, "category": CAT_NEXT,
		"reason_key": "MODREC_DIFF_NEXT", "reason_args": [ceiling, target],
		"score": 70.0, "confidence": conf, "reward_delta": 0.0,
		"difficulty_stars": target, "is_safe": true, "type": "difficulty",
		"difficulty": target
	}]

# ---------------------------------------------------------------------------
# Helpers

static func _mk(mods: Array, category: String, reason_key: String, reason_args: Array, score: float, confidence: float) -> Dictionary:
	var reward := 0.0
	var stars := 0
	for m in mods:
		reward += float(RunModifiers.REWARD_DELTA.get(m, 0))
		stars = maxi(stars, RunModifiers.modifier_difficulty_stars(m))
	var params := RunModifiers.sanitize_params(RunModifiers.default_params())
	return {
		"mods": mods, "params": params, "category": category,
		"reason_key": reason_key, "reason_args": reason_args,
		"score": score, "confidence": confidence, "reward_delta": reward,
		"difficulty_stars": stars, "is_safe": true, "type": "modifier"
	}

static func _rank_score(c: Dictionary) -> float:
	var base := float(c.get("score", 0)) * 0.85 + float(c.get("confidence", 0)) * 15.0
	var nov := float(c.get("novelty", 0)) * NOVELTY_W
	var pri := float(c.get("priority", 0)) * PRIORITY_W
	var pen := _repeat_penalty(c)
	return base + nov + pri - pen

static func _rank(candidates: Array) -> void:
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := _rank_score(a)
		var sb := _rank_score(b)
		if absf(sa - sb) > 0.01:
			return sa > sb
		var ra := float(a.get("reward_delta", 0))
		var rb := float(b.get("reward_delta", 0))
		if str(a.get("category", "")) == CAT_FIT and str(b.get("category", "")) == CAT_FIT:
			return ra < rb
		if str(a.get("category", "")) == CAT_CHALLENGE:
			return ra > rb
		return sa > sb
	)

static func _compute_novelty(stats: Dictionary, c: Dictionary) -> float:
	# Новизна = комбинация модов ещё ни разу не встречалась в истории
	if str(c.get("type", "modifier")) != "modifier":
		return 0.0
	var mods: Array = c.get("mods", [])
	if mods.is_empty():
		return 0.0
	var hist: Array = stats.get("history", [])
	for s in hist:
		if _same_mods(mods, s.get("modifiers", [])):
			return 0.0
	return 1.0

static func _same_mods(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var sa := []
	var sb := []
	for x in a: sa.append(str(x))
	for x in b: sb.append(str(x))
	sa.sort(); sb.sort()
	for i in sa.size():
		if sa[i] != sb[i]:
			return false
	return true

static func _compute_priority(stats: Dictionary, c: Dictionary) -> float:
	var cat: String = str(c.get("category", ""))
	var cat_w := 0.5
	if cat == CAT_FIT:
		cat_w = 1.0
	elif cat == CAT_NEXT:
		cat_w = 0.9
	elif cat == CAT_COMBO:
		cat_w = 0.7
	elif cat == CAT_CHALLENGE:
		cat_w = 0.6
	var t: String = str(c.get("type", "modifier"))
	if t != "modifier":
		# difficulty: приоритет = вес категории (готовность уже в confidence)
		return cat_w
	var delta: float = float(stats.get("week_accuracy_delta", 0))
	var momentum := 0.5
	if delta > 0:
		momentum = 0.5 + clamp(delta, 0.0, 0.4)
	elif delta < 0:
		momentum = 0.5 + clamp(delta, -0.3, 0.0)
	return clamp(cat_w * momentum, 0.0, 1.0)

static func _prepare_strict_difficulty_widget(candidates: Array) -> void:
	# strict_high_acc-рекомендация передаёт сложность 3-м аргументом reason_args
	# (напр. "на 10 stars"). Выносим её в отдельное поле reason_difficulty, чтобы
	# DiscoveryCard отрисовал zap+число вместо текстового "X stars".
	for c in candidates:
		if str(c.get("reason_key", "")) == "MODREC_REASON_STRICT_HIGH_ACC":
			var args: Array = c.get("reason_args", [])
			if args.size() >= 3:
				c["reason_difficulty"] = int(args[2])
				c["reason_args"] = [args[0], args[1]]

static func _rec_key(c: Dictionary) -> String:
	var t := str(c.get("type", "modifier"))
	if t == "difficulty":
		return "difficulty:" + str(c.get("difficulty", 0))
	var m := []
	for x in c.get("mods", []):
		m.append(str(x))
	m.sort()
	return "mod:" + "+".join(m)

static func _repeat_penalty(_c: Dictionary) -> float:
	# Phase 1-3: функционально no-op (anti-repeat реализуется в V2)
	return 0.0

static func _mean_accuracy_at_rating(hist: Array, r: int) -> float:
	var sum := 0.0
	var n := 0
	for s in hist:
		if int(s.get("chart_rating", 0)) == r:
			sum += float(s.get("accuracy", 0))
			n += 1
	return sum / float(n) if n > 0 else -1.0

static func _confidence_for_difficulty(hist: Array, ceiling: int) -> float:
	var at := 0
	var above := 0
	for s in hist:
		var r := int(s.get("chart_rating", 0))
		if r == ceiling:
			at += 1
		elif r > ceiling:
			above += 1
	if above > 0:
		return 0.85
	if at >= 6:
		return 0.7
	if at >= DIFFICULTY_MIN_SAMPLES:
		return 0.62
	return 0.55

static func _confidence_for_n(n: int, delta: float) -> float:
	if n <5:
		return 0.35
	if n <15:
		return 0.62 if absf(delta) <1.0 else 0.58
	return 0.82 if delta >0 else 0.78

static func _filter_candidates(candidates: Array, song_path: String) -> Array:
	var out: Array = []
	for c in candidates:
		if not c is Dictionary: continue
		var mods: Array = c.get("mods",[])
		var ctype: String = str(c.get("type", "modifier"))
		if mods.is_empty():
			# difficulty/song и пр. типы без модов — не санитайзим, но сохраняем
			if ctype == "modifier":
				continue
			out.append(c)
			continue
		# autoplay never
		if mods.has(RunModifiers.ID_AUTOPLAY):
			continue
		# combo_escalation / sudden_death already filtered by is_safe + max, but double-check
		# DNA gate — для MVP глобально пропускаем DNA только если есть .rfd; иначе отфильтруй
		var has_dna := false
		for m in mods:
			if str(m) in RunModifiers.DNA_IDS:
				has_dna = true
				break
		if has_dna and song_path == "":
			# Глобально — проверить есть ли хоть один .rfd в библиотеке, иначе скип
			var has_any_dna := false
			if SongLibrary and SongLibrary.has_method("get_songs_list"):
				for s in SongLibrary.get_songs_list():
					if s is Dictionary and str(s.get("path","")).ends_with(".rfd"):
						has_any_dna = true
						break
			if not has_any_dna:
				# Пробуем через DynamicLanesSchedule.has_usable_dna с первым треком — если нет, скип
				continue
		elif has_dna and song_path != "":
			if not _has_usable_dna(song_path):
				continue
		# Санитайз
		var sanitized: Array = RunModifiers.sanitize(mods)
		if sanitized.size() != mods.size():
			continue
		# Проверка конфликтов через ui_conflict (если после sanitize размер совпадает, конфликтов нет)
		# Параметры уже sanitized при создании
		out.append(c)
	return out

static func _has_usable_dna(song_path: String) -> bool:
	if song_path == "":
		return false
	# Call static method directly on DynamicLanesSchedule
	var result := DynamicLanesSchedule.has_usable_dna(song_path, "drums", "basic", 4)
	return result
	return false

static func _fallback_popular(candidates: Array) -> Array:
	# Новый профиль — показать 3 популярных безопасных
	var popular := [
		{"mods": [RunModifiers.ID_HIDDEN], "category": CAT_FIT},
		{"mods": [RunModifiers.ID_MIRROR_MODE], "category": CAT_NEXT},
		{"mods": [RunModifiers.ID_NO_FAIL], "category": CAT_NEXT},
	]
	var out: Array = []
	for p in popular:
		for c in candidates:
			if str(c.get("mods",[])) == str(p.get("mods",[])):
				out.append(c)
				break
	if out.size() <3:
		for c in candidates:
			if not out.has(c):
				out.append(c)
			if out.size()>=3: break
	return out

static func _apply_diversity(candidates: Array) -> Array:
	# Дедуп по ключу рекомендации — не показываем одно и то же дважды
	var seen := {}
	var out := []
	for c in candidates:
		var k := _rec_key(c)
		if seen.has(k):
			continue
		seen[k] = true
		out.append(c)
	return out

static func _pick_top3(candidates: Array) -> Array:
	if candidates.size() <= 3:
		return candidates
	# Жёсткий type-cap (макс. 2 одного type) + мягкий quality margin.
	# Разнообразие: кандидат ДРУГОГО type (напр. difficulty) допускается как
	# diversity-слот даже если его ранг чуть ниже — он уже прошёл confidence-порог.
	# Кандидат ТОГО ЖЕ type, что и лучший, блокируется quality margin (не форсируем слабый вариант).
	var top_score := _rank_score(candidates[0])
	var top_type := str(candidates[0].get("type", "modifier"))
	var chosen: Array = []
	var type_count := {}
	for c in candidates:
		if chosen.size() >= 3:
			break
		var t := str(c.get("type", "modifier"))
		if int(type_count.get(t, 0)) >= 2:
			continue
		var s := _rank_score(c)
		if chosen.size() > 0 and t == top_type and (top_score - s) > QUALITY_MARGIN:
			continue
		chosen.append(c)
		type_count[t] = int(type_count.get(t, 0)) + 1
	# Дозаполнение до 3 без нарушения type-cap и без добавления
	# низкокачественного кандидата того же type (quality margin сохраняется).
	var i := 0
	while chosen.size() < 3 and i < candidates.size():
		var c: Dictionary = candidates[i]
		if chosen.has(c):
			i += 1
			continue
		var t := str(c.get("type", "modifier"))
		if int(type_count.get(t, 0)) >= 2:
			i += 1
			continue
		var s := _rank_score(c)
		if chosen.size() > 0 and t == top_type and (top_score - s) > QUALITY_MARGIN:
			i += 1
			continue
		chosen.append(c)
		type_count[t] = int(type_count.get(t, 0)) + 1
		i += 1
	return chosen.slice(0, 3)
