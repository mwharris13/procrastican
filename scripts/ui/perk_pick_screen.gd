class_name PerkPickScreen
extends ScreenBase

signal picked(perk: Dictionary)

var buttons: Array[Button] = []


func _init() -> void:
	super()
	add_title("Pick a perk", 20)


func show_perks(perks: Array) -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for p in perks:
		var perk: Dictionary = p
		var b := add_button("%s (%s)\n%s" % [perk.name, perk.rarity, perk.desc], func(): picked.emit(perk))
		b.custom_minimum_size = Vector2(0, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
