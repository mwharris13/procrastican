class_name ScreenBase
extends PanelContainer
## Full-screen menu layer (optionally dimming the street) with a column of labels and buttons.

var box: VBoxContainer
var _target: Container


func _init() -> void:
	# Guard: subclasses call super(), and the base must only build once.
	if box:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.build()
	set_dim(0.0)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_target = box


## Dark plum veil over the live street; 0 leaves it clear.
func set_dim(alpha: float) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiTheme.INK_DEEP, alpha)
	add_theme_stylebox_override("panel", s)


## Later add_* calls go inside a new paper panel; returns the panel's column.
func begin_card() -> VBoxContainer:
	var card := PanelContainer.new()
	box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	_target = col
	return col


func end_card() -> void:
	_target = box


func add_spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return c


## Heading in light text with an ink outline (sits over the street or dim).
func add_title(text: String, size: int = UiTheme.BIG, color: Color = UiTheme.GOLD) -> Label:
	var l := add_label(text, size)
	UiTheme.outlined(l, size, color)
	return l


func add_label(text: String, size: int = UiTheme.SMALL, light := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	if light:
		UiTheme.outlined(l, size)
	_target.add_child(l)
	return l


## kind: "" regular (16 px), "primary" (accent fill), "small" (8 px, shrinks to fit).
func add_button(text: String, cb: Callable, kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	match kind:
		"primary":
			b.theme_type_variation = "PrimaryButton"
		"small":
			b.custom_minimum_size = Vector2(0, 28)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_:
			b.theme_type_variation = "BigButton"
	b.pressed.connect(cb)
	_target.add_child(b)
	return b
