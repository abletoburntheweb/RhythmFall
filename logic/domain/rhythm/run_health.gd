# logic/utils/run_health.gd
extends RefCounted
class_name RunHealth

const START_RATIO := 1.0
const MISS_DELTA := -0.12
const GOOD_DELTA := 0.01
const PERFECT_DELTA := 0.02


static func apply_hit(current: float, hit_kind: String) -> float:
	match hit_kind:
		"perfect":
			return minf(START_RATIO, current + PERFECT_DELTA)
		"good":
			return minf(START_RATIO, current + GOOD_DELTA)
		_:
			return current


static func apply_miss(current: float) -> float:
	return maxf(0.0, current + MISS_DELTA)
