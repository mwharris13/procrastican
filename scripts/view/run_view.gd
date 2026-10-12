class_name RunView
extends Node2D
## Draws the street and can in code, turns touches into aim and taps, and forwards sim events.

signal sim_event(ev: Dictionary)
signal progressed(x: float)
signal run_ended(ev: Dictionary)

const CAN_SCREEN_X := 90.0
const KID_X := -0.9
const HOUSE_SPACING_M := 7.0
const RING_LEAD_S := 0.5
const CAMERA_FOLLOW := 8.0

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
var _pal := {}
var _drag_index := -1
var _drag_start := Vector2.ZERO
var _aim := {"valid": false}
var _preview := PackedVector2Array()
var _squash := 0.0


static func default_palette() -> Dictionary:
	return {
		"sky_top": "8fd3f4", "sky_bottom": "fbe3c4", "hills": "a8d5a2",
		"sidewalk": "d9d4cc", "road": "5d5f71", "lane": "e9e6ee",
		"houses": ["f7b267", "9ad1d4", "f4d35e", "f6bd60"],
		"roofs": ["e5676a", "4a6fa5", "ee964b", "84a59d"],
	}


func _ready() -> void:
	ground_y = roundf(get_viewport_rect().size.y * 0.7)
	if _pal.is_empty():
		set_palette(default_palette())


func setup(p_juice: Juice, p_sfx: Sfx, p_probe: LatencyProbe) -> void:
	juice = p_juice
	sfx = p_sfx
	probe = p_probe


func set_palette(hex: Dictionary) -> void:
	_pal = {}
	for k in hex:
		_pal[k] = hex[k].map(func(h): return Color(h)) if hex[k] is Array else Color(hex[k])
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
			juice.burst(self, world_to_screen(sim.can.pos), _pal.get("sidewalk", Color.WHITE), 5)
		"helper":
			sfx.play("helper")
			juice.shake(3.0)
			juice.popup("BOING", at + Vector2(0, -20), Color.WHITE, 14)
		"hazard":
			sfx.play("helper" if ev.get("trampoline", false) else "hazard")
			juice.popup(str(ev.id).replace("_", " "), at + Vector2(0, -18), Color("9a9aa8"), 12)


func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_sky(size)
	_draw_hills(size)
	_draw_houses(size)
	_draw_street(size)
	_draw_objects(size)
	if state != "idle":
		_draw_kid()
	if sim:
		_draw_shadow_and_ring()
		_draw_can()
	for i in _preview.size():
		draw_circle(world_to_screen(_preview[i]), 1.5 if i % 2 == 0 else 1.0, Color(1, 1, 1, 0.9))


func _draw_sky(size: Vector2) -> void:
	var bands := 10
	var h := (ground_y - 6.0) / bands
	for i in bands:
		draw_rect(Rect2(0, i * h, size.x, h + 1.0), _pal.sky_top.lerp(_pal.sky_bottom, float(i) / (bands - 1)))
	draw_circle(Vector2(size.x - 60, 110), 26.0, Color("fff4d6"))


func _draw_hills(size: Vector2) -> void:
	var base := ground_y - 6.0
	var pts := PackedVector2Array([Vector2(0, base)])
	var x := 0.0
	while x <= size.x + 6.0:
		var wx := x / ppm + cam_x * 0.3
		pts.append(Vector2(x, base - 50.0 - 14.0 * sin(wx * 0.35) - 8.0 * sin(wx * 0.9)))
		x += 6.0
	pts.append(Vector2(size.x + 6.0, base))
	draw_colored_polygon(pts, _pal.hills)


