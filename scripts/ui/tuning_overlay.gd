class_name TuningOverlay
extends CanvasLayer
## Hidden live-tuning panel with latency readout; three-finger touch or F1 toggles it.

const KEYS: Array[String] = [
	"gravity", "air_drag", "launch_speed_max", "restitution_miss", "restitution_good",
	"restitution_perfect", "good_vx_keep", "perfect_vx_boost", "rekick_vy_min",
	"ground_friction", "perfect_window", "good_window", "tap_reach_m", "px_per_m",
]

signal visibility_toggled(open: bool)

var stats: Dictionary
var probe: LatencyProbe
var _readout: Label
var _export: TextEdit
var _value_labels := {}
var _touches := {}


func setup(p_stats: Dictionary, p_probe: LatencyProbe) -> void:
	stats = p_stats
	probe = p_probe


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.theme = UiTheme.build()
	panel.theme.default_font_size = 9
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_readout = Label.new()
	_readout.add_theme_color_override("font_color", Color.WHITE)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for k in KEYS:
		_add_row(rows, k)
	_export = TextEdit.new()
	_export.custom_minimum_size = Vector2(0, 90)
	_export.editable = false
	box.add_child(_export)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var copy := Button.new()
	copy.text = "Copy"
	copy.pressed.connect(func(): DisplayServer.clipboard_set(export_text()))
	buttons.add_child(copy)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(toggle)
	buttons.add_child(close)
	_refresh_export()


func _add_row(rows: VBoxContainer, key: String) -> void:
	var base: float = stats[key]
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(label)
	_value_labels[key] = label
	var slider := HSlider.new()
	slider.min_value = base * 0.25 if base > 0.0 else 0.0
	slider.max_value = base * 2.5 if base > 0.0 else 1.0
	slider.step = (slider.max_value - slider.min_value) / 200.0
	slider.value = base
	slider.value_changed.connect(func(v): set_value(key, v))
	rows.add_child(slider)
	_update_label(key)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			_touches.clear()
		elif event.pressed:
			_touches[event.index] = true
			if _touches.size() >= 3:
				toggle()
				get_viewport().set_input_as_handled()
		else:
			_touches.erase(event.index)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle()


func _process(_delta: float) -> void:
	if visible:
		_readout.text = readout_text()


func toggle() -> void:
	visible = not visible
	_touches.clear()
	if visible:
		if _readout:
			_readout.text = readout_text()
		_refresh_export()
	visibility_toggled.emit(visible)


func set_value(key: String, v: float) -> void:
	stats[key] = v
	_update_label(key)
	_refresh_export()


func export_text() -> String:
	var out := {}
	for k in KEYS:
		out[k] = stats[k]
	return JSON.stringify(out, "\t")


func readout_text() -> String:
	return "fps %d | frame avg %.1f max %.1f ms | input→frame avg %.1f max %.1f ms" % [
		int(Engine.get_frames_per_second()), probe.frame_avg_ms(), probe.frame_max_ms(),
		probe.input_avg_ms(), probe.input_max_ms()]


func _update_label(key: String) -> void:
	if _value_labels.has(key):
		_value_labels[key].text = "%s = %.3f" % [key, stats[key]]


func _refresh_export() -> void:
	if _export:
		_export.text = export_text()
