class_name ShopScreen
extends ScreenBase
## Upgrade shop with Gear / Skills / Luck tabs; Gear also sells and equips cans.

signal back
signal changed

const TRACKS: Array[String] = ["gear", "skills", "luck"]
const MAX_PIPS := 5
const UNAFFORDABLE_ALPHA := 0.55

var save: Dictionary
var data: GameData
var coins_label: Label
var rows := {}
var tabs := {}
var _list: VBoxContainer
var _track := "gear"


func _init() -> void:
	super()
	set_dim(0.55)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Shop"
	UiTheme.outlined(title, UiTheme.BIG, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var chip := Chip.new(true)
	head.add_child(chip)
	coins_label = chip.label
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	box.add_child(tab_row)
	for t in TRACKS:
		var track: String = t
		var b := Button.new()
		b.text = track.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 28)
		b.pressed.connect(func(): show_track(track))
		tab_row.add_child(b)
		tabs[track] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	add_button("Back", func(): back.emit())


func open(p_save: Dictionary, p_data: GameData) -> void:
	save = p_save
	data = p_data
	show_track(_track)


func show_track(track: String) -> void:
	_track = track
	for t in tabs:
		tabs[t].theme_type_variation = "TabOn" if t == track else "TabOff"
	for c in _list.get_children():
		c.queue_free()
	rows.clear()
	coins_label.text = NumFmt.format(save.coins)
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
	var row := ShopRow.new()
	row.setup(def.id, def.name, def.desc, "MAX" if maxed else NumFmt.format(price), not maxed, lvl, int(def.max_level))
	_add_row(row, def.id, maxed or save.coins < price, maxed)
	row.pressed.connect(_on_buy.bind(def))


func _can_row(c: Dictionary) -> void:
	var owned: bool = save.owned_cans.has(c.id)
	var equipped: bool = save.equipped_can == c.id
	var row := ShopRow.new()
	if owned:
		row.setup(c.id, c.name, c.desc, "Equipped" if equipped else "Equip", false, -1, 0)
	else:
		row.setup(c.id, c.name, c.desc, NumFmt.format(float(c.cost)), true, -1, 0)
	_add_row(row, "can_" + c.id, equipped or (not owned and save.coins < float(c.cost)), owned)
	row.pressed.connect(_on_can.bind(c))


func _add_row(row: ShopRow, key: String, disabled: bool, settled: bool) -> void:
	row.disabled = disabled
	# Only rows you can't afford fade; maxed, equipped and owned rows stay solid.
	if disabled and not settled:
		row.modulate.a = UNAFFORDABLE_ALPHA
	_list.add_child(row)
	rows[key] = row


func _on_buy(def: Dictionary) -> void:
	if Economy.try_buy(save, def):
		changed.emit()
		show_track(_track)


func _on_can(c: Dictionary) -> void:
	var ok := Economy.equip_can(save, c.id) if save.owned_cans.has(c.id) else Economy.try_buy_can(save, c)
	if ok:
		changed.emit()
		show_track(_track)


## A panel-styled button: icon, name, level pips, price, then the description underneath.
class ShopRow extends Button:
	const DESC_WIDTH := 222
	var price_label: Label
	var name_label: Label

	func setup(id: String, p_name: String, desc: String, price: String, coin: bool, level: int, max_level: int) -> void:
		theme_type_variation = "RowButton"
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 4)
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 8
		col.offset_top = 6
		col.offset_right = -8
		col.offset_bottom = -9
		add_child(col)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 6)
		col.add_child(top)
		top.add_child(UiTheme.icon(id))
		var mid := VBoxContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_theme_constant_override("separation", 3)
		top.add_child(mid)
		name_label = _text(p_name)
		mid.add_child(name_label)
		if level >= 0:
			mid.add_child(_pips(level, max_level))
		var pr := HBoxContainer.new()
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_theme_constant_override("separation", 3)
		pr.alignment = BoxContainer.ALIGNMENT_END
		top.add_child(pr)
		if coin:
			var c := TextureRect.new()
			c.texture = UiTheme.atlas("ui", "coin_icon")
			c.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pr.add_child(c)
		price_label = _text(price)
		pr.add_child(price_label)
		var d := _text(desc)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		var lines := maxi(1, ceili(UiTheme.font().get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, DESC_WIDTH, UiTheme.SMALL).y / UiTheme.SMALL))
		custom_minimum_size = Vector2(0, 6 + 17 + 4 + lines * UiTheme.SMALL + (lines - 1) * 3 + 9)

	func _text(t: String) -> Label:
		var l := Label.new()
		l.text = t
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func _pips(level: int, max_level: int) -> Control:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		for i in mini(MAX_PIPS, max_level):
			var p := TextureRect.new()
			p.texture = UiTheme.atlas("ui", "pip_on" if i < level else "pip_off")
			p.stretch_mode = TextureRect.STRETCH_KEEP
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(p)
		if level > MAX_PIPS:
			row.add_child(_text("+%d" % (level - MAX_PIPS)))
		return row
