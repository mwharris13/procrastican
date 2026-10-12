class_name TitleScreen
extends ScreenBase

signal play
signal shop
signal settings

var coins_label: Label
var best_label: Label
var play_button: Button
var _coin_chip: Chip


func _init() -> void:
	super()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_spacer(48)
	_add_logo()
	add_label("Mild Littering", UiTheme.SMALL, true)
	add_spacer(2)
	_coin_chip = Chip.new(true, UiTheme.BIG)
	_coin_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_coin_chip)
	coins_label = _coin_chip.label
	best_label = add_label("", UiTheme.SMALL, true)
	add_spacer(24)
	play_button = add_button("Kick a can", func(): play.emit(), "primary")
	add_button("Shop", func(): shop.emit())
	add_spacer(2)
	add_button("Settings", func(): settings.emit(), "small")


# 16 px, two lines at x2: the 12-letter word is too wide on one line at that scale.
func _add_logo() -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(7 * 16 * 2, 35 * 2)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var l := Label.new()
	l.text = "PROCRAS\nTICAN"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(7 * 16, 35)
	l.scale = Vector2(2, 2)
	UiTheme.outlined(l, UiTheme.BIG, UiTheme.GOLD)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_constant_override("line_spacing", 3)
	l.add_theme_color_override("font_shadow_color", UiTheme.INK_DEEP)
	l.add_theme_constant_override("shadow_offset_y", 3)
	holder.add_child(l)


func set_coins(c: float) -> void:
	coins_label.text = NumFmt.format(c)


func set_best(m: float) -> void:
	best_label.text = "Best: %.1f m" % m
