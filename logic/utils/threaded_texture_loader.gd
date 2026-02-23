extends Node
class_name ThreadedTextureLoader
signal loaded(path: String, texture: Texture2D)
signal failed(path: String)
var _pending: Dictionary = {}
var _cache: Dictionary = {}
static var _instance: ThreadedTextureLoader = null
static func get_instance() -> ThreadedTextureLoader:
	if _instance == null:
		_instance = ThreadedTextureLoader.new()
		var tree = Engine.get_main_loop()
		if tree and tree is SceneTree:
			tree.root.add_child(_instance)
	return _instance
func request(path: String) -> void:
	if path == "":
		return
	if _cache.has(path):
		emit_signal("loaded", path, _cache[path])
		return
	if _pending.has(path):
		return
	var ok = ResourceLoader.load_threaded_request(path, "Texture2D")
	if ok == OK:
		_pending[path] = true
		set_process(true)
	else:
		var tex = ResourceLoader.load(path, "Texture2D")
		if tex and tex is Texture2D:
			_cache[path] = tex
			emit_signal("loaded", path, tex)
		else:
			emit_signal("failed", path)
func get_cached(path: String) -> Texture2D:
	return _cache.get(path, null)
func clear_cache() -> void:
	_cache.clear()
func _process(_delta: float) -> void:
	var done := []
	for path in _pending.keys():
		var st = ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var tex = ResourceLoader.load_threaded_get(path)
			if tex and tex is Texture2D:
				_cache[path] = tex
				emit_signal("loaded", path, tex)
			else:
				emit_signal("failed", path)
			done.append(path)
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			emit_signal("failed", path)
			done.append(path)
	for path in done:
		_pending.erase(path)
	if _pending.is_empty():
		set_process(false)
