# logic/onboarding/first_steps_manager.gd
extends Node

## Интерактивное обучение «Первые шаги»: 5 шагов, состояние в SettingsManager.
## Менеджер — единственный владелец состояния, текущего шага, expected_screen/action,
## событий и прогресса. Экраны регистрируются через register_screen() и только
## реагируют на state_changed, показывая соответствующий Spotlight/intro/success.

signal state_changed
signal completed

const STEP_COUNT := 5
const ACHIEVEMENT_ID := 181

## Идентификаторы экранов (значения — строки, регистрируются экранами).
const SCREEN_MAIN_MENU := "main_menu"
const SCREEN_SETTINGS := "settings"
const SCREEN_SONG_SELECT := "song_select"
const SCREEN_GAME := "game"
const SCREEN_VICTORY := "victory"

const STEP_TITLE_KEYS := [
	"FIRST_STEPS_STEP_1_TITLE",
	"FIRST_STEPS_STEP_2_TITLE",
	"FIRST_STEPS_STEP_3_TITLE",
	"FIRST_STEPS_STEP_4_TITLE",
	"FIRST_STEPS_STEP_5_TITLE",
]

const STEP_DESC_KEYS := [
	"FIRST_STEPS_STEP_1_DESC",
	"FIRST_STEPS_STEP_2_DESC",
	"FIRST_STEPS_STEP_3_DESC",
	"FIRST_STEPS_STEP_4_DESC",
	"FIRST_STEPS_STEP_5_DESC",
]

## Текст карточки «Шаг N из 5» (что делать на этом экране).
const STEP_INTRO_KEYS := [
	"FIRST_STEPS_STEP_1_INTRO",
	"FIRST_STEPS_STEP_2_INTRO",
	"FIRST_STEPS_STEP_3_INTRO",
	"FIRST_STEPS_STEP_4_INTRO",
	"FIRST_STEPS_STEP_5_INTRO",
]

## Кнопка на карточке шага (навигация к месту действия / продолжение).
## Значения — CAPS (ОТКРЫТЬ БИБЛИОТЕКУ, К ВЫБОРУ ПЕСНИ, …).
const STEP_ACTION_KEYS := [
	"FIRST_STEPS_STEP_1_ACTION",
	"FIRST_STEPS_STEP_2_ACTION",
	"FIRST_STEPS_STEP_3_ACTION",
	"FIRST_STEPS_STEP_4_ACTION",
	"FIRST_STEPS_STEP_5_ACTION",
]

const STEP_FINISH_KEY := "FIRST_STEPS_FINISH"

## Success-карточки после валидации шага.
const SUCCESS_TITLE_KEYS := [
	"FIRST_STEPS_SUCCESS_1_TITLE",
	"FIRST_STEPS_SUCCESS_2_TITLE",
	"FIRST_STEPS_SUCCESS_3_TITLE",
	"FIRST_STEPS_SUCCESS_4_TITLE",
	"FIRST_STEPS_SUCCESS_5_TITLE",
]

const SUCCESS_BODY_KEYS := [
	"FIRST_STEPS_SUCCESS_1_BODY",
	"FIRST_STEPS_SUCCESS_2_BODY",
	"FIRST_STEPS_SUCCESS_3_BODY",
	"FIRST_STEPS_SUCCESS_4_BODY",
	"FIRST_STEPS_SUCCESS_5_BODY",
]

const STEP_ICONS := [
	"music.svg",
	"metronome.svg",
	"chart_difficulty.svg",
	"circle-play.svg",
	"trophy.svg",
]

const STEP_TINT_COLORS := [
	Color(0.62, 0.86, 0.72, 1.0),
	Color(0.55, 0.78, 0.98, 1.0),
	Color(0.98, 0.72, 0.32, 1.0),
	Color(0.72, 0.58, 0.95, 1.0),
	Color(0.95, 0.78, 0.35, 1.0),
]

const DETAILS_MASK_CURRENCY := 1
const DETAILS_MASK_XP := 2
const DETAILS_MASK_ACCURACY := 4
const DETAILS_MASK_ALL := 7

var _done: Array[bool] = []
var _preview_step: int = -1

## Экран, зарегистрировавшийся последним.
var _current_screen: String = ""

