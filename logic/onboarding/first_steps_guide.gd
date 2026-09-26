# logic/onboarding/first_steps_guide.gd
class_name FirstStepsGuide
extends Node

## Универсальный помощник «Первых шагов»: живёт в экране-хосте и реагирует на
## FirstStepsManager.state_changed, показывая модальные карточки (welcome /
## step intro / success / resume) и экранные спотлайы на целевых элементах UI.
## Менеджер хранит состояние; экраны регистрируются и дают цели спотлайта.

const _SpotlightTutorialScenePath := "res://ui/spotlight_tutorial.tscn"
const _TargetGlowScenePath := "res://ui/target_glow.tscn"
const _TargetGlowScript := preload("res://ui/target_glow.gd")

const STEP_NAV_FMT := "FIRST_STEPS_STEP_NAV_FMT"
const STEP_COUNT_FALLBACK := 5

@export var screen_id: String = ""
@export var allow_step_intro: bool = true
## Хост сам показывает Welcome (например, главное меню) — тогда guide не
## должен рисовать что-либо поверх него, пока welcome активен.
@export var allow_welcome: bool = true
## Хост вызывает refresh() сам (например, после загрузки UI) — тогда
## _ready не запускает _update сразу, чтобы карточка не мигала над лоадером.
@export var auto_show_on_ready: bool = true

## callable() → открыть ожидаемый экран для текущего шага (или запустить практику).
var navigate_to_expected_screen: Callable = Callable()
## callable() → Array[Control] целей спотлайта для текущего шага (или пусто).
var spotlight_targets_provider: Callable = Callable()

var _spotlight_tutorial: CanvasLayer = null
var _target_glow: CanvasLayer = null
var _overlay_running := false
## Тип текущего оверлея (welcome / intro / resume / spotlight / success).
## Нужен, чтобы завершать только target-спотлайт, а не success-карточку.
var _overlay_kind := ""
## Шаг, для которого открыт текущий оверлей (-1 для welcome).
## Позволяет закрыть «устаревший» спотлайт, если шаг сменился (preview next,
## повторный вход на экран) — иначе старый glow блокирует показ нового.
var _overlay_step: int = -1
var _overlay_finish_cb: Callable = Callable()
var _overlay_skip_cb: Callable = Callable()


func _ready() -> void:
	if FirstStepsManager:
		FirstStepsManager.register_screen(screen_id)
		if not FirstStepsManager.state_changed.is_connected(_on_state_changed):
			FirstStepsManager.state_changed.connect(_on_state_changed)
	# Подписка на смену числа открытых модалок: после закрытия модалки
	# перепроверяем glow/overlay (см. on_app_overlay_modal_changed).
	add_to_group("app_overlay_watchers")
	if auto_show_on_ready:
		_refresh_if_visible()


func register_with_manager() -> void:
	if FirstStepsManager:
		FirstStepsManager.register_screen(screen_id)


func _on_state_changed() -> void:
	_refresh_if_visible()


## Модалка открылась/закрылась (вызывается из AppOverlayBase через группу
## app_overlay_watchers): перепроверяем glow (восстановить после закрытия или
## убрать устаревший после смены шага во время показа модалки).
func on_app_overlay_modal_changed() -> void:
	_refresh_if_visible()


func _refresh_if_visible() -> void:
	var host := get_parent()
	if host == null or not host.is_visible_in_tree():
		return
	_update()


func refresh() -> void:
	_update()


