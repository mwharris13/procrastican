class_name Main
extends Node2D
## Game flow: Title → Run (⇄ Perk pick) → Results → Shop / Settings, with saving and pause.

enum Screen { TITLE, RUN, PERK, RESULTS, SHOP, SETTINGS }

var save_path := SaveStore.DEFAULT_PATH
var data: GameData
var save: Dictionary
var stats: Dictionary = {}
var run_state: RunState
var modifier: Dictionary = {}
var run_perks: Array = []
var screen := Screen.TITLE
var juice: Juice
var sfx: Sfx
var probe := LatencyProbe.new()
var run_view: RunView
var hud: Hud
var overlay: TuningOverlay
var title: TitleScreen
var perk_pick: PerkPickScreen
var results: ResultsScreen
var shop: ShopScreen
var settings: SettingsScreen
var toast_label: Label
var pause_label: Label
var _rng := RandomNumberGenerator.new()
var _perks_pending := 0
var _bg_paused := false
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = GameData.load_all()
	save = SaveStore.load_from(save_path)
	juice = Juice.new()
	add_child(juice)
	sfx = Sfx.new()
	add_child(sfx)
	run_view = RunView.new()
	run_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run_view)
	run_view.setup(juice, sfx, probe)
	run_view.sim_event.connect(_on_sim_event)
	run_view.progressed.connect(_on_progressed)
	run_view.run_ended.connect(_on_run_ended)
	hud = Hud.new()
	add_child(hud)
	_build_menus()
	_build_notices()
	overlay = TuningOverlay.new()
	overlay.setup(data.tuning, probe)
	add_child(overlay)
	overlay.visibility_toggled.connect(_on_overlay_toggled)
	show_title()


func _build_menus() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	title = TitleScreen.new()
	perk_pick = PerkPickScreen.new()
	results = ResultsScreen.new()
	shop = ShopScreen.new()
	settings = SettingsScreen.new()
	for s in [title, perk_pick, results, shop, settings]:
		layer.add_child(s)
	title.play.connect(start_run)
	title.shop.connect(open_shop)
	title.settings.connect(open_settings)
	perk_pick.picked.connect(_on_perk_picked)
	results.again.connect(start_run)
	results.coin_tick.connect(func(progress: float): sfx.play("tick", 0.9 + 0.5 * progress))
	results.shop.connect(open_shop)
	shop.changed.connect(_persist)
	shop.back.connect(show_title)
	settings.back.connect(show_title)
	settings.imported.connect(_on_imported)


func _build_notices() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var theme := UiTheme.build()
	toast_label = Label.new()
	toast_label.theme = theme
	toast_label.position = Vector2(10, 540)
	toast_label.size = Vector2(250, 20)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.outlined(toast_label, UiTheme.SMALL)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)
	pause_label = Label.new()
	pause_label.theme = theme
	pause_label.text = "Paused.\nTap to resume."
	UiTheme.outlined(pause_label, UiTheme.BIG)
	pause_label.position = Vector2(10, 260)
	pause_label.size = Vector2(250, 40)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_label.visible = false
	layer.add_child(pause_label)


func _show(s: Screen) -> void:
	screen = s
	title.visible = s == Screen.TITLE
	perk_pick.visible = s == Screen.PERK
	results.visible = s == Screen.RESULTS
	shop.visible = s == Screen.SHOP
	settings.visible = s == Screen.SETTINGS
	hud.visible = s == Screen.RUN or s == Screen.PERK
	get_tree().paused = s == Screen.PERK


func show_title() -> void:
	title.set_coins(save.coins)
	title.set_best(save.best_distance)
	_show(Screen.TITLE)


func open_shop() -> void:
	shop.open(save, data)
	_show(Screen.SHOP)


func open_settings() -> void:
	settings.set_save(save)
	_show(Screen.SETTINGS)


func _resolve_stats() -> void:
	var effects: Array = Economy.profile_effects(save, data) + modifier.get("effects", [])
	for p in run_perks:
		effects += p.effects
	var fresh := StatResolver.resolve(data.tuning, effects)
	for k in fresh:
		stats[k] = fresh[k]


