class_name RunSim
extends RefCounted
## One run: can physics plus tap timing, air kicks, street objects and a stuck-run watchdog.

const STALL_SECONDS := 5.0
const MAX_HAZARD_W := 6.0

var stats: Dictionary
var can: CanPhysics
var street = null
var ended := false
var air_kicks_left := 0
var perfect_count := 0
var _buffered_tap_t := NAN
var _late_open := false
var _since_touchdown := 0.0
var _used := {}
var _stall_x := 0.0
var _stall_t := 0.0


func _init(p_stats: Dictionary) -> void:
	stats = p_stats
	can = CanPhysics.new(stats)
	air_kicks_left = int(stats.air_kicks)


func launch(angle_deg: float, power01: float) -> void:
	can.launch(angle_deg, power01)


func can_center() -> Vector2:
	return can.pos + Vector2(0.0, stats.can_half_height)


func tap(world_pos: Vector2) -> Dictionary:
	if ended or not can.launched:
		return {}
	if not TapJudge.in_reach(world_pos, can_center(), stats.tap_reach_m):
		return {}
	if _late_open:
		_late_open = false
		return _resolve(TapJudge.grade(_since_touchdown, stats.perfect_window, stats.good_window))
	if not is_nan(_buffered_tap_t):
		return {}
	var ttd := can.time_to_touchdown()
	if ttd <= stats.good_window:
		_buffered_tap_t = can.time
		return {"type": "tap_buffered"}
	if air_kicks_left > 0 and ttd < INF:
		air_kicks_left -= 1
		can.air_kick(stats.air_kick_boost)
		return {"type": "air_kick", "x": can.pos.x}
	return {}


func advance(dt: float) -> Array:
	var events: Array = []
	if ended or not can.launched:
		return events
	var remaining := dt
	while remaining > 0.0 and not ended:
		var prev := can.pos
		var chunk: Array = []
		var step_dt := remaining
		if _late_open:
			# Cap so the late-window MISS fires before any next touchdown.
			step_dt = minf(remaining, maxf(stats.good_window - _since_touchdown, 0.0) + 1e-4)
		var used := can.step(step_dt, chunk)
		remaining -= used
		if _late_open:
			_since_touchdown += used
		_check_street(prev, chunk, events)
		for ev in chunk:
			events.append(ev)
			if ev.type == "touchdown":
				_on_touchdown(ev, events)
		if _late_open and _since_touchdown > stats.good_window:
			_late_open = false
			events.append(_resolve(TapJudge.Grade.MISS))
		_watchdog(used, events)
		if can.at_rest and not _late_open and not ended:
			_end("rest", events)
	return events


func _on_touchdown(ev: Dictionary, events: Array) -> void:
	if not is_nan(_buffered_tap_t):
		var offset: float = ev.t - _buffered_tap_t
		_buffered_tap_t = NAN
		events.append(_resolve(TapJudge.grade(offset, stats.perfect_window, stats.good_window)))
	else:
		_late_open = true
		_since_touchdown = 0.0


func _resolve(grade: int) -> Dictionary:
	var ev := {"type": "graded", "grade": grade, "x": can.pos.x, "super": false}
	if grade == TapJudge.Grade.MISS:
		return ev
	can.rekick(grade == TapJudge.Grade.PERFECT)
	if grade == TapJudge.Grade.PERFECT:
		perfect_count += 1
		var every := int(stats.super_kick_every)
		if every > 0 and perfect_count % every == 0:
			can.vel.x = minf(can.vel.x * stats.super_kick_mult, stats.max_speed)
			ev.super = true
	return ev


func _check_street(prev: Vector2, chunk: Array, events: Array) -> void:
	if street == null:
		return
	var now := can.pos
	for obj in street.objects_between(prev.x, now.x):
		var def: Dictionary = street.objects[obj.id]
		if def.kind != "helper" or _used.has(obj.x):
			continue
		var t: float = 0.0 if is_equal_approx(now.x, prev.x) else (obj.x - prev.x) / (now.x - prev.x)
		if lerpf(prev.y, now.y, t) <= float(def.height):
			_used[obj.x] = true
			can.apply_helper(def, stats.helper_speed_mult)
			events.append({"type": "helper", "id": obj.id, "x": obj.x, "combo": int(def.get("combo", 0))})
	var probe_x := NAN
	for ev in chunk:
		if ev.type == "touchdown":
			probe_x = ev.x
	var span_start := probe_x
	if is_nan(probe_x) and can.rolling:
		# Test the whole rolled span so a big step can't skip a narrow hazard.
		probe_x = now.x
		span_start = prev.x
	if is_nan(probe_x):
		return
	for obj in street.objects_between(span_start - MAX_HAZARD_W, probe_x):
		var def: Dictionary = street.objects[obj.id]
		if def.kind != "hazard" or _used.has(obj.x) or span_start > obj.x + float(def.width):
			continue
		_used[obj.x] = true
		var tramp: bool = obj.id == "puddle" and stats.puddle_trampoline >= 1.0
		can.apply_hazard(obj.id, def)
		events.append({"type": "hazard", "id": obj.id, "x": obj.x, "trampoline": tramp})


func _watchdog(used: float, events: Array) -> void:
	if ended:
		return
	var p := can.pos
	var v := can.vel
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(v.x) and is_finite(v.y)):
		_end("watchdog", events)
		return
	if can.time >= stats.max_run_time:
		_end("watchdog", events)
		return
	if can.at_rest:
		return
	if p.x - _stall_x > 0.01:
		_stall_x = p.x
		_stall_t = 0.0
	else:
		_stall_t += used
		if _stall_t >= STALL_SECONDS:
			_end("watchdog", events)


func _end(reason: String, events: Array) -> void:
	ended = true
	events.append({"type": "run_end", "x": can.pos.x, "reason": reason})