## Песня, выбранная для обучения в текущей сессии онбординга. Фиксируется при
## первом автовыборе в Song Select и используется всеми последующими переходами
## (BPM → Chart → Run), пока песня существует в библиотеке.
var _first_steps_tutorial_song: String = ""

## Сессионные флаги (сбрасываются при старте/рестарте/сбросе).
var _intro_shown: Array[bool] = []
var _spotlight_shown: Array[bool] = []
var _success_shown: Array[bool] = []
var _event_validated: Array[bool] = []
var _scan_flow_pending: bool = false  # <-- NEW: flag while waiting for scan result dialog
var _resume_pending := false
var _preview_welcome_done := false

## Снапшот настроек генератора: First Steps применяет tutorial preset
## (drums/arcade/medium) на шаге 2, а по завершении/выходе возвращает
## пользовательскую конфигурацию как была.
const GEN_SETTING_KEYS := [
	"generation_ready_goals",
	"generation_ready_diffs",
	"generation_ready_instruments",
	"generation_ready_preset_slots",
	"generation_goal",
	"generation_difficulty",
	"last_generation_instrument",
	"last_generation_mode",
	"last_generation_lanes",
	"last_generation_intent",
]
var _gen_snapshot: Dictionary = {}
var _gen_snapshot_taken := false
## Активный generation-пресет пользователя: пока обучение ставит свой tutorial
## конфиг (drums/arcade/medium/4 lanes), пресет отключается, чтобы его значения
## (напр. цель «Оригинал» из дефолтного пресета) не перезаписывали настройки
## генератора и не проскакивали в UI. Возвращается при завершении/выходе.
var _gen_preset_slot_snapshot := -1


func set_tutorial_song(path: String) -> void:
	if path != "":
		_first_steps_tutorial_song = path


func get_tutorial_song() -> String:
	return _first_steps_tutorial_song


func capture_generation_settings() -> void:
	if _gen_snapshot_taken:
		return
	_gen_snapshot_taken = true
	_gen_snapshot.clear()
	for key in GEN_SETTING_KEYS:
		_gen_snapshot[key] = SettingsManager.get_setting(key, null)
	_gen_preset_slot_snapshot = int(SettingsManager.get_generation_presets().get("active_slot", 0))


func restore_generation_settings() -> void:
	if not _gen_snapshot_taken:
		return
	_gen_snapshot_taken = false
	for key in GEN_SETTING_KEYS:
		if _gen_snapshot.has(key):
			SettingsManager.set_setting(key, _gen_snapshot[key])
	if _gen_preset_slot_snapshot >= 0:
		var presets := SettingsManager.get_generation_presets()
		if int(presets.get("active_slot", 0)) != _gen_preset_slot_snapshot:
			presets = presets.duplicate(true)
			presets["active_slot"] = _gen_preset_slot_snapshot
			SettingsManager.set_generation_presets(presets)
		_gen_preset_slot_snapshot = -1
	SettingsManager.save_settings()
	_gen_snapshot.clear()


## Отключает активный generation-пресет, чтобы tutorial preset (drums/arcade/
## medium/4 lanes) был единственным источником настроек генератора на время
## обучения. Вызывается из _prepare_first_steps_chart_config в Song Select.
func clear_active_generation_preset_slot() -> void:
	if SettingsManager == null:
		return
	var presets := SettingsManager.get_generation_presets()
	if int(presets.get("active_slot", 0)) == 0:
		return
	presets = presets.duplicate(true)
	presets["active_slot"] = 0
	SettingsManager.set_generation_presets(presets)


func is_preview_active() -> bool:
	return _preview_step >= 0


func enter_preview() -> void:
	if _preview_step < 0:
		_preview_step = 0
		_preview_welcome_done = false
		_reset_session_flags()
		state_changed.emit()


func exit_preview() -> void:
	if _preview_step >= 0:
		_preview_step = -1
		restore_generation_settings()
		_reset_session_flags()
		state_changed.emit()


func set_preview_step(step: int) -> void:
	if not is_preview_active():
		return
	_preview_step = clampi(step, 0, STEP_COUNT)
	if _preview_step >= STEP_COUNT:
		exit_preview()
		return
	_reset_session_flags()
	state_changed.emit()


