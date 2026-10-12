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


func _add_logo() -> void:
	var tex := UiTheme.atlas("ui", "logo")
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.custom_minimum_size = tex.get_size() if tex else Vector2(235, 30)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rect)


func set_coins(c: float) -> void:
	coins_label.text = NumFmt.format(c)


func set_best(m: float) -> void:
	best_label.text = "Best: %.1f m" % m