func _update() -> void:
	if not FirstStepsManager or not FirstStepsManager.is_active():
		_close_overlay()
		return
	if FirstStepsManager.is_scan_flow_pending():
		_close_overlay()
		return
	if _TargetGlowScript.is_modal_open():
		# Цели НЕ стираем: target_glow._process сам скрывает glow под модалкой и
		# восстанавливает его после закрытия (слой 119 ниже модалок). Вдобавок
		# AppOverlayBase оповестит нас через группу app_overlay_watchers —
		# glow обновится по новому шагу.
		return
	if _overlay_running:
		if _overlay_kind != "spotlight":
			# Модальные карточки (intro/success/resume) привязаны к шагу. Если шаг
			# сменился, пока карточка оставалась открытой на скрытом экране
			# (напр. derived-success открылся на главном меню, пока игрок ушёл
			# в настройки), закрываем её БЕЗ колбэков — иначе старый success
			# «прострелит» продвижение по текущему шагу при возврате.
			if _overlay_step != FirstStepsManager.get_current_step():
				_close_overlay()
			else:
				return
		# Игрок кликнул цель прямо во время показа спотлайта → шаг уже
		# валидирован. Завершаем спотлайт корректно, чтобы success-карточка
		# показалась сразу, без лишнего «сначала закрой подсказку».
		# complete_current_overlay() сам вызывает _refresh_if_visible() →
		# реентерабельный _update уже покажет success — поэтому выходим.
		if FirstStepsManager.should_show_success():
			complete_current_overlay()
			return
		if _overlay_step != FirstStepsManager.get_current_step():
			# Спотлайт открыт для другого шага (шаг сменился во время показа:
			# preview next, reset, повторный вход на экран). Закрываем его БЕЗ
			# mark_spotlight_shown (иначе glow нового шага никогда не появится)
			# и продолжаем обычную логику ниже.
			_close_overlay()
		else:
			return
	# Если Welcome показывает сам хост-экран (главное меню) — не рисовать
	# поверх него другие карточки/спотлайты до его закрытия.
	if FirstStepsManager.should_show_welcome() and not allow_welcome:
		return
	var st := FirstStepsManager.get_current_step()
	if st < 0:
		_close_overlay()
		return
	if FirstStepsManager.should_show_welcome():
		_open_welcome()
		return
	if FirstStepsManager.should_show_success():
		_open_success(st)
		return
	if FirstStepsManager.should_show_resume():
		_open_resume(st)
		return
	# Единая карточка шага: title + intro + primary-кнопка навигации к месту
	# действия + рамка вокруг цели (если цель доступна на этом экране). Отдельный
	# intro-оверлей убрали — две карточки с одинаковым текстом подряд («Шаг N из 5»
	# + тот же intro) выглядели дублированием. Карточка показывается один раз
	# (should_show_target_spotlight), дальше — пульсирующий glow вокруг кнопки.
	if FirstStepsManager.should_show_target_glow():
		var targets: Array = _provider_targets()
		if FirstStepsManager.should_show_target_spotlight():
			_open_spotlight(st, targets)
		elif targets.size() > 0:
			_apply_glow(targets, st)
		else:
			_hide_glow()
		return
	_hide_glow()


func _step_number_label(step: int) -> String:
	var count := _first_steps_step_count(FirstStepsManager)
	var fmt := tr(STEP_NAV_FMT)
	if fmt == STEP_NAV_FMT:
		fmt = "Шаг %d из %d"
	return fmt % [step + 1, count]


func _first_steps_step_count(manager) -> int:
	if manager and manager.has_method("get_step_count"):
		return int(manager.get_step_count())
	return STEP_COUNT_FALLBACK


func _open_welcome() -> void:
	var tut := _ensure_spotlight()
	if tut == null:
		return
	_hide_glow()
	_overlay_running = true
	_overlay_kind = "welcome"
	_overlay_step = -1
	tut.start([
		{
			"title_key": "FIRST_STEPS_WELCOME_TITLE",
			"body_key": "FIRST_STEPS_WELCOME_BODY",
			"next_key": "FIRST_STEPS_WELCOME_START",
			"skip_key": "FIRST_STEPS_WELCOME_SKIP",
			"hide_step_label": true,
			"hide_nav_hint": true,
		},
	])
	_connect_overlay(tut, _on_welcome_started, _on_welcome_skipped)


func _on_welcome_started() -> void:
	_overlay_running = false
	_overlay_kind = ""
	if FirstStepsManager:
		FirstStepsManager.begin_onboarding()
	_refresh_if_visible()


