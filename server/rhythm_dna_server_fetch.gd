# server/rhythm_dna_server_fetch.gd
extends RefCounted

const _CONNECT_TIMEOUT_MS := 20000


static func api_host() -> String:
	if SettingsManager:
		if bool(SettingsManager.get_setting("generation_server_use_lan_host", false)):
			var lan := str(SettingsManager.get_setting("generation_server_lan_host", "")).strip_edges()
			return lan if not lan.is_empty() else "127.0.0.1"
		return "127.0.0.1"
	var h := str(ProjectSettings.get_setting("rhythmfall/generation_api/host", "127.0.0.1")).strip_edges()
	return h if not h.is_empty() else "127.0.0.1"


static func api_port() -> int:
	if SettingsManager:
		var p = SettingsManager.get_setting("generation_server_port", null)
		if p != null:
			return clampi(int(p), 1, 65535)
	return clampi(int(ProjectSettings.get_setting("rhythmfall/generation_api/port", 5000)), 1, 65535)


static func track_stem_from_song_path(song_path: String) -> String:
	return String(song_path).get_file().get_basename()


static func extract_payload(payload: Variant) -> Dictionary:
	if payload is Dictionary:
		return payload
	if payload is String:
		var text := String(payload).strip_edges()
		if text.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed
	return {}


static func _poll_until_connected(http_client: HTTPClient) -> bool:
	var start_ms := Time.get_ticks_msec()
	while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http_client.poll()
		if Time.get_ticks_msec() - start_ms > _CONNECT_TIMEOUT_MS:
			return false
		OS.delay_msec(10)
	return http_client.get_status() == HTTPClient.STATUS_CONNECTED


static func _read_body(http_client: HTTPClient) -> PackedByteArray:
	var response_body := PackedByteArray()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		http_client.poll()
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			response_body.append_array(chunk)
		else:
			OS.delay_msec(10)
	return response_body


static func http_get_json(path: String) -> Dictionary:
	var out := {"ok": false, "code": 0, "json": null, "body_size": 0}
	var host := api_host()
	var port := api_port()
	var http_client := HTTPClient.new()
	if http_client.connect_to_host(host, port) != OK:
		push_warning("RhythmDNA fetch: connect failed %s:%d path=%s" % [host, port, path])
		return out
	if not _poll_until_connected(http_client):
		http_client.close()
		push_warning("RhythmDNA fetch: connect timeout %s:%d" % [host, port])
		return out
	http_client.request_raw(HTTPClient.METHOD_GET, path, PackedStringArray(), PackedByteArray())
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		OS.delay_msec(10)
	out.code = http_client.get_response_code()
	var response_body := _read_body(http_client)
	http_client.close()
	out.body_size = response_body.size()
	var response_json: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if response_json != null:
		out.json = response_json
		out.ok = true
	else:
		push_warning("RhythmDNA fetch: JSON parse failed code=%d bytes=%d path=%s" % [
			out.code, out.body_size, path,
		])
	return out


static func fetch_by_task_id(task_id: String) -> Dictionary:
	var tid := task_id.strip_edges()
	if tid == "":
		return {}
	var path := "/rhythm_dna?task_id=" + tid.uri_encode()
	var resp := http_get_json(path)
	if not resp.ok or not (resp.json is Dictionary):
		return {}
	var body: Dictionary = resp.json
	if int(resp.code) == 202:
		return {}
	var payload := extract_payload(body.get("rhythm_dna", null))
	if not payload.is_empty():
		push_warning("RhythmDNA fetch: OK via /rhythm_dna task_id=%s" % tid)
	return payload


static func fetch_sidecar(song_path: String, mode: String, instrument: String = "drums") -> Dictionary:
	var track := track_stem_from_song_path(song_path)
	if track == "":
		return {}
	var path := "/rhythm_dna_sidecar?track=%s&mode=%s&instrument=%s" % [
		track.uri_encode(),
		String(mode).uri_encode(),
		String(instrument).uri_encode(),
	]
	push_warning("RhythmDNA fetch: GET %s:%d%s" % [api_host(), api_port(), path])
	var resp := http_get_json(path)
	if not resp.ok or not (resp.json is Dictionary):
		push_warning("RhythmDNA fetch: sidecar HTTP failed code=%d" % int(resp.code))
		return {}
	var body: Dictionary = resp.json
	if int(resp.code) == 404 or body.has("error"):
		push_warning("RhythmDNA fetch: sidecar 404/error track=%s err=%s" % [
			track, str(body.get("error", "")),
		])
		return {}
	var payload := extract_payload(body.get("rhythm_dna", null))
	if payload.is_empty():
		push_warning("RhythmDNA fetch: sidecar empty body for track=%s" % track)
		return payload
	var pipeline: Dictionary = payload.get("pipeline", {}) if payload.get("pipeline", {}) is Dictionary else {}
	push_warning("RhythmDNA fetch: OK via sidecar track=%s source=%s" % [
		track, str(pipeline.get("source", 0)),
	])
	return payload


static func fetch_for_song(
	song_path: String,
	mode: String,
	instrument: String = "drums",
	task_id: String = ""
) -> Dictionary:
	var payload := fetch_by_task_id(task_id)
	if not payload.is_empty() and not NotesUtils.is_minimal_rhythm_dna(payload):
		return payload
	payload = fetch_sidecar(song_path, mode, instrument)
	if not payload.is_empty() and not NotesUtils.is_minimal_rhythm_dna(payload):
		return payload
	if not payload.is_empty():
		push_warning("RhythmDNA fetch: sidecar returned minimal report")
	return {}