func advance_preview() -> void:
	set_preview_step(get_step() + 1)


func _ready() -> void:
	for i in range(STEP_COUNT):
		_done.append(false)
	_reset_session_flags()
	if SongLibrary and SongLibrary.has_signal("songs_list_changed"):
		SongLibrary.songs_list_changed.connect(func(): _refresh(true))
	if PlayerDataManager and PlayerDataManager.has_signal("daily_quests_updated"):
		PlayerDataManager.daily_quests_updated.connect(func(): _refresh(false))
	if PlayerDataManager and PlayerDataManager.has_signal("calendar_day_changed"):
		PlayerDataManager.calendar_day_changed.connect(func(): _refresh(false))
	_refresh(false)
	# Однократное напоминание о прерванном онбординге при следующем запуске
	# игры: онбординг начат (intro показан), но не завершён и не пропущен,
	# и игрок не на нулевом шаге (welcome уже отработал ранее).
	if not is_preview_active() and is_active() \
			and SettingsManager.get_first_steps_intro_done() and get_step() > 0:
		_resume_pending = true


func _reset_session_flags() -> void:
	_intro_shown = []
	_spotlight_shown = []
	_success_shown = []
	_event_validated = []
	for i in range(STEP_COUNT):
		_intro_shown.append(false)
		_spotlight_shown.append(false)
		_success_shown.append(false)
		_event_validated.append(false)
	_resume_pending = false


## ---------------------------------------------------------------- экраны ---

func register_screen(screen_id: String) -> void:
	_current_screen = screen_id
	# Напоминание «Вы были на середине обучения» НЕ выставляем на каждый вход
	# в ожидаемый экран: при активном прохождении это превращалось в спам на
	# каждом переходе. Единственный источник — однократная установка в _ready
	# (см. ниже), т.е. настоящее возвращение к прерванному онбордингу.
	state_changed.emit()


func get_current_screen() -> String:
	return _current_screen


func expected_screen_for_step(step: int) -> String:
	match step:
		0:
			return SCREEN_SETTINGS
		1, 2, 3:
			return SCREEN_SONG_SELECT
		4:
			return SCREEN_VICTORY
	return ""


func expected_action_for_step(step: int) -> String:
	match step:
		0:
			return "song_scanned"
		1:
			return "bpm_set"
		2:
			return "chart_ready"
		3:
			return "run_completed"
		4:
			return "details_mask_full"
	return ""


func is_on_expected_screen() -> bool:
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	return _current_screen == expected_screen_for_step(st)


func target_kind_for_step(step: int) -> String:
	match step:
		0:
			return "library"
		1, 2, 3:
			return "song_select"
		_:
			return "song_select"


## ---------------------------------------------------------- welcome/intro ---

func should_show_welcome() -> bool:
	if is_preview_active():
		return get_step() == 0 and not _preview_welcome_done
	return is_active() and not SettingsManager.get_first_steps_intro_done() and get_step() == 0 \
		and _current_screen == SCREEN_MAIN_MENU


func should_show_intro() -> bool:
	return should_show_welcome()


func begin_onboarding() -> void:
	if is_preview_active():
		_preview_welcome_done = true
		state_changed.emit()
		return
	if not SettingsManager.get_first_steps_intro_done():
		SettingsManager.set_first_steps_intro_done(true)
	state_changed.emit()


func mark_intro_done() -> void:
	begin_onboarding()


func should_show_step_intro() -> bool:
	if not is_active():
		return false
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	if is_step_done(st):
		return false
	if _intro_shown[st]:
		return false
	return true


func mark_step_intro_shown() -> void:
	var st := get_step()
	if st >= 0 and st < STEP_COUNT:
		_intro_shown[st] = true
	state_changed.emit()


## ---------------------------------------------------------------- spotlight ---

func should_show_spotlight() -> bool:
	if not is_active():
		return false
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	if is_step_done(st):
		return false
	if _spotlight_shown[st]:
		return false
	if not is_on_expected_screen():
		return false
	return true