func _on_welcome_skipped() -> void:
	_overlay_running = false
	_overlay_kind = ""
	# Skipping the welcome must never skip onboarding silently: re-show it and
	# let the real skip flow (with confirmation) be the only way out.
	if FirstStepsManager and FirstStepsManager.should_show_welcome():
		_open_welcome()
		return
	_refresh_if_visible()


func _open_resume(step: int) -> void:
	var tut := _ensure_spotlight()
	if tut == null:
		return
	_hide_glow()
	_overlay_running = true
	_overlay_kind = "resume"
	_overlay_step = step
	tut.start([
		{
			"step_label_text": _step_number_label(step),
			"title_key": "FIRST_STEPS_RESUME_TITLE",
			"body_key": "FIRST_STEPS_RESUME_BODY",
			"next_key": "FIRST_STEPS_CONTINUE",
			"hide_nav_hint": true,
		},
	])
	_connect_overlay(tut, _on_resume_finished, _on_resume_skipped)


func _on_resume_finished() -> void:
	_overlay_running = false
	_overlay_kind = ""
	if FirstStepsManager:
		FirstStepsManager.resume_continue()
	_refresh_if_visible()
	if navigate_to_expected_screen.is_valid():
		navigate_to_expected_screen.call()


func _on_resume_skipped() -> void:
	_overlay_running = false
	_overlay_kind = ""
	_close_overlay()
	if FirstStepsManager:
		# Без этого _resume_pending остаётся true и карточка «продолжим?»
		# появляется снова после каждого следующего оверлея — skip «не работает».
		FirstStepsManager.resume_dismiss()
	_refresh_if_visible()


func _open_spotlight(step: int, targets: Array) -> void:
	var tut := _ensure_spotlight()
	if tut == null:
		return
	# Glow НЕ показываем, пока открыта карточка спотлайта: dim (CanvasLayer 120)
	# лежит выше glow (119) и glow через затемнение просвечивать не должен —
	# цель подсвечивает рамка HighlightFrame. После закрытия карточки _update
	# применит пульсирующий glow вокруг цели (should_show_target_glow).
	_overlay_running = true
	_overlay_kind = "spotlight"
	_overlay_step = step
	var step_data := {
		"step_label_text": _step_number_label(step),
		"title_text": FirstStepsManager.get_step_title(step),
		"body_text": FirstStepsManager.get_step_intro(step),
		"next_key": FirstStepsManager.get_step_nav_action(step),
		"hide_nav_hint": true,
	}
	if not targets.is_empty():
		step_data["targets"] = targets
	tut.start([step_data])
	_connect_overlay(tut, _on_spotlight_done, _on_spotlight_done)


func _on_spotlight_done() -> void:
	_overlay_running = false
	_overlay_kind = ""
	if FirstStepsManager:
		FirstStepsManager.mark_spotlight_shown()
	_refresh_if_visible()
	# На чужом экране (карточка была по центру, целей нет) primary-кнопка ведёт
	# к месту действия — как раньше intro. На нужном экране не навигируем:
	# игрок уже на месте, после закрытия остаётся glow цели.
	if navigate_to_expected_screen.is_valid() \
			and (FirstStepsManager == null or not FirstStepsManager.is_on_expected_screen()):
		navigate_to_expected_screen.call()


func _open_success(step: int) -> void:
	var tut := _ensure_spotlight()
	if tut == null:
		return
	_hide_glow()
	_overlay_running = true
	_overlay_kind = "success"
	_overlay_step = step
	tut.start([
		{
			"step_label_text": _step_number_label(step),
			"title_text": FirstStepsManager.get_success_title(step),
			"body_text": FirstStepsManager.get_success_body(step),
			"next_key": FirstStepsManager.get_next_step_nav_action(step),
			"hide_nav_hint": true,
		},
	])
	_connect_overlay(tut, _on_success_finished, _on_success_skipped)


