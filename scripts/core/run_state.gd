class_name RunState
extends RefCounted
## Per-run bookkeeping: distance, combo, coin value, zone and perk checkpoints.

const PERK_FIRST_M := 250.0
const PERK_GROWTH := 1.6

var stats: Dictionary
var zones: Array
var distance := 0.0
var combo := 0
var best_combo := 0
var perfects := 0
var value_meters := 0.0
var zone_index := 0
var next_perk_at := PERK_FIRST_M
var perk_count := 0


func _init(p_stats: Dictionary, p_zones: Array) -> void:
	stats = p_stats
	zones = p_zones


static func zone_index_at(p_zones: Array, x: float) -> int:
	var idx := 0
	for i in p_zones.size():
		if x >= float(p_zones[i].start_m):
			idx = i
	return idx


func zone_value() -> float:
	return float(zones[zone_index].value) if not zones.is_empty() else 1.0


func on_distance(x: float) -> Array:
	var events: Array = []
	if x <= distance:
		return events
	value_meters += (x - distance) * Economy.meter_value(zone_value(), combo, stats.combo_step)
	distance = x
	var zi := zone_index_at(zones, x)
	if zi != zone_index:
		zone_index = zi
		events.append({"type": "zone", "index": zi})
	while distance >= next_perk_at:
		perk_count += 1
		next_perk_at += PERK_FIRST_M * pow(PERK_GROWTH, perk_count)
		events.append({"type": "perk_due"})
	return events


func on_grade(grade: int) -> void:
	if grade == TapJudge.Grade.PERFECT:
		combo += 1
		perfects += 1
	elif grade == TapJudge.Grade.MISS:
		combo = 0
	best_combo = maxi(best_combo, combo)


func on_helper(add: int) -> void:
	combo += add
	best_combo = maxi(best_combo, combo)


func coins() -> float:
	return Economy.run_coins(value_meters, stats.coin_per_meter, stats.coin_mult)
