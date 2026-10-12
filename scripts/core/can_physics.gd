class_name CanPhysics
extends RefCounted
## Deterministic can flight: meters and seconds, y up, ground at y = 0, pos is the can's bottom.

const SUBSTEP := 1.0 / 240.0

var stats: Dictionary
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var angle := 0.0
var time := 0.0
var launched := false
var rolling := false
var at_rest := false
var last_impact_vel := Vector2.ZERO


func _init(p_stats: Dictionary) -> void:
	stats = p_stats


func launch(angle_deg: float, power01: float) -> void:
	var a := deg_to_rad(angle_deg)
	var speed: float = stats.launch_speed_max * clampf(power01, 0.0, 1.0)
	vel = Vector2(cos(a), sin(a)) * speed
	pos = Vector2.ZERO
	launched = true
	rolling = false
	at_rest = false


## Advances up to dt but stops right after a touchdown or rest; returns the time consumed.
func step(dt: float, events: Array) -> float:
	if not launched or at_rest:
		return dt
	var used := 0.0
	while used < dt:
		var h := minf(SUBSTEP, dt - used)
		used += h
		time += h
		if _substep(h, events):
			break
	return used


func _substep(h: float, events: Array) -> bool:
	if rolling:
		vel.x = maxf(0.0, vel.x + (stats.tailwind - stats.ground_friction) * h)
		pos.x += vel.x * h
		angle += vel.x / stats.can_radius * h
		if vel.x <= stats.rest_speed:
			vel = Vector2.ZERO
			at_rest = true
			events.append({"type": "rest", "x": pos.x, "t": time})
			return true
		return false
	vel.y -= stats.gravity * h
	vel.x += stats.tailwind * h
	vel -= vel * stats.air_drag * h
	vel.x = minf(vel.x, stats.max_speed)
	pos += vel * h
	angle += vel.x / stats.can_radius * h * 0.5
	if pos.y <= 0.0 and vel.y < 0.0:
		pos.y = 0.0
		last_impact_vel = vel
		_dead_bounce()
		events.append({"type": "touchdown", "x": pos.x, "t": time})
		return true
	return false


func _dead_bounce() -> void:
	vel = Vector2(last_impact_vel.x * stats.miss_vx_keep, -last_impact_vel.y * stats.restitution_miss)
	if vel.y < stats.roll_vy:
		vel.y = 0.0
		rolling = true


func rekick(perfect: bool) -> void:
	var rest: float = stats.restitution_perfect if perfect else stats.restitution_good
	var keep: float = stats.perfect_vx_boost if perfect else stats.good_vx_keep
	vel.x = minf(last_impact_vel.x * keep, stats.max_speed)
	vel.y = maxf(-last_impact_vel.y * rest, stats.rekick_vy_min)
	pos.y = maxf(pos.y, 0.0)
	rolling = false
	at_rest = false


func air_kick(boost: float) -> void:
	vel.x = minf(vel.x + boost, stats.max_speed)
	vel.y = maxf(vel.y, boost * 0.5)


## Ignores drag, so it slightly overestimates; good enough for buffering and the telegraph ring.
func time_to_touchdown() -> float:
	if not launched or rolling or at_rest:
		return INF
	var g: float = stats.gravity
	return (vel.y + sqrt(vel.y * vel.y + 2.0 * g * maxf(pos.y, 0.0))) / g