func _on_success_finished() -> void:
	_overlay_running = false
	_overlay_kind = ""
	if FirstStepsManager:
		FirstStepsManager.continue_after_success(true)
	_refresh_if_visible()
	if navigate_to_expected_screen.is_valid():
		navigate_to_expected_screen.call()


## «ПРОПУСТИТЬ» на success-карточке: шаг продвигается (иначе после закрытия
## не останется никакого next action), но без навигации — intro следующего
## шага покажется на текущем экране со своей кнопкой перехода.
func _on_success_skipped() -> void:
	_overlay_running = false
	_overlay_kind = ""
	if FirstStepsManager:
		FirstStepsManager.continue_after_success(false)
	_refresh_if_visible()


func _connect_overlay(tut, finish_cb: Callable, skip_cb: Callable) -> void:
	_disconnect_overlay(tut)  # ensure no stale connections
	_overlay_finish_cb = finish_cb
	_overlay_skip_cb = skip_cb
	if finish_cb.is_valid() and tut.finished.is_connected(finish_cb):
		# already connected – skip to avoid double-connect error
		pass
	else:
		tut.finished.connect(finish_cb, CONNECT_ONE_SHOT)
	if skip_cb.is_valid() and tut.skipped.is_connected(skip_cb):
		# already connected – skip to avoid double-connect error
		pass
	else:
		tut.skipped.connect(skip_cb, CONNECT_ONE_SHOT)


func _disconnect_overlay(tut) -> void:
	if tut == null:
		return
	if _overlay_finish_cb.is_valid() and tut.finished.is_connected(_overlay_finish_cb):
		tut.finished.disconnect(_overlay_finish_cb)
	if _overlay_skip_cb.is_valid() and tut.skipped.is_connected(_overlay_skip_cb):
		tut.skipped.disconnect(_overlay_skip_cb)
	_overlay_finish_cb = Callable()
	_overlay_skip_cb = Callable()


func _provider_targets() -> Array:
	if spotlight_targets_provider.is_valid():
		var out = spotlight_targets_provider.call()
		if out is Array:
			return out
	return []


func _ensure_target_glow() -> CanvasLayer:
	if _target_glow != null and is_instance_valid(_target_glow):
		return _target_glow
	_target_glow = (load(_TargetGlowScenePath) as PackedScene).instantiate() as CanvasLayer
	if _target_glow == null:
		return null
	add_child(_target_glow)
	return _target_glow


func _apply_glow(targets: Array, step: int) -> void:
	var glow := _ensure_target_glow()
	if glow == null:
		return
	glow.set_color(FirstStepsManager.get_step_tint(step))
	glow.set_targets(targets)


func _hide_glow() -> void:
	if _target_glow != null and is_instance_valid(_target_glow):
		_target_glow.clear_targets()


func _ensure_spotlight() -> CanvasLayer:
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		return _spotlight_tutorial
	_spotlight_tutorial = (load(_SpotlightTutorialScenePath) as PackedScene).instantiate() as CanvasLayer
	if _spotlight_tutorial == null:
		return null
	add_child(_spotlight_tutorial)
	return _spotlight_tutorial


func _close_overlay() -> void:
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		if _spotlight_tutorial.visible:
			_spotlight_tutorial.hide()
	_disconnect_overlay(_spotlight_tutorial)
	_overlay_running = false
	_overlay_kind = ""
	_hide_glow()


## Завершает текущий оверлей так, как будто игрок нажал «Далее»/пропустил.
## Используется, когда шаг уже валидирован во время показа спотлайта, а также
## когда другой экран берёт показ подсказки на себя (например, контекстная
## подсказка панели практики в паузе).
func complete_current_overlay() -> void:
	if not _overlay_running:
		return
	if _spotlight_tutorial != null and is_instance_valid(_spotlight_tutorial):
		_disconnect_overlay(_spotlight_tutorial)
		if _spotlight_tutorial.visible:
			_spotlight_tutorial.hide()
	_on_spotlight_done()