## Спотлайт по UI-цели текущего шага. В отличие от should_show_spotlight(),
## не требует нахождения на ожидаемом экране: экран сам предоставляет цели
## через spotlight_targets_provider. Если целей для текущего шага нет —
## спотлайт не показывается (напр. игрок ещё не на нужном экране/вкладке).
func should_show_target_spotlight() -> bool:
	if not is_active():
		return false
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	if is_step_done(st):
		return false
	if _spotlight_shown[st]:
		return false
	return true


## Glow-подсветка цели: как target spotlight, но НЕ зависит от _spotlight_shown.
## Карточка спотлайта показывается один раз, а пульсирующий glow остаётся
## вокруг цели, пока шаг не валидирован (USER ACTION → TARGET GLOW OFF → SUCCESS).
func should_show_target_glow() -> bool:
	if not is_active():
		return false
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	if is_step_done(st):
		return false
	return true


func get_step_nav_action(step: int) -> String:
	return tr(STEP_ACTION_KEYS[clampi(step, 0, STEP_COUNT - 1)])


## Надпись на primary-кнопке success-карточки: навигация к МЕСТУ следующего
## действия (следующий шаг). Для последнего шага — завершение обучения.
func get_next_step_nav_action(step: int) -> String:
	var next := step + 1
	if next >= STEP_COUNT:
		return tr(STEP_FINISH_KEY)
	return get_step_nav_action(next)


func is_step_intro_shown(step: int) -> bool:
	step = clampi(step, 0, STEP_COUNT - 1)
	return _intro_shown[step]


func mark_spotlight_shown() -> void:
	var st := get_step()
	if st >= 0 and st < STEP_COUNT:
		_spotlight_shown[st] = true
	state_changed.emit()


## ------------------------------------------------------------------- resume ---

func should_show_resume() -> bool:
	if not is_active():
		return false
	return _resume_pending


func resume_continue() -> void:
	var st := get_step()
	_resume_pending = false
	if st >= 0 and st < STEP_COUNT:
		_spotlight_shown[st] = false
	state_changed.emit()


## Skip на resume-карточке: напоминание больше не показывается в этой сессии,
## но спотлайт цели при этом не «размораживается» (resume_continue это делает
## только по явному «Продолжить»).
func resume_dismiss() -> void:
	_resume_pending = false
	state_changed.emit()


## ------------------------------------------------------------------- success ---

func should_show_success() -> bool:
	if not is_active():
		return false
	var st := get_step()
	if st < 0 or st >= STEP_COUNT:
		return false
	if not _event_validated[st]:
		return false
	if _success_shown[st]:
		return false
	return true


func mark_success_shown() -> void:
	var st := get_step()
	if st >= 0 and st < STEP_COUNT:
		_success_shown[st] = true


## Продолжить после success-карточки.
## with_navigation=true — primary-кнопка: следующий шаг уже описан в тексте
## success-карточки, поэтому intro следующего шага на целевом экране не
## показывается (сразу glow цели). with_navigation=false — «ПРОПУСТИТЬ»:
## шаг тоже продвигается (иначе после закрытия success игрок останется
## без какого-либо next action), но без навигации — intro следующего шага
## покажется здесь же, со своей кнопкой перехода.
func continue_after_success(with_navigation: bool = true) -> void:
	_resume_pending = false
	var st := get_step()
	if st >= 0 and st < STEP_COUNT:
		_success_shown[st] = true
	if is_preview_active():
		advance_preview()
		return
	var next := st + 1
	if next >= STEP_COUNT:
		SettingsManager.set_first_steps_completed(true)
		restore_generation_settings()
		_ensure_achievement_granted()
		StatusToast.show_from_node(self, "first_steps_done", tr("FIRST_STEPS_COMPLETE_TOAST"), "success", 4.0)
		completed.emit()
		state_changed.emit()
		return
	SettingsManager.set_first_steps_step(next)
	if with_navigation:
		_intro_shown[next] = true
	_refresh(false)
	state_changed.emit()


## ------------------------------------------------------------ базовые геттеры ---

func is_active() -> bool:
	if is_preview_active():
		return true
	return not is_completed() and not is_skipped()


func is_scan_flow_pending() -> bool:
	return _scan_flow_pending


func is_completed() -> bool:
	return SettingsManager.get_first_steps_completed()


func is_skipped() -> bool:
	return SettingsManager.get_first_steps_skipped()


