class_name PerkPickScreen
extends ScreenBase

signal picked(perk: Dictionary)

const ARM_MS := 400
const POP_STEP_S := 0.08
const TEXT_WIDTH := 182

var buttons: Array[Button] = []
var heading: Label
var checkpoint_label: Label
var _shown_ms := 0


func _init() -> void:
	super()
	set_dim(0.55)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_spacer(80)
	heading = add_title("Pick a perk!", UiTheme.BIG)
	checkpoint_label = add_label("", UiTheme.SMALL, true)
	add_spacer(4)


## distance >= 0 shows the checkpoint line.
func show_perks(perks: Array, distance := -1.0) -> void:
	_shown_ms = Time.get_ticks_msec()
	checkpoint_label.text = "%d m checkpoint" % int(distance) if distance >= 0.0 else ""
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for i in perks.size():
		var perk: Dictionary = perks[i]
		var card := PerkCard.new()
		card.setup(perk)
		card.pressed.connect(func():
			if armed() and card.modulate.a > 0.0:
				picked.emit(perk))
		box.add_child(card)
		buttons.append(card)
		_pop_in(card, ARM_MS / 1000.0 + POP_STEP_S * i)


func armed() -> bool:
	return Time.get_ticks_msec() - _shown_ms >= ARM_MS


func _pop_in(card: Control, delay: float) -> void:
	card.modulate.a = 0.0
	card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
	card.scale = Vector2(0.7, 0.7)
	var tw := card.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_property(card, "modulate:a", 1.0, 0.01)
	tw.tween_property(card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A panel-styled button (lilac for rare and epic) with the perk icon, name and description.
class PerkCard extends Button:
	var perk: Dictionary

	func setup(p: Dictionary) -> void:
		perk = p
		var rare: bool = p.rarity != "common"
		theme_type_variation = "RareCard" if rare else "RowButton"
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_top = 6
		row.offset_right = -8
		row.offset_bottom = -9
		add_child(row)
		var ico := UiTheme.icon(p.id)
		ico.custom_minimum_size = Vector2(32, 32)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_SCALE
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ico)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var n := Label.new()
		n.text = p.name
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(n)
		var desc: String = ("%s · " % String(p.rarity).capitalize() if rare else "") + p.desc
		var d := Label.new()
		d.text = desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.add_theme_color_override("font_color", UiTheme.LILAC_DARK if rare else UiTheme.INK)
		col.add_child(d)
		var font := UiTheme.font()
		var nl := ceili(font.get_multiline_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, TEXT_WIDTH, UiTheme.SMALL).y / UiTheme.SMALL)
		var dl := ceili(font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, TEXT_WIDTH, UiTheme.SMALL).y / UiTheme.SMALL)
		var text_h := (nl + dl) * UiTheme.SMALL + (nl + dl - 2) * 3 + 4
		custom_minimum_size = Vector2(0, maxi(32, text_h) + 6 + 9)
