class_name UiTheme
extends RefCounted
## Golden Hour UI theme: Press Start 2P (sizes 8 and 16) and 9-slice sprites from the ui sheet.

const INK := Color("3b2d4a")
const INK_DEEP := Color("2b2140")
const GOLD := Color("ffd166")
const PAPER := Color("fff4e6")
const PAPER2 := Color("f6dcc6")
const ACCENT := Color("e5676a")
const ACCENT_DARK := Color("8a3b4a")
const TEAL := Color("5aa9a0")
const LILAC_DARK := Color("6a5687")
const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const SMALL := 8
const BIG := 16

static var _font: FontFile


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
	return _font


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = SMALL
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 3)
	_buttons(t)
	_panels(t)
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_border_width_all(2)
	box.border_color = INK
	box.set_content_margin_all(4)
	t.set_stylebox("normal", "TextEdit", box)
	t.set_stylebox("read_only", "TextEdit", box)
	t.set_stylebox("focus", "TextEdit", box)
	t.set_color("font_color", "TextEdit", INK)
	t.set_color("font_readonly_color", "TextEdit", INK)
	return t


## A region of a baked sheet as an AtlasTexture (null when the sprite is missing).
static func atlas(sheet: String, sprite: String) -> AtlasTexture:
	var f := SpriteBank.frame(sheet, sprite)
	if f.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = f.tex
	at.region = f.region
	return at


static func icon(id: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = atlas("icons", "icon_" + id)
	r.custom_minimum_size = Vector2(16, 16)
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Light text with an ink outline for labels that sit over the street.
static func outlined(l: Label, size: int, color: Color = PAPER) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4 if size >= BIG else 2)


static func _slice(sprite: String, margins: Array, content: Array) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = atlas("ui", sprite)
	s.texture_margin_left = margins[0]
	s.texture_margin_top = margins[1]
	s.texture_margin_right = margins[2]
	s.texture_margin_bottom = margins[3]
	s.content_margin_left = content[0]
	s.content_margin_top = content[1]
	s.content_margin_right = content[2]
	s.content_margin_bottom = content[3]
	return s


static func _button_styles(t: Theme, type: String, normal: String, pressed: String, disabled: String, font_size: int, color: Color, outline: Color) -> void:
	var m := [6, 6, 6, 9]
	t.set_stylebox("normal", type, _slice(normal, m, [8, 4, 8, 7]))
	t.set_stylebox("hover", type, _slice(normal, m, [8, 4, 8, 7]))
	t.set_stylebox("pressed", type, _slice(pressed, m, [8, 6, 8, 5]))
	t.set_stylebox("disabled", type, _slice(disabled, m, [8, 4, 8, 7]))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_font_size("font_size", type, font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, type, color)
	t.set_color("font_disabled_color", type, Color(INK, 0.5))
	t.set_color("font_outline_color", type, outline)
	t.set_constant("outline_size", type, 0 if outline == INK else 2)


static func _buttons(t: Theme) -> void:
	_button_styles(t, "Button", "button_normal", "button_pressed", "button_disabled", SMALL, INK, INK)
	for type in ["BigButton", "PrimaryButton", "TabOn", "TabOff", "RowButton"]:
		t.set_type_variation(type, "Button")
	_button_styles(t, "BigButton", "button_normal", "button_pressed", "button_disabled", BIG, INK, INK)
	_button_styles(t, "PrimaryButton", "button_primary_normal", "button_primary_pressed", "button_disabled", BIG, PAPER, ACCENT_DARK)
	t.set_color("font_disabled_color", "PrimaryButton", PAPER)
	# Folder tabs: the selected one is joined to the list, the others sit lower.
	for pair in [["TabOn", "tab_on"], ["TabOff", "tab_off"]]:
		var type: String = pair[0]
		var sprite: String = pair[1]
		for state in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(state, type, _slice(sprite, [6, 6, 6, 6], [6, 4 if sprite == "tab_on" else 6, 6, 4]))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_font_size("font_size", type, SMALL)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			t.set_color(c, type, INK)
	# Shop rows and perk cards are buttons that look like panels; their children draw the content.
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "RowButton", _slice("panel", [8, 8, 8, 8], [8, 6, 8, 9]))
	t.set_stylebox("pressed", "RowButton", _slice("panel", [8, 8, 8, 8], [8, 8, 8, 7]))
	t.set_stylebox("focus", "RowButton", StyleBoxEmpty.new())
	t.set_type_variation("RareCard", "RowButton")
	for state in ["normal", "hover", "disabled"]:
		t.set_stylebox(state, "RareCard", _slice("panel_rare", [8, 8, 8, 8], [8, 6, 8, 9]))
	t.set_stylebox("pressed", "RareCard", _slice("panel_rare", [8, 8, 8, 8], [8, 8, 8, 7]))
	t.set_stylebox("focus", "RareCard", StyleBoxEmpty.new())


static func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", _slice("panel", [8, 8, 8, 8], [10, 8, 10, 11]))
	t.set_type_variation("Chip", "PanelContainer")
	t.set_stylebox("panel", "Chip", _slice("chip", [5, 5, 5, 7], [6, 3, 6, 5]))