func get_step() -> int:
	if is_preview_active():
		return _preview_step
	return SettingsManager.get_first_steps_step()


func get_step_count() -> int:
	return STEP_COUNT


func get_done_count() -> int:
	var count := 0
	for i in range(STEP_COUNT):
		if is_step_done(i):
			count += 1
	return count


func is_step_done(step: int) -> bool:
	step = clampi(step, 0, STEP_COUNT - 1)
	if step < get_step():
		return true
	if is_preview_active():
		return false
	return _done[step]


func get_current_step() -> int:
	if not is_active():
		return -1
	var st := get_step()
	if st >= STEP_COUNT:
		return -1
	return st


func get_step_cards(max_count: int = 3) -> Array:
	var cards: Array = []
	if not is_active():
		return cards
	var current := get_step()
	if current >= STEP_COUNT:
		current = STEP_COUNT - 1
	# «Окно прогресса»: показываем последние шаги вплоть до текущего, чтобы
	# выполненные оставались видимыми как выполненные, а текущий всегда был
	# последней карточкой. Будущие шаги подразумеваются прогрессом 0..N.
	var start := maxi(0, current - maxi(0, max_count - 1))
	for i in range(start, current + 1):
		cards.append({
			"step": i,
			"current": i == current,
			"done": is_step_done(i),
		})
	return cards


func get_step_title(step: int) -> String:
	return tr(STEP_TITLE_KEYS[clampi(step, 0, STEP_COUNT - 1)])


func get_step_desc(step: int) -> String:
	return tr(STEP_DESC_KEYS[clampi(step, 0, STEP_COUNT - 1)])


func get_step_intro(step: int) -> String:
	return tr(STEP_INTRO_KEYS[clampi(step, 0, STEP_COUNT - 1)])


func get_success_title(step: int) -> String:
	return tr(SUCCESS_TITLE_KEYS[clampi(step, 0, STEP_COUNT - 1)])


func get_success_body(step: int) -> String:
	return tr(SUCCESS_BODY_KEYS[clampi(step, 0, STEP_COUNT - 1)])


func get_step_icon(step: int) -> String:
	return STEP_ICONS[clampi(step, 0, STEP_COUNT - 1)]


func get_step_tint(step: int) -> Color:
	return STEP_TINT_COLORS[clampi(step, 0, STEP_COUNT - 1)]


## ---------------------------------------------------------------- события ---

func notify_event(event_name: String) -> void:
	if not is_active():
		return
	if is_preview_active():
		# ------- preview validation path ------
		var st := get_step()
		if st < 0 or st >= STEP_COUNT:
			return
		# allowed events per step in preview
		var allowed: Array[String] = []
		match st:
			0: allowed = ["song_scanned"]
			1: allowed = ["bpm_set"]
			2: allowed = ["chart_ready"]
			3: allowed = ["run_completed"]
			4: allowed = ["details_currency", "details_xp", "details_accuracy"]
		if event_name in allowed:
			_event_validated[st] = true
			state_changed.emit()
			return
		# not an expected preview event -> ignore
		return
	
	# ------- real mode (unchanged) -------
	if is_preview_active():  # safety guard (should never be true here)
		return
	var st := get_step()
	var event_matched := false
	match event_name:
		"song_scanned":
			# Валидацию держим на производном условии, но emit обязателен даже
			# если _event_validated уже проставлен молчаливым _recompute_done()
			# (напр. songs_list_changed прилетел прямо во время сканирования):
			# иначе guide не узнает о завершении шага и не покажет success.
			if st == 0 and _has_user_song():
				_event_validated[0] = true
				event_matched = true
		"bpm_set":
			if st == 1 and _has_bpm():
				_event_validated[1] = true
				event_matched = true
		"chart_ready":
			if st == 2 and _has_chart():
				_event_validated[2] = true
				event_matched = true
		"run_completed":
			if st == 3:
				_event_validated[3] = true
				event_matched = true
		"details_currency":
			if not _has_detail(DETAILS_MASK_CURRENCY):
				_set_detail(DETAILS_MASK_CURRENCY)
				event_matched = true
		"details_xp":
			if not _has_detail(DETAILS_MASK_XP):
				_set_detail(DETAILS_MASK_XP)
				event_matched = true
		"details_accuracy":
			if not _has_detail(DETAILS_MASK_ACCURACY):
				_set_detail(DETAILS_MASK_ACCURACY)
				event_matched = true
	if st == 4 and SettingsManager.get_first_steps_details_mask() == DETAILS_MASK_ALL and not _event_validated[4]:
		_event_validated[4] = true
		event_matched = true
	# Always recompute derived state: an event may satisfy a step while
	# onboarding is on another step (e.g. a run or practice completed early).
	var done_before := _done.duplicate()
	_recompute_done()
	if event_matched or done_before != _done:
		state_changed.emit()


