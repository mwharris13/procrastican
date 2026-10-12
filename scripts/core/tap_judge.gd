class_name TapJudge
extends RefCounted

enum Grade { MISS, GOOD, PERFECT }


static func grade(offset_s: float, perfect_window: float, good_window: float) -> int:
	var d := absf(offset_s)
	if d <= perfect_window:
		return Grade.PERFECT
	if d <= good_window:
		return Grade.GOOD
	return Grade.MISS


static func in_reach(tap: Vector2, can_center: Vector2, reach_m: float) -> bool:
	# Epsilon because Vector2 is float32 and an exact-boundary tap would otherwise fail.
	return tap.distance_to(can_center) <= reach_m + 0.0001
