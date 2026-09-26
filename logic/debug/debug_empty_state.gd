# logic/debug/debug_empty_state.gd
extends RefCounted
class_name DebugEmptyState

static var enabled: bool = false

static func is_enabled() -> bool:
	return enabled

static func set_enabled(v: bool) -> void:
	enabled = v

static func toggle() -> bool:
	enabled = not enabled
	return enabled