## ------------------------------------------------------------------- сброс ---

func skip() -> void:
	if not is_active() or is_preview_active():
		return
	SettingsManager.set_first_steps_skipped(true)
	restore_generation_settings()
	_reset_session_flags()
	_refresh(false)
	# _refresh рано выходит при is_skipped() — оповестить guide-ы явно,
	# чтобы любые открытые оверлеи закрылись (is_active() → false).
	state_changed.emit()


func restart_from_help() -> void:
	restore_generation_settings()
	_preview_step = -1
	_preview_welcome_done = false
	_first_steps_tutorial_song = ""
	SettingsManager.set_first_steps_skipped(false)
	SettingsManager.set_first_steps_completed(false)
	SettingsManager.set_first_steps_step(0)
	SettingsManager.set_first_steps_details_mask(0)
	_reset_session_flags()
	_refresh(false)


func reset_progress() -> void:
	# Сброс должен гарантировать реальный (не preview) онбординг: если в сессии
	# остался активный предпросмотр (tutorial.first_steps.show/.practice),
	# notify_event/_refresh работают как no-op и весь flow выглядит «мёртвым».
	restore_generation_settings()
	_preview_step = -1
	_preview_welcome_done = false
	_first_steps_tutorial_song = ""
	SettingsManager.set_first_steps_skipped(false)
	SettingsManager.set_first_steps_completed(false)
	SettingsManager.set_first_steps_step(0)
	SettingsManager.set_first_steps_details_mask(0)
	SettingsManager.set_first_steps_intro_done(false)
	_reset_session_flags()
	_refresh(true)
	state_changed.emit()


func refresh_state() -> void:
	_refresh(true)


## ------------------------------------------------------------- производные ---

## Открыта ли уже конкретная модалка деталей шага «Результат» (bit маски).
## Используется экраном результата, чтобы подсвечивать glow только те строки,
## которые игрок ещё не смотрел (постепенное снятие подсветки).
func is_detail_opened(mask_bit: int) -> bool:
	return _has_detail(mask_bit)


func _has_detail(mask_bit: int) -> bool:
	return SettingsManager.get_first_steps_details_mask() & mask_bit != 0


func _set_detail(mask_bit: int) -> void:
	SettingsManager.set_first_steps_details_mask(SettingsManager.get_first_steps_details_mask() | mask_bit)


func _check_derived_done(step: int) -> bool:
	match step:
		0:
			return _has_user_song()
		1:
			return _has_bpm()
		2:
			return _has_chart()
		3:
			return _has_completed_run()
		4:
			return SettingsManager.get_first_steps_details_mask() == DETAILS_MASK_ALL
	return false


func _has_user_song() -> bool:
	if not SongLibrary:
		return false
	for s in SongLibrary.get_songs_list():
		if str(s.get("source", "")) == "user":
			return true
	return false


func _has_bpm() -> bool:
	if not SongLibrary:
		return false
	for s in SongLibrary.get_songs_list():
		var path := str(s.get("path", ""))
		if path == "":
			continue
		var bpm := str(SongLibrary.get_metadata_for_song(path).get("bpm", ""))
		if bpm != "" and bpm != "Н/Д":
			return true
	return false


func _has_chart() -> bool:
	if not SongLibrary:
		return false
	for s in SongLibrary.get_songs_list():
		var path := str(s.get("path", ""))
		if path == "":
			continue
		var chart = SongLibrary.get_metadata_for_song(path).get("chart_difficulty", {})
		if chart is Dictionary and not chart.is_empty():
			return true
	return false


