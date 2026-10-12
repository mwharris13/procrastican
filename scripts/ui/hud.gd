class_name Hud
extends CanvasLayer
## In-run readouts: distance, combo, info line and a bottom message.

var root: Control
var distance_label: Label
var combo_label: Label
var info_label: Label
var message_label: Label


func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	distance_label = _label(Rect2(8, 8, 140, 20), HORIZONTAL_ALIGNMENT_LEFT, 16)
	combo_label = _label(Rect2(150, 8, 112, 20), HORIZONTAL_ALIGNMENT_RIGHT, 16)
	info_label = _label(Rect2(8, 30, 254, 16), HORIZONTAL_ALIGNMENT_LEFT, 10)
	message_label = _label(Rect2(10, 470, 250, 40), HORIZONTAL_ALIGNMENT_CENTER, 13)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(r: Rect2, align: HorizontalAlignment, size: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func set_distance(m: float) -> void:
	distance_label.text = "%.1f m" % m


func set_combo(n: int) -> void:
	combo_label.text = "x%d" % n if n > 0 else ""


func show_message(t: String) -> void:
	message_label.text = t


func show_info(t: String) -> void:
	info_label.text = t
