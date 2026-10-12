class_name Juice
extends Node
## Hit-stop, screen shake and popups; uses real time so hit-stop never stalls itself.

const HITSTOP_SCALE := 0.05
const SHAKE_DECAY_PX_PER_S := 40.0
const POPUP_WIDTH := 270

var shake_offset := Vector2.ZERO
var popup_layer: CanvasLayer
var _hitstop_left := 0.0
var _shake := 0.0
var _last_usec := 0
var _flashes: Array[FlashSprite] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	popup_layer = CanvasLayer.new()
	popup_layer.layer = 5
	add_child(popup_layer)
	_last_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	# Only restore when a hit-stop is active so an idle Juice leaves external time_scale alone.
	if _hitstop_left > 0.0:
		end_hitstop()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	advance_real((now - _last_usec) / 1_000_000.0)
	_last_usec = now


func advance_real(sec: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left -= sec
		if _hitstop_left <= 0.0:
			end_hitstop()
	# Advanced here on real time so flashes still play during hit-stop.
	for f in _flashes.duplicate():
		if not is_instance_valid(f):
			_flashes.erase(f)
			continue
		f.elapsed += sec
		if f.elapsed >= f.frames * f.frame_time:
			_flashes.erase(f)
			f.queue_free()
		else:
			f.queue_redraw()
	_shake = maxf(0.0, _shake - sec * SHAKE_DECAY_PX_PER_S)
	shake_offset = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake)).round()


func hitstop(duration: float) -> void:
	_hitstop_left = maxf(_hitstop_left, duration)
	Engine.time_scale = HITSTOP_SCALE


func end_hitstop() -> void:
	_hitstop_left = 0.0
	Engine.time_scale = 1.0


func shake(px: float) -> void:
	_shake = maxf(_shake, px)


func popup(text: String, screen_pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	l.add_theme_font_override("font", UiTheme.font())
	UiTheme.outlined(l, UiTheme.BIG, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(l)
	l.position = screen_pos - Vector2(POPUP_WIDTH / 2.0, UiTheme.BIG)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "position:y", l.position.y - 24.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tw.tween_callback(l.queue_free)
	return l


func burst(parent: Node, screen_pos: Vector2, sprite: String, amount: int = 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 260)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := SpriteBank.frame("fx", sprite)
	if not f.is_empty():
		var at := AtlasTexture.new()
		at.atlas = f.tex
		at.region = f.region
		p.texture = at
	p.position = screen_pos
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)
	return p


func flash(parent: Node, screen_pos: Vector2, sheet: String, base_name: String, frames: int, frame_time: float = 0.05) -> Node2D:
	var n := FlashSprite.new()
	n.sheet = sheet
	n.base_name = base_name
	n.frames = frames
	n.frame_time = frame_time
	n.position = screen_pos
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(n)
	_flashes.append(n)
	return n


class FlashSprite extends Node2D:
	var sheet := ""
	var base_name := ""
	var frames := 1
	var frame_time := 0.05
	var elapsed := 0.0

	func _draw() -> void:
		var i := mini(int(elapsed / frame_time), frames - 1)
		SpriteBank.draw(self, sheet, "%s#%d" % [base_name, i], Vector2.ZERO)
