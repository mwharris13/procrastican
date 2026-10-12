class_name ResultsScreen
extends ScreenBase

signal again
signal shop

# Ignore taps briefly so a player tapping as the can stops doesn't skip the results.
const ARM_MS := 400

var summary: Label
var again_button: Button
var shop_button: Button
var _shown_ms := 0


func _init() -> void:
	super()
	add_title("Can came to rest", 20)
	summary = add_label("", 14)
	again_button = add_button("Kick again", func():
		if armed():
			again.emit())
	shop_button = add_button("Shop", func():
		if armed():
			shop.emit())


func show_results(distance: float, best_combo: int, coins: float, record: bool) -> void:
	_shown_ms = Time.get_ticks_msec()
	summary.text = "%s%.1f m\nBest combo x%d\n+%s ¢" % [
		"NEW RECORD!\n" if record else "", distance, best_combo, NumFmt.format(coins)]


func armed() -> bool:
	return Time.get_ticks_msec() - _shown_ms >= ARM_MS
