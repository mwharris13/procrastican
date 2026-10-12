class_name TitleScreen
extends ScreenBase

signal play
signal shop
signal settings

var coins_label: Label
var best_label: Label
var play_button: Button


func _init() -> void:
	super()
	add_title("PROCRASTICAN", 28)
	add_label("Mild Littering", 12)
	coins_label = add_label("", 14)
	best_label = add_label("", 11)
	play_button = add_button("Kick a can", func(): play.emit())
	add_button("Shop", func(): shop.emit())
	add_button("Settings", func(): settings.emit())


func set_coins(c: float) -> void:
	coins_label.text = "%s ¢" % NumFmt.format(c)


func set_best(m: float) -> void:
	best_label.text = "Best: %.1f m" % m
