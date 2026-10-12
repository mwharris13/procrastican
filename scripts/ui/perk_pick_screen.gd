class_name PerkPickScreen
extends ScreenBase

signal picked(perk: Dictionary)

const ARM_MS := 400

var buttons: Array[Button] = []
var _shown_ms := 0


func _init() -> void:
	super()
	add_title("Pick a perk", 20)


func show_perks(perks: Array) -> void:
	_shown_ms = Time.get_ticks_msec()
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for p in perks:
		var perk: Dictionary = p
		var b := add_button("%s (%s)\n%s" % [perk.name, perk.rarity, perk.desc], func():
			if armed():
				picked.emit(perk))
		b.custom_minimum_size = Vector2(0, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)


func armed() -> bool:
	return Time.get_ticks_msec() - _shown_ms >= ARM_MS
