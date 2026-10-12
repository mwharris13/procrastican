class_name Hud
extends CanvasLayer
## In-run readouts: distance chip, combo chip, modifier line and a bottom message.

var root: Control
var distance_label: Label
var combo_label: Label
var info_label: Label
var message_label: Label
var _combo_chip: Chip
var _message_chip: Chip


func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)
	var top := HBoxContainer.new()
	top.position = Vector2(8, 8)
	top.size = Vector2(254, 28)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var dist_chip := Chip.new(false, UiTheme.BIG)
	top.add_child(dist_chip)
	distance_label = dist_chip.label
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	_combo_chip = Chip.new(false, UiTheme.BIG)
	_combo_chip.visible = false
	top.add_child(_combo_chip)
	combo_label = _combo_chip.label
	info_label = _label(Rect2(8, 44, 254, 24), HORIZONTAL_ALIGNMENT_LEFT)
	_message_chip = Chip.new(false, UiTheme.SMALL)
	_message_chip.visible = false
	_message_chip.position = Vector2(135, 470)
	_message_chip.resized.connect(func(): _message_chip.position.x = (270 - _message_chip.size.x) / 2.0)
	root.add_child(_message_chip)
	message_label = _message_chip.label


func _label(r: Rect2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.outlined(l, UiTheme.SMALL)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func set_distance(m: float) -> void:
	distance_label.text = "%.1f m" % m


func set_combo(n: int) -> void:
	combo_label.text = "x%d" % n if n > 0 else ""
	_combo_chip.visible = n > 0


func show_message(t: String) -> void:
	message_label.text = t
	_message_chip.visible = t != ""
	_message_chip.reset_size()


func show_info(t: String) -> void:
	info_label.text = t
