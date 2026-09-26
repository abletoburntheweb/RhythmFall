# Rare diary "wow" toasts — StatusDock secondary, one per flush.
extends RefCounted
class_name DiaryCelebration

const _StatusToast = preload("res://logic/ui/status_toast.gd")
const _Portrait = preload("res://logic/domain/profile/profile_genre_portrait.gd")

const KIND := "diary"
const DURATION_SEC := 4.8

const PRIORITY_SHELF := 100
const PRIORITY_GENRE_SS := 80
const PRIORITY_RR_LADDER := 70
const PRIORITY_MASTERY_BASE := 55
const PRIORITY_LIBRARY := 50

## Round mastery levels worth a toast / feed event (not every +1).
const MASTERY_ROUND_LEVELS := [2, 5, 10, 15, 20]

## Total-RR ladder (feed). After the table: +1M per step. Toast on rarer steps.
const RR_LADDER_THRESHOLDS := [25000, 50000, 100000, 250000, 500000, 1000000]
const RR_LADDER_TOAST_THRESHOLDS := [25000, 100000, 250000, 1000000]
const RR_LADDER_EXTEND_STEP := 1000000

## Shelf keys that get a celebration when first unlocked.
const SHELF_CELEBRATE_KEYS := [
	"first_track_played",
	"first_ss",
	"first_fc",
	"first_mod_clear",
	"unique_100_tracks",
	"clears_250",
	"genre_group_level_10",
	"total_rr_10000",
]

static var _queue: Array = []


static func clear_queue() -> void:
	_queue.clear()


static func offer(priority: int, id: String, text: String) -> void:
	var t := text.strip_edges()
	if id.strip_edges() == "" or t == "":
		return
	_queue.append({
		"priority": priority,
		"id": id,
		"text": t,
	})


static func flush_from_node(host: Node) -> void:
	if host == null or _queue.is_empty():
		_queue.clear()
		return
	var best: Dictionary = {}
	var best_p := -1
	for item in _queue:
		if not item is Dictionary:
			continue
		var p := int(item.get("priority", 0))
		if p > best_p:
			best_p = p
			best = item
	_queue.clear()
	if best.is_empty():
		return
	_StatusToast.show_from_node(
		host,
		str(best.get("id", "diary")),
		str(best.get("text", "")),
		KIND,
		DURATION_SEC
	)


static func celebrate_library(host: Node, count: int) -> void:
	clear_queue()
	var n := maxi(0, count)
	if n <= 0:
		return
	offer(
		PRIORITY_LIBRARY,
		"diary_library_%d" % n,
		TranslationServer.translate("DIARY_CELEBRATE_LIBRARY_FMT") % n
	)
	flush_from_node(host)


static func offer_shelf_milestone(key: String) -> void:
	if key == "" or not SHELF_CELEBRATE_KEYS.has(key):
		return
	var text := _shelf_text(key)
	if text == "":
		return
	offer(PRIORITY_SHELF, "diary_shelf_%s" % key, text)


static func offer_genre_group_ss(group_id: String) -> void:
	var gid := group_id.strip_edges()
	if gid == "" or gid == "_other":
		return
	var label := TranslationServer.translate(_Portrait.group_locale_key(gid))
	offer(
		PRIORITY_GENRE_SS,
		"diary_ss_ggroup_%s" % gid,
		TranslationServer.translate("DIARY_CELEBRATE_GENRE_SS_FMT") % label
	)


static func offer_mastery_level(group_id: String, level: int) -> void:
	var gid := group_id.strip_edges()
	if gid == "" or gid == "_other":
		return
	if not MASTERY_ROUND_LEVELS.has(level):
		return
	var label := TranslationServer.translate(_Portrait.group_locale_key(gid))
	offer(
		PRIORITY_MASTERY_BASE + level,
		"diary_mastery_%s_%d" % [gid, level],
		TranslationServer.translate("DIARY_CELEBRATE_MASTERY_FMT") % [label, level]
	)


static func offer_rr_ladder(threshold: int) -> void:
	if not should_toast_rr_ladder(threshold):
		return
	var amt := _format_rr_amount(threshold)
	offer(
		PRIORITY_RR_LADDER + mini(threshold / 25000, 40),
		"diary_rr_%d" % threshold,
		TranslationServer.translate("DIARY_CELEBRATE_RR_LADDER_FMT") % amt
	)


## Fixed early steps + open-ended +1M after the last table value.
static func rr_thresholds_reached(total: int, claimed: Array) -> Array:
	var newly: Array = []
	var t_total := maxi(0, total)
	var targets: Array = []
	for threshold in RR_LADDER_THRESHOLDS:
		targets.append(int(threshold))
	var last_fixed := int(RR_LADDER_THRESHOLDS[RR_LADDER_THRESHOLDS.size() - 1])
	if t_total > last_fixed:
		var t := last_fixed + RR_LADDER_EXTEND_STEP
		while t <= t_total:
			targets.append(t)
			t += RR_LADDER_EXTEND_STEP
	for t in targets:
		if t_total >= int(t) and not claimed.has(int(t)):
			newly.append(int(t))
	newly.sort()
	return newly


static func should_toast_rr_ladder(threshold: int) -> bool:
	if RR_LADDER_TOAST_THRESHOLDS.has(threshold):
		return true
	# Beyond 1M: toast each +1M step (rare enough).
	return threshold > int(RR_LADDER_THRESHOLDS[RR_LADDER_THRESHOLDS.size() - 1]) \
		and threshold % RR_LADDER_EXTEND_STEP == 0


## Debug / QA: force one diary StatusDock toast (does not write profile claims).
static func debug_show(host: Node, kind: String = "first_ss") -> void:
	clear_queue()
	var k := kind.strip_edges().to_lower()
	match k:
		"library", "library_100":
			celebrate_library(host, 100)
			return
		"mastery":
			offer_mastery_level("electronic", 5)
		"rr", "rr_ladder":
			offer(
				PRIORITY_RR_LADDER,
				"diary_debug_rr",
				TranslationServer.translate("DIARY_CELEBRATE_RR_LADDER_FMT") % _format_rr_amount(100000)
			)
		"genre_ss", "ss_group":
			offer_genre_group_ss("electronic")
		"first_fc":
			offer_shelf_milestone("first_fc")
		"first_track":
			offer_shelf_milestone("first_track_played")
		_:
			offer_shelf_milestone("first_ss")
	flush_from_node(host)


static func _format_rr_amount(n: int) -> String:
	var s := str(maxi(0, n))
	var out := ""
	var i := 0
	for j in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = " " + out
		out = s[j] + out
		i += 1
	return out


static func _shelf_text(key: String) -> String:
	match key:
		"first_track_played":
			return TranslationServer.translate("DIARY_CELEBRATE_FIRST_TRACK")
		"first_ss":
			return TranslationServer.translate("DIARY_CELEBRATE_FIRST_SS")
		"first_fc":
			return TranslationServer.translate("DIARY_CELEBRATE_FIRST_FC")
		"first_mod_clear":
			return TranslationServer.translate("DIARY_CELEBRATE_FIRST_MOD")
		"unique_100_tracks":
			return TranslationServer.translate("DIARY_CELEBRATE_UNIQUE_100")
		"clears_250":
			return TranslationServer.translate("DIARY_CELEBRATE_CLEARS_250")
		"genre_group_level_10":
			return TranslationServer.translate("DIARY_CELEBRATE_GENRE_L10")
		"total_rr_10000":
			return TranslationServer.translate("DIARY_CELEBRATE_RR_10K")
		_:
			return ""
