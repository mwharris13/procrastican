class_name UiTheme
extends RefCounted
## Shared placeholder theme; the art pass swaps in a pixel font.

const INK := Color("2f3245")
const GOLD := Color("ffd166")
const PAPER := Color("fff6e0")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", PAPER)
	t.set_constant("outline_size", "Label", 3)
	var normal := StyleBoxFlat.new()
	normal.bg_color = INK
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var pressed := normal.duplicate()
	pressed.bg_color = INK.lightened(0.2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(INK, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", Color(PAPER, 0.5))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fbe3c4")
	t.set_stylebox("panel", "PanelContainer", panel)
	return t
