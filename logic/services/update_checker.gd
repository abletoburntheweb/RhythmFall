# logic/services/update_checker.gd
extends Node

signal check_completed(result: Dictionary)

const GITHUB_LATEST_URL := "https://api.github.com/repos/abletoburntheweb/RhythmFall/releases/latest"
const REQUEST_TIMEOUT_SEC := 15.0

var _http: HTTPRequest = null
var _silent: bool = false
var _busy: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_busy() -> bool:
	return _busy


func check_for_updates(silent: bool = false) -> void:
	if _busy:
		return
	_silent = silent
	_busy = true
	var headers := PackedStringArray(["User-Agent: RhythmFall-Client", "Accept: application/json"])
	var err := _http.request(GITHUB_LATEST_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_emit_result({
			"ok": false,
			"silent": silent,
			"error_key": "UPDATE_ERROR_NETWORK",
			"current": AppVersion.get_display_version(),
		})


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_busy = false
	var silent := _silent
	_silent = false
	var current := AppVersion.get_display_version()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_emit_result({
			"ok": false,
			"silent": silent,
			"error_key": "UPDATE_ERROR_NETWORK",
			"current": current,
		})
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_emit_result({
			"ok": false,
			"silent": silent,
			"error_key": "UPDATE_ERROR_PARSE",
			"current": current,
		})
		return

	var data: Dictionary = parsed
	var latest_tag := str(data.get("tag_name", "")).strip_edges()
	if latest_tag == "":
		_emit_result({
			"ok": false,
			"silent": silent,
			"error_key": "UPDATE_ERROR_PARSE",
			"current": current,
		})
		return

	var latest_url := str(data.get("html_url", AppVersion.get_releases_url())).strip_edges()
	var up_to_date := AppVersion.compare_tags(current, latest_tag) >= 0
	_emit_result({
		"ok": true,
		"silent": silent,
		"up_to_date": up_to_date,
		"current": current,
		"latest": latest_tag,
		"latest_url": latest_url,
	})


func _emit_result(result: Dictionary) -> void:
	check_completed.emit(result)


static func should_skip_startup_notice(latest_tag: String) -> bool:
	if latest_tag == "" or SettingsManager == null:
		return true
	if not bool(SettingsManager.get_setting("check_updates_on_startup", true)):
		return true
	var dismissed := str(SettingsManager.get_setting("update_notice_dismissed_version", "")).strip_edges()
	if dismissed == "":
		return false
	return AppVersion.compare_tags(latest_tag, dismissed) <= 0


static func remember_dismissed_version(latest_tag: String) -> void:
	if SettingsManager == null or latest_tag == "":
		return
	SettingsManager.set_setting("update_notice_dismissed_version", latest_tag)
	SettingsManager.save_settings()
