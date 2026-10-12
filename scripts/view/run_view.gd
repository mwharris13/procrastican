class_name RunView
extends Node2D
## Draws the street and can from baked sprites, turns touches into aim and taps, and forwards sim events.

signal sim_event(ev: Dictionary)
signal progressed(x: float)
signal run_ended(ev: Dictionary)

const CAN_SCREEN_X := 90.0
const KID_X := -0.9
const HOUSE_SPACING_M := 7.0
const RING_LEAD_S := 0.5
const CAMERA_FOLLOW := 8.0
const KICK_POSE_S := 0.15
const STRONG_AIM := 0.6
const SKY_BANDS := 24

var stats: Dictionary = {}
var sim: RunSim
var juice: Juice
var sfx: Sfx
var probe: LatencyProbe
var state := "idle"
var input_enabled := true
var cam_x := 0.0
var ground_y := 410.0
var ppm := 14.0
var zones: Array = []
var can_sprite := "soda"
var _drag_index := -1
var _drag_start := Vector2.ZERO
var _aim := {"valid": false}
var _preview := PackedVector2Array()
var _squash := 0.0
var _since_launch := 0.0
var _blink_in := 3.0
var _blink_left := 0.0


static func default_zones() -> Array:
	return [{"start_m": 0, "palette": {
		"sky": ["6c6fb4", "c995c0", "f2a8a6", "ffd6a0"], "sidewalk": "d8b9a8", "curb": "b89a8f",
		"road": "4b4560", "lane": "e8d6d0", "tint": "ffffff", "sheet": "block"}}]


func _ready() -> void:
	ground_y = roundf(get_viewport_rect().size.y * 0.7)
	if zones.is_empty():
		zones = default_zones()


func setup(p_juice: Juice, p_sfx: Sfx, p_probe: LatencyProbe) -> void:
	juice = p_juice
	sfx = p_sfx
	probe = p_probe


func set_zones(p_zones: Array) -> void:
	zones = p_zones
	queue_redraw()


func start_aim(p_stats: Dictionary, street = null) -> void:
	stats = p_stats
	ppm = stats.px_per_m
	sim = RunSim.new(stats)
	sim.street = street
	state = "aiming"
	cam_x = -CAN_SCREEN_X / ppm
	_aim = {"valid": false}
	_preview = PackedVector2Array()
	_drag_index = -1
	_since_launch = 0.0
	queue_redraw()


func world_to_screen(w: Vector2) -> Vector2:
	return Vector2(roundf((w.x - cam_x) * ppm), roundf(ground_y - w.y * ppm))


