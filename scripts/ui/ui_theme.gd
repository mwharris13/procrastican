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
	return t