func start_run() -> void:
	_rng.seed = Time.get_ticks_usec()
	modifier = ModifierDeck.draw(data.modifiers, _rng)
	run_perks = []
	_perks_pending = 0
	_resolve_stats()
	run_state = RunState.new(stats, data.zones)
	var street := StreetGen.new(_rng.randi(), data.zones, data.objects, stats.helper_freq)
	run_view.set_zones(data.zones)
	run_view.can_sprite = save.equipped_can
	run_view.start_aim(stats, street)
	hud.set_distance(0.0)
	hud.set_combo(0)
	hud.show_info("%s: %s" % [modifier.get("name", ""), modifier.get("desc", "")])
	hud.show_message("Pull back and release to kick")
	_show(Screen.RUN)


func _on_sim_event(ev: Dictionary) -> void:
	match ev.type:
		"launch":
			hud.show_message("")
		"graded":
			run_state.on_grade(ev.grade)
			hud.set_combo(run_state.combo)
		"helper":
			run_state.on_helper(ev.combo)
			hud.set_combo(run_state.combo)


func _on_progressed(x: float) -> void:
	# RunView emits progressed after run_ended in the same tick.
	if screen != Screen.RUN and screen != Screen.PERK:
		return
	hud.set_distance(x)
	for ev in run_state.on_distance(x):
		if ev.type == "zone":
			var z: Dictionary = data.zones[ev.index]
			juice.popup("%s  x%s" % [z.name, NumFmt.format(float(z.value))], Vector2(135, 160), UiTheme.GOLD)
			sfx.play("coin")
		elif ev.type == "perk_due":
			_perks_pending += 1
	if _perks_pending > 0 and screen == Screen.RUN:
		_offer_perk()


func _offer_perk() -> void:
	var taken := run_perks.map(func(p): return p.id)
	var offers := PerkDeck.draw(data.perks, _rng, 3, taken, stats.rare_mult)
	if offers.is_empty():
		_perks_pending = 0
		return
	_perks_pending -= 1
	juice.end_hitstop()
	perk_pick.show_perks(offers, run_state.distance)
	_show(Screen.PERK)


func _on_perk_picked(perk: Dictionary) -> void:
	if screen != Screen.PERK:
		return
	var old_kicks := int(stats.air_kicks)
	run_perks.append(perk)
	_resolve_stats()
	if run_view.sim:
		run_view.sim.air_kicks_left += int(stats.air_kicks) - old_kicks
	sfx.play("ui")
	_show(Screen.RUN)
	if _perks_pending > 0:
		_offer_perk()


func _on_overlay_toggled(open: bool) -> void:
	if open:
		run_view.cancel_drag()
	run_view.input_enabled = not open


func _on_run_ended(_ev: Dictionary) -> void:
	var coins := run_state.coins()
	var record: bool = run_state.distance > save.best_distance
	save.coins += coins
	save.lifetime_coins += coins
	save.runs += 1
	save.best_distance = maxf(save.best_distance, run_state.distance)
	_persist()
	var zone: Dictionary = data.zones[run_state.zone_index]
	results.show_results(run_state.distance, run_state.best_combo, coins, record, run_state.perfects,
		"%s x%s" % [zone.name, NumFmt.format(float(zone.value))])
	sfx.play("coin")
	_show(Screen.RESULTS)


func _on_imported(d: Dictionary) -> void:
	save = d
	var ok := _persist()
	show_title()
	if ok:
		toast("Save imported")


func _persist() -> bool:
	var ok := SaveStore.save_to(save, save_path)
	if not ok:
		toast("Couldn't save progress")
	return ok


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = toast_label.create_tween().set_ignore_time_scale(true)
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		background_pause()


func background_pause() -> void:
	if juice:
		juice.end_hitstop()
	if screen == Screen.RUN and not _bg_paused:
		run_view.cancel_drag()
		_bg_paused = true
		get_tree().paused = true
		pause_label.visible = true


func resume() -> void:
	_bg_paused = false
	pause_label.visible = false
	get_tree().paused = screen == Screen.PERK


func _unhandled_input(event: InputEvent) -> void:
	if _bg_paused and event is InputEventScreenTouch and event.pressed:
		resume()
		get_viewport().set_input_as_handled()
