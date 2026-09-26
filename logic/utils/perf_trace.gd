# logic/utils/perf_trace.gd
extends RefCounted
class_name PerfTrace

# Static performance tracer — zero overhead when OFF.
# Levels: OFF (0) < LOAD (1) < RUNTIME (2) < DETAIL (3), inclusive.
#   DETAIL includes LOAD+RUNTIME+DETAIL.
# Not an Autoload — static API, holds mode + aggregated stats.
# Usage:
#   var t := PerfTrace.begin("perf.load.shop.total")  # 0 if disabled (cheap)
#   ... work ...
#   PerfTrace.end("perf.load.shop.total", t)
#   # or one-shot:
#   PerfTrace.record("perf.load.shop.data", elapsed_usec)
#   # guard for frequent paths:
#   if not PerfTrace.is_enabled(PerfTrace.LEVEL_RUNTIME): return
enum Level {
	OFF = 0,
	LOAD = 1,
	RUNTIME = 2,
	DETAIL = 3,
}

const LEVEL_NAMES: Dictionary = {
	Level.OFF: "OFF",
	Level.LOAD: "LOAD",
	Level.RUNTIME: "RUNTIME",
	Level.DETAIL: "DETAIL",
}

const CATEGORY_FOR_METRIC: Dictionary = {
	"perf.load": Level.LOAD,
	"perf.runtime": Level.RUNTIME,
	"perf.detail": Level.DETAIL,
}

# Aggregated stats: key(String) -> {count:int, total_usec:int, min_usec:int, max_usec:int}
static var _stats: Dictionary = {}
static var _level: int = Level.OFF
# Optional sampling for RUNTIME: measure 1 of N calls. 1 = measure every call.
# Kept simple — no decorrelated jitter needed for now.
static var _runtime_sample_rate: int = 1
static var _runtime_sample_counter: int = 0

static func set_level(level: int) -> void:
	_level = clampi(level, Level.OFF, Level.DETAIL)
	if _level == Level.OFF:
		_runtime_sample_counter = 0

static func get_level() -> int:
	return _level

static func level_name(level: int = -1) -> String:
	var l := _level if level < 0 else level
	return str(LEVEL_NAMES.get(l, "OFF"))

static func set_runtime_sample_rate(rate: int) -> void:
	_runtime_sample_rate = clampi(rate, 1, 1000)
	_runtime_sample_counter = 0

static func get_runtime_sample_rate() -> int:
	return _runtime_sample_rate

static func is_enabled(required: int) -> bool:
	# Inclusive: DETAIL enables everything, RUNTIME enables LOAD+RUNTIME, etc.
	return _level >= required

static func is_metric_enabled(metric: String) -> bool:
	# Fast prefix check without RegEx / split for hot path.
	if _level == Level.OFF:
		return false
	if metric.begins_with("perf.load."):
		return _level >= Level.LOAD
	if metric.begins_with("perf.runtime."):
		return _level >= Level.RUNTIME
	if metric.begins_with("perf.detail."):
		return _level >= Level.DETAIL
	# Fallback: treat unknown perf.* as LOAD
	if metric.begins_with("perf."):
		return _level >= Level.LOAD
	return false

# Hot-path helper: returns 0 if disabled (caller must check `if t == 0: return`).
# No String formatting, no Dictionary alloc when disabled.
static func begin(metric: String) -> int:
	if not is_metric_enabled(metric):
		return 0
	# Sampling for RUNTIME — skip N-1 of N without touching timer.
	if metric.begins_with("perf.runtime."):
		if _runtime_sample_rate > 1:
			_runtime_sample_counter += 1
			if (_runtime_sample_counter % _runtime_sample_rate) != 0:
				return 0
	return Time.get_ticks_usec()

static func end(metric: String, start_usec: int) -> void:
	if start_usec == 0:
		return
	var elapsed := Time.get_ticks_usec() - start_usec
	record(metric, elapsed)

static func record(metric: String, elapsed_usec: int) -> void:
	if elapsed_usec < 0:
		elapsed_usec = 0
	var entry: Dictionary = _stats.get(metric, {})
	if entry.is_empty():
		_stats[metric] = {
			"count": 1,
			"total_usec": elapsed_usec,
			"min_usec": elapsed_usec,
			"max_usec": elapsed_usec,
		}
	else:
		entry["count"] = int(entry.get("count", 0)) + 1
		entry["total_usec"] = int(entry.get("total_usec", 0)) + elapsed_usec
		var mn := int(entry.get("min_usec", elapsed_usec))
		var mx := int(entry.get("max_usec", elapsed_usec))
		if elapsed_usec < mn:
			entry["min_usec"] = elapsed_usec
		if elapsed_usec > mx:
			entry["max_usec"] = elapsed_usec

static func reset() -> void:
	_stats.clear()
	_runtime_sample_counter = 0

static func get_stats() -> Dictionary:
	return _stats.duplicate(true)

static func get_stats_sorted() -> Array:
	var keys := _stats.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		var e: Dictionary = _stats[k]
		var cnt := int(e.get("count", 0))
		var total := int(e.get("total_usec", 0))
		var avg_ms := (float(total) / float(maxi(cnt, 1))) / 1000.0
		var min_ms := float(int(e.get("min_usec", 0))) / 1000.0
		var max_ms := float(int(e.get("max_usec", 0))) / 1000.0
		out.append({
			"key": str(k),
			"count": cnt,
			"avg_ms": avg_ms,
			"min_ms": min_ms,
			"max_ms": max_ms,
			"total_usec": total,
		})
	return out

static func format_stats_text() -> String:
	var rows := get_stats_sorted()
	if rows.is_empty():
		return "[PERF] no metrics collected (level=%s)" % level_name()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[PERF] stats level=%s sample_rate=%d metrics=%d" % [level_name(), _runtime_sample_rate, rows.size()])
	# Group by prefix for readability: LOAD vs RUNTIME vs DETAIL
	var current_prefix := ""
	for r in rows:
		var key: String = str(r.get("key", ""))
		var prefix := "other"
		if key.begins_with("perf.load."):
			prefix = "LOAD"
		elif key.begins_with("perf.runtime."):
			prefix = "RUNTIME"
		elif key.begins_with("perf.detail."):
			prefix = "DETAIL"
		if prefix != current_prefix:
			current_prefix = prefix
			lines.append("[PERF][%s]" % current_prefix)
		lines.append("  %s  n=%d avg=%.2f ms min=%.2f ms max=%.2f ms" % [
			key, int(r.get("count", 0)), float(r.get("avg_ms", 0.0)), float(r.get("min_ms", 0.0)), float(r.get("max_ms", 0.0))
		])
	return "\n".join(lines)

static func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[PERF] Performance debug: %s" % level_name())
	lines.append("  LOAD:    %s" % ("ON" if _level >= Level.LOAD else "OFF"))
	lines.append("  RUNTIME: %s" % ("ON" if _level >= Level.RUNTIME else "OFF"))
	lines.append("  DETAIL:  %s" % ("ON" if _level >= Level.DETAIL else "OFF"))
	lines.append("  sample_rate (runtime): 1/%d" % _runtime_sample_rate)
	lines.append("  metrics collected: %d" % _stats.size())
	if not _stats.is_empty():
		lines.append("  use perf.stats to see aggregation, perf.reset to clear")
	return "\n".join(lines)
