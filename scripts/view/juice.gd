class_name Juice
extends Node
## Hit-stop, screen shake and popups; uses real time so hit-stop never stalls itself.

const HITSTOP_SCALE := 0.05
const SHAKE_DECAY_PX_PER_S := 40.0

var shake_offset := Vector2.ZERO
var popup_layer: CanvasLayer
var _hitstop_left := 0.0
var _shake := 0.0
var _last_usec := 0
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


func popup(text: String, screen_pos: Vector2, color: Color, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("2f3245"))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(l)
	l.position = screen_pos - Vector2(60, size)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "position:y", l.position.y - 24.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tw.tween_callback(l.queue_free)
	return l


func burst(parent: Node, screen_pos: Vector2, color: Color, amount: int = 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.position = screen_pos
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)
	return p
