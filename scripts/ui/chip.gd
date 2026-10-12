class_name Chip
extends PanelContainer
## Small paper tag holding a label, optionally led by a coin icon.

var label: Label


func _init(with_coin := false, size: int = UiTheme.SMALL) -> void:
	theme_type_variation = "Chip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	if with_coin:
		var coin := TextureRect.new()
		coin.texture = UiTheme.atlas("ui", "coin_icon")
		coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		coin.custom_minimum_size = Vector2(8, 8)
		row.add_child(coin)
	label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	row.add_child(label)


func set_text(t: String) -> void:
	label.text = t