func screen_to_world(s: Vector2) -> Vector2:
	return Vector2(s.x / ppm + cam_x, (ground_y - s.y) / ppm)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		if probe:
			probe.mark_input(Time.get_ticks_usec())
		if state == "aiming":
			if event.pressed and _drag_index == -1:
				_drag_index = event.index
				begin_drag(event.position)
			elif not event.pressed and event.index == _drag_index:
				# iOS touchcancel arrives as a release; it must not kick.
				if event.canceled:
					cancel_drag()
				else:
					end_drag()
			get_viewport().set_input_as_handled()
		elif state == "flying" and event.pressed:
			tap_screen(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and state == "aiming" and event.index == _drag_index:
		update_drag(event.position)
		get_viewport().set_input_as_handled()


func begin_drag(pos: Vector2) -> void:
	_drag_start = pos
	_aim = {"valid": false}


func update_drag(pos: Vector2) -> void:
	_aim = LaunchAim.from_drag(pos - _drag_start, stats)
	_preview = LaunchAim.preview(_aim.angle, _aim.power, stats) if _aim.valid else PackedVector2Array()
	queue_redraw()


func cancel_drag() -> void:
	_drag_index = -1
	_aim = {"valid": false}
	_preview = PackedVector2Array()
	queue_redraw()


func end_drag() -> void:
	_drag_index = -1
	_preview = PackedVector2Array()
	if state != "aiming" or not _aim.valid:
		queue_redraw()
		return
	sim.launch(_aim.angle, _aim.power)
	state = "flying"
	_since_launch = 0.0
	sfx.play("kick")
	juice.hitstop(0.05)
	juice.shake(3.0)
	sim_event.emit({"type": "launch", "angle": _aim.angle, "power": _aim.power})


func tap_screen(pos: Vector2) -> Dictionary:
	if state != "flying":
		return {}
	var r := sim.tap(screen_to_world(pos))
	if not r.is_empty():
		_react(r)
		sim_event.emit(r)
	return r


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if probe:
		probe.mark_frame(Time.get_ticks_usec())
	if juice:
		position = juice.shake_offset
	_squash = maxf(0.0, _squash - delta * 6.0)
	_since_launch += delta
	_blink_left = maxf(0.0, _blink_left - delta)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_left = 0.15
		_blink_in = randf_range(3.0, 5.0)
	if state == "flying":
		for ev in sim.advance(delta):
			_react(ev)
			sim_event.emit(ev)
			if ev.type == "run_end":
				state = "done"
				run_ended.emit(ev)
		var target := sim.can.pos.x - CAN_SCREEN_X / ppm
		cam_x = maxf(cam_x, lerpf(cam_x, target, minf(1.0, delta * CAMERA_FOLLOW)))
		progressed.emit(sim.can.pos.x)
	queue_redraw()


func _react(ev: Dictionary) -> void:
	var at := world_to_screen(sim.can_center())
	match ev.type:
		"graded":
			_squash = 1.0
			match ev.grade:
				TapJudge.Grade.PERFECT:
					sfx.play("perfect", randf_range(0.97, 1.05))
					juice.hitstop(0.06)
					juice.shake(4.0)
					juice.popup("SUPER!" if ev.super else "PERFECT!", at + Vector2(0, -22), UiTheme.GOLD, 18)
					juice.burst(self, at, UiTheme.GOLD, 18)
				TapJudge.Grade.GOOD:
					sfx.play("good")
					juice.shake(2.0)
					juice.popup("GOOD", at + Vector2(0, -20), Color.WHITE, 14)
					juice.burst(self, at, Color.WHITE, 8)
				_:
					sfx.play("miss")
					juice.popup("miss", at + Vector2(0, -18), Color("9a9aa8"), 12)
		"air_kick":
			sfx.play("kick", 1.3)
			juice.shake(2.0)
			juice.popup("AIR!", at + Vector2(0, -20), Color.WHITE, 14)
		"touchdown":
			_squash = 1.0
			juice.burst(self, world_to_screen(sim.can.pos), ZoneLook.color(zones, sim.can.pos.x, "sidewalk"), 5)
		"helper":
			sfx.play("helper")
			juice.shake(3.0)
			juice.popup("BOING", at + Vector2(0, -20), Color.WHITE, 14)
		"hazard":
			sfx.play("helper" if ev.get("trampoline", false) else "hazard")
			juice.popup(str(ev.id).replace("_", " "), at + Vector2(0, -18), Color("9a9aa8"), 12)


func _draw() -> void:
	var size := get_viewport_rect().size
	var lx := _look_x()
	var tint := ZoneLook.tint(zones, lx)
	_draw_sky(size, lx)
	_draw_far(size, lx)
	_draw_street(size, lx)
	_draw_buildings(size)
	_draw_objects(size, tint)
	if state != "idle":
		_draw_kid(tint)
	if sim:
		_draw_shadow_and_ring()
		_draw_can(Color.WHITE.lerp(tint, 0.5))
	for i in _preview.size():
		draw_circle(world_to_screen(_preview[i]), 1.5 if i % 2 == 0 else 1.0, Color(1, 1, 1, 0.9))


func _look_x() -> float:
	return sim.can.pos.x if sim else cam_x


func _base_y() -> float:
	return ground_y - 6.0


func _draw_sky(size: Vector2, lx: float) -> void:
	var stops := ZoneLook.sky_stops(zones, lx)
	var h := _base_y() / SKY_BANDS
	for i in SKY_BANDS:
		var f := float(i) / (SKY_BANDS - 1) * (stops.size() - 1)
		var k := mini(int(f), stops.size() - 2)
		draw_rect(Rect2(0, roundf(i * h), size.x, ceilf(h) + 1.0), stops[k].lerp(stops[k + 1], f - k))
	var b := ZoneLook.blend_at(zones, lx)
	_draw_sky_props(size, zones[b.from].palette.sheet, 1.0 - b.t)
	if b.t > 0.0:
		_draw_sky_props(size, zones[b.to].palette.sheet, b.t)


func _draw_sky_props(size: Vector2, sheet: String, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	var drift := cam_x * ppm * 0.1
	match sheet:
		"block":
			SpriteBank.draw(self, "block", "sun_low", Vector2(size.x - 46, _base_y() - 70), a)
			SpriteBank.draw(self, "block", "cloud_a", Vector2(fposmod(60 - drift, size.x + 80) - 40, 96), a)
			SpriteBank.draw(self, "block", "cloud_b", Vector2(fposmod(200 - drift * 0.7, size.x + 80) - 40, 150), a)
		"downtown":
			SpriteBank.draw(self, "downtown", "sun_dusk", Vector2(46, _base_y() - 110), a)
			SpriteBank.draw(self, "downtown", "cloud_dusk", Vector2(fposmod(150 - drift, size.x + 80) - 40, 120), a)
		"highway":
			for i in 24:
				var star := "star_a" if i % 4 == 0 else "star_b"
				var sx := fposmod(i * 53.0 - drift * 0.2, size.x)
				SpriteBank.draw(self, "highway", star, Vector2(sx, 12.0 + float((i * 29) % 230)), a)
			SpriteBank.draw(self, "highway", "moon", Vector2(size.x - 64, 92), a)


func _draw_far(size: Vector2, lx: float) -> void:
	var b := ZoneLook.blend_at(zones, lx)
	_draw_far_layer(size, zones[b.from].palette.sheet, 1.0 - b.t)
	if b.t > 0.0:
		_draw_far_layer(size, zones[b.to].palette.sheet, b.t)


func _draw_far_layer(size: Vector2, sheet: String, alpha: float) -> void:
	var a := Color(1, 1, 1, alpha)
	match sheet:
		"block":
			_tile(size, "block", "hills_far", 0.3, _base_y() - 66, a)
			_tile(size, "block", "hills_near", 0.45, _base_y() - 40, a)
		"downtown":
			_tile(size, "downtown", "skyline", 0.3, _base_y() - 150, a)
		"highway":
			_tile(size, "highway", "city_far", 0.3, _base_y() - 76, a)


## Repeats a top-left-anchored strip across the screen at a parallax factor.
func _tile(size: Vector2, sheet: String, sprite: String, factor: float, top: float, modulate: Color) -> void:
	var f := SpriteBank.frame(sheet, sprite)
	if f.is_empty():
		return
	var w: float = f.region.size.x
	var x := -fposmod(cam_x * ppm * factor, w)
	while x < size.x:
		SpriteBank.draw(self, sheet, sprite, Vector2(x, top), modulate)
		x += w


func _draw_street(size: Vector2, lx: float) -> void:
	var base := _base_y()
	var curb := ZoneLook.color(zones, lx, "curb")
	draw_rect(Rect2(0, base, size.x, 12), ZoneLook.color(zones, lx, "sidewalk"))
	var joint := 3.0
	var jx := floorf(cam_x / joint) * joint
	while (jx - cam_x) * ppm < size.x:
		draw_rect(Rect2(roundf((jx - cam_x) * ppm), base, 1, 12), curb)
		jx += joint
	draw_rect(Rect2(0, base + 12, size.x, 4), curb)
	draw_rect(Rect2(0, base + 16, size.x, size.y - base - 16), ZoneLook.color(zones, lx, "road"))
	var lane := ZoneLook.color(zones, lx, "lane")
	var dash := 4.0
	var wx := floorf(cam_x / dash) * dash
	while (wx - cam_x) * ppm < size.x:
		draw_rect(Rect2(roundf((wx - cam_x) * ppm), ground_y + 60, 1.6 * ppm, 3), lane)
		wx += dash


func _draw_buildings(size: Vector2) -> void:
	var base := _base_y()
	var first := int(floor(cam_x / HOUSE_SPACING_M)) - 1
	var last := int(ceil((cam_x + size.x / ppm) / HOUSE_SPACING_M)) + 1
	for i in range(first, last + 1):
		var wx := i * HOUSE_SPACING_M + 2.5
		var b := ZoneLook.building(zones, i, wx)
		if b.is_empty():
			continue
		var cx := roundf((wx - cam_x) * ppm)
		if b.sheet == "block":
			SpriteBank.draw(self, "block", "house_shadow", Vector2(cx - 68, base), Color(1, 1, 1, 0.28))
		SpriteBank.draw(self, b.sheet, b.name, Vector2(cx, base))


func _draw_objects(size: Vector2, tint: Color) -> void:
	if sim == null or sim.street == null:
		return
	var x0 := cam_x - 6.0
	var x1 := cam_x + size.x / ppm + 2.0
	for o in sim.street.objects_between(x0, x1):
		var def: Dictionary = sim.street.objects[o.id]
		var p := world_to_screen(Vector2(o.x, 0.0))
		# Hazards span [x, x + width] and lie on the walk; helpers stand centered on x.
		SpriteBank.draw(self, "objects", o.id, p + (Vector2(0, 2) if def.kind == "hazard" else Vector2.ZERO), tint)


func _kid_pose() -> String:
	match state:
		"aiming":
			if _drag_index >= 0 and _aim.valid:
				return "aim_strong" if _aim.power >= STRONG_AIM else "aim_light"
			return "idle#1" if _blink_left > 0.0 else "idle#0"
		"flying":
			return "kick" if _since_launch < KICK_POSE_S else "watch"
	return "watch"


func _draw_kid(tint: Color) -> void:
	SpriteBank.draw(self, "kid", _kid_pose(), world_to_screen(Vector2(KID_X, 0)), tint)


func _draw_shadow_and_ring() -> void:
	var g := world_to_screen(Vector2(sim.can.pos.x, 0))
	var k := 1.0 / (1.0 + sim.can.pos.y * 0.15)
	draw_set_transform(g, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 6.0 * k, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state != "flying":
		return
	var ttd := sim.can.time_to_touchdown()
	if ttd < RING_LEAD_S:
		draw_arc(world_to_screen(sim.can_center()), 8.0 + ttd * 60.0, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 1.0)


static func spin_frame(angle_rad: float) -> int:
	return posmod(roundi(rad_to_deg(angle_rad) / 22.5), 16)


func _draw_can(modulate: Color) -> void:
	var c := world_to_screen(sim.can_center())
	if c.y < 6.0:
		# Off the top of the screen: show a marker instead.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x, 2), Vector2(c.x - 4, 9), Vector2(c.x + 4, 9)]), Color("e63946"))
		return
	draw_set_transform(c, 0.0, Vector2(1.0 + 0.35 * _squash, 1.0 - 0.35 * _squash))
	SpriteBank.draw(self, "cans", "%s#%d" % [can_sprite, spin_frame(sim.can.angle)], Vector2.ZERO, modulate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
