class_name ScreenBase
extends PanelContainer
## Full-screen menu panel with a centered column of labels and buttons.

var box: VBoxContainer


func _init() -> void:
	# Guard: subclasses call super(), and the base must only build once.
	if box:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.make()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)


func add_title(text: String, size: int = 24) -> Label:
	var l := add_label(text, size)
	l.add_theme_color_override("font_color", UiTheme.INK)
	return l


func add_label(text: String, size: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	box.add_child(l)
	return l


func add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	box.add_child(b)
	return b