func _draw_houses(size: Vector2) -> void:
	var houses: Array = _pal.houses
	var roofs: Array = _pal.roofs
	var base := ground_y - 6.0
	var win := Color("fff6e0")
	var first := int(floor(cam_x / HOUSE_SPACING_M)) - 1
	var last := int(ceil((cam_x + size.x / ppm) / HOUSE_SPACING_M)) + 1
	for i in range(first, last + 1):
		var h := absi(hash(i))
		var x0 := (i * HOUSE_SPACING_M - cam_x) * ppm
		var w := 5.0 * ppm
		var ht := (3.0 + float(h % 17) / 10.0) * ppm
		draw_rect(Rect2(x0, base - ht, w, ht), houses[h % houses.size()])
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0 - 4, base - ht), Vector2(x0 + w / 2, base - ht - 1.6 * ppm), Vector2(x0 + w + 4, base - ht)
		]), roofs[(h / 7) % roofs.size()])
		draw_rect(Rect2(x0 + 0.8 * ppm, base - ht + 0.8 * ppm, ppm, ppm), win)
		draw_rect(Rect2(x0 + w - 1.8 * ppm, base - ht + 0.8 * ppm, ppm, ppm), win)


func _draw_street(size: Vector2) -> void:
	draw_rect(Rect2(0, ground_y - 6, size.x, 16), _pal.sidewalk)
	draw_rect(Rect2(0, ground_y + 10, size.x, size.y - ground_y - 10), _pal.road)
	var dash := 4.0
	var wx := floorf(cam_x / dash) * dash
	while (wx - cam_x) * ppm < size.x:
		draw_rect(Rect2((wx - cam_x) * ppm, ground_y + 60, 1.6 * ppm, 3), _pal.lane)
		wx += dash


func _draw_objects(size: Vector2) -> void:
	if sim == null or sim.street == null:
		return
	var x0 := cam_x - 6.0
	var x1 := cam_x + size.x / ppm + 2.0
	for o in sim.street.objects_between(x0, x1):
		var def: Dictionary = sim.street.objects[o.id]
		var col := Color(def.get("color", "ffffff"))
		var p := world_to_screen(Vector2(o.x, 0.0))
		if def.kind == "helper":
			var h := float(def.height) * ppm
			var w := maxf(6.0, h * 0.7)
			draw_rect(Rect2(p.x - w / 2, p.y - h, w, h), col)
			draw_rect(Rect2(p.x - w / 2, p.y - h, w, 2), col.lightened(0.3))
		else:
			draw_rect(Rect2(p.x, p.y - 1, float(def.width) * ppm, 3), col)


func _draw_kid() -> void:
	var f := world_to_screen(Vector2(KID_X, 0))
	var pants := Color("2f3245")
	draw_rect(Rect2(f.x - 5, f.y - 24, 10, 12), Color("3f8fd6"))
	draw_circle(f + Vector2(0, -29), 5.0, Color("f2c79a"))
	draw_rect(Rect2(f.x - 5, f.y - 35, 10, 4), Color("3d2c2e"))
	draw_rect(Rect2(f.x - 4, f.y - 12, 3, 12), pants)
	if state == "aiming":
		draw_rect(Rect2(f.x + 1, f.y - 12, 3, 12), pants)
	else:
		draw_set_transform(f + Vector2(2, -12), -0.9, Vector2.ONE)
		draw_rect(Rect2(0, 0, 3, 12), pants)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


func _draw_can() -> void:
	var c := world_to_screen(sim.can_center())
	if c.y < 6.0:
		# Off the top of the screen: show a marker instead.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x, 2), Vector2(c.x - 4, 9), Vector2(c.x + 4, 9)]), Color("e63946"))
		return
	var w: float = stats.can_radius * 2.0 * ppm
	var h: float = stats.can_half_height * 2.0 * ppm
	draw_set_transform(c, sim.can.angle, Vector2(1.0 + 0.35 * _squash, 1.0 - 0.35 * _squash))
	draw_rect(Rect2(-w / 2, -h / 2, w, h), Color("e63946"))
	draw_rect(Rect2(-w / 2, -h / 2, w, 2), Color("e6e6e6"))
	draw_rect(Rect2(-w / 2, h / 2 - 2, w, 2), Color("bdbdbd"))
	draw_rect(Rect2(-w / 2 + 1, -1, w - 2, 2), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
