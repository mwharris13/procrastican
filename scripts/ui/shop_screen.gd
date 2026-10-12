class_name ShopScreen
extends ScreenBase
## Upgrade shop with Gear / Skills / Luck tabs; Gear also sells and equips cans.

signal back
signal changed

const TRACKS: Array[String] = ["gear", "skills", "luck"]

var save: Dictionary
var data: GameData
var coins_label: Label
var rows := {}
var _list: VBoxContainer
var _track := "gear"


func _init() -> void:
	super()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_title("Shop", 20)
	coins_label = add_label("", 14)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	for t in TRACKS:
		var track: String = t
		var b := Button.new()
		b.text = track.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): show_track(track))
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_button("Back", func(): back.emit())


func open(p_save: Dictionary, p_data: GameData) -> void:
	save = p_save
	data = p_data
	show_track(_track)


func show_track(track: String) -> void:
	_track = track
	for c in _list.get_children():
		c.queue_free()
	rows.clear()
	coins_label.text = "%s ¢" % NumFmt.format(save.coins)
	for def in data.upgrades:
		if def.track == track:
			_upgrade_row(def)
	if track == "gear":
		for c in data.cans:
			_can_row(c)


func _upgrade_row(def: Dictionary) -> void:
	var lvl := Economy.level_of(save, def.id)
	var maxed := Economy.is_maxed(def, lvl)
	var price := Economy.cost(def, lvl)
	var b := _row_button("%s  Lv %d\n%s  %s" % [def.name, lvl, def.desc, "MAX" if maxed else NumFmt.format(price) + " ¢"])
	b.disabled = maxed or save.coins < price
	b.pressed.connect(_on_buy.bind(def))
	rows[def.id] = b


func _can_row(c: Dictionary) -> void:
	var owned: bool = save.owned_cans.has(c.id)
	var equipped: bool = save.equipped_can == c.id
	var action := "Equipped" if equipped else ("Equip" if owned else NumFmt.format(float(c.cost)) + " ¢")
	var b := _row_button("%s\n%s  %s" % [c.name, c.desc, action])
	b.disabled = equipped or (not owned and save.coins < float(c.cost))
	b.pressed.connect(_on_can.bind(c))
	rows["can_" + c.id] = b


func _on_buy(def: Dictionary) -> void:
	if Economy.try_buy(save, def):
		changed.emit()
		show_track(_track)


func _on_can(c: Dictionary) -> void:
	var ok := Economy.equip_can(save, c.id) if save.owned_cans.has(c.id) else Economy.try_buy_can(save, c)
	if ok:
		changed.emit()
		show_track(_track)


func _row_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 11)
	_list.add_child(b)
	return b
