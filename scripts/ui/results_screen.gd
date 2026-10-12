class_name ResultsScreen
extends ScreenBase

signal again
signal shop
## Emitted for each step of the coin count-up; progress runs 0..1 (drives sfx pitch).
signal coin_tick(progress: float)

# Ignore taps briefly so a player tapping as the can stops doesn't skip the results.
const ARM_MS := 400
const COUNT_SECONDS := 0.8
const COUNT_STEPS := 14

var distance_label: Label
var best_combo_label: Label
var perfects_label: Label
var zone_label: Label
var coins_label: Label
var stamp: TextureRect
var kid: KidPose
var again_button: Button
var shop_button: Button
var coins_target := 0.0
var _perfects_row: Control
var _zone_row: Control
var _shown_ms := 0
var _count_tween: Tween
var _last_step := 0


func _init() -> void:
	super()
	set_dim(0.45)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_spacer(52)
	begin_card()
	add_label("Can came to rest", UiTheme.SMALL)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 6)
	_target.add_child(head)
	distance_label = _label(UiTheme.BIG)
	head.add_child(distance_label)
	stamp = TextureRect.new()
	stamp.texture = UiTheme.atlas("ui", "new_best_stamp")
	stamp.stretch_mode = TextureRect.STRETCH_KEEP
	stamp.visible = false
	head.add_child(stamp)
	best_combo_label = _row("Best combo")
	perfects_label = _row("Perfects")
	_perfects_row = perfects_label.get_parent()
	zone_label = _row("Zone")
	_zone_row = zone_label.get_parent()
	coins_label = _row("Earned", UiTheme.BIG)
	end_card()
	add_spacer(8)
	again_button = add_button("Kick again", func():
		if armed():
			again.emit(), "primary")
	shop_button = add_button("Shop", func():
		if armed():
			shop.emit())
	kid = KidPose.new()
	add_child(kid)


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	return l


# A "name ..... value" row; returns the value label.
func _row(name: String, size: int = UiTheme.SMALL) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_target.add_child(row)
	var n := _label(size)
	n.text = name
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	var v := _label(size)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if size == UiTheme.BIG:
		var coin := TextureRect.new()
		coin.texture = UiTheme.atlas("ui", "coin_icon")
		coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(coin)
	row.add_child(v)
	return v


## perfects < 0 or an empty zone hides that row.
func show_results(distance: float, best_combo: int, coins: float, record: bool, perfects := -1, zone := "") -> void:
	_shown_ms = Time.get_ticks_msec()
	distance_label.text = "%.1f m" % distance
	best_combo_label.text = "x%d" % best_combo
	_perfects_row.visible = perfects >= 0
	perfects_label.text = str(perfects)
	_zone_row.visible = zone != ""
	zone_label.text = zone
	stamp.visible = record
	kid.pose = "cheer" if record else "shrug"
	coins_target = coins
	_start_count()
	if record:
		_slap_stamp()


func armed() -> bool:
	return Time.get_ticks_msec() - _shown_ms >= ARM_MS


## Jumps the coin count-up to its final value.
func finish_count() -> void:
	if _count_tween:
		_count_tween.kill()
	_set_count(coins_target)


func _start_count() -> void:
	if _count_tween:
		_count_tween.kill()
	_last_step = 0
	if coins_target <= 0.0 or not is_inside_tree():
		_set_count(coins_target)
		return
	_set_count(0.0)
	_count_tween = create_tween().set_ignore_time_scale(true)
	_count_tween.tween_method(_set_count, 0.0, coins_target, COUNT_SECONDS)


func _set_count(v: float) -> void:
	coins_label.text = "+" + NumFmt.format(v)
	var progress := clampf(v / coins_target, 0.0, 1.0) if coins_target > 0.0 else 1.0
	var step := int(progress * COUNT_STEPS)
	if step > _last_step:
		_last_step = step
		coin_tick.emit(progress)


func _slap_stamp() -> void:
	if not is_inside_tree():
		return
	stamp.pivot_offset = stamp.texture.get_size() / 2.0
	stamp.scale = Vector2(2, 2)
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.25)
	tw.tween_property(stamp, "modulate:a", 1.0, 0.01)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