func _has_completed_run() -> bool:
	if not PlayerDataManager:
		return false
	return PlayerDataManager.get_levels_completed() > 0


## Лучшая песня для текущего шага (используется для автовыбора в Library).
## Приоритет — tutorial song: один раз зафиксированная песня обучения
## восстанавливается на всех последующих переходах (BPM → Chart → Run),
## пока она всё ещё существует в библиотеке.
func get_suggested_song_path() -> String:
	if not is_active():
		return ""
	var st := get_step()
	var t := _first_steps_tutorial_song
	if t != "" and _song_exists(t):
		if st == 1 and _song_needs_bpm(t):
			return t
		if st == 2 and not _song_needs_bpm(t):
			return t
		if st == 3:
			return t
	# Tutorial song устарела/не подходит для шага — лучший доступный кандидат.
	if st == 1:
		return _first_song_needing_bpm()
	if st == 2:
		return _first_song_with_bpm()
	if st == 3:
		return _first_song_with_bpm()
	return ""


func _song_exists(path: String) -> bool:
	if not SongLibrary or path == "":
		return false
	for s in SongLibrary.get_songs_list():
		if str(s.get("path", "")) == path:
			return true
	return false


func _song_needs_bpm(path: String) -> bool:
	if not SongLibrary:
		return false
	var bpm := str(SongLibrary.get_metadata_for_song(path).get("bpm", ""))
	return bpm == "" or bpm == "Н/Д"


func _first_song_needing_bpm() -> String:
	if not SongLibrary:
		return ""
	for s in SongLibrary.get_songs_list():
		var path := str(s.get("path", ""))
		if path != "" and _song_needs_bpm(path):
			return path
	return ""


func _first_song_with_bpm() -> String:
	if not SongLibrary:
		return ""
	for s in SongLibrary.get_songs_list():
		var path := str(s.get("path", ""))
		if path != "" and not _song_needs_bpm(path):
			return path
	return ""


func _recompute_done() -> void:
	for i in range(STEP_COUNT):
		var d := _check_derived_done(i)
		_done[i] = d
		if d:
			_event_validated[i] = true


## Шаг «активно ведётся» (уже показан intro/spotlight/success или валидирован
## событием) — такой шаг не пропускается авто-переходом в _refresh.
func _step_actively_guided(step: int) -> bool:
	if step < 0 or step >= STEP_COUNT:
		return false
	return _intro_shown[step] or _spotlight_shown[step] or _event_validated[step] or _success_shown[step]


func _refresh(silent: bool) -> void:
	if is_preview_active():
		return
	var validated_before := _event_validated.duplicate()
	var done_before := _done.duplicate()
	_recompute_done()
	if is_completed():
		_ensure_achievement_granted()
		return
	if is_skipped():
		return
	var st := get_step()
	var advanced := false
	while st < STEP_COUNT and _check_derived_done(st) and not _step_actively_guided(st):
		st += 1
		advanced = true
	if st != get_step():
		SettingsManager.set_first_steps_step(st)
		advanced = true
	if advanced:
		_resume_pending = false
	_recompute_done()
	if st >= STEP_COUNT and not is_completed():
		SettingsManager.set_first_steps_completed(true)
		restore_generation_settings()
		_ensure_achievement_granted()
		if not silent:
			StatusToast.show_from_node(self, "first_steps_done", tr("FIRST_STEPS_COMPLETE_TOAST"), "success", 4.0)
		completed.emit()
		state_changed.emit()
	elif (advanced and not silent) \
			or validated_before != _event_validated or done_before != _done:
		# Silent refresh (songs_list_changed, daily_quests_updated, …) may flip a
		# derived step (user song added via folder change, BPM via ID3 enrichment,
		# chart/run/practice completed elsewhere) WITHOUT any notify_event. If we
		# stay silent the guides never learn and the step hangs without a success
		# card. Emit whenever validated/done state actually changed.
		state_changed.emit()


func _ensure_achievement_granted() -> void:
	var am = null
	if PlayerDataManager:
		am = PlayerDataManager.achievement_manager
	if am and am.has_method("unlock_achievement_by_id"):
		am.unlock_achievement_by_id(ACHIEVEMENT_ID)